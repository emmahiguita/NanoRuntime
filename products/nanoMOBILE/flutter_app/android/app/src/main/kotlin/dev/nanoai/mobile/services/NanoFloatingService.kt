package dev.nanoai.mobile.services

import android.animation.ValueAnimator
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.IBinder
import android.provider.Settings
import android.view.*
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import dev.nanoai.mobile.R

/**
 * NanoFloatingService — Asistente flotante nativo tipo Gemini fuera de Nano AI.
 *
 * QUÉ HACE: Despliega el búho en material Liquid Glass sobre cualquier app con
 *           levitación zero-g viva, física táctil de resorte y consulta a la IA.
 * CÓMO FUNCIONA: Usa WindowManager OVERLAY, interpoladores elásticos para morphing
 *                y dispatch directo de prompts hacia el chat de Nano AI.
 * POR QUÉ: Brinda acceso ubicuo e intuitivo a la IA local sin salir de la tarea activa.
 * CONTROL ZOMBI: START_NOT_STICKY y cancelación exhaustiva en onDestroy().
 */
class NanoFloatingService : Service() {
    private lateinit var manager: WindowManager
    private lateinit var root: NanoGlassCapsule
    private lateinit var params: WindowManager.LayoutParams
    private lateinit var owl: ImageView
    private lateinit var editor: EditText
    private lateinit var submit: TextView

    private var expanded = false
    private var levitateAnim: ValueAnimator? = null
    private var snapAnim: ValueAnimator? = null
    private var expandAnim: ValueAnimator? = null
    private val density get() = resources.displayMetrics.density
    private fun dp(v: Int): Int = (v * density).toInt()

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY

    override fun onCreate() {
        super.onCreate()
        if (!Settings.canDrawOverlays(this)) { stopSelf(); return }
        manager = getSystemService(WINDOW_SERVICE) as WindowManager
        _buildViews()
        _buildParams()
        _attachTouchListener()
        manager.addView(root, params)
        _startLevitation()
    }

