package net.alopro.datawatch.alerts

import android.app.NotificationManager
import android.content.Context
import net.alopro.datawatch.usage.NetworkUsageReader
import net.alopro.datawatch.usage.UsageAccess

/**
 * Compare la consommation mobile depuis le début du forfait aux seuils.
 * Appelé par le Worker (application fermée) et par Flutter après chaque
 * actualisation.
 */
object AlertChecker {

    /** Seuils notifiés lors de cette vérification (vide le plus souvent). */
    @Synchronized
    fun run(context: Context, now: Long = System.currentTimeMillis()): List<Int> {
        val config = AlertConfig.load(context) ?: return emptyList()
        if (!config.enabled || !config.hasPlan) return emptyList()
        if (now <= config.start || now >= config.end) return emptyList()
        if (!UsageAccess.isGranted(context)) return emptyList()
        val notifications = context.getSystemService(NotificationManager::class.java)
        if (!notifications.areNotificationsEnabled()) return emptyList()

        val used = NetworkUsageReader(context).deviceTotals(config.start, now)["mobileBytes"]
            ?: return emptyList()
        val reached = config.thresholds.filter { used * 100 >= config.volumeBytes * it }
        val fresh = reached.filterNot { it in config.notified }
        if (fresh.isEmpty()) return emptyList()

        // Un seul message, pour le seuil le plus haut : pas de rafale si
        // plusieurs seuils sont franchis entre deux vérifications.
        AlertNotifier.show(context, fresh.max(), used, config)
        AlertConfig.save(context, config.copy(notified = config.notified + reached))
        return fresh
    }
}
