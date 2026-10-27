package dev.nanoai.mobile.services.whatsapp

import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Rect
import android.os.Build
import android.os.Bundle

/** Separa flags del Intent y opciones de lanzamiento. ActivityOptions se pasa
 * a startActivity(intent, options), nunca mediante putExtras del Intent. */
interface WindowStrategy {
    fun applyToIntent(intent: Intent, context: Context)
    fun launchOptions(context: Context): Bundle? = null
}

/** Solicita límites públicos de Android. El sistema puede ignorarlos; esta
 * estrategia no certifica que WhatsApp haya quedado en una ventana reducida. */
class AndroidFreeformStrategy : WindowStrategy {
    /** Una Activity externa conserva tarea propia sin extras OEM no documentados. */
    override fun applyToIntent(intent: Intent, context: Context) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    /** Calcula tamaño según el espacio real. El Bundle pertenece a ActivityOptions. */
    override fun launchOptions(context: Context): Bundle? {
        if (!WindowStrategySelector.supportsFloating(context)) return null
        val dm = context.resources.displayMetrics
        val width = (dm.widthPixels * .8f).toInt()
        val height = (dm.heightPixels * .7f).toInt()
        val left = (dm.widthPixels - width) / 2
        val top = (dm.heightPixels - height) / 2
        return ActivityOptions.makeBasic().apply {
            launchBounds = Rect(left, top, left + width, top + height)
        }.toBundle()
    }
}

/** Apertura normal. El overlay de Nano tiene permisos y ciclo de vida propios;
 * esta estrategia no afirma que el overlay esté activo ni fuerza mini-ventanas. */
class FullscreenOverlayStrategy : WindowStrategy {
    /** Conserva la ruta existente para compartir desde una tarea Android propia. */
    override fun applyToIntent(intent: Intent, context: Context) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }
}

/** Solo ofrece capacidades publicadas por Android; la marca no demuestra
 * soporte y no autoriza a inyectar flags privados de Samsung/ColorOS. */
object WindowStrategySelector {
    /** No confunde soporte PiP de vídeo con poder poner otra app en freeform. */
    fun supportsFloating(context: Context): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_FREEFORM_WINDOW_MANAGEMENT)

    /** Mantiene apertura normal salvo petición explícita y capacidad disponible. */
    fun resolveBest(context: Context, preferFloating: Boolean = false): WindowStrategy =
        if (preferFloating && supportsFloating(context)) AndroidFreeformStrategy()
        else FullscreenOverlayStrategy()
}
