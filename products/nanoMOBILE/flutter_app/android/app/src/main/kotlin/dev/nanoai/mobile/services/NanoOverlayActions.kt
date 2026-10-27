package dev.nanoai.mobile.services

import android.content.Context

/** Despacha acciones del panel al puente existente. No posee ventanas ni motores
 * de IA. El servicio entrega sus callbacks y libera descargas al destruirse. */
internal class NanoOverlayActions(
    private val context: Context,
    private val panel: () -> NanoGeminiOverlayView?,
    private val collapse: () -> Unit,
    private val receipt: (String) -> Unit,
    private val mood: (String) -> Unit,
    private val active: () -> Boolean,
) {
    private val downloader = NanoMediaDownloader(context)
    private val mediaResolver = NanoMediaResolver(context)
    private var speechRequest = 0
    private var presentationGeneration = 0
    /** El servicio cancela transporte multimedia al dejar de ser propietario. */
    fun close() {
        presentationGeneration++
        downloader.detach()
        mediaResolver.destroy()
    }

    // QUÉ: Procesa la acción del panel flotante sin bloquear ni volcar logcat/pantalla innecesariamente.
    // CÓMO: Solo invoca NanoScreenReader si la acción es "Resumir", "Media" o consulta la pantalla activa.
    //       Para conversación general o preguntas directas, envía el prompt limpio sin adjuntos masivos.
    // POR QUÉ: Evita inyectar miles de caracteres de volcados de pantalla/logcat en consultas conversacionales,
    //          permitiendo que el modelo responda de forma fluida, completa y sin truncamiento a 300 caracteres.
    fun handle(tool: String, provider: String, prompt: String) {
        if (tool == "Cancel") {
            requestStop()
            return
        }
        if (tool == "Speak" || tool == "StopSpeech") {
            handleSpeech(tool, prompt)
            return
        }
        NanoPanelAttachments.source(tool)?.let {
            handleAttachment(it)
            return
        }
        val view = panel() ?: return
        val generation = ++presentationGeneration
        val isScreenQuery = NanoPanelScreenContext.isRequested(tool, prompt)
        val screen = if (isScreenQuery || tool == "Media") {
            runCatching { NanoScreenReader.readCurrentScreen() }.getOrNull()
        } else null

        if (tool == "Resumir") {
            view.showResult(NanoPanelScreenContext.reading(screen))
            return
        }
        if (prompt.isBlank() && tool != "Media" && tool != "Historial") {
            view.showResult("Escribe la instrucción antes de ejecutar. Seleccionar una herramienta no ejecuta acciones.")
            return
        }

        if (tool == "Media") {
            val detectedUrl = NanoMediaResolver.extractUrlFromText(prompt)
            val target = detectedUrl ?: screen?.links?.firstOrNull() ?: ""
            if (target.isNotEmpty()) {
                view.showResult("Enlace multimedia detectado:\n$target", listOf(target))
                return
            }
            view.showResult("Pega un enlace multimedia válido; no se detectó uno en la pantalla.")
            return
        }

        val localAction = tool == "Auto" || tool == "WhatsApp"
        view.setLoading(if (localAction) "Ejecutando acción" else "Pensando…", canStop = true)
        val screenCtx = if (isScreenQuery) {
            NanoPanelScreenContext.asBridgeData(screen)
        } else null

        val queryPrompt = prompt

        // Auto usa el ejecutor Android, sin proveedor web. Apartar el panel
        // libera el foco del teclado y deja visibles los controles de WhatsApp.
        mood("thinking")
        if (localAction) collapse()
        val mode = when (tool) {
            "WhatsApp" -> "whatsapp"
            "Auto" -> "action"
            "Historial" -> "history"
            else -> "quick"
        }
        val sent = NanoOverlayBridge.query(queryPrompt, mode, screenCtx) { text, ok ->
            // El recibo solo puede actualizar la misma intención visible;
            // una respuesta antigua nunca sustituye una consulta más reciente.
            if (!active() || generation != presentationGeneration) return@query
            mood(if (ok) "success" else "error")
            val answer = text ?: "No se recibió un resultado verificable."
            if (localAction) {
                receipt(answer)
                android.widget.Toast.makeText(context, answer.take(140), android.widget.Toast.LENGTH_LONG).show()
            } else panel()?.showResult(answer)
        }
        if (!sent) {
            val unavailable = "Abre Nano para conectar su motor local; no se ejecutó la acción."
            mood("error")
            if (localAction) receipt(unavailable)
            else view.showResult(unavailable)
        }
    }

    /** Invalida presentación anterior y solicita cancelar la tarea del búho.
     * El motor conserva su bloqueo hasta liberar la operación realmente activa. */
    private fun requestStop() {
        val generation = ++presentationGeneration
        val sent = NanoOverlayBridge.query("", "cancel_action") { text, _ ->
            if (!active() || generation != presentationGeneration) return@query
            receipt(text ?: "Detención solicitada; revisa la app antes de repetir.")
            mood("idle")
        }
        if (!sent) panel()?.showResult("No hay conexión con Nano para solicitar detener.")
    }

    /** Envía voz al runtime compartido sin clasificar ni invocar el modelo.
     * Stop también funciona cuando el servicio acaba de desmontar su panel. */
    private fun handleSpeech(tool: String, prompt: String) {
        val view = panel()
        val request = ++speechRequest
        val mode = if (tool == "Speak") "speak" else "stop_speech"
        val sent = NanoOverlayBridge.query(prompt, mode) { message, ok ->
            if (request != speechRequest || !active() || view?.isAttachedToWindow != true) return@query
            if (!ok) view.showSpeechFailure(message ?: "No se pudo completar la lectura de voz.")
        }
        if (!sent) view?.showSpeechFailure("Abre Nano para conectar su salida de voz.")
    }

    /** Delega selección al proveedor existente y conserva su recibo al regresar.
     * Solo prepara: ni el archivo ni el borrador se envían desde esta ruta. */
    private fun handleAttachment(source: String) {
        val view = panel() ?: return
        val generation = ++presentationGeneration
        view.setLoading("Abriendo selector de adjuntos…")
        val sent = NanoOverlayBridge.query(source, "pick_attachment") { text, ok ->
            if (!active() || generation != presentationGeneration) return@query
            val result = text ?: "No se recibió confirmación de un adjunto preparado."
            receipt(result)
            mood(if (ok) "success" else "error")
            android.widget.Toast.makeText(context, result.take(140), android.widget.Toast.LENGTH_LONG).show()
        }
        if (sent) collapse()
        else view.showResult("Abre Nano para conectar el selector de adjuntos. No se preparó ningún archivo.")
    }

    /** Descarga solo tras la selección explícita ofrecida por el modo Media. */
    fun download(url: String, audioOnly: Boolean) {
        if (!active()) return
        val generation = ++presentationGeneration
        panel()?.setLoading("Extrayendo stream con NanoSnaptube…")
        mediaResolver.resolveMedia(url, audioOnly) { media, err ->
            if (!active() || generation != presentationGeneration) return@resolveMedia
            if (media != null) {
                downloader.download(media.downloadUrl) downloaded@ { ok, path ->
                    if (!active() || generation != presentationGeneration) return@downloaded
                    panel()?.showResult(if (ok) "✅ Descargado en Downloads/Nano/: $path" else "❌ Error en descarga.")
                }
            } else {
                panel()?.showResult("❌ No se pudo extraer stream: ${err ?: "Enlace no soportado"}")
            }
        }
    }

}
