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
 * - le subscriberId est nul : depuis Android 10, une application ordinaire ne
 *   peut pas lire l'identifiant de la SIM. Les données mobiles sont donc le
 *   total de toutes les SIM ;
 * - Android regroupe les compteurs par tranches d'environ deux heures : une
 *   période qui commence au milieu d'une tranche peut inclure un peu de
 *   consommation antérieure.
 */
@Suppress("DEPRECATION") // NetworkStatsManager attend toujours ConnectivityManager.TYPE_*.
class NetworkUsageReader(context: Context) {

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

    /** Totaux de l'appareil. Une valeur nulle signifie « mesure indisponible ». */
    fun deviceTotals(start: Long, end: Long): Map<String, Long?> = mapOf(
        "mobileBytes" to deviceBytes(Network.MOBILE, start, end),
        "wifiBytes" to deviceBytes(Network.WIFI, start, end),
    )

    private fun deviceBytes(network: Network, start: Long, end: Long): Long? = try {
        val bucket = stats.querySummaryForDevice(network.type, null, start, end)
        bucket.rxBytes + bucket.txBytes
    } catch (_: RemoteException) {
        null
    }

    /** Consommation par uid (une application = un uid, sauf uid partagés). */
    fun usageByUid(network: Network, start: Long, end: Long): List<UidUsage> {
        val totals = HashMap<Int, LongArray>()
        val summary = stats.querySummary(network.type, null, start, end)
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
        val details = stats.queryDetailsForUid(
            network.type,
            null,
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
        return out.toList()
    }
}
