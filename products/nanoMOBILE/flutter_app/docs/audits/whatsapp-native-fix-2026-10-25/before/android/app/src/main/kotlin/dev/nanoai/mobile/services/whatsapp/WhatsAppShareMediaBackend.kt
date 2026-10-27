package dev.nanoai.mobile.services.whatsapp

import android.content.ActivityNotFoundException
import android.content.ClipData
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
        targetAlias: String? = null,
        recipientKind: String = "direct",
        recipientVerified: Boolean = false,
        caption: String = "",
        requestedPackage: String = "com.whatsapp",
        autoSend: Boolean = false
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
                clipData = ClipData.newUri(context.contentResolver, "Nano media", fileUri)
                val trustedJid = targetContact?.trim()?.takeIf { raw ->
                    recipientVerified && when (recipientKind) {
                        "group" -> raw.endsWith("@g.us", ignoreCase = true)
                        else -> raw.endsWith("@s.whatsapp.net", ignoreCase = true)
                    }
                }
                if (trustedJid != null) {
                    putExtra("jid", trustedJid)
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

            val targetPackage = resolveTargetPackage(intent, requestedPackage)
            if (targetPackage == null) {
                Log.e(TAG, "Ninguna versión compatible de WhatsApp puede recibir el archivo")
                return false
            }

            // Armar verificación por accesibilidad si el servicio está activo (desactivado en Play Store)
            val autoSendArmed = if (
                !dev.nanoai.mobile.BuildConfig.PLAY_STORE_BUILD &&
                autoSend &&
                AgentAccessibilityBridge.service != null &&
                recipientVerified &&
                !targetAlias.isNullOrBlank()
            ) {
                armAccessibilityMediaSend(targetContact, targetAlias, recipientKind, targetPackage)
            } else {
                if (autoSend) {
                    Log.w(TAG, "Autoenvío no disponible; se usará el selector nativo de WhatsApp")
                }
                false
            }

            // Sin autoenvío, Android Sharesheet expone los Direct Share de WhatsApp.
            return launchWithFallback(intent, targetPackage, useChooser = !autoSendArmed)

        } catch (e: Exception) {
            Log.e(TAG, "Error fatal durante la preparación de envío multimedia: ${e.message}", e)
            AgentAccessibilityBridge.disarmAutoSend()
            return false
        }
    }

    /**
     * QUÉ HACE: Registra la tarea de verificación y clic en el bridge de Accesibilidad.
     */
    private fun armAccessibilityMediaSend(
        targetContact: String?,
        targetAlias: String,
        recipientKind: String,
        pkg: String,
    ): Boolean {
        val digits = if (recipientKind == "group") null else targetContact
            ?.takeUnless { it.startsWith("shortcut:", ignoreCase = true) }
            ?.filter(Char::isDigit)
            ?.takeIf { it.length in 7..15 }
        return AgentAccessibilityBridge.armAutoSendAndReturn(
            targetPkg = pkg,
            targetContact = digits,
            expectedAlias = targetAlias,
            timeoutMs = 25_000L,
        )
    }

    private fun resolveTargetPackage(intent: Intent, requestedPackage: String): String? {
        val candidates = listOf(
            requestedPackage,
            if (requestedPackage == "com.whatsapp") "com.whatsapp.w4b" else "com.whatsapp",
        ).distinct()
        return candidates.firstOrNull { pkg ->
            Intent(intent).setPackage(pkg).resolveActivity(context.packageManager) != null
        }
    }

    /**
     * QUÉ HACE: Ejecuta el Intent con manejo de excepciones y conmutación entre WhatsApp y WhatsApp Business.
     */
    private fun launchWithFallback(intent: Intent, primaryPkg: String, useChooser: Boolean): Boolean {
        fun launchFor(pkg: String, chooser: Boolean = useChooser) {
            val targeted = Intent(intent).setPackage(pkg)
            val launchIntent = if (chooser) {
                Intent.createChooser(targeted, null).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            } else {
                targeted
            }
            context.startActivity(launchIntent)
        }
        return try {
            launchFor(primaryPkg)
            true
        } catch (e: ActivityNotFoundException) {
            val fallbackPkg = if (primaryPkg == "com.whatsapp") "com.whatsapp.w4b" else "com.whatsapp"
            try {
                Log.w(TAG, "Paquete $primaryPkg no disponible. Intentando fallback: $fallbackPkg")
                AgentAccessibilityBridge.disarmAutoSend("El paquete objetivo cambió antes de abrir WhatsApp.")
                launchFor(fallbackPkg, chooser = true)
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
            "gif" -> "image/gif"
            "heic", "heif" -> "image/heic"
            "bmp" -> "image/bmp"
            "mp4" -> "video/mp4"
            "m4v" -> "video/x-m4v"
            "mov" -> "video/quicktime"
            "3gp" -> "video/3gpp"
            "mkv" -> "video/x-matroska"
            "webm" -> "video/webm"
            "avi" -> "video/x-msvideo"
            "pdf" -> "application/pdf"
            "ogg" -> "audio/ogg"
            "mp3" -> "audio/mpeg"
            "txt" -> "text/plain"
            else -> "*/*"
        }
    }
}
