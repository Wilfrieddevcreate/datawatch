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
import net.alopro.datawatch.usage.MobileSubscribers
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Ce qui touche au système hors statistiques : permissions, écrans de
 * réglages, liens, version, et configuration des alertes en arrière-plan.
 */
class DeviceChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val context get() = activity.applicationContext

    /** Demandes de permission en attente de réponse, par code de requête. */
    private val pendingPermissions = HashMap<Int, MethodChannel.Result>()

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
            "requestNotificationPermission" ->
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || notificationsAllowed()) {
                    result.success(notificationsAllowed())
                } else {
                    request(Manifest.permission.POST_NOTIFICATIONS, REQUEST_NOTIFICATIONS, result)
                }
            "phonePermissionNeeded" -> result.success(MobileSubscribers.permissionMissing(context))
            "requestPhonePermission" ->
                if (!MobileSubscribers.permissionMissing(context)) {
                    result.success(true)
                } else {
                    request(Manifest.permission.READ_PHONE_STATE, REQUEST_PHONE, result)
                }
            "openNotificationSettings" -> result.success(start(notificationSettings(), appDetails(activity.packageName)))
            "backgroundUnrestricted" -> result.success(backgroundUnrestricted())
            "openBatterySettings" -> result.success(
                start(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS), appDetails(activity.packageName)),
            )
            "openAppSettings" -> {
                val pkg = call.argument<String>("packageName") ?: activity.packageName
                result.success(start(appDetails(pkg)))
            }
            "openUrl" -> {
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("BAD_ARGS", "url manquante", null)
                } else {
                    val uri = Uri.parse(url)
                    val action = if (uri.scheme == "mailto") Intent.ACTION_SENDTO else Intent.ACTION_VIEW
                    result.success(start(Intent(action, uri)))
                }
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
        val result = pendingPermissions.remove(requestCode) ?: return
        result.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
    }

    private fun request(permission: String, code: Int, result: MethodChannel.Result) {
        if (pendingPermissions.containsKey(code)) {
            result.error("BUSY", "Demande déjà en cours", null)
            return
        }
        pendingPermissions[code] = result
        activity.requestPermissions(arrayOf(permission), code)
    }

    private fun notificationsAllowed(): Boolean =
        context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    /** Vrai si Android ne restreint pas DataWatch en arrière-plan (alertes à l'heure). */
    private fun backgroundUnrestricted(): Boolean =
        context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(activity.packageName)

    private fun notificationSettings(): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
        } else {
            appDetails(activity.packageName)
        }

    private fun appVersion(): String {
        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return "${info.versionName} ($code)"
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
        private const val REQUEST_PHONE = 4202
    }
}
