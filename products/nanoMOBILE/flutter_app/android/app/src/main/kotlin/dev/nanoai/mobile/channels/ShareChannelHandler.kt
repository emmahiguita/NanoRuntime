package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import dev.nanoai.mobile.services.AgentAccessibilityBridge
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ShareChannelHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "shareText" -> shareText(call, result)
            "openChat" -> openChat(call, result)
            "copyToCatalog" -> copyToCatalog(call, result)
            "shareFile" -> shareFile(call, result)
            "isAccessibilityEnabled" -> isAccessibilityEnabled(result)
            "openAccessibilitySettings" -> openAccessibilitySettings(result)
            else -> result.notImplemented()
        }
    }

    private fun isAccessibilityEnabled(result: MethodChannel.Result) {
        val isConnected = AgentAccessibilityBridge.service != null
        result.success(isConnected)
    }

    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("settings_failed", "No se pudo abrir ajustes de accesibilidad: ${e.message}", null)
        }
    }

    private fun shareText(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val text = args?.get("text") as? String
        val title = args?.get("title") as? String ?: "NanoAI"
        if (text.isNullOrBlank()) {
            result.error("empty_text", "No hay texto para compartir", null)
            return
        }
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            putExtra(Intent.EXTRA_TITLE, title)
        }
        val chooser = Intent.createChooser(send, title)
        activity.startActivity(chooser)
        result.success(true)
    }

    private fun openChat(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val contact = args?.get("contact") as? String
        val text = args?.get("text") as? String ?: ""
        val requestedPkg = ((args?.get("package") ?: args?.get("packageName")) as? String)?.takeIf { it.isNotBlank() } ?: "com.whatsapp"
        val autoSend = (args?.get("autoSend") as? Boolean) ?: true

        if (contact.isNullOrBlank()) {
            result.error("empty_contact", "Sin contacto de destino", null)
            return
        }

        try {
            val cleanContact = contact.replace("@s.whatsapp.net", "").replace("@g.us", "").trim()
            val digits = cleanContact.filter { it.isDigit() }

            if (digits.length < 7) {
                // Fail-closed estricto: sin número de teléfono válido (mínimo 7 dígitos),
                // JAMÁS lanzar intent genérico ni armar auto-envío por accesibilidad,
                // porque WhatsApp enviaría el mensaje al chat que esté abierto en primer plano.
                AgentAccessibilityBridge.disarmAutoSend()
                result.error(
                    "invalid_phone",
                    "No se encontró un número de teléfono válido para '$contact' (se requieren al menos 7 dígitos).",
                    null
                )
                return
            }

            val uri = Uri.parse("https://api.whatsapp.com/send?phone=$digits&text=${Uri.encode(text)}")

            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage(requestedPkg)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            // Si el servicio de accesibilidad está disponible y se solicita auto-envío,
            // armamos el retorno automático flash.
            if (autoSend && AgentAccessibilityBridge.service != null) {
                AgentAccessibilityBridge.armAutoSendAndReturn(targetPkg = requestedPkg)
            }

            try {
                activity.startActivity(intent)
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                val fallbackPkg = if (requestedPkg == "com.whatsapp") "com.whatsapp.w4b" else "com.whatsapp"
                try {
                    intent.setPackage(fallbackPkg)
                    if (autoSend && AgentAccessibilityBridge.service != null) {
                        AgentAccessibilityBridge.armAutoSendAndReturn(targetPkg = fallbackPkg)
                    }
                    activity.startActivity(intent)
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    intent.setPackage(null)
                    activity.startActivity(intent)
                    result.success(true)
                }
            }
        } catch (e: Exception) {
            AgentAccessibilityBridge.disarmAutoSend()
            result.error("open_chat_failed", "No se pudo abrir el chat: ${e.message}", null)
        }
    }

    /// WA-MEDIA-01 — copia el archivo elegido por el usuario a la carpeta FIJA
    /// del catálogo (files/nano/catalog/<basename>). El archivo vive estable:
    /// la regla persiste ESTA ruta, no el path temporal del file_picker. Si ya
    /// existe un archivo con el mismo nombre, se reutiliza (nombre fijo).
    private fun copyToCatalog(call: MethodCall, result: MethodChannel.Result) {
        val source = (call.arguments as? Map<*, *>)?.get("sourcePath") as? String
        if (source.isNullOrBlank()) {
            result.error("empty_path", "Sin archivo de origen", null)
            return
        }
        try {
            val src = File(source)
            if (!src.isFile) {
                result.error("missing_file", "El archivo de origen no existe", null)
                return
            }
            val dir = File(activity.filesDir, "nano/catalog").apply { mkdirs() }
            val dest = File(dir, src.name)
            if (!dest.exists()) src.copyTo(dest, overwrite = false)
            result.success(dest.absolutePath)
        } catch (e: Exception) {
            result.error("copy_failed", "No se pudo copiar al catálogo: ${e.message}", null)
        }
    }

    /// WA-MEDIA-01 — Camino A (1 tap del usuario): abre WhatsApp directamente
    /// con el archivo + contacto + caption. ACTION_SEND + EXTRA_STREAM +
    /// package fijo com.whatsapp + extra "jid" (contacto; no documentado pero
    /// funciona, evidencia del análisis). El usuario toca Enviar en WhatsApp.
    /// Éxito = la actividad se LANZÓ, no que el archivo se envió (honesto).
    private fun shareFile(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val path = args?.get("path") as? String
        val contact = args?.get("contact") as? String
        val caption = args?.get("caption") as? String ?: ""
        val requestedPkg = ((args?.get("package") ?: args?.get("packageName")) as? String)?.takeIf { it.isNotBlank() } ?: "com.whatsapp"

        if (path.isNullOrBlank()) {
            result.error("empty_path", "Sin archivo para compartir", null)
            return
        }
        if (contact.isNullOrBlank()) {
            result.error("empty_contact", "Sin contacto de destino", null)
            return
        }
        val file = File(path)
        if (!file.isFile) {
            result.error("missing_file", "El archivo no existe: $path", null)
            return
        }
        try {
            val uri: Uri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.fileprovider",
                file,
            )
            val mime = mimeFor(file.name)
            val cleanContact = contact.replace("@s.whatsapp.net", "").replace("@g.us", "").trim()
            val jid = if (contact.contains("@g.us")) {
                contact
            } else {
                val digits = cleanContact.filter { it.isDigit() }
                if (digits.isNotBlank()) "$digits@s.whatsapp.net" else "$cleanContact@s.whatsapp.net"
            }

            fun createSendIntent(pkg: String) = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra("jid", jid)
                if (caption.isNotBlank()) putExtra(Intent.EXTRA_TEXT, caption)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setPackage(pkg)
            }

            try {
                activity.startActivity(createSendIntent(requestedPkg))
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                // Fallback automático entre WhatsApp y WhatsApp Business
                val fallbackPkg = if (requestedPkg == "com.whatsapp") "com.whatsapp.w4b" else "com.whatsapp"
                try {
                    activity.startActivity(createSendIntent(fallbackPkg))
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    result.error("whatsapp_missing", "WhatsApp no está instalado", null)
                }
            }
        } catch (e: Exception) {
            result.error("share_failed", "No se pudo lanzar el envío: ${e.message}", null)
        }
    }

    /// MIME por extensión conocida del catálogo y documentos; el resto genérico.
    private fun mimeFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "pdf" -> "application/pdf"
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        "webp" -> "image/webp"
        "mp4" -> "video/mp4"
        "csv" -> "text/comma-separated-values"
        "txt" -> "text/plain"
        "doc", "docx" -> "application/msword"
        "xls", "xlsx" -> "application/vnd.ms-excel"
        else -> "*/*"
    }

    companion object {
        const val CHANNEL_NAME = "com.nanoai/share"
    }
}
