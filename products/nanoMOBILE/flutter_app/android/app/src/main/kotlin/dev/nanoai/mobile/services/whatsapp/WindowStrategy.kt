package dev.nanoai.mobile.services.whatsapp

import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.Build

/**
 * QUÉ HACE: Interfaz abstracta para estrategias de posicionamiento de ventana al lanzar WhatsApp.
 * CÓMO FUNCIONA: Aplica flags de Intent y ActivityOptions según las capacidades del dispositivo.
 * POR QUÉ: Android impide embeber WhatsApp en WebViews o layouts Flutter (Activity Embedding sin permiso).
 *          Esta abstracción permite usar ventanas flotantes u overlays según el fabricante (OPPO, Samsung, etc.).
 * SOLID: Cumple Abierto/Cerrado (OCP) e Inversión de Dependencias (DIP).
 */
interface WindowStrategy {
    fun applyToIntent(intent: Intent, context: Context)
}

/**
 * QUÉ HACE: Estrategia para posicionar WhatsApp en modo ventana flotante (Freeform) nativo de Android.
 * CÓMO FUNCIONA: Utiliza [ActivityOptions.setLaunchBounds] con un marco centrado en pantalla.
 * POR QUÉ: Si el dispositivo admite Freeform (ej. Android Desktop o Developer Options), WhatsApp abre en ventana reducida.
 */
class AndroidFreeformStrategy(
    private val widthPercent: Float = 0.8f,
    private val heightPercent: Float = 0.7f
) : WindowStrategy {
    override fun applyToIntent(intent: Intent, context: Context) {
        val displayMetrics = context.resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels

        // Cálculo dinámico del rectángulo sin valores hardcodeados
        val width = (screenWidth * widthPercent).toInt()
        val height = (screenHeight * heightPercent).toInt()
        val left = (screenWidth - width) / 2
        val top = (screenHeight - height) / 2

        val bounds = Rect(left, top, left + width, top + height)
        val options = ActivityOptions.makeBasic()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            options.launchBounds = bounds
        }

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.putExtras(options.toBundle())
    }
}

/**
 * QUÉ HACE: Estrategia específica para dispositivos OEM (ColorOS/OPPO, MIUI, OneUI).
 * CÓMO FUNCIONA: Inyecta extras propietarios de ventana flotante conocidos de los fabricantes.
 * POR QUÉ: Dispositivos como OPPO CPH2557 (ColorOS) responden a extras OEM para abrir mini-ventanas flotantes.
 */
class OemFloatingWindowStrategy : WindowStrategy {
    override fun applyToIntent(intent: Intent, context: Context) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        // Flag propietario de ColorOS / OPPO para forzar ventana flotante Smart Sidebar
        intent.putExtra("com.oppo.intent.extra.FLOAT_WINDOW", true)
        // Flag propietario de Samsung Multi-Window / Pop-up view
        intent.putExtra("com.samsung.android.action.FORCE_WINDOW_MODE", true)
    }
}

/**
 * QUÉ HACE: Estrategia para abrir WhatsApp en pantalla dividida al lado de Nano.
 * CÓMO FUNCIONA: Aplica FLAG_ACTIVITY_LAUNCH_ADJACENT y FLAG_ACTIVITY_NEW_TASK.
 * POR QUÉ: Permite que Nano mantenga su UI visible en un lado mientras WhatsApp opera en el otro.
 */
class AdjacentMultiWindowStrategy : WindowStrategy {
    override fun applyToIntent(intent: Intent, context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            intent.addFlags(Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT or Intent.FLAG_ACTIVITY_NEW_TASK)
        } else {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }
}

/**
 * QUÉ HACE: Estrategia de respaldo universal (Fallback).
 * CÓMO FUNCIONA: Abre WhatsApp a pantalla completa mientras el Overlay de Accesibilidad de Nano permanece arriba.
 * POR QUÉ: Garantiza compatibilidad al 100% en teléfonos donde el SO ignora solicitudes de ventana flotante.
 */
class FullscreenOverlayStrategy : WindowStrategy {
    override fun applyToIntent(intent: Intent, context: Context) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }
}

/**
 * QUÉ HACE: Selector inteligente de la mejor estrategia de ventana disponible en el dispositivo.
 * CÓMO FUNCIONA: Evalúa la marca del fabricante y soporte de Android para retornar la estrategia óptima.
 * POR QUÉ: Evita fallos en tiempo de ejecución al seleccionar automáticamente la mejor opción según el hardware.
 */
object WindowStrategySelector {
    fun resolveBest(context: Context): WindowStrategy {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return when {
            // Samsung soporta flotante nativo Knox/OneUI de forma estable
            manufacturer.contains("samsung") -> {
                OemFloatingWindowStrategy()
            }
            // En ColorOS/OPPO/Realme/OnePlus y Android 14 moderno, flags propietarios
            // provocan onTaskVanished por FlexibleTaskController.
            // Usamos FullscreenOverlayStrategy para garantizar apertura confiable.
            else -> FullscreenOverlayStrategy()
        }
    }
}
