package dev.nanoai.mobile.services.whatsapp

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import dev.nanoai.mobile.services.AgentAccessibilityBridge
import java.io.File

/**
 * QUÉ HACE: Backend principal de orquestación para compartir fotos, vídeos, PDFs y audios en WhatsApp.
 * CÓMO FUNCIONA: Prepara los permisos de FileProvider, configura la estrategia de ventana (WindowStrategy),
 *                arma la verificación por accesibilidad y ejecuta el Intent de envío.
 * POR QUÉ: Permite enviar archivos multimedia usando la app de WhatsApp instalada sin violar sus términos (sin Baileys),
 *          manteniendo la UI de Nano visible según las capacidades del SO.
 * SOLID: Fachada limpia (Facade) que integra WindowStrategy, InteractiveWindowFinder y WhatsAppMediaVerifier.
 */
class WhatsAppShareMediaBackend(private val context: Context) {

    companion object {
        private const val TAG = "nanoagent_share"
    }

    /**
     * QUÉ HACE: Ejecuta la secuencia completa de preparación y envío multimedia.
     * CÓMO FUNCIONA:
     * 1. Valida existencia del archivo local.
     * 2. Obtiene URI segura vía FileProvider (`content://`).
     * 3. Configura Intent `ACTION_SEND` con MIME type, caption y permisos de lectura.
     * 4. Aplica [WindowStrategy] (Freeform / Multiwindow / Overlay).
     * 5. Arma la verficación atómica por accesibilidad en [AgentAccessibilityBridge].
     * 6. Lanza la actividad con fallback automático entre `com.whatsapp` y `com.whatsapp.w4b`.
     */
    fun shareMedia(
        filePath: String,
        targetContact: String?,
        caption: String = "",
        requestedPackage: String = "com.whatsapp",
        autoSend: Boolean = true
    ): Boolean {
        val resolved = try { File(filePath).canonicalFile } catch (_: Exception) { File(filePath) }
        val file = if (resolved.isFile) resolved else File(filePath)
        if (!file.isFile) {
            Log.e(TAG, "Fail-closed: El archivo no existe o no es válido: $filePath (canonical: ${resolved.path})")
            return false
        }

        try {
            // Generación de URI segura vía FileProvider
            val authority = "${context.packageName}.fileprovider"
            val fileUri: Uri = FileProvider.getUriForFile(context, authority, file)
            val mimeType = resolveMimeType(file.name)

            // Construcción del Intent base de envío oficial de Android
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, fileUri)
                if (caption.isNotBlank()) {
                    putExtra(Intent.EXTRA_TEXT, caption)
                }
                val digits = targetContact?.replace(Regex("\\D"), "")
                if (!digits.isNullOrBlank()) {
                    val jid = if (digits.contains("@")) digits else "$digits@s.whatsapp.net"
                    putExtra("jid", jid)
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            // Conceder permisos explícitos sobre el URI para el paquete de destino
            listOf(requestedPackage, "com.whatsapp", "com.whatsapp.w4b").forEach { pkg ->
                try {
                    context.grantUriPermission(pkg, fileUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } catch (_: Exception) {}
            }

            // Aplicar la estrategia de ventana óptima según el dispositivo (ColorOS, Freeform, Overlay)
            val windowStrategy = WindowStrategySelector.resolveBest(context)
            windowStrategy.applyToIntent(intent, context)

            // Armar verificación por accesibilidad si el servicio está activo (desactivado en Play Store)
            if (!dev.nanoai.mobile.BuildConfig.PLAY_STORE_BUILD && autoSend && AgentAccessibilityBridge.service != null) {
                armAccessibilityMediaSend(targetContact, requestedPackage)
            }

            // Intentar lanzamiento en paquete solicitado con fallback automático
            return launchWithFallback(intent, requestedPackage)

        } catch (e: Exception) {
            Log.e(TAG, "Error fatal durante la preparación de envío multimedia: ${e.message}", e)
            AgentAccessibilityBridge.disarmAutoSend()
            return false
        }
    }

    /**
     * QUÉ HACE: Registra la tarea de verificación y clic en el bridge de Accesibilidad.
     */
    private fun armAccessibilityMediaSend(targetContact: String?, pkg: String) {
        val digits = targetContact?.filter { it.isDigit() }?.takeIf { it.length >= 7 }
        val alias = targetContact?.takeIf { it != digits }
        AgentAccessibilityBridge.armAutoSendAndReturn(
            targetPkg = pkg,
            targetContact = digits ?: targetContact,
            expectedAlias = alias
        )
    }

    /**
     * QUÉ HACE: Ejecuta el Intent con manejo de excepciones y conmutación entre WhatsApp y WhatsApp Business.
     */
    private fun launchWithFallback(intent: Intent, primaryPkg: String): Boolean {
        return try {
            intent.setPackage(primaryPkg)
            context.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            val fallbackPkg = if (primaryPkg == "com.whatsapp") "com.whatsapp.w4b" else "com.whatsapp"
            try {
                Log.w(TAG, "Paquete $primaryPkg no disponible. Intentando fallback: $fallbackPkg")
                intent.setPackage(fallbackPkg)
                context.startActivity(intent)
                true
            } catch (fallbackEx: ActivityNotFoundException) {
                Log.e(TAG, "Ninguna versión de WhatsApp está instalada en el dispositivo")
                AgentAccessibilityBridge.disarmAutoSend()
                false
            }
        }
    }

    /**
     * QUÉ HACE: Determina el MIME Type preciso por la extensión del archivo.
     * POR QUÉ: Permite que WhatsApp reconozca si debe desplegar vista previa de imagen, reproductor de vídeo o visor de PDF.
     */
    private fun resolveMimeType(fileName: String): String {
        return when (fileName.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "mp4" -> "video/mp4"
            "pdf" -> "application/pdf"
            "ogg" -> "audio/ogg"
            "mp3" -> "audio/mpeg"
            "txt" -> "text/plain"
            else -> "*/*"
        }
    }
}
