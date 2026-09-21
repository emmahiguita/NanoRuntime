package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
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
            val pm = activity.packageManager
            val launchIntent = pm.getLaunchIntentForPackage(requestedPkg)
                ?: pm.getLaunchIntentForPackage("com.whatsapp")
                ?: pm.getLaunchIntentForPackage("com.whatsapp.w4b")
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(launchIntent)
                result.success(true)
            } else {
                result.error("package_not_found", "No se encontró WhatsApp instalado", null)
            }
            return
        }

        try {
            val cleanContact = contact
                .replace("@s.whatsapp.net", "")
                .replace("@g.us", "")
                .replace(Regex("[()\"'\\[\\]]"), "")
                .trim()
            var digits = cleanContact.filter { it.isDigit() }

            if (digits.length < 7) {
                val resolved = resolveContactPhone(cleanContact)
                if (!resolved.isNullOrBlank()) {
                    digits = resolved
                }
            }

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

            val expectedAlias = resolveContactName(digits) ?: cleanContact.takeIf { it != digits }

            // Si el servicio de accesibilidad está disponible y se solicita auto-envío,
            // armamos el retorno automático con verificación de contacto/número.
            if (autoSend && AgentAccessibilityBridge.service != null) {
                AgentAccessibilityBridge.armAutoSendAndReturn(
                    targetPkg = requestedPkg,
                    targetContact = digits,
                    expectedAlias = expectedAlias
                )
            }

            try {
                activity.startActivity(intent)
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                val fallbackPkg = if (requestedPkg == "com.whatsapp") "com.whatsapp.w4b" else "com.whatsapp"
                try {
                    intent.setPackage(fallbackPkg)
                    if (autoSend && AgentAccessibilityBridge.service != null) {
                        AgentAccessibilityBridge.armAutoSendAndReturn(
                            targetPkg = fallbackPkg,
                            targetContact = digits,
                            expectedAlias = expectedAlias
                        )
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

    private fun resolveContactName(phoneDigits: String): String? {
        if (phoneDigits.length < 7) return null
        try {
            val cr = activity.contentResolver
            val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(phoneDigits))
            val projection = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)
            cr.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    return cursor.getString(0)
                }
            }
        } catch (_: Exception) {}
        return null
    }

    private fun resolveContactPhone(nameOrPhone: String): String? {
        val cleanName = nameOrPhone
            .replace("@s.whatsapp.net", "")
            .replace("@g.us", "")
            .replace(Regex("[()\"'\\[\\]]"), "")
            .trim()
        val digits = cleanName.filter { it.isDigit() }
        if (digits.length >= 7) return digits
        if (cleanName.isBlank()) return null
        try {
            val cr = activity.contentResolver
            val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.NUMBER,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            )
            val selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?"
            val selectionArgs = arrayOf("%$cleanName%")
            cr.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val number = cursor.getString(0)?.filter { it.isDigit() }
                    if (!number.isNullOrBlank() && number.length >= 7) {
                        return number
                    }
                }
            }
        } catch (_: Exception) {}
        return null
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
    /// WA-MEDIA-01 — Envió de archivos multimedia con soporte de WindowStrategy,
    /// FileProvider y verificación de accesibilidad atómica vía WhatsAppShareMediaBackend.
    private fun shareFile(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val path = args?.get("path") as? String
        val contact = args?.get("contact") as? String
        val caption = args?.get("caption") as? String ?: ""
        val requestedPkg = ((args?.get("package") ?: args?.get("packageName")) as? String)?.takeIf { it.isNotBlank() } ?: "com.whatsapp"
        val autoSend = (args?.get("autoSend") as? Boolean) ?: true

        if (path.isNullOrBlank()) {
            result.error("empty_path", "Sin archivo para compartir", null)
            return
        }
        if (contact.isNullOrBlank()) {
            result.error("empty_contact", "Sin contacto de destino", null)
            return
        }

        val resolvedPhone = if (!contact.isNullOrBlank()) resolveContactPhone(contact) else null
        val target = resolvedPhone ?: contact
        val backend = dev.nanoai.mobile.services.whatsapp.WhatsAppShareMediaBackend(activity)
        val success = backend.shareMedia(
            filePath = path,
            targetContact = target,
            caption = caption,
            requestedPackage = requestedPkg,
            autoSend = autoSend
        )

        if (success) {
            result.success(true)
        } else {
            result.error("share_failed", "No se pudo iniciar el flujo de envío multimedia", null)
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
