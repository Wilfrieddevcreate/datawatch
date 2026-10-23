package net.alopro.datawatch.usage

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context

/**
 * Temps passé au premier plan par application, avec la même autorisation
 * « Accès aux données d'utilisation » que les statistiques réseau.
 *
 * Sur les derniers jours, on reconstitue les sessions à partir du journal
 * d'événements d'Android (ouverture, fermeture, écran éteint) : c'est précis à
 * la seconde. Android ne garde ce journal que quelques jours ; au-delà, on
 * additionne ses totaux quotidiens, plus approximatifs aux bords de la période.
 */
class ScreenTimeReader(context: Context) {

    private val usage = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

    /** Millisecondes au premier plan, par nom de paquet. */
    fun foregroundTime(start: Long, end: Long): Map<String, Long> {
        val eventsKeptSince = System.currentTimeMillis() - EVENTS_RETENTION_MS
        val totals = if (start >= eventsKeptSince) fromEvents(start, end) else fromDailyStats(start, end)
        return totals.filterValues { it > 0 }
    }

    private fun fromEvents(start: Long, end: Long): Map<String, Long> {
        val totals = HashMap<String, Long>()
        // Activités ouvertes par paquet : une appli reste au premier plan tant
        // qu'il lui en reste une (passage d'un écran à l'autre, multi-fenêtre).
        val open = HashMap<String, MutableSet<String>>()
        val since = HashMap<String, Long>()
        val seen = HashSet<String>()

        fun close(pkg: String, at: Long) {
            val from = since.remove(pkg) ?: return
            totals[pkg] = (totals[pkg] ?: 0L) + (at - from).coerceAtLeast(0L)
        }

        val events = usage.queryEvents(start, end)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            val at = event.timeStamp
            when (event.eventType) {
                RESUMED -> {
                    val activities = open.getOrPut(pkg) { HashSet() }
                    if (activities.isEmpty()) since[pkg] = at
                    activities.add(event.className.orEmpty())
                }
                PAUSED -> {
                    val activities = open[pkg]
                    if (activities.isNullOrEmpty()) {
                        // Déjà ouverte au début de la période : on compte depuis le début.
                        if (pkg !in seen) totals[pkg] = (totals[pkg] ?: 0L) + (at - start).coerceAtLeast(0L)
                    } else {
                        activities.remove(event.className.orEmpty())
                        if (activities.isEmpty()) close(pkg, at)
                    }
                }
                SCREEN_OFF, SHUTDOWN -> {
                    for (openPkg in since.keys.toList()) close(openPkg, at)
                    open.clear()
                }
            }
            seen.add(pkg)
        }
        // Encore à l'écran à la fin de la période.
        for (pkg in since.keys.toList()) close(pkg, end)
        return totals
    }

    private fun fromDailyStats(start: Long, end: Long): Map<String, Long> =
        usage.queryAndAggregateUsageStats(start, end).mapValues { it.value.totalTimeInForeground }

    companion object {
        /** Prudence : Android garde le journal d'événements au moins 7 jours. */
        private const val EVENTS_RETENTION_MS = 6L * 24 * 60 * 60 * 1000

        // Valeurs stables de UsageEvents.Event, disponibles sous ces numéros
        // dès Android 7 (les noms ACTIVITY_* datent d'Android 10).
        private const val RESUMED = 1
        private const val PAUSED = 2
        private const val SCREEN_OFF = 16
        private const val SHUTDOWN = 26
    }
}
