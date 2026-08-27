package dev.nanoai.mobile.voice

import android.service.voice.VoiceInteractionService

/**
 * A16 — Assistant Role de Android (VoiceInteractionService).
 *
 * LIGERO por diseño (sección 6 del documento): NO mantiene LLM, ScreenGraph ni
 * ningún modelo pesado residente. Solo informa disponibilidad del rol y delega
 * la interacción a [NanoVoiceInteractionSessionService].
 *
 * Wake word: [AlwaysOnHotwordDetector] es @hide (restringido a apps de sistema),
 * NO accesible para una app normal. Por eso la activación pasiva requiere un
 * detector LOCAL (microWakeWord/openWakeWord, modelo .tflite propio) — ese es el
 * "modelo" que la arquitectura contempla, no un hotword del sistema. Mientras
 * tanto, la activación es por botón/asistente (foreground).
 */
class NanoVoiceInteractionService : VoiceInteractionService() {

    override fun onReady() {
        super.onReady()
        // Disponibilidad factual del Assistant Role. El sistema mantiene vivo
        // este servicio solo cuando Nano está seleccionado como asistente global.
    }
}
