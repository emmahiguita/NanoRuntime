package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ShareChannelHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "shareText" -> shareText(call, result)
            "copyToCatalog" -> copyToCatalog(call, result)
            "shareFile" -> shareFile(call, result)
            else -> result.notImplemented()
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
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra("jid", "$contact@s.whatsapp.net")
                if (caption.isNotBlank()) putExtra(Intent.EXTRA_TEXT, caption)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setPackage("com.whatsapp")
            }
            activity.startActivity(send)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("whatsapp_missing", "WhatsApp no está instalado", null)
        } catch (e: Exception) {
            result.error("share_failed", "No se pudo lanzar el envío: ${e.message}", null)
        }
    }

    /// MIME por extensión conocida del catálogo; el resto genérico.
    private fun mimeFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "pdf" -> "application/pdf"
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        "webp" -> "image/webp"
        "mp4" -> "video/mp4"
        "csv" -> "text/comma-separated-values"
        else -> "*/*"
    }

    companion object {
        const val CHANNEL_NAME = "com.nanoai/share"
    }
}
