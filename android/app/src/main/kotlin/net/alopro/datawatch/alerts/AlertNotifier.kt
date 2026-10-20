package net.alopro.datawatch.alerts

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import net.alopro.datawatch.R

/** Notification d'un seuil atteint. Le texte rappelle qu'il s'agit d'une estimation. */
object AlertNotifier {
    private const val CHANNEL_ID = "consumption_alerts"
    private const val NOTIFICATION_BASE_ID = 1000
    private const val INK = 0xFF10131A.toInt()

    fun show(context: Context, threshold: Int, usedBytes: Long, config: AlertConfig) {
        val manager = context.getSystemService(NotificationManager::class.java)
        ensureChannel(manager)

        val volume = DataFormat.bytes(config.volumeBytes, config.units)
        val remaining = DataFormat.bytes(config.volumeBytes - usedBytes, config.units)
        val title: String
        val text: String
        if (threshold >= 100) {
            title = "Forfait épuisé (estimation)"
            text = "Votre forfait de $volume semble épuisé, selon la mesure de ce téléphone."
        } else {
            title = "Seuil de $threshold % atteint"
            text = "Il reste environ $remaining sur $volume, jusqu’au ${DataFormat.dayMonthTime(config.end)}."
        }
        val details = "$text\nEstimation mesurée par ce téléphone : ce n’est pas le solde officiel de l’opérateur."

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            // Android 7 : pas de canaux, l'importance passe par la priorité.
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_datawatch)
            .setColor(INK)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(details))
            .setContentIntent(openApp(context, threshold))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_STATUS)
            .build()
        manager.notify(NOTIFICATION_BASE_ID + threshold, notification)
    }

    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Alertes de consommation",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = "Seuils atteints sur votre forfait déclaré" }
        manager.createNotificationChannel(channel)
    }

    private fun openApp(context: Context, requestCode: Int): PendingIntent? {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            ?: return null
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
