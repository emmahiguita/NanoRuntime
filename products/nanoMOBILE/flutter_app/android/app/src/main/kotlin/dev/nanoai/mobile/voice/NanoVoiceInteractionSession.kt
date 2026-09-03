package dev.nanoai.mobile.voice

import android.content.Context
import android.os.Bundle
import android.service.voice.VoiceInteractionSession

/**
 * A16 — sesión activa de asistente. Recibe la activación del usuario (hotword o
 * botón) y, en la fundación, solo confirma el inicio de la sesión. El STT real
 * lo dispara la app (canal `com.nanoai/speech`), no este servicio ligero.
 */
class NanoVoiceInteractionSession(context: Context) : VoiceInteractionSession(context) {

    override fun onCreate() {
        super.onCreate()
        activeSessions++
    }

    override fun onDestroy() {
        super.onDestroy()
        if (activeSessions > 0) activeSessions--
    }

    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        // Hotword detectado → sesión activa. La app inicia el STT.
    }

    override fun onHide() {
        super.onHide()
    }

    companion object {
        /** Sesiones vivas (creadas y no destruidas). Contador defensivo:
         *  el sistema puede solaparlas (re-show). */
        @Volatile
        private var activeSessions = 0

        /** Factual: ¿hay una sesión de asistente activa AHORA? (ROLE-01 lo
         *  expone para llenar el AssistContext del SystemContextProvider). */
        val isSessionActive: Boolean get() = activeSessions > 0
    }
}
