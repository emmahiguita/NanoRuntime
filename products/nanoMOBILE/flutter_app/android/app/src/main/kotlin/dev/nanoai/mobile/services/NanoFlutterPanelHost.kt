package dev.nanoai.mobile.services

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/** Presta la superficie del MISMO engine al servicio. No inicia otro isolate,
 * modelo o controlador. Al volver a Nano devuelve la vista a la Activity. */
internal object NanoFlutterPanelHost {
    private var engine: FlutterEngine? = null
    private var home: WeakReference<FlutterView>? = null
    private var external: FlutterView? = null
    private var channel: MethodChannel? = null
    var action: ((String, Map<*, *>?) -> Unit)? = null
    private var generation = 0
    private var context: Context? = null
    private val main = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null

    /** Registra únicamente el transporte de presentación del engine existente. */
    fun register(value: FlutterEngine, appContext: Context) {
        engine = value
        context = appContext.applicationContext
        channel = MethodChannel(value.dartExecutor.binaryMessenger, "dev.nanoai/owl_surface").also { wire ->
            wire.setMethodCallHandler { call, result ->
                if (call.method == "pendingImports") {
                    result.success(context?.let(NanoOwlShareInbox::list) ?: emptyList<Map<String, String>>())
                    return@setMethodCallHandler
                }
                if (call.method == "ackImport") {
                    result.success(context?.let { NanoOwlShareInbox.acknowledge(it, call.argument<String>("path") ?: "") } ?: false)
                    return@setMethodCallHandler
                }
                if (call.method == "inputStatus") {
                    result.success(context?.let(dev.nanoai.mobile.input.NanoInputStatus::snapshot))
                    return@setMethodCallHandler
                }
                if (call.method == "openInputSettings") {
                    try {
                        context?.let(dev.nanoai.mobile.input.NanoInputStatus::openKeyboardSettings)
                        result.success(context != null)
                    } catch (_: Exception) {
                        result.error("INPUT_SETTINGS_UNAVAILABLE", "No se pudieron abrir ajustes del teclado.", null)
                    }
                    return@setMethodCallHandler
                }
                if (call.method in setOf("collapse", "close", "openNano", "resize", "captureVisibility", "executionVisibility", "mood")) {
                    action?.invoke(call.method, call.arguments as? Map<*, *>)
                    result.success(true)
                } else result.notImplemented()
            }
        }
    }

    /** Entrega datos al importador del mismo engine. Sin UI, el inbox queda
     * pendiente para el próximo arranque, sin declarar un guardado inexistente. */
    fun notifyImport(): Boolean {
        val wire = channel ?: return false
        wire.invokeMethod("importReady", null)
        return true
    }

    /** Encuentra la vista creada por FlutterActivity después de super.onResume.
     * Conserva solo referencia débil: no retiene una Activity destruida. */
    fun bindActivity(activity: Activity) {
        val current = find(activity.window.decorView) ?: return
        close(restoreHome = false)
        home = WeakReference(current)
        engine?.let { current.attachToFlutterEngine(it) }
    }

    /** Recorre solo el árbol de vistas de nuestra propia Activity. */
    private fun find(view: View): FlutterView? {
        if (view is FlutterView) return view
        if (view is ViewGroup) for (i in 0 until view.childCount) {
            find(view.getChildAt(i))?.let { return it }
        }
        return null
    }

    /** Crea una textura transparente. El servicio la añade oculta antes de
     * attach para que el primer frame no muestre el navegador completo. */
    fun create(context: Context): FlutterView? {
        val owner = engine ?: return null
        if (!owner.dartExecutor.isExecutingDart) return null
        home?.get()?.detachFromFlutterEngine()
        val texture = FlutterTextureView(context).apply { isOpaque = false }
        return NanoOwlFlutterView(context, texture) { channel?.invokeMethod("back", null) }.apply {
            setBackgroundColor(Color.TRANSPARENT)
            alpha = 0f
            external = this
        }
    }

    /** Flutter confirma que ha montado el panel compartido antes de mostrarlo.
     * Cada apertura tiene revisión para descartar respuestas de ventanas cerradas. */
    fun attach(view: FlutterView, failed: () -> Unit) {
        val owner = engine ?: return failed()
        val revision = ++generation
        pending?.let(main::removeCallbacks)
        pending = Runnable { if (revision == generation) failed() }.also { main.postDelayed(it, 5000) }
        view.attachToFlutterEngine(owner)
        owner.lifecycleChannel.appIsResumed()
        channel?.invokeMethod("setVisible", true, object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (revision != generation) return
                pending?.let(main::removeCallbacks)
                pending = null
                if (result == true) view.alpha = 1f else failed()
            }
            override fun error(code: String, message: String?, details: Any?) {
                if (revision == generation) failed()
            }
            override fun notImplemented() { if (revision == generation) failed() }
        }) ?: failed()
    }

    /** Cierra solo presentación. El controlador Dart y el turno permanecen en
     * su engine propietario; no se crea una segunda conversación al volver. */
    fun close(restoreHome: Boolean = true) {
        if (external == null) return
        generation++
        pending?.let(main::removeCallbacks)
        pending = null
        external?.detachFromFlutterEngine()
        external = null
        channel?.invokeMethod("setVisible", false)
        if (restoreHome) engine?.let { home?.get()?.attachToFlutterEngine(it) }
        if (!dev.nanoai.mobile.MainActivity.isForeground) engine?.lifecycleChannel?.appIsPaused()
    }

    /** Una Activity destruida cierra sus canales. No vuelve a prestar un engine
     * cacheado cuyo transporte de archivos/voz ya fue liberado. */
    fun release(value: FlutterEngine) {
        if (engine !== value) return
        close(restoreHome = false)
        action?.invoke("close", null)
        channel?.setMethodCallHandler(null)
        channel = null
        home = null
        engine = null
    }
}
