package net.alopro.datawatch.usage

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager

/**
 * Cartes SIM à interroger pour les données mobiles.
 *
 * Depuis Android 10, un identifiant nul couvre toutes les SIM. Avant, Android
 * exige l'identifiant de chaque SIM, lisible seulement avec l'autorisation
 * « Téléphone » (READ_PHONE_STATE) : on additionne alors toutes les cartes.
 */
object MobileSubscribers {

    /** Vrai si cette version d'Android exige l'autorisation « Téléphone » et qu'elle manque. */
    fun permissionMissing(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            context.checkSelfPermission(Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED

    /**
     * Identifiants à interroger. Liste vide : aucune SIM active (0 octet mobile).
     * @throws SecurityException si l'autorisation « Téléphone » manque (Android 9 et avant).
     */
    @SuppressLint("MissingPermission", "HardwareIds")
    @Suppress("DEPRECATION")
    fun ids(context: Context): List<String?> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) return listOf(null)
        if (permissionMissing(context)) throw SecurityException("READ_PHONE_STATE manquante")

        val telephony = context.getSystemService(TelephonyManager::class.java)
        val subscriptions = context.getSystemService(SubscriptionManager::class.java)
            ?.activeSubscriptionInfoList.orEmpty()
        val ids = subscriptions
            .mapNotNull { telephony.createForSubscriptionId(it.subscriptionId).subscriberId }
            .distinct()
        return ids.ifEmpty { listOfNotNull(telephony.subscriberId) }
    }
}
