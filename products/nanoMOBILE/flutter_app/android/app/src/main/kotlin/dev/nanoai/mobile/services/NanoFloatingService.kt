package dev.nanoai.mobile.services

import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import dev.nanoai.mobile.R

/**
 * NanoFloatingService — Asistente flotante nativo estilo Gemini y descargador estilo Snaptube.
 *
 * QUÉ: Alterna entre burbuja viva/pestaña iOS y panel Glass interactivo sin abrir MainActivity.
 * CÓMO: WindowManager gestiona TYPE_APPLICATION_OVERLAY. Orquesta NanoScreenReader, NanoOverlayBridge,
 *       NanoMediaResolver (YouTube/X/Insta) y NanoMediaDownloader (DownloadManager).
 * POR QUÉ: Permite usar la IA y descargar MP4/MP3 en WhatsApp o YouTube sin salir de ellas.
 * SOLID-S: Orquesta las capas nativas de vista, interacción y descarga multimedia.
 */
class NanoFloatingService : Service() {
    private lateinit var manager: WindowManager
    private lateinit var bubble: FrameLayout
    private lateinit var owlView: ImageView
    private lateinit var bubbleLayout: WindowManager.LayoutParams
    private lateinit var owlMotion: NanoOwlAnimator
    private lateinit var touchHelper: NanoBubbleTouchHelper
    private lateinit var downloader: NanoMediaDownloader
    private lateinit var mediaResolver: NanoMediaResolver

    private var panelView: NanoGeminiOverlayView? = null
    private var isExpanded = false
    private var isHiddenToEdge = false

    private fun dp(n: Int) = NanoOverlayStyle.dp(this, n)
    override fun onBind(i: Intent?): IBinder? = null

    override fun onStartCommand(i: Intent?, f: Int, id: Int): Int {
        if (i?.action == "expand" || i?.getStringExtra("action") == "expand") {
            expandPanel()
        }
        return START_NOT_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        if (!Settings.canDrawOverlays(this)) { stopSelf(); return }

        manager = getSystemService(WINDOW_SERVICE) as WindowManager
        downloader = NanoMediaDownloader(this)
        mediaResolver = NanoMediaResolver(this)
        setupBubble()
        manager.addView(bubble, bubbleLayout)
        owlMotion = NanoOwlAnimator(owlView).also { it.start() }
    }

