package dev.nanoai.mobile.services

import android.content.Context
import android.os.Build
import android.view.KeyEvent
import android.view.MotionEvent
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView

/** Superficie Flutter con Atrás propio de esta ventana. El IME conserva su
 * prioridad; no se envía Atrás al navegador de Nano que está fuera de pantalla. */
internal class NanoOwlFlutterView(context: Context, texture: FlutterTextureView,
    private val collapse: () -> Unit) : FlutterView(context, texture) {
    private var release: (() -> Unit)? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (Build.VERSION.SDK_INT >= 33) {
            val dispatcher = findOnBackInvokedDispatcher() ?: return
            val callback = OnBackInvokedCallback(collapse)
            dispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, callback)
            release = { dispatcher.unregisterOnBackInvokedCallback(callback) }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_BACK) return super.dispatchKeyEvent(event)
        if (event.action == KeyEvent.ACTION_UP && !event.isCanceled) collapse()
        return true
    }

    /** Un toque fuera de la ventana del panel lo repliega a la burbuja del búho. */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_OUTSIDE) {
            collapse()
            return true
        }
        return super.onTouchEvent(event)
    }

    override fun onDetachedFromWindow() {
        release?.invoke()
        release = null
        super.onDetachedFromWindow()
    }
}
