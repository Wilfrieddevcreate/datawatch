package net.alopro.datawatch.usage

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Process

object UsageAccess {
    /** Vrai si l'utilisateur a accordé « Accès aux données d'utilisation ». */
    fun isGranted(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
        )
        // MODE_DEFAULT : certains constructeurs délèguent à la permission classique.
        return if (mode == AppOpsManager.MODE_DEFAULT) {
            context.checkCallingOrSelfPermission(Manifest.permission.PACKAGE_USAGE_STATS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            mode == AppOpsManager.MODE_ALLOWED
        }
    }
}
