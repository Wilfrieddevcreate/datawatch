package net.alopro.datawatch.device

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import net.alopro.datawatch.alerts.AlertChecker
import net.alopro.datawatch.alerts.AlertConfig
import net.alopro.datawatch.alerts.AlertScheduler
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Ce qui touche au système hors statistiques : permissions, écrans de
 * réglages, version, et configuration des alertes en arrière-plan.
 */
class DeviceChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val context get() = activity.applicationContext
    private var pendingPermission: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "notificationsAllowed" -> result.success(notificationsAllowed())
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "openNotificationSettings" -> result.success(
                start(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName),
                    appDetails(activity.packageName),
                ),
            )
            "backgroundUnrestricted" -> result.success(backgroundUnrestricted())
            "openBatterySettings" -> result.success(
                start(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS), appDetails(activity.packageName)),
            )
            "openAppSettings" -> {
                val pkg = call.argument<String>("packageName") ?: activity.packageName
                result.success(start(appDetails(pkg)))
            }
            "appVersion" -> result.success(appVersion())
            "configureAlerts" -> {
                AlertScheduler.configure(context, alertConfig(call))
                result.success(null)
            }
            "checkAlertsNow" -> executor.execute {
                // Une exception non rattrapée sur ce thread ferait planter l'application.
                val notified = try {
                    AlertChecker.run(context)
                } catch (_: Exception) {
                    emptyList()
                }
                mainHandler.post { result.success(notified) }
            }
            "clearAlerts" -> {
                AlertScheduler.clear(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** À relayer depuis MainActivity.onRequestPermissionsResult. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_NOTIFICATIONS) return
        val result = pendingPermission ?: return
        pendingPermission = null
        result.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
    }

    private fun notificationsAllowed(): Boolean =
        context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || notificationsAllowed()) {
            result.success(notificationsAllowed())
            return
        }
        if (pendingPermission != null) {
            result.error("BUSY", "Demande déjà en cours", null)
            return
        }
        pendingPermission = result
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    /** Vrai si Android ne restreint pas DataWatch en arrière-plan (alertes à l'heure). */
    private fun backgroundUnrestricted(): Boolean =
        context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(activity.packageName)

    private fun appVersion(): String {
        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
        return "${info.versionName} (${info.longVersionCode})"
    }

    private fun alertConfig(call: MethodCall) = AlertConfig(
        enabled = call.argument<Boolean>("enabled") ?: false,
        start = call.argument<Number>("start")?.toLong() ?: 0,
        end = call.argument<Number>("end")?.toLong() ?: 0,
        volumeBytes = call.argument<Number>("volumeBytes")?.toLong() ?: 0,
        thresholds = call.argument<List<Number>>("thresholds")?.map { it.toInt() }.orEmpty(),
        units = call.argument<String>("units") ?: "auto",
    )

    private fun appDetails(packageName: String) =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))

    /** Ouvre le premier écran disponible parmi [intents]. */
    private fun start(vararg intents: Intent): Boolean {
        for (intent in intents) {
            try {
                activity.startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // Écran absent sur ce constructeur : essai suivant.
            }
        }
        return false
    }

    companion object {
        const val CHANNEL = "net.alopro.datawatch/device"
        private const val REQUEST_NOTIFICATIONS = 4201
    }
}
