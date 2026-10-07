package dev.nanoai.mobile.services

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Notifica a la interfaz que terminó una escritura del historial local. */
object NotificationHistoryBridge {
    @Volatile
    private var sink: EventChannel.EventSink? = null

    /** Conecta solo el consumidor visual; no alimenta el motor de automatización. */
    fun attach(events: EventChannel.EventSink?) {
        sink = events
    }

    /** Publica después del commit SQLite y siempre desde el hilo principal Flutter. */
    fun notifyStored() {
        Handler(Looper.getMainLooper()).post {
            sink?.success(System.currentTimeMillis())
        }
    }
}
