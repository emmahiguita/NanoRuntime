package dev.nanoai.mobile.input

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.widget.Toast
import androidx.core.content.ContextCompat

/**
 * QUÉ HACE: Administrador de dictado por voz integrado para Nano Keyboard.
 * POR QUÉ EXISTE: Provee reconocimiento de voz con estados claros sin bloquear el hilo principal.
 * QUÉ PUEDE FALLAR: Si el permiso RECORD_AUDIO no está concedido o no hay motor STT disponible.
 */
internal class NanoVoiceInputHelper(
    private val context: Context,
    private val onResult: (String) -> Unit,
    private val onStateChanged: (VoiceState) -> Unit,
) {
    enum class VoiceState { IDLE, LISTENING, PROCESSING, ERROR, PERMISSION_DENIED }

    private var speechRecognizer: SpeechRecognizer? = null
    var currentState = VoiceState.IDLE
        private set

    fun isPermissionGranted(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    fun startListening() {
        if (!isPermissionGranted()) {
            currentState = VoiceState.PERMISSION_DENIED
            onStateChanged(currentState)
            Toast.makeText(context, "Concede permiso de micrófono en Ajustes para dictar.", Toast.LENGTH_LONG).show()
            return
        }

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            currentState = VoiceState.ERROR
            onStateChanged(currentState)
            Toast.makeText(context, "Reconocimiento de voz no disponible en el sistema.", Toast.LENGTH_SHORT).show()
            return
        }

        stopListening()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    currentState = VoiceState.LISTENING
                    onStateChanged(currentState)
                }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {
                    currentState = VoiceState.PROCESSING
                    onStateChanged(currentState)
                }
                override fun onError(error: Int) {
                    currentState = VoiceState.ERROR
                    onStateChanged(currentState)
                    stopListening()
                }
                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!matches.isNullOrEmpty()) {
                        onResult(matches[0])
                    }
                    currentState = VoiceState.IDLE
                    onStateChanged(currentState)
                    stopListening()
                }
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        speechRecognizer?.startListening(intent)
    }

    fun stopListening() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        if (currentState != VoiceState.IDLE) {
            currentState = VoiceState.IDLE
            onStateChanged(currentState)
        }
    }
}
