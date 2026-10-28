package dev.nanoai.mobile.services

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.Toast
import dev.nanoai.mobile.R
import io.flutter.embedding.android.FlutterView

/** Posee esfera y superficie Flutter compartida, sin otra UI ni ejecutor. */
open class NanoOwlWindowService : Service() {
    companion object {
        @Volatile var isActive = false
            private set
    }
    private lateinit var manager: WindowManager
    private lateinit var bubble: FrameLayout
    private lateinit var owl: ImageView
    private lateinit var placement: WindowManager.LayoutParams
    private lateinit var motion: NanoOwlAnimator
    private lateinit var lifecycle: NanoOverlayMotionLifecycle
    private lateinit var touch: NanoBubbleTouchHelper
    private lateinit var visibility: NanoOverlayHostVisibility
    private var panel: FlutterView? = null
    private var panelLayout: WindowManager.LayoutParams? = null
    private var hostVisible = false
    private var compact = false
    private var captureHidden = false
    private fun dp(value: Int) = NanoOverlayStyle.dp(this, value)
    override fun onBind(intent: Intent?): IBinder? = null

    /** Solo una entrada explícita expande; Android no reinicia la ventana sola. */
    override fun onStartCommand(intent: Intent?, flags: Int, id: Int): Int {
        if (intent?.action == "expand" || intent?.getStringExtra("action") == "expand") expand()
        return START_NOT_STICKY
    }

    /** Conserva sprites y reloj originales; observa la Activity por eventos. */
    override fun onCreate() {
        super.onCreate()
        if (!Settings.canDrawOverlays(this)) { stopSelf(); return }
        manager = getSystemService(WINDOW_SERVICE) as WindowManager
        NanoOverlayStyle.configure(this)
        owl = ImageView(this).apply {
            setImageResource(R.drawable.nano_owl_idle)
            scaleType = ImageView.ScaleType.FIT_CENTER
        }
        bubble = FrameLayout(this).apply {
            background = NanoOwlGlassDrawable()
            contentDescription = "Asistente Nano sobre otras apps"
            isClickable = true
            addView(owl, FrameLayout.LayoutParams(dp(58), dp(58), Gravity.CENTER))
        }
        placement = NanoOverlayWindowLayout.bubble(this)
        touch = NanoBubbleTouchHelper(this, placement, ::updateBubble,
            { if (compact) dock(false) else expand() }, { dock(!compact) })
        bubble.setOnTouchListener(touch)
        manager.addView(bubble, placement)
        motion = NanoOwlAnimator(owl)
        lifecycle = NanoOverlayMotionLifecycle(this, ::syncMotion)
        isActive = true
        lifecycle.attach()
        NanoFlutterPanelHost.action = { action, args -> when (action) {
            "collapse" -> collapse()
            "close" -> stopSelf()
            "openNano" -> openNano()
            "resize" -> resize((args?.get("height") as? Number)?.toDouble())
            "mood" -> (args?.get("state") as? String)?.let { motion.mood(it) }
            "captureVisibility" -> {
                captureHidden = args?.get("hidden") == true
                bubble.visibility = if (captureHidden || hostVisible || panel != null) View.GONE else View.VISIBLE
                syncMotion()
            }
            else -> Unit
        } }
        visibility = NanoOverlayHostVisibility(this) { foreground ->
            hostVisible = foreground
            if (foreground) collapse()
            bubble.visibility = if (captureHidden || foreground || panel != null) View.GONE else View.VISIBLE
            syncMotion()
        }
        visibility.attach()
    }

    /** Usa el mismo engine. Sin conexión informa el límite, sin UI alternativa. */
    private fun expand() {
        if (!isActive || hostVisible || panel != null) return
        val view = NanoFlutterPanelHost.create(this) ?: run {
            Toast.makeText(this, "Abre Nano una vez para conectar el búho.", Toast.LENGTH_LONG).show()
            return
        }
        panel = view
        panelLayout = NanoOverlayWindowLayout.panel(this).apply {
            height = minOf(dp(520), (resources.displayMetrics.heightPixels * .72f).toInt())
        }
        bubble.visibility = View.GONE
        syncMotion()
        manager.addView(view, panelLayout)
        NanoFlutterPanelHost.attach(view, ::collapse)
    }

    /** Minimizar conserva el controlador/borrador. La X detiene este servicio. */
    private fun collapse() {
        val old = panel ?: return
        panel = null
        NanoFlutterPanelHost.close()
        runCatching { manager.removeView(old) }
        bubble.visibility = if (hostVisible) View.GONE else View.VISIBLE
        syncMotion()
    }

    /** Recibe tamaño real por cambios de layout, nunca mediante un sondeo. */
    private fun resize(height: Double?) {
        if (height == null || !height.isFinite()) return
        val view = panel ?: return
        val layout = panelLayout ?: return
        val max = (resources.displayMetrics.heightPixels * .72f).toInt()
        val pixels = (height * resources.displayMetrics.density).toInt().coerceIn(dp(120), max)
        if (layout.height == pixels) return
        layout.height = pixels
        runCatching { manager.updateViewLayout(view, layout) }
    }

    /** Acople pequeño con mascota visible y coordenadas dentro de pantalla. */
    private fun dock(value: Boolean) {
        compact = value
        placement.width = dp(if (value) 44 else 70)
        placement.height = placement.width
        owl.layoutParams = FrameLayout.LayoutParams(dp(if (value) 34 else 58),
            dp(if (value) 34 else 58), Gravity.CENTER)
        placement.x = placement.x.coerceIn(0, (resources.displayMetrics.widthPixels - placement.width).coerceAtLeast(0))
        updateBubble()
    }
    private fun updateBubble() {
        if (panel == null) runCatching { manager.updateViewLayout(bubble, placement) }
    }
    private fun syncMotion() {
        if (!::motion.isInitialized || !::lifecycle.isInitialized) return
        if (isActive && !hostVisible && !captureHidden && panel == null && lifecycle.allowed) motion.start() else motion.stop()
    }
    private fun openNano() {
        collapse()
        packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            startActivity(this)
        }
    }
    /** Libera ventanas y listeners propios; no cancela tareas de otro dueño. */
    override fun onDestroy() {
        isActive = false
        NanoFlutterPanelHost.action = null
        if (::visibility.isInitialized) visibility.detach()
        if (::lifecycle.isInitialized) lifecycle.detach()
        if (::touch.isInitialized) touch.cancel()
        if (::motion.isInitialized) motion.stop()
        collapse()
        if (::manager.isInitialized && ::bubble.isInitialized) runCatching { manager.removeView(bubble) }
        super.onDestroy()
    }
}
