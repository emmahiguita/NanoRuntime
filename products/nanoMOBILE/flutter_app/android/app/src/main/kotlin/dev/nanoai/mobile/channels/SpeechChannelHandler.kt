package dev.nanoai.mobile.channels

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Entrada por voz (A16): reconocimiento de voz del sistema Android. El texto
 * transcrito entra al MISMO pipeline de ejecución que una orden escrita (el
 * motor AutomationCoordinator). Sin segundo motor de voz.
 *
 * El resultado del MethodChannel se resuelve en el hilo principal cuando
 * onResults entrega el texto; onError devuelve un error tipado (no excepción).
 */
class SpeechChannelHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/speech"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startListening" -> startListening(
                call.argument<String>("language") ?: "es-ES",
                result,
            )
            "speak" -> speak(call.argument<String>("text").orEmpty(), result)
            "cancel" -> {
                recognizer?.cancel()
                recognizer = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Salida de voz (TTS). Inicializa el motor on-demand y habla el texto. */
    private fun speak(text: String, result: MethodChannel.Result) {
        if (text.isBlank()) {
            result.success(false)
            return
        }
        val existing = tts
        if (existing != null) {
            speakNow(existing, text, result)
            return
        }
        TextToSpeech(context) { status ->
            val engine = tts
            if (status == TextToSpeech.SUCCESS && engine != null) {
                speakNow(engine, text, result)
            } else {
                result.error("tts_error", "init status=$status", null)
            }
        }.also { tts = it }
    }

    private fun speakNow(engine: TextToSpeech, text: String, result: MethodChannel.Result) {
        engine.language = Locale("es", "ES")
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "nano_tts")
        result.success(true)
    }

    private fun startListening(language: String, result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            result.error("speech_unavailable", "Reconocimiento de voz no disponible", null)
            return
        }
        val rec = SpeechRecognizer.createSpeechRecognizer(context)
        recognizer = rec
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull().orEmpty()
                rec.destroy()
                recognizer = null
                mainHandler.post { result.success(text) }
            }

            override fun onError(error: Int) {
                rec.destroy()
                recognizer = null
                mainHandler.post { result.error("speech_error", "code=$error", null) }
            }

            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        rec.startListening(intent)
    }
}
