package dev.nanoai.mobile.services

import android.content.Context
import android.service.notification.StatusBarNotification
import android.util.Log
import dev.nanoai.mobile.NanoApplication
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/** Serializa escrituras de historial fuera del callback del sistema Android. */
internal class NotificationHistoryCapture(context: Context) {
    private val app = NanoApplication.from(context.applicationContext)
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Captura contenido que Android mostró y lo guarda localmente sin bloquear la UI. */
    fun capture(notification: StatusBarNotification) {
        val events = NotificationHistoryExtractor.extract(notification)
        if (events.isEmpty()) return
        ioScope.launch {
            try {
                app.automationStoreDb.appendNotificationHistory(events)
                // El Centro relee SQLite cuando el commit termina, no antes.
                NotificationHistoryBridge.notifyStored()
            } catch (error: Exception) {
                // No se escribe texto de mensajes en logcat; solo el tipo del fallo.
                Log.e("NanoHistory", "No se pudo guardar historial: ${error.javaClass.simpleName}")
            }
        }
    }

    /** Al destruir el listener cancela trabajo pendiente y evita una corrutina huérfana. */
    fun close() = ioScope.cancel()
}
