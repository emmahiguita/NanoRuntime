package dev.nanoai.mobile.services

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.util.Locale

/**
 * NanoVoiceCapture — Dictado STT iniciado por el usuario desde el overlay nativo.
 *
 * QUÉ: Transcripción de voz a texto usando el motor del sistema Android.
 * CÓMO: SpeechRecognizer con RecognizerIntent.ACTION_RECOGNIZE_SPEECH.
 *       RECORD_AUDIO debe estar concedido desde la Activity de Nano (no desde el Service).
 * POR QUÉ: El Service no puede pedir permisos en tiempo de ejecución — solo la Activity puede.
 *          Si no hay permiso, onStatus informa al usuario con un mensaje claro.
 * ZOMBI: stop() destruye el recognizer y marca listening=false — sin fugas de audio.
 */
internal class NanoVoiceCapture(private val context: Context) {
    private var speech: SpeechRecognizer? = null
    private var listening = false

    fun start(onText: (String) -> Unit, onStatus: (String) -> Unit) {
        if (listening) return
        // Verificar permiso sin pedirlo (el Service no puede solicitarlo).
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED) {
            onStatus("Autoriza el micrófono desde Nano"); return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            onStatus("Este dispositivo no tiene reconocimiento de voz"); return
        }
        try {
            speech = SpeechRecognizer.createSpeechRecognizer(context).apply {
                setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) { onStatus("Te escucho…") }
                    override fun onBeginningOfSpeech() { onStatus("Escuchando…") }
                    override fun onRmsChanged(rmsdB: Float) { /* Sin onda falsa. */ }
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() { onStatus("Transcribiendo…") }
                    override fun onError(error: Int) {
                        listening = false
                        onStatus("No se pudo transcribir: código $error")
                        closeRecognizer()
                    }
                    override fun onResults(results: Bundle?) {
                        val text = results
                            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            ?.firstOrNull()
                        listening = false
                        if (text.isNullOrBlank()) onStatus("No escuché una frase")
                        else { onText(text); onStatus("Dictado listo") }
                        closeRecognizer()
                    }
                    override fun onPartialResults(results: Bundle?) {}
                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })
                startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                })
            }
            listening = true
        } catch (e: Exception) {
            listening = false; closeRecognizer()
            onStatus("Voz no disponible: ${e.javaClass.simpleName}")
        }
    }

    private fun closeRecognizer() { speech?.destroy(); speech = null }

    fun stop() { listening = false; speech?.cancel(); closeRecognizer() }
}
