package dev.nanoai.mobile.channels

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.speech.RecognitionService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.util.Log
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
        private const val TAG = "NanoSpeech"

        // Reconocedor legacy del TTS de Google (server-based): va al final de
        // la cadena de motores (VOICE-PRO-03).
        private const val TTS_PACKAGE = "com.google.android.tts"

        // Silencio antes de considerar que el usuario terminó (ms). Valores
        // generosos para que el usuario no se quede corto al dictar.
        // Int (no Long): el servicio de reconocimiento de Google lee estos
        // extras como Integer y un Long provoca ClassCastException →
        // silencio 0 y sesión rota.
        private const val COMPLETE_SILENCE_MS = 2000
        private const val POSSIBLY_COMPLETE_SILENCE_MS = 1500
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
            // Conversación continua: la app pregunta si el TTS sigue hablando
            // antes de volver a escuchar (evita captar la propia voz de Nano).
            "isSpeaking" -> result.success(tts?.isSpeaking ?: false)
            "cancel" -> {
                recognizer?.cancel()
                // VOICE-PRO-01: cancel no destruye el servicio; sin destroy
                // el recognizer queda vivo (leak) hasta que la app muere.
                recognizer?.destroy()
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
        // VOICE-PRO-01: un motor con init fallido se apaga en el acto; `tts`
        // jamás queda apuntando a un motor muerto (hablar sobre él = silencio
        // silencioso con success(false) sin diagnóstico).
        val enginePref = listOf("com.google.android.tts", "com.android.tts", "")
        fun tryInit(index: Int) {
            if (index >= enginePref.size) {
                tts?.shutdown()
                tts = null
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
                        // Motor fallido: apagarlo antes del siguiente intento.
                        tts?.shutdown()
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
        // Android rechaza entradas mayores que getMaxSpeechInputLength(). Una
        // lista real de notificaciones puede superar ese límite, por lo que se
        // divide en frases y se encola manteniendo el orden. El primer bloque
        // reemplaza cualquier locución anterior; los demás se agregan.
        val chunks = speechChunks(text)
        var accepted = true
        chunks.forEachIndexed { index, chunk ->
            val queueMode = if (index == 0) {
                TextToSpeech.QUEUE_FLUSH
            } else {
                TextToSpeech.QUEUE_ADD
            }
            val status = engine.speak(
                chunk,
                queueMode,
                null,
                "nano_tts_${System.nanoTime()}_$index",
            )
            if (status == TextToSpeech.ERROR) accepted = false
        }
        result.success(accepted)
    }

    private fun speechChunks(text: String): List<String> {
        val normalized = text.trim()
        if (normalized.isEmpty()) return emptyList()
        val maxLength = TextToSpeech.getMaxSpeechInputLength().coerceAtMost(3500)
        if (normalized.length <= maxLength) return listOf(normalized)

        val chunks = mutableListOf<String>()
        var start = 0
        while (start < normalized.length) {
            var end = (start + maxLength).coerceAtMost(normalized.length)
            if (end < normalized.length) {
                val minimumBreak = start + maxLength / 2
                val sentenceBreak = normalized.lastIndexOfAny(
                    charArrayOf('.', '?', '!', '\n'),
                    startIndex = end - 1,
                )
                val spaceBreak = normalized.lastIndexOf(' ', end - 1)
                end = when {
                    sentenceBreak >= minimumBreak -> sentenceBreak + 1
                    spaceBreak >= minimumBreak -> spaceBreak
                    else -> end
                }
            }
            normalized.substring(start, end).trim().takeIf { it.isNotEmpty() }
                ?.let(chunks::add)
            start = end
            while (start < normalized.length && normalized[start].isWhitespace()) {
                start++
            }
        }
        return chunks
    }

    /// VOICE-PRO-03 — lista ordenada de motores de reconocimiento reales.
    /// Motores on-device primero (excluye el recognizer legacy del TTS, que
    /// detecta voz pero tarda o se cuelga entregando resultados); el TTS al
    /// final como último recurso: al menos abre el micrófono y da tiempo de
    /// hablar. Vacía → lista con null (constructor estándar, que hereda el
    /// setting global del sistema).
    private fun recognitionServices(): List<ComponentName?> {
        val intent = Intent(RecognitionService.SERVICE_INTERFACE)
        val services = context.packageManager.queryIntentServices(intent, 0)
        val infos = services.mapNotNull { it.serviceInfo }
        fun components(infos: List<android.content.pm.ServiceInfo>) =
            infos.map { ComponentName(it.packageName, it.name) }
        val preferred = components(infos.filter { it.packageName != TTS_PACKAGE })
        val tts = components(infos.filter { it.packageName == TTS_PACKAGE })
        val names = preferred + tts
        return names.ifEmpty { listOf(null) }
    }

    /// Intent de reconocimiento. Los motores on-device aceptan el intent
    /// completo (streaming de parciales + silencios generosos). El motor
    /// legacy del TTS se confunde con esos extras: recibe el intent mínimo
    /// estándar (modelo libre + idioma).
    private fun buildRecognitionIntent(language: String, minimal: Boolean): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            if (!minimal) {
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
        // VOICE-PRO-01: sesión previa viva (dictado repetido rápido) se
        // destruye antes de crear la nueva. Dos recognizers simultáneos =
        // ERROR_RECOGNIZER_BUSY en el segundo o captura doble.
        recognizer?.destroy()
        recognizer = null
        startWithService(0, language, result)
    }

    /// VOICE-PRO-03 — cadena de fallback de motores: si un motor falla
    /// (p. ej. el on-device rechaza con TOO_MANY_REQUESTS), se intenta el
    /// siguiente de la lista. Solo se reporta error al agotar todos.
    private fun startWithService(
        serviceIndex: Int,
        language: String,
        result: MethodChannel.Result,
    ) {
        val services = recognitionServices()
        if (serviceIndex >= services.size) {
            result.error("speech_unavailable", "ningún motor de reconocimiento respondió", null)
            return
        }
        val service = services[serviceIndex]
        val rec = if (service == null) {
            Log.d(TAG, "recognizer = sistema por defecto")
            SpeechRecognizer.createSpeechRecognizer(context)
        } else {
            Log.d(TAG, "recognizer = $service (motor ${serviceIndex + 1}/${services.size})")
            SpeechRecognizer.createSpeechRecognizer(context, service)
        }
        recognizer = rec
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull().orEmpty()
                rec.destroy()
                recognizer = null
                mainHandler.post {
                    partialSink?.success(text)
                    // VOICE-PRO-01: algunos motores entregan onResults con
                    // matches vacío en vez de onError. Texto vacío se reporta
                    // null ("sin resultado"), misma semántica que NO_MATCH.
                    if (text.isEmpty()) result.success(null) else result.success(text)
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
                Log.d(TAG, "onError code=$error (motor ${serviceIndex + 1}/${services.size})")
                rec.destroy()
                recognizer = null
                mainHandler.post {
                    partialSink?.endOfStream()
                    // No-match o timeout del motor actual: el siguiente motor
                    // de la lista se intenta de inmediato (el último de la
                    // lista reporta el error tipado; la UI decide el mensaje).
                    if (serviceIndex + 1 < services.size) {
                        startWithService(serviceIndex + 1, language, result)
                    } else {
                        result.error("speech_error", "code=$error", null)
                    }
                }
            }

            override fun onReadyForSpeech(params: Bundle?) {
                Log.d(TAG, "onReadyForSpeech — micrófono abierto")
            }
            override fun onBeginningOfSpeech() {
                Log.d(TAG, "onBeginningOfSpeech — voz detectada")
            }
            override fun onRmsChanged(rmsdB: Float) {
                // Diagnóstico de captura: rms constante ≈ -inf / plano = el
                // micrófono entrega silencio; valores crecientes (> -20 dB) =
                // audio real entrando al reconocedor.
                Log.d(TAG, "rms=$rmsdB")
            }
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {
                Log.d(TAG, "onEndOfSpeech — fin de voz")
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        // El motor legacy del TTS recibe el intent mínimo estándar: los
        // extras custom (PARTIAL_RESULTS + silencios) lo confunden.
        val minimal = service == null || service.packageName == TTS_PACKAGE
        rec.startListening(buildRecognitionIntent(language, minimal))
    }
}
