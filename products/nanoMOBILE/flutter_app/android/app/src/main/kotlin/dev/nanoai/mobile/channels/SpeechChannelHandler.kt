package dev.nanoai.mobile.channels

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
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
            "stop" -> {
                tts?.stop()
                result.success(null)
            }
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
        // Prefiere el motor de Google TTS (voz natural) sobre el Pico robótico.
        // Fallback al motor por defecto del sistema si Google no está instalado.
        val enginePref = listOf("com.google.android.tts", "com.android.tts", "")
        fun tryInit(index: Int) {
            if (index >= enginePref.size) {
                result.error("tts_error", "sin motor TTS disponible", null)
                return
            }
            val pref = enginePref[index]
            TextToSpeech(
                context,
                { status ->
                    val engine = tts
                    if (status == TextToSpeech.SUCCESS && engine != null) {
                        speakNow(engine, text, result)
                    } else {
                        tryInit(index + 1)
                    }
                },
                if (pref.isEmpty()) null else pref,
            ).also { tts = it }
        }
        tryInit(0)
    }

    private fun speakNow(engine: TextToSpeech, text: String, result: MethodChannel.Result) {
        // Pitch y rate neutros (natural). Locale auto: es si hay señales de
        // español, si no el locale del dispositivo.
        engine.setPitch(1.0f)
        engine.setSpeechRate(1.0f)
        val lower = text.lowercase()
        val locale = if (
            lower.contains('ñ') || lower.contains('á') || lower.contains('é') ||
            lower.contains('í') || lower.contains('ó') || lower.contains('ú') ||
            lower.contains('¿')
        ) {
            Locale("es", "ES")
        } else {
            Locale.getDefault()
        }
        engine.language = locale
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "nano_tts")
        result.success(true)
    }

    private fun startListening(language: String, result: MethodChannel.Result) {
        // A16: RECORD_AUDIO es permiso runtime. Sin él, SpeechRecognizer falla
        // con ERROR_INSUFFICIENT_PERMISSIONS. Reportamos un error tipado para
        // que Dart solicite el permiso (aquí solo hay Context, no Activity).
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "mic_permission_denied",
                "Permiso de micrófono no concedido",
                null,
            )
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            result.error("speech_unavailable", "Reconocimiento de voz no disponible", null)
            return
        }
        val rec = createRecognizer()
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

    /**
     * Lógica REAL de audio. API 31+: reconocimiento ON-DEVICE del sistema
     * (`createOnDeviceSpeechRecognizer`) — transcribe offline con el modelo del
     * dispositivo, sin depender del servicio configurado (`voice_recognition_service`
     * apunta al stub TTS) ni de Google Search. Forzar el ComponentName de Google
     * Search falla con error 10 (ERROR_CLIENT: servicio restringido para apps de
     * terceros). Si el modelo on-device no está descargado, fallback al
     * reconocedor por defecto del sistema.
     */
    private fun createRecognizer(): SpeechRecognizer {
        if (Build.VERSION.SDK_INT >= 31) {
            try {
                return SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            } catch (_: Exception) {
                // Modelo on-device no disponible: fallback al reconocedor del sistema.
            }
        }
        return SpeechRecognizer.createSpeechRecognizer(context)
    }
}
