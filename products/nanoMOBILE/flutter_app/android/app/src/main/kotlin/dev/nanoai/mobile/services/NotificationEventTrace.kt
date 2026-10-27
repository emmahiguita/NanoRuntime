package dev.nanoai.mobile.services

import android.util.Log

// QUÉ HACE: registra etapas del listener sin guardar texto ni datos del chat.
// CÓMO: relaciona eventos por paquete y hora de publicación; limpia motivos dinámicos.
// POR QUÉ: permite localizar el primer salto perdido sin exponer mensajes privados.
internal object NotificationEventTrace {
    private const val TAG = "NanoNotifications"

    fun lifecycle(state: String, pending: Int? = null) {
        val backlog = pending?.let { " pending=$it" }.orEmpty()
        Log.i(TAG, "stage=listener state=$state$backlog")
    }

    fun event(
        stage: String,
        packageName: String,
        postedAtMs: Long,
        outcome: String,
        detail: String = "none",
    ) {
        val safeDetail = detail.filter { it.isLetterOrDigit() || it in "._-" }.take(48)
        Log.i(
            TAG,
            "stage=$stage pkg=$packageName at=$postedAtMs outcome=$outcome detail=${safeDetail.ifEmpty { "none" }}",
        )
    }
}
