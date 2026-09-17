package dev.nanoai.mobile.services

import android.app.Notification
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * Último tramo del transporte de respuesta: inyecta texto en los RemoteInput
 * libres de una acción y entrega su PendingIntent.
 *
 * La selección de notificación, identidad y protección TOCTOU siguen en
 * [NotificationAutomationService]. Separar sólo este tramo permite validarlo
 * con una notificación fixture local sin apuntar a WhatsApp ni a contactos.
 */
object RemoteInputReplySender {
    data class Result(val ok: Boolean, val code: String)

    fun send(
        context: Context,
        action: Notification.Action,
        text: String,
    ): Result {
        val remoteInputs = action.remoteInputs
            ?.filter(RemoteInput::getAllowFreeFormInput)
            ?.toTypedArray()
            ?: emptyArray()
        if (remoteInputs.isEmpty()) return Result(false, "REPLY_UNAVAILABLE")

        return try {
            val intent = Intent()
            val results = Bundle()
            remoteInputs.forEach { input ->
                results.putCharSequence(input.resultKey, text)
            }
            RemoteInput.addResultsToIntent(remoteInputs, intent, results)
            action.actionIntent.send(context, 0, intent)
            Result(true, "REMOTE_INPUT_ACCEPTED")
        } catch (_: PendingIntent.CanceledException) {
            Result(false, "ACTION_EXPIRED")
        } catch (_: SecurityException) {
            Result(false, "ACTION_DENIED")
        }
    }
}