    private fun setupBubble() {
        owlView = ImageView(this).apply {
            setImageResource(R.drawable.nano_owl_idle)
            scaleType = ImageView.ScaleType.CENTER_CROP
        }
        val circleBg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.argb(235, 9, 13, 22))
            setStroke(dp(2), NanoOverlayStyle.cyanGlow)
        }
        bubble = FrameLayout(this).apply {
            background = circleBg
            elevation = dp(12).toFloat()
            addView(owlView, FrameLayout.LayoutParams(dp(68), dp(68), Gravity.CENTER))
        }
        bubbleLayout = WindowManager.LayoutParams(
            dp(70), dp(70),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(8); y = dp(180)
        }
        touchHelper = NanoBubbleTouchHelper(
            context = this, layout = bubbleLayout,
            onUpdate = { tryUpdateBubble() },
            onClick = { if (isHiddenToEdge) restoreFromEdge() else expandPanel() },
            onDoubleTap = { toggleEdgeDock() }
        )
        bubble.setOnTouchListener(touchHelper)
    }

    private fun expandPanel() {
        if (isExpanded) return
        isExpanded = true
        bubble.visibility = View.GONE

        val dm = resources.displayMetrics
        val panelW = (dm.widthPixels * 0.94f).toInt().coerceAtMost(dp(420))
        val panelLayout = WindowManager.LayoutParams(
            panelW, dp(400),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dp(24)
        }

        panelView = NanoGeminiOverlayView(
            context = this,
            onClose = { collapsePanel() },
            onOpenFullApp = { openFullApp() },
            onAction = { tool, provider, prompt -> handlePanelAction(tool, provider, prompt) },
            onDownloadRequest = { url, audioOnly -> handleDownload(url, audioOnly) }
        )
        manager.addView(panelView, panelLayout)
    }

    private fun collapsePanel() {
        if (!isExpanded) return
        isExpanded = false
        panelView?.let {
            try { manager.removeView(it) } catch (_: IllegalArgumentException) {}
            panelView = null
        }
        bubble.visibility = View.VISIBLE
    }

    private fun toggleEdgeDock() {
        isHiddenToEdge = !isHiddenToEdge
        bubbleLayout.width = if (isHiddenToEdge) dp(32) else dp(70)
        owlView.visibility = if (isHiddenToEdge) View.INVISIBLE else View.VISIBLE
        tryUpdateBubble()
    }

    private fun restoreFromEdge() {
        isHiddenToEdge = false
        bubbleLayout.width = dp(70)
        owlView.visibility = View.VISIBLE
        tryUpdateBubble()
    }

    private fun handlePanelAction(tool: String, provider: String, prompt: String) {
        val view = panelView ?: return
        val detectedUrl = NanoMediaResolver.extractUrlFromText(prompt)
        val screen = NanoScreenReader.readCurrentScreen()

        // Si el usuario pasó un link directo o eligió Media, activa descarga de una
        if (detectedUrl != null || tool == "Media") {
            val target = detectedUrl ?: screen?.links?.firstOrNull() ?: ""
            if (target.isNotEmpty()) {
                view.showResult("Enlace multimedia detectado:\n$target", listOf(target))
                return
            }
        }

        view.setLoading("Analizando con $provider ($tool)")
        val screenCtx = screen?.let { mapOf("package" to it.packageName, "text" to it.visibleText, "links" to it.links) }
        val queryPrompt = when (tool) {
            "Resumir" -> if (prompt.isEmpty()) "Resume concisamente la pantalla activa." else prompt
            else -> prompt.ifEmpty { "Explica el contenido de la pantalla." }
        }
        val sent = NanoOverlayBridge.query(queryPrompt, "quick", screenCtx) { text, ok ->
            view.showResult(text ?: (screen?.visibleText?.take(300) ?: "Listo."), screen?.links.orEmpty())
        }
        if (!sent) view.showResult(screen?.visibleText?.take(300) ?: "Listo.", screen?.links.orEmpty())
    }

    private fun handleDownload(url: String, audioOnly: Boolean) {
        panelView?.setLoading("Extrayendo stream con NanoSnaptube…")
        mediaResolver.resolveMedia(url, audioOnly) { media, err ->
            if (media != null) {
                downloader.download(media.downloadUrl) { ok, path ->
                    panelView?.showResult(if (ok) "✅ Descargado en Downloads/Nano/: $path" else "❌ Error en descarga.")
                }
            } else {
                panelView?.showResult("❌ No se pudo extraer stream: ${err ?: "Enlace no soportado"}")
            }
        }
    }

    private fun openFullApp() {
        collapsePanel()
        packageManager.getLaunchIntentForPackage(packageName)?.apply {
            action = Intent.ACTION_VIEW
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            startActivity(this)
        }
    }

    private fun tryUpdateBubble() {
        if (::manager.isInitialized && ::bubble.isInitialized && !isExpanded) {
            try { manager.updateViewLayout(bubble, bubbleLayout) } catch (_: IllegalArgumentException) {}
        }
    }

    override fun onDestroy() {
        if (::touchHelper.isInitialized) touchHelper.cancel()
        if (::owlMotion.isInitialized) owlMotion.stop()
        if (::downloader.isInitialized) downloader.detach()
        if (::mediaResolver.isInitialized) mediaResolver.destroy()
        collapsePanel()
        if (::manager.isInitialized && ::bubble.isInitialized) {
            try { manager.removeView(bubble) } catch (_: IllegalArgumentException) {}
        }
        super.onDestroy()
    }
}
