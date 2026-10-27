package dev.nanoai.mobile.services

import android.animation.ValueAnimator
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PowerManager

/** Observa pantalla y ahorro de batería por eventos, sin sondeos. El servicio
 * conserva su función; solo el movimiento decorativo se detiene en reposo. */
internal class NanoOverlayMotionLifecycle(
    private val context: Context,
    private val onChanged: () -> Unit,
) {
    private val power = context.getSystemService(PowerManager::class.java)
    val allowed: Boolean get() = power.isInteractive && !power.isPowerSaveMode &&
        (Build.VERSION.SDK_INT < 26 || ValueAnimator.areAnimatorsEnabled())
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, i: Intent?) = onChanged()
    }
    fun attach() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else context.registerReceiver(receiver, filter)
        onChanged()
    }
    fun detach() = context.unregisterReceiver(receiver)
}
