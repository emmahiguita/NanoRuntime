package dev.nanoai.mobile.services

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import dev.nanoai.mobile.MainActivity

/** Observa la Activity propietaria sin sondeos. El servicio puede seguir activo
 * fuera de Nano, pero sus ventanas se apartan cuando Nano vuelve a primer plano. */
internal class NanoOverlayHostVisibility(
    context: Context,
    private val changed: (Boolean) -> Unit,
) : Application.ActivityLifecycleCallbacks {
    private val app = context.applicationContext as Application
    private var attached = false
    private var hostVisible = MainActivity.isForeground

    /** Registra una sola suscripción y publica el estado real inicial. */
    fun attach() {
        if (attached) return
        attached = true
        app.registerActivityLifecycleCallbacks(this)
        changed(hostVisible)
    }

    /** El servicio es dueño de esta suscripción; no detiene ninguna acción. */
    fun detach() {
        if (!attached) return
        attached = false
        app.unregisterActivityLifecycleCallbacks(this)
    }

    /** Evita reconstruir ventanas por cada callback de una misma transición. */
    private fun update(visible: Boolean) {
        if (!attached || hostVisible == visible) return
        hostVisible = visible
        changed(visible)
    }

    override fun onActivityStarted(activity: Activity) {
        if (activity is MainActivity) update(true)
    }

    override fun onActivityResumed(activity: Activity) {
        if (activity is MainActivity) update(true)
    }

    override fun onActivityStopped(activity: Activity) {
        // Rotar Nano no es abrir otra app: la Activity sustituta conserva dueño.
        if (activity is MainActivity && !activity.isChangingConfigurations) update(false)
    }

    override fun onActivityCreated(activity: Activity, state: Bundle?) = Unit
    override fun onActivityPaused(activity: Activity) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit
    override fun onActivityDestroyed(activity: Activity) = Unit
}
