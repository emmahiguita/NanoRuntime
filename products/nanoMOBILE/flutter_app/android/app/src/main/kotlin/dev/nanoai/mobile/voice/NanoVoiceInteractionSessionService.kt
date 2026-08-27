package dev.nanoai.mobile.voice

import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService

/**
 * A16 — sesión de interacción de voz. Crea [NanoVoiceInteractionSession] por
 * activación del usuario (assistant). No ejecuta acciones por sí misma: delega
 * el resultado (texto/hotword) a la app vía el runtime existente.
 */
class NanoVoiceInteractionSessionService : VoiceInteractionSessionService() {

    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return NanoVoiceInteractionSession(this)
    }
}
