package dev.nanoai.mobile.automation

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.core.app.NotificationCompat
import dev.nanoai.mobile.MainActivity
import dev.nanoai.mobile.R

/** QUÉ: aviso real requerido para trabajo visible de segundo plano.
 * CÓMO: mantiene canal, ID y PendingIntent originales.
 * POR QUÉ: la extracción no cambia permisos ni el tipo de servicio. */
internal object AutomationForegroundNotice {
    private const val FGS_CHANNEL_ID = "nano_automation_fgs"
    private const val FGS_NOTIFICATION_ID = 0x4E43
    fun start(service: Service) {
        val manager = service.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            FGS_CHANNEL_ID,
            "Automatización",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Procesamiento de mensajes en segundo plano"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)

        val openIntent = Intent(service, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val openPending = PendingIntent.getActivity(
            service,
            FGS_NOTIFICATION_ID,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(service, FGS_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_nano_confirmation)
            .setContentTitle("Nano procesando mensajes")
            .setContentText("Automatización activa en segundo plano")
            .setOngoing(true)
            .setContentIntent(openPending)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            service.startForeground(FGS_NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            service.startForeground(FGS_NOTIFICATION_ID, notification)
        }
    }
}
