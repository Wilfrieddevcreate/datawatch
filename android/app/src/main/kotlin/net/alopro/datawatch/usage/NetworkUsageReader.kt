package net.alopro.datawatch.usage

import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.net.ConnectivityManager
import android.os.RemoteException

/**
 * Lecture des compteurs réseau tenus par Android.
 *
 * Limites à connaître :
 * - les données mobiles sont le total de toutes les SIM (voir [MobileSubscribers]) ;
 * - Android regroupe les compteurs par tranches d'environ deux heures : une
 *   période qui commence au milieu d'une tranche en reçoit une part au prorata.
 */
@Suppress("DEPRECATION") // NetworkStatsManager attend toujours ConnectivityManager.TYPE_*.
class NetworkUsageReader(private val context: Context) {

    enum class Network(val type: Int) {
        MOBILE(ConnectivityManager.TYPE_MOBILE),
        WIFI(ConnectivityManager.TYPE_WIFI);

        companion object {
            fun fromName(name: String?): Network = when (name) {
                "wifi" -> WIFI
                else -> MOBILE
            }
        }
    }

    data class UidUsage(val uid: Int, val rxBytes: Long, val txBytes: Long)

    private val stats = context.getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager

    /** Identifiants à interroger : toutes les SIM en mobile, aucun en Wi-Fi. */
    private fun subscribers(network: Network): List<String?> =
        if (network == Network.MOBILE) MobileSubscribers.ids(context) else listOf(null)

    /** Totaux de l'appareil. Une valeur nulle signifie « mesure indisponible ». */
    fun deviceTotals(start: Long, end: Long): Map<String, Long?> = mapOf(
        "mobileBytes" to deviceBytes(Network.MOBILE, start, end),
        "wifiBytes" to deviceBytes(Network.WIFI, start, end),
    )

    private fun deviceBytes(network: Network, start: Long, end: Long): Long? = try {
        subscribers(network).sumOf { id ->
            val bucket = stats.querySummaryForDevice(network.type, id, start, end)
            bucket.rxBytes + bucket.txBytes
        }
    } catch (_: RemoteException) {
        null
    }

    /** Consommation par uid (une application = un uid, sauf uid partagés). */
    fun usageByUid(network: Network, start: Long, end: Long): List<UidUsage> {
        val totals = HashMap<Int, LongArray>()
        for (id in subscribers(network)) {
            val summary = stats.querySummary(network.type, id, start, end)
            try {
                val bucket = NetworkStats.Bucket()
                while (summary.hasNextBucket()) {
                    summary.getNextBucket(bucket)
                    val acc = totals.getOrPut(bucket.uid) { LongArray(2) }
                    acc[0] += bucket.rxBytes
                    acc[1] += bucket.txBytes
                }
            } finally {
                summary.close()
            }
        }
        return totals
            .map { (uid, bytes) -> UidUsage(uid, bytes[0], bytes[1]) }
            .filter { it.rxBytes + it.txBytes > 0 }
    }

    /**
     * Consommation d'un uid répartie sur des fenêtres [début, fin[ (des jours,
     * pour le graphique). Une tranche Android à cheval sur deux fenêtres est
     * partagée au prorata du temps.
     */
    fun usageForUidByRange(network: Network, uid: Int, ranges: List<LongArray>): List<Long> {
        if (ranges.isEmpty()) return emptyList()
        val out = LongArray(ranges.size)
        for (id in subscribers(network)) {
            val details = stats.queryDetailsForUid(
                network.type,
                id,
                ranges.minOf { it[0] },
                ranges.maxOf { it[1] },
                uid,
            )
            try {
                val bucket = NetworkStats.Bucket()
                while (details.hasNextBucket()) {
                    details.getNextBucket(bucket)
                    val bytes = bucket.rxBytes + bucket.txBytes
                    val span = (bucket.endTimeStamp - bucket.startTimeStamp).coerceAtLeast(1)
                    ranges.forEachIndexed { i, range ->
                        val overlap = minOf(bucket.endTimeStamp, range[1]) - maxOf(bucket.startTimeStamp, range[0])
                        if (overlap > 0) out[i] += bytes * overlap / span
                    }
                }
            } finally {
                details.close()
            }
        }
        return out.toList()
    }
}
