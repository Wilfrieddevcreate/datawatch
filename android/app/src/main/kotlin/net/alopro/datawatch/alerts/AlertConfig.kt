package net.alopro.datawatch.alerts

import android.content.Context

/**
 * Ce que le Worker doit surveiller, recopié depuis Flutter à chaque
 * changement du forfait ou des réglages. Stocké à part des préférences
 * Flutter pour que le Worker n'en dépende pas.
 */
data class AlertConfig(
    val enabled: Boolean,
    val start: Long,
    val end: Long,
    val volumeBytes: Long,
    val thresholds: List<Int>,
    /** « auto », « mo » ou « go » : unités choisies dans les paramètres. */
    val units: String,
    /** Seuils déjà notifiés pour ce forfait : une seule notification par seuil. */
    val notified: Set<Int> = emptySet(),
) {
    val hasPlan: Boolean get() = volumeBytes > 0 && end > start

    /** Change si le forfait change : les seuils notifiés repartent de zéro. */
    val planKey: String get() = "$start|$end|$volumeBytes"

    companion object {
        private const val PREFS = "datawatch_alerts"

        fun load(context: Context): AlertConfig? {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (!p.contains("enabled")) return null
            return AlertConfig(
                enabled = p.getBoolean("enabled", false),
                start = p.getLong("start", 0),
                end = p.getLong("end", 0),
                volumeBytes = p.getLong("volume", 0),
                thresholds = p.getString("thresholds", "").orEmpty()
                    .split(',').mapNotNull { it.toIntOrNull() },
                units = p.getString("units", "auto") ?: "auto",
                notified = p.getString("notified", "").orEmpty()
                    .split(',').mapNotNull { it.toIntOrNull() }.toSet(),
            )
        }

        fun save(context: Context, config: AlertConfig) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("enabled", config.enabled)
                .putLong("start", config.start)
                .putLong("end", config.end)
                .putLong("volume", config.volumeBytes)
                .putString("thresholds", config.thresholds.joinToString(","))
                .putString("units", config.units)
                .putString("notified", config.notified.joinToString(","))
                .apply()
        }

        fun clear(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        }
    }
}
