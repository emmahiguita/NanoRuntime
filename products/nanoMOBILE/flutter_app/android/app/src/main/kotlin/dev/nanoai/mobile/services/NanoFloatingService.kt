package dev.nanoai.mobile.services

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import dev.nanoai.mobile.R

/** Overlay nativo: WindowManager posee la burbuja y libera sus recursos al detenerse. */
class NanoFloatingService : Service() {
    companion object {
        // Estado del servicio real, no una preferencia que sobreviva a su muerte.
        @Volatile var isActive = false
            private set
    }

    private lateinit var manager: WindowManager
    private lateinit var bubble: FrameLayout
    private lateinit var owlView: ImageView
    private lateinit var bubbleLayout: WindowManager.LayoutParams
    private lateinit var owlMotion: NanoOwlAnimator
    private lateinit var motionLifecycle: NanoOverlayMotionLifecycle
    private lateinit var touchHelper: NanoBubbleTouchHelper
    private lateinit var actions: NanoOverlayActions

    private var panelView: NanoGeminiOverlayView? = null
    private var isExpanded = false
    private var isHiddenToEdge = false
    private val session = NanoOverlaySession()

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
        actions = NanoOverlayActions(this, { panelView }, { collapsePanel() },
            { session.result = it; panelView?.showResult(it) }, { owlMotion.mood(it) }, { isActive })
        NanoOverlayStyle.configure(this)
        setupBubble()
        manager.addView(bubble, bubbleLayout)
        owlMotion = NanoOwlAnimator(owlView)
        motionLifecycle = NanoOverlayMotionLifecycle(this) { syncOwlMotion() }
        isActive = true
        motionLifecycle.attach()
    }

    private fun setupBubble() {
        owlView = ImageView(this).apply {
            setImageResource(R.drawable.nano_owl_idle)
            scaleType = ImageView.ScaleType.CENTER_CROP
        }
        val circleBg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(NanoOverlayStyle.bgGlass)
            setStroke(dp(1), NanoOverlayStyle.borderGlass)
        }
        bubble = FrameLayout(this).apply {
            background = circleBg
            contentDescription = "Asistente Nano sobre otras apps"
            isClickable = true
            setOnClickListener { if (isHiddenToEdge) setEdgeDock(false) else expandPanel() }
            elevation = dp(12).toFloat()
            addView(owlView, FrameLayout.LayoutParams(dp(68), dp(68), Gravity.CENTER))
        }

        var bubbleFlags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && NanoOverlayStyle.glassEnabled) {
            bubbleFlags = bubbleFlags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
        }

        bubbleLayout = WindowManager.LayoutParams(
            dp(70), dp(70), WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            bubbleFlags,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(8)
            y = dp(180)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && NanoOverlayStyle.glassEnabled) {
                blurBehindRadius = dp(16)
            }
        }
        touchHelper = NanoBubbleTouchHelper(this, bubbleLayout, { tryUpdateBubble() },
            { if (isHiddenToEdge) setEdgeDock(false) else expandPanel() }, { setEdgeDock(!isHiddenToEdge) })
        bubble.setOnTouchListener(touchHelper)
    }

    /** Reconstruye la ventana adaptativa y recupera el borrador del servicio;
     * cerrar la superficie no invalida el resultado pendiente del ejecutor. */
    private fun expandPanel() {
        if (isExpanded) return
        NanoOverlayStyle.configure(this)
        isExpanded = true
        owlMotion.stop()
        bubble.visibility = View.GONE
        val dm = resources.displayMetrics
        val panelW = (dm.widthPixels * 0.94f).toInt().coerceAtMost(dp(420))

        var panelFlags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && NanoOverlayStyle.glassEnabled) {
            panelFlags = panelFlags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
        }

        val panelLayout = WindowManager.LayoutParams(
            panelW, WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            panelFlags, PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.CENTER
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && NanoOverlayStyle.glassEnabled) {
                blurBehindRadius = dp(NanoOverlayStyle.glassBlur)
            }
        }

        panelView = NanoGeminiOverlayView(this, { collapsePanel() }, { openFullApp() },
            { tool, provider, prompt -> actions.handle(tool, provider, prompt) },
            { url, audioOnly -> actions.download(url, audioOnly) },
            initialTool = session.tool, initialDraft = session.draft,
            onDraftChanged = { session.draft = it }, onToolSelected = { session.tool = it })
        manager.addView(panelView, panelLayout)
        session.takeResult()?.let { panelView?.showResult(it) }
    }

    private fun collapsePanel() {
        if (!isExpanded) return
        isExpanded = false
        panelView?.let { try { manager.removeView(it) } catch (_: IllegalArgumentException) {}; panelView = null }
        bubble.visibility = View.VISIBLE
        syncOwlMotion()
    }

    private fun setEdgeDock(dock: Boolean) {
        isHiddenToEdge = dock
        bubbleLayout.width = if (dock) dp(32) else dp(70)
        owlView.visibility = if (dock) View.INVISIBLE else View.VISIBLE
        syncOwlMotion()
        tryUpdateBubble()
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

    private fun syncOwlMotion() {
        if (!::owlMotion.isInitialized || !::motionLifecycle.isInitialized) return
        if (isActive && !isExpanded && !isHiddenToEdge && motionLifecycle.allowed) owlMotion.start()
        else owlMotion.stop()
    }

    // onDestroy: orden crítico (animaciones → panel → burbuja).
    // NanoAtomicSnapshotter pertenece al AccessibilityService, no al overlay.
    override fun onDestroy() {
        isActive = false
        if (::motionLifecycle.isInitialized) motionLifecycle.detach()
        if (::touchHelper.isInitialized) touchHelper.cancel()
        if (::owlMotion.isInitialized) owlMotion.stop()
        if (::actions.isInitialized) actions.close()
        collapsePanel()
        if (::manager.isInitialized && ::bubble.isInitialized) {
            try { manager.removeView(bubble) } catch (_: IllegalArgumentException) {}
        }
        super.onDestroy()
    }
}
