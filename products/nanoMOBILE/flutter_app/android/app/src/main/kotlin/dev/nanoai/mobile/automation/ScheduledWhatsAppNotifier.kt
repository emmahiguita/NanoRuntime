package dev.nanoai.mobile.automation

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

// Publica fallos e incertidumbres desde alarmas y recuperación sin depender de una Activity viva.
internal object ScheduledWhatsAppNotifier {
    fun failure(context: Context, recipient: String, reason: String) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val channelId = "nano_scheduled_messages"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(channelId, "Mensajes programados", NotificationManager.IMPORTANCE_HIGH),
            )
        }
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("Revisa el mensaje de $recipient")
            .setContentText(reason)
            .setStyle(NotificationCompat.BigTextStyle().bigText(reason))
            .setAutoCancel(true)
            .build()
        manager.notify((recipient + System.currentTimeMillis()).hashCode(), notification)
    }
}
