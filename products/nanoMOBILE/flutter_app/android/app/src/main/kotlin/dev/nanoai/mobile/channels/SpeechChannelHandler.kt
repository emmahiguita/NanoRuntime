package dev.nanoai.mobile.channels

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Entrada por voz (A16): reconocimiento de voz del sistema Android con STREAMING
 * de resultados parciales. El texto transcrito entra al MISMO pipeline de
 * ejecución que una orden escrita (AutomationCoordinator). Sin segundo motor.
 *
 * Dos canales:
 *  - MethodChannel `com.nanoai/speech`  → startListening/speak/stop (resultado final).
 *  - EventChannel `com.nanoai/speech_partial` → resultados parciales en vivo
 *    (el texto crece mientras el usuario habla; la UI lo muestra en tiempo real).
 *
 * El resultado del MethodChannel se resuelve en el hilo principal cuando
 * onResults entrega el texto; onError devuelve un error tipado (no excepción).
 */
class SpeechChannelHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/speech"
        const val PARTIAL_CHANNEL_NAME = "com.nanoai/speech_partial"

        // Silencio antes de considerar que el usuario terminó (ms). Valores
        // generosos para que el usuario no se quede corto al dictar.
        private const val COMPLETE_SILENCE_MS = 2000L
        private const val POSSIBLY_COMPLETE_SILENCE_MS = 1500L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null

    // Sink del EventChannel de parciales. null = nadie escuchando.
    private var partialSink: EventChannel.EventSink? = null

    // ── EventChannel.StreamHandler (partial results) ─────────────────────────
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        partialSink = events
    }

    override fun onCancel(arguments: Any?) {
        partialSink = null
    }

    // ── MethodChannel ────────────────────────────────────────────────────────
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startListening" -> startListening(
                call.argument<String>("language") ?: "es-ES",
                result,
            )
            "speak" -> speak(call.argument<String>("text").orEmpty(), result)
            "stop" -> {
                tts?.stop()
                recognizer?.stopListening()
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
        // Voz propia de Nano: identidad vocal consistente. Tono ligeramente
        // más agudo que la voz genérica del sistema + ritmo natural + español
        // (es-ES) SIEMPRE (sin heurística de acentos que mezclaba locales).
        engine.setPitch(1.1f)
        engine.setSpeechRate(1.0f)
        engine.language = Locale("es", "ES")
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "nano_tts")
        result.success(true)
    }

    private fun startListening(language: String, result: MethodChannel.Result) {
        // RECORD_AUDIO es permiso runtime. Sin él, SpeechRecognizer falla con
        // ERROR_INSUFFICIENT_PERMISSIONS. Reportamos tipado para que Dart
        // solicite el permiso (aquí solo hay Context, no Activity).
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
        val rec = SpeechRecognizer.createSpeechRecognizer(context)
        recognizer = rec
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull().orEmpty()
                rec.destroy()
                recognizer = null
                mainHandler.post {
                    partialSink?.success(text)
                    result.success(text)
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                // Streaming: el texto crece en vivo. La UI lo muestra mientras
                // el usuario habla; el resultado final llega por onResults.
                val partial = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                if (!partial.isNullOrEmpty()) {
                    mainHandler.post { partialSink?.success(partial) }
                }
            }

            override fun onError(error: Int) {
                rec.destroy()
                recognizer = null
                mainHandler.post {
                    // No-match o timeout = usuario no dijo nada (o silencio).
                    // Se reporta tipado; la UI decide el mensaje.
                    result.error("speech_error", "code=$error", null)
                    partialSink?.endOfStream()
                }
            }

            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // Tiempo de silencio generoso para no cortar el dictado a medias.
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                COMPLETE_SILENCE_MS,
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                POSSIBLY_COMPLETE_SILENCE_MS,
            )
        }
        rec.startListening(intent)
    }
}
