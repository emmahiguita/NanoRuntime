package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
import android.provider.Settings
import android.os.Build
import androidx.core.content.FileProvider
import dev.nanoai.mobile.BuildConfig
import dev.nanoai.mobile.automation.ScheduledWhatsAppAlarmScheduler
import dev.nanoai.mobile.automation.ScheduledWhatsAppBatch
import dev.nanoai.mobile.automation.ScheduledWhatsAppRecipient
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
            "listCatalog" -> listCatalog(result)
            "shareFile" -> shareFile(call, result)
            "scheduleWhatsAppMessage" -> scheduleWhatsAppMessage(call, result)
            "cancelScheduledWhatsAppMessage" -> cancelScheduledWhatsAppMessage(call, result)
            "openExactAlarmSettings" -> openExactAlarmSettings(result)
            "isAccessibilityEnabled" -> isAccessibilityEnabled(result)
            "openAccessibilitySettings" -> openAccessibilitySettings(result)
            else -> result.notImplemented()
        }
    }

    private fun scheduleWhatsAppMessage(call: MethodCall, result: MethodChannel.Result) {
        if (BuildConfig.PLAY_STORE_BUILD) {
            result.error(
                "unsupported_distribution",
                "El autoenvío programado solo está disponible en la edición completa.",
                null,
            )
            return
        }
        if (AgentAccessibilityBridge.service == null) {
            result.error(
                "accessibility_disabled",
                "Activa el servicio de Accesibilidad de Nano antes de programar envíos.",
                null,
            )
            return
        }
        val args = call.arguments as? Map<*, *>
        val ruleId = args?.get("ruleId")?.toString().orEmpty()
        val recipients = (args?.get("recipients") as? List<*>)
            .orEmpty()
            .mapNotNull { raw ->
                val map = raw as? Map<*, *> ?: return@mapNotNull null
                val name = map["name"]?.toString().orEmpty().trim()
                val number = map["number"]?.toString().orEmpty().filter(Char::isDigit)
                if (name.isBlank() || number.length < 7) null
                else ScheduledWhatsAppRecipient(name, number)
            }
        val batch = ScheduledWhatsAppBatch(
            ruleId = ruleId,
            hour = (args?.get("hour") as? Number)?.toInt() ?: -1,
            minute = (args?.get("minute") as? Number)?.toInt() ?: -1,
            weekdays = (args?.get("weekdays") as? List<*>)
                .orEmpty().mapNotNull { (it as? Number)?.toInt() }.toSet(),
            timeZoneId = args?.get("timeZoneId")?.toString().orEmpty(),
            recurring = args?.get("recurring") == true,
            message = args?.get("message")?.toString().orEmpty().trim(),
            packageName = args?.get("packageName")?.toString()
                ?.takeIf(String::isNotBlank) ?: "com.whatsapp",
            recipients = recipients,
        )
        val scheduled = ScheduledWhatsAppAlarmScheduler.schedule(
            activity.applicationContext,
            batch,
        )
        result.success(
            mapOf(
                "ok" to scheduled.ok,
                "exact" to scheduled.exact,
                "scheduledAtMs" to scheduled.scheduledAtMs,
                "reason" to scheduled.reason,
            ),
        )
    }

    private fun cancelScheduledWhatsAppMessage(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val ruleId = (call.arguments as? Map<*, *>)?.get("ruleId")?.toString().orEmpty()
        if (ruleId.isNotBlank()) {
            ScheduledWhatsAppAlarmScheduler.cancel(activity.applicationContext, ruleId)
        }
        result.success(null)
    }

    private fun openExactAlarmSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            result.success(null)
            return
        }
        try {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:${activity.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error(
                "exact_alarm_settings_failed",
                "No se pudo abrir el permiso de alarmas exactas: ${error.message}",
                null,
            )
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
        val autoSend = WhatsAppAutoSendPolicy.isRequested(args)
        val pm = activity.packageManager

        // Apertura general de la app sin destinatario
        if (contact.isNullOrBlank()) {
            val launchIntent = pm.getLaunchIntentForPackage(requestedPkg)
                ?: (if (requestedPkg.contains("telegram")) {
                    pm.getLaunchIntentForPackage("org.telegram.messenger")
                        ?: pm.getLaunchIntentForPackage("com.telegram.messenger")
                } else if (requestedPkg.contains("messenger") || requestedPkg.contains("orca")) {
                    pm.getLaunchIntentForPackage("com.facebook.orca")
                        ?: pm.getLaunchIntentForPackage("com.facebook.mlite")
                } else {
                    pm.getLaunchIntentForPackage("com.whatsapp")
                        ?: pm.getLaunchIntentForPackage("com.whatsapp.w4b")
                })
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(launchIntent)
                result.success(true)
            } else {
                result.error("package_not_found", "No se encontró la aplicación ($requestedPkg) instalada", null)
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

            // 1. Ruta TELEGRAM
            if (requestedPkg.contains("telegram")) {
                val uri = if (digits.length >= 7) {
                    Uri.parse("tg://msg?to=$digits&text=${Uri.encode(text)}")
                } else {
                    val username = cleanContact.removePrefix("@").trim()
                    Uri.parse("https://t.me/$username?text=${Uri.encode(text)}")
                }
                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                    setPackage(requestedPkg)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try {
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    try {
                        intent.setPackage(if (requestedPkg == "org.telegram.messenger") "com.telegram.messenger" else "org.telegram.messenger")
                        activity.startActivity(intent)
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        intent.setPackage(null)
                        activity.startActivity(intent)
                        result.success(true)
                    }
                }
                return
            }

            // 2. Ruta FACEBOOK MESSENGER
            if (requestedPkg.contains("orca") || requestedPkg.contains("messenger") || requestedPkg.contains("facebook")) {
                val uri = Uri.parse("https://m.me/$cleanContact")
                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                    setPackage(requestedPkg)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try {
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    intent.setPackage(null)
                    activity.startActivity(intent)
                    result.success(true)
                }
                return
            }

            // 3. Ruta SMS / Mensajes
            if (requestedPkg.contains("messaging") || requestedPkg.contains("mms")) {
                val uri = Uri.parse("smsto:$digits")
                val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                    putExtra("sms_body", text)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(intent)
                result.success(true)
                return
            }

            // 4. Ruta WHATSAPP
            if (digits.length < 7) {
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

            if (autoSend && !armVerifiedAutoSend(requestedPkg, digits, expectedAlias)) {
                AgentAccessibilityBridge.disarmAutoSend()
                result.error(
                    "accessibility_unavailable",
                    "Activa Nano Mobile Agent en Accesibilidad para iniciar el envío automático.",
                    null
                )
                return
            }

            try {
                activity.startActivity(intent)
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                val fallbackPkg = if (requestedPkg == "com.whatsapp") "com.whatsapp.w4b" else "com.whatsapp"
                try {
                    AgentAccessibilityBridge.disarmAutoSend()
                    intent.setPackage(fallbackPkg)
                    if (autoSend && !armVerifiedAutoSend(fallbackPkg, digits, expectedAlias)) {
                        result.error(
                            "accessibility_unavailable",
                            "No se pudo preparar el envío automático en la app de WhatsApp disponible.",
                            null
                        )
                        return
                    }
                    activity.startActivity(intent)
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    AgentAccessibilityBridge.disarmAutoSend()
                    if (autoSend) {
                        result.error("package_not_found", "No se encontró una app compatible de WhatsApp", null)
                        return
                    }
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

    // Arma el envío únicamente si el servicio conectado acepta el destinatario que se verificará.
    private fun armVerifiedAutoSend(pkg: String, phone: String, alias: String?): Boolean {
        if (AgentAccessibilityBridge.service == null) return false
        return AgentAccessibilityBridge.armAutoSendAndReturn(
            targetPkg = pkg,
            targetContact = phone,
            expectedAlias = alias
        )
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

    /// Copia el archivo elegido a una carpeta de Nano privada y persistente.
    private fun copyToCatalog(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val source = args?.get("sourcePath") as? String
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
            val allowedCategories = setOf(
                "productos_servicios", "informes", "fotos", "videos", "documentos"
            )
            val requestedCategory = args?.get("category")?.toString()
            val category = requestedCategory?.takeIf { it in allowedCategories } ?: "documentos"
            val dir = File(activity.filesDir, "nano/catalog/$category").apply { mkdirs() }
            val extension = src.extension.takeIf { it.isNotBlank() }?.let { ".$it" }.orEmpty()
            val stem = src.nameWithoutExtension.ifBlank { "archivo" }
            var dest = File(dir, src.name)
            var suffix = 2
            while (dest.exists()) {
                dest = File(dir, "$stem ($suffix)$extension")
                suffix++
            }
            src.copyTo(dest, overwrite = false)
            result.success(dest.absolutePath)
        } catch (e: Exception) {
            result.error("copy_failed", "No se pudo copiar al catálogo: ${e.message}", null)
        }
    }

    /// Devuelve solo archivos de las carpetas administradas por Nano.
    private fun listCatalog(result: MethodChannel.Result) {
        try {
            val root = File(activity.filesDir, "nano/catalog").apply { mkdirs() }
            val categories = listOf(
                "productos_servicios", "informes", "fotos", "videos", "documentos"
            )
            val files = mutableListOf<Map<String, Any>>()
            // Conserva la compatibilidad con archivos copiados por versiones anteriores.
            root.listFiles()?.filter { it.isFile }?.forEach { file ->
                files += catalogFile(file, "documentos")
            }
            categories.forEach { category ->
                val dir = File(root, category).apply { mkdirs() }
                dir.listFiles()?.filter { it.isFile }?.forEach { file ->
                    files += catalogFile(file, category)
                }
            }
            result.success(files.sortedByDescending { it["modifiedAtMs"] as Long })
        } catch (e: Exception) {
            result.error("catalog_read_failed", "No se pudo leer la biblioteca de Nano: ${e.message}", null)
        }
    }

    private fun catalogFile(file: File, category: String): Map<String, Any> = mapOf(
        "name" to file.name,
        "path" to file.absolutePath,
        "category" to category,
        "sizeBytes" to file.length(),
        "modifiedAtMs" to file.lastModified(),
    )

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
        val autoSend = WhatsAppAutoSendPolicy.isRequested(args)
        val recipientName = args?.get("recipientName")?.toString()?.trim().orEmpty()
        val recipientKind = args?.get("recipientKind")?.toString()?.trim()?.lowercase() ?: "direct"
        val recipientVerified = args?.get("recipientVerified") == true

        if (path.isNullOrBlank()) {
            result.error("empty_path", "Sin archivo para compartir", null)
            return
        }
        if (contact.isNullOrBlank()) {
            result.error("empty_contact", "Sin contacto de destino", null)
            return
        }

        val resolvedPhone = if (recipientKind == "group") null else resolveContactPhone(contact)
        val target = resolvedPhone ?: contact
        val backend = dev.nanoai.mobile.services.whatsapp.WhatsAppShareMediaBackend(activity)
        val success = backend.shareMedia(
            filePath = path,
            targetContact = target,
            targetAlias = recipientName,
            recipientKind = recipientKind,
            recipientVerified = recipientVerified,
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
