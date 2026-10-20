package net.alopro.datawatch.alerts

import java.util.Calendar
import java.util.Locale
import kotlin.math.roundToLong

/** Mêmes règles d'affichage que lib/core/format.dart (1 Go = 1 024 Mo). */
object DataFormat {
    private const val NBSP = ' '
    private const val MO = 1024.0 * 1024.0
    private const val GO = MO * 1024.0

    private val months = arrayOf(
        "janv.", "févr.", "mars", "avr.", "mai", "juin",
        "juil.", "août", "sept.", "oct.", "nov.", "déc.",
    )

    fun bytes(value: Long, units: String = "auto"): String {
        val b = value.coerceAtLeast(0)
        if (b == 0L) return "0${NBSP}Mo"
        val go = b / GO
        val mo = b / MO
        return when (units) {
            "mo" -> if (mo < 10) "${decimal(mo, 1)}${NBSP}Mo" else "${thousands(mo.roundToLong())}${NBSP}Mo"
            "go" -> "${decimal(go, 2)}${NBSP}Go"
            else -> when {
                go >= 10 -> "${decimal(go, 1)}${NBSP}Go"
                go >= 1 -> "${decimal(go, 2)}${NBSP}Go"
                mo.roundToLong() >= 1024 -> "1${NBSP}Go"
                mo >= 1 -> "${mo.roundToLong()}${NBSP}Mo"
                else -> "<${NBSP}1${NBSP}Mo"
            }
        }
    }

    /** « 22 oct. à 08:30 » */
    fun dayMonthTime(millis: Long): String {
        val c = Calendar.getInstance().apply { timeInMillis = millis }
        val day = c.get(Calendar.DAY_OF_MONTH)
        val dayText = if (day == 1) "1er" else "$day"
        return "$dayText ${months[c.get(Calendar.MONTH)]} à %02d:%02d"
            .format(c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
    }

    private fun decimal(value: Double, digits: Int): String {
        val text = String.format(Locale.FRANCE, "%.${digits}f", value)
        return if (text.contains(',')) text.trimEnd('0').trimEnd(',') else text
    }

    private fun thousands(value: Long): String =
        value.toString().reversed().chunked(3).joinToString("$NBSP").reversed()
}
