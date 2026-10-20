package net.alopro.datawatch.alerts

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Planifie la vérification des seuils toutes les 15 minutes (le minimum
 * d'Android). WorkManager la conserve après un redémarrage du téléphone.
 * Le système peut la retarder (économie d'énergie) : les alertes ne sont
 * pas garanties à l'octet près.
 */
object AlertScheduler {
    private const val WORK_NAME = "datawatch-alert-check"

    fun configure(context: Context, config: AlertConfig) {
        val previous = AlertConfig.load(context)
        val notified = if (previous?.planKey == config.planKey) previous.notified else emptySet()
        AlertConfig.save(context, config.copy(notified = notified))

        val work = WorkManager.getInstance(context)
        if (config.enabled && config.hasPlan && System.currentTimeMillis() < config.end) {
            val request = PeriodicWorkRequest.Builder(AlertWorker::class.java, 15, TimeUnit.MINUTES).build()
            work.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        } else {
            work.cancelUniqueWork(WORK_NAME)
        }
    }

    fun clear(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        AlertConfig.clear(context)
    }

    internal fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }
}

class AlertWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val config = AlertConfig.load(applicationContext)
        if (config == null || !config.enabled || System.currentTimeMillis() >= config.end) {
            // Forfait expiré ou alertes coupées : plus rien à surveiller.
            AlertScheduler.cancel(applicationContext)
            return Result.success()
        }
        return try {
            AlertChecker.run(applicationContext)
            Result.success()
        } catch (_: SecurityException) {
            // Accès aux données d'utilisation retiré : on réessaiera au prochain passage.
            Result.success()
        } catch (_: Exception) {
            // Statistiques momentanément indisponibles : prochain passage dans 15 min.
            Result.success()
        }
    }
}
