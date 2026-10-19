package net.alopro.datawatch.usage

import android.app.usage.NetworkStats
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Process
import java.io.ByteArrayOutputStream

/**
 * Associe un uid réseau à ce que l'utilisateur reconnaît : une application
 * (nom, paquet, catégorie) ou un regroupement fait par Android.
 *
 * Utilisé uniquement depuis le thread de DataUsageChannel.
 */
class AppResolver(context: Context) {

    private val pm: PackageManager = context.packageManager
    private val cache = HashMap<Int, Map<String, Any?>>()

    fun describe(usage: NetworkUsageReader.UidUsage): Map<String, Any?> {
        val owner = cache.getOrPut(usage.uid) { resolve(usage.uid) }
        return owner + mapOf(
            "uid" to usage.uid,
            "rxBytes" to usage.rxBytes,
            "txBytes" to usage.txBytes,
        )
    }

    private fun resolve(uid: Int): Map<String, Any?> {
        when {
            uid == NetworkStats.Bucket.UID_REMOVED -> return owner("removed")
            uid == NetworkStats.Bucket.UID_TETHERING -> return owner("tethering")
            uid % PER_USER_RANGE < Process.FIRST_APPLICATION_UID -> return owner("system")
        }
        // Null si le paquet n'est pas visible (Android 11+, hors lanceur).
        val packages = pm.getPackagesForUid(uid)?.takeIf { it.isNotEmpty() } ?: return owner("hidden")
        val info = packages.firstNotNullOfOrNull { applicationInfo(it) } ?: return owner("hidden")
        return mapOf(
            "kind" to "app",
            "packageName" to info.packageName,
            "label" to pm.getApplicationLabel(info).toString(),
            "category" to categoryName(info.category),
            "isSystemApp" to ((info.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
        )
    }

    private fun applicationInfo(packageName: String): ApplicationInfo? = try {
        pm.getApplicationInfo(packageName, 0)
    } catch (_: PackageManager.NameNotFoundException) {
        null
    }

    private fun owner(kind: String): Map<String, Any?> = mapOf("kind" to kind)

    private fun categoryName(category: Int): String? = when (category) {
        ApplicationInfo.CATEGORY_VIDEO -> "video"
        ApplicationInfo.CATEGORY_AUDIO -> "audio"
        ApplicationInfo.CATEGORY_SOCIAL -> "social"
        ApplicationInfo.CATEGORY_IMAGE -> "image"
        ApplicationInfo.CATEGORY_GAME -> "game"
        ApplicationInfo.CATEGORY_NEWS -> "news"
        ApplicationInfo.CATEGORY_MAPS -> "maps"
        ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
        else -> null
    }

    /** Icône de l'application en PNG carré, ou null si le paquet est introuvable. */
    fun iconPng(packageName: String, sizePx: Int): ByteArray? {
        val drawable = try {
            pm.getApplicationIcon(packageName)
        } catch (_: PackageManager.NameNotFoundException) {
            return null
        }
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, sizePx, sizePx)
        drawable.draw(Canvas(bitmap))
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    companion object {
        /** Taille d'une plage d'uid par profil utilisateur Android. */
        private const val PER_USER_RANGE = 100_000
    }
}
