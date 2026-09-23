package dev.nanoai.mobile.services

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * NanoOverlayBridge — Puente singleton entre NanoFloatingService y el engine Flutter.
 *
 * QUÉ: Envía overlayQuery al canal 'dev.nanoai/overlay_runtime' de Flutter.
 * CÓMO: MainActivity llama attach() en configureFlutterEngine; el servicio nativo
 *       llama query() para pedir una respuesta al NanoAiController activo.
 * POR QUÉ: MainActivity es propietaria del engine — no se duplican runtimes de Dart.
 *          query() retorna false si Flutter no está disponible → el servicio abre Nano.
 */
internal object NanoOverlayBridge {
    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    /** Llamar en MainActivity.configureFlutterEngine. */
    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "dev.nanoai/overlay_runtime")
    }

    /** Llamar en MainActivity.cleanupFlutterEngine para evitar leaks. */
    fun detach() { channel = null }

    /**
     * Envía el prompt al controller Flutter.
     * @return true si el canal Flutter está disponible; false → abrir Nano.
     * complete recibe (texto, ok) desde Flutter. Llamado siempre en main thread.
     */
    fun query(
        prompt: String,
        mode: String,
        screenContext: Map<String, Any?>? = null,
        complete: (String?, Boolean) -> Unit,
    ): Boolean {
        val target = channel ?: return false
        // Despachar en el main looper — MethodChannel es thread-unsafe fuera de él.
        main.post {
            val args = mutableMapOf<String, Any>("prompt" to prompt, "mode" to mode)
            if (screenContext != null) {
                args["screenContext"] = screenContext
            }
            target.invokeMethod(
                "overlayQuery",
                args,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        val data = result as? Map<*, *>
                        complete(data?.get("text")?.toString(), data?.get("ok") == true)
                    }
                    override fun error(code: String, message: String?, details: Any?) {
                        complete(message ?: code, false)
                    }
                    override fun notImplemented() { complete(null, false) }
                },
            )
        }
        return true
    }
}
