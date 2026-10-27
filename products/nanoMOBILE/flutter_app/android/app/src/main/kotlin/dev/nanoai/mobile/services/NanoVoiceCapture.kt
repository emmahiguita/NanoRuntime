package dev.nanoai.mobile.services

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
    private var generation = 0
    private var stateChanged: ((Boolean) -> Unit)? = null
    private val main = Handler(Looper.getMainLooper())
    private var timeout: Runnable? = null

    /** Inicia dictado explícito; entrega un borrador y nunca ejecuta acciones. */
    fun start(onText: (String) -> Unit, onStatus: (String) -> Unit,
              onState: (Boolean) -> Unit = {}) {
        if (listening) return
        // Verificar permiso sin pedirlo (el Service no puede solicitarlo).
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED) {
            onState(false)
            onStatus("Autoriza el micrófono desde Nano"); return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            onState(false)
            onStatus("Este dispositivo no tiene reconocimiento de voz"); return
        }
        val session = ++generation
        stateChanged = onState
        try {
            val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
            speech = recognizer
            recognizer.apply {
                setRecognitionListener(object : RecognitionListener {
                    /** Refleja apertura real del micrófono, sin estados simulados. */
                    override fun onReadyForSpeech(params: Bundle?) {
                        if (session == generation) onStatus("Te escucho… Pulsa cancelar para salir.")
                    }
                    /** Refleja voz detectada en la sesión vigente. */
                    override fun onBeginningOfSpeech() {
                        if (session == generation) onStatus("Escuchando…")
                    }
                    /** No fabrica ondas ni guarda amplitudes. */
                    override fun onRmsChanged(rmsdB: Float) { /* Sin onda falsa. */ }
                    /** El motor Android conserva la propiedad del audio. */
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    /** Espera el resultado final antes de liberar el reconocedor. */
                    override fun onEndOfSpeech() {
                        if (session == generation) onStatus("Transcribiendo…")
                    }
                    /** Libera audio y estado antes de publicar el error recuperable. */
                    override fun onError(error: Int) {
                        if (session != generation) return
                        stop()
                        onStatus(when (error) {
                            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Autoriza el micrófono desde Nano."
                            SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No se reconoció una frase."
                            SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "El reconocimiento de voz no pudo conectar."
                            else -> "No se pudo transcribir: código $error"
                        })
                    }
                    /** Solo el resultado definitivo prepara texto, nunca lo envía. */
                    override fun onResults(results: Bundle?) {
                        if (session != generation) return
                        val text = results
                            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            ?.firstOrNull()
                        stop()
                        if (text.isNullOrBlank()) onStatus("No escuché una frase")
                        else { onText(text); onStatus("Dictado listo. Revisa antes de ejecutar.") }
                    }
                    /** Descarta parciales para no reemplazar el borrador. */
                    override fun onPartialResults(results: Bundle?) {}
                    /** Los eventos propietarios no cambian el estado visible. */
                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })
                listening = true
                onState(true)
                onStatus("Iniciando micrófono…")
                timeout = Runnable {
                    if (session == generation) {
                        stop()
                        onStatus("El dictado terminó sin resultado. Puedes volver a intentarlo.")
                    }
                }.also { main.postDelayed(it, 30_000) }
                startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                })
            }
        } catch (e: Exception) {
            stop()
            onStatus("Voz no disponible: ${e.javaClass.simpleName}")
        }
    }

    /** Invalida callbacks tardíos y libera micrófono en fin, error o desmontaje. */
    fun stop() {
        generation++
        listening = false
        timeout?.let(main::removeCallbacks)
        timeout = null
        val recognizer = speech
        speech = null
        runCatching { recognizer?.cancel() }
        runCatching { recognizer?.destroy() }
        val notify = stateChanged
        stateChanged = null
        notify?.invoke(false)
    }
}
