package dev.nanoai.mobile.voice

import android.service.voice.VoiceInteractionService

/**
 * A16 — Assistant Role de Android (VoiceInteractionService).
 *
 * LIGERO por diseño (sección 6 del documento): NO mantiene LLM, ScreenGraph ni
 * ningún modelo pesado residente. Solo informa disponibilidad del rol y delega
 * la interacción a [NanoVoiceInteractionSessionService]. El trabajo pesado
 * (STT/TTS/automation) vive en la app, no en este servicio persistente.
 */
class NanoVoiceInteractionService : VoiceInteractionService() {

    override fun onReady() {
        super.onReady()
        // Disponibilidad factual del Assistant Role. El sistema mantiene vivo
        // este servicio solo cuando Nano está seleccionado como asistente global.
    }
}
