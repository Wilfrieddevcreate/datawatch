package net.alopro.datawatch.usage

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Pont entre Flutter et les statistiques réseau d'Android.
 *
 * Les requêtes NetworkStatsManager sont bloquantes : elles tournent sur un
 * thread dédié et le résultat est renvoyé sur le thread principal.
 */
class DataUsageChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val reader = NetworkUsageReader(activity.applicationContext)
    private val resolver = AppResolver(activity.applicationContext)
    private val screenTime = ScreenTimeReader(activity.applicationContext)

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsageAccess" -> result.success(UsageAccess.isGranted(activity))
            "openUsageAccessSettings" -> result.success(openUsageAccessSettings())
            "getDeviceTotals" -> {
                val start = call.longArg("start")
                val end = call.longArg("end")
                runAsync(result) { reader.deviceTotals(start, end) }
            }
            "getAppUsage" -> {
                val network = NetworkUsageReader.Network.fromName(call.argument<String>("network"))
                val start = call.longArg("start")
                val end = call.longArg("end")
                runAsync(result) {
                    reader.usageByUid(network, start, end).map { resolver.describe(it) }
                }
            }
            "getAppUsageByRange" -> {
                val network = NetworkUsageReader.Network.fromName(call.argument<String>("network"))
                val uid = call.argument<Int>("uid")
                val ranges = call.argument<List<List<Number>>>("ranges")
                if (uid == null || ranges == null) {
                    result.error("BAD_ARGS", "uid ou ranges manquant", null)
                    return
                }
                val windows = ranges.map { longArrayOf(it[0].toLong(), it[1].toLong()) }
                runAsync(result) { reader.usageForUidByRange(network, uid, windows) }
            }
            "getScreenTime" -> {
                val start = call.longArg("start")
                val end = call.longArg("end")
                runAsync(result) { screenTime.foregroundTime(start, end) }
            }
            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName == null) {
                    result.error("BAD_ARGS", "packageName manquant", null)
                    return
                }
                val size = call.argument<Int>("size") ?: DEFAULT_ICON_SIZE
                runAsync(result) { resolver.iconPng(packageName, size) }
            }
            else -> result.notImplemented()
        }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: SecurityException) {
                mainHandler.post { result.error("NO_USAGE_ACCESS", e.message, null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("QUERY_FAILED", e.message, null) }
            }
        }
    }

    /**
     * Ouvre directement la page de DataWatch quand le système le permet,
     * sinon la liste générale « Accès aux données d'utilisation ».
     */
    private fun openUsageAccessSettings(): Boolean {
        val direct = Intent(
            Settings.ACTION_USAGE_ACCESS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        )
        val generic = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        for (intent in listOf(direct, generic)) {
            try {
                activity.startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // Essai suivant.
            }
        }
        return false
    }

    private fun MethodCall.longArg(name: String): Long =
        (argument<Number>(name) ?: throw IllegalArgumentException("$name manquant")).toLong()

    companion object {
        const val CHANNEL = "net.alopro.datawatch/usage"
        private const val DEFAULT_ICON_SIZE = 96
    }
}