    private fun _buildViews() {
        root = NanoGlassCapsule(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(5), dp(5), dp(8), dp(5))
            elevation = dp(16).toFloat()
        }
        owl = ImageView(this).apply {
            setImageResource(R.drawable.nano_owl_overlay)
            scaleType = ImageView.ScaleType.FIT_CENTER
            contentDescription = "Nano AI Asistente"
            setOnClickListener { toggle() }
        }
        editor = EditText(this).apply {
            hint = "Pregúntale a Nano..."
            textSize = 14f
            setTextColor(Color.WHITE)
            setHintTextColor(Color.rgb(148, 163, 184))
            background = null
            isSingleLine = true
            visibility = View.GONE
            imeOptions = EditorInfo.IME_ACTION_SEND
            setOnEditorActionListener { _, actionId, _ ->
                if (actionId == EditorInfo.IME_ACTION_SEND) { _submitPrompt(text.toString()); true } else false
            }
            setPadding(dp(8), 0, dp(6), 0)
        }
        submit = TextView(this).apply {
            text = "➤"
            textSize = 18f
            setTextColor(Color.rgb(56, 189, 248))
            gravity = Gravity.CENTER
            visibility = View.GONE
            setPadding(dp(8), dp(4), dp(8), dp(4))
            setOnClickListener { _submitPrompt(editor.text.toString()) }
        }
        root.addView(owl, LinearLayout.LayoutParams(dp(56), dp(56)))
        root.addView(editor, LinearLayout.LayoutParams(0, dp(48), 1f))
        root.addView(submit, LinearLayout.LayoutParams(dp(44), dp(48)))
    }

    private fun _buildParams() {
        params = WindowManager.LayoutParams(
            dp(68), dp(68), WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16); y = dp(180)
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        }
    }

    private fun _startLevitation() {
        levitateAnim = ValueAnimator.ofFloat(-1f, 1f).apply {
            duration = 2800; repeatCount = ValueAnimator.INFINITE; repeatMode = ValueAnimator.REVERSE
            addUpdateListener {
                val f = it.animatedValue as Float
                owl.translationY = f * dp(3)
                val breath = 1f + (kotlin.math.abs(f) * 0.035f)
                owl.scaleX = breath; owl.scaleY = breath
                owl.rotation = f * 1.5f
            }
            start()
        }
    }

    private fun _attachTouchListener() {
        var x0 = 0f; var y0 = 0f; var px = 0; var py = 0; var moved = false
        owl.setOnTouchListener { v, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    x0 = event.rawX; y0 = event.rawY; px = params.x; py = params.y; moved = false
                    owl.animate().scaleX(0.92f).scaleY(0.92f).setDuration(100).start()
                    root.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (kotlin.math.hypot((event.rawX - x0).toDouble(), (event.rawY - y0).toDouble()) > dp(6)) moved = true
                    if (moved) {
                        val dm = resources.displayMetrics
                        params.x = (px + event.rawX - x0).toInt().coerceIn(0, (dm.widthPixels - params.width).coerceAtLeast(0))
                        params.y = (py + event.rawY - y0).toInt().coerceIn(0, (dm.heightPixels - params.height).coerceAtLeast(0))
                        manager.updateViewLayout(root, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    owl.animate().scaleX(1f).scaleY(1f).setDuration(160).setInterpolator(OvershootInterpolator(1.4f)).start()
                    if (!moved) v.performClick() else _snapToEdge()
                    true
                }
                else -> false
            }
        }
    }

    private fun _snapToEdge() {
        val max = (resources.displayMetrics.widthPixels - params.width).coerceAtLeast(0)
        val target = if (params.x < max / 2) dp(8) else (max - dp(8)).coerceAtLeast(0)
        snapAnim?.cancel()
        snapAnim = ValueAnimator.ofInt(params.x, target).apply {
            duration = 260; interpolator = DecelerateInterpolator(1.8f)
            addUpdateListener {
                params.x = (it.animatedValue as Int).coerceIn(0, max)
                manager.updateViewLayout(root, params)
            }
            start()
        }
    }

    private fun toggle() {
        expanded = !expanded
        val targetW = if (expanded) (resources.displayMetrics.widthPixels - dp(24)).coerceAtMost(dp(360)) else dp(68)
        params.flags = if (expanded) WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                       else WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN

        expandAnim?.cancel()
        expandAnim = ValueAnimator.ofInt(params.width, targetW).apply {
            duration = if (expanded) 260 else 200
            interpolator = if (expanded) OvershootInterpolator(1.15f) else DecelerateInterpolator(1.5f)
            addUpdateListener {
                params.width = it.animatedValue as Int
                params.x = params.x.coerceIn(0, (resources.displayMetrics.widthPixels - params.width).coerceAtLeast(0))
                manager.updateViewLayout(root, params)
            }
            start()
        }

        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        if (expanded) {
            editor.visibility = View.VISIBLE; editor.alpha = 0f; editor.translationX = -dp(14).toFloat()
            editor.animate().alpha(1f).translationX(0f).setDuration(220).start()
            submit.visibility = View.VISIBLE; submit.scaleX = 0f; submit.scaleY = 0f
            submit.animate().scaleX(1f).scaleY(1f).setDuration(220).setInterpolator(OvershootInterpolator(1.3f)).start()
            editor.requestFocus(); imm.showSoftInput(editor, InputMethodManager.SHOW_IMPLICIT)
        } else {
            imm.hideSoftInputFromWindow(editor.windowToken, 0); editor.clearFocus()
            editor.animate().alpha(0f).setDuration(150).withEndAction { editor.visibility = View.GONE }.start()
            submit.animate().scaleX(0f).scaleY(0f).setDuration(150).withEndAction { submit.visibility = View.GONE }.start()
        }
    }

    private fun _submitPrompt(raw: String) {
        val prompt = raw.trim(); if (prompt.isEmpty()) return
        root.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
        root.setThinking(true)
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        launch.putExtra("nano.entry.prompt", prompt)
        launch.putExtra("nano.entry.source", "floating")
        startActivity(launch)
        root.postDelayed({
            editor.text?.clear(); root.setThinking(false)
            if (expanded) toggle()
        }, 380)
    }

    override fun onDestroy() {
        levitateAnim?.cancel(); snapAnim?.cancel(); expandAnim?.cancel()
        root.stopAnimations()
        if (::root.isInitialized) { try { manager.removeView(root) } catch (_: Exception) {} }
        super.onDestroy()
    }
}
