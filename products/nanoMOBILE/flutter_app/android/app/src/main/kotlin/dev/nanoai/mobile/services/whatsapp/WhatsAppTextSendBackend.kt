package dev.nanoai.mobile.services.whatsapp

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
import dev.nanoai.mobile.services.AgentAccessibilityBridge

data class WhatsAppOpenResult(
    val ok: Boolean,
    val code: String = "",
    val message: String = "",
)

/**
 * Backend reutilizable de mensajes de texto para UI y alarmas sin Flutter.
 * Resuelve un contacto, arma el deep link oficial y, cuando se autoriza,
 * prepara el clic de envío fail-closed por Accesibilidad.
 */
class WhatsAppTextSendBackend(private val context: Context) {
    fun openChat(
        contact: String,
        text: String,
        requestedPackage: String = "com.whatsapp",
        autoSend: Boolean = false,
        expectedAliasOverride: String? = null,
        onAutoSendResult: ((Boolean, String) -> Unit)? = null,
    ): WhatsAppOpenResult {
        val cleanContact = contact
            .replace("@s.whatsapp.net", "")
            .replace("@g.us", "")
            .replace(Regex("[()\"'\\[\\]]"), "")
            .trim()
        var digits = cleanContact.filter { it.isDigit() }
        if (digits.length < 7) {
            digits = resolveContactPhone(cleanContact).orEmpty()
        }
        if (digits.length < 7) {
            AgentAccessibilityBridge.disarmAutoSend()
            return WhatsAppOpenResult(
                ok = false,
                code = "invalid_phone",
                message = "No se encontró un número válido para '$contact'.",
            )
        }

        val uri = Uri.parse(
            "https://api.whatsapp.com/send?phone=$digits&text=${Uri.encode(text)}",
        )
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage(requestedPackage)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val expectedAlias = expectedAliasOverride
            ?: resolveContactName(digits)
            ?: cleanContact.takeIf { it != digits }

        fun arm(pkg: String): Boolean {
            if (!autoSend) return true
            return AgentAccessibilityBridge.armAutoSendAndReturn(
                    targetPkg = pkg,
                    targetContact = digits,
                    expectedAlias = expectedAlias,
                    timeoutMs = 12_000L,
                    onResult = onAutoSendResult,
                )
        }

        return try {
            if (!arm(requestedPackage)) {
                return WhatsAppOpenResult(
                    ok = false,
                    code = "accessibility_unavailable",
                    message = "Accesibilidad de Nano no est?? conectada.",
                )
            }
            context.startActivity(intent)
            WhatsAppOpenResult(ok = true)
        } catch (_: ActivityNotFoundException) {
            val fallback = if (requestedPackage == "com.whatsapp") {
                "com.whatsapp.w4b"
            } else {
                "com.whatsapp"
            }
            try {
                intent.setPackage(fallback)
                if (!arm(fallback)) {
                    return WhatsAppOpenResult(
                        ok = false,
                        code = "accessibility_unavailable",
                        message = "Accesibilidad de Nano no est?? conectada.",
                    )
                }
                context.startActivity(intent)
                WhatsAppOpenResult(ok = true)
            } catch (_: ActivityNotFoundException) {
                AgentAccessibilityBridge.disarmAutoSend()
                WhatsAppOpenResult(
                    ok = false,
                    code = "package_not_found",
                    message = "No se encontró WhatsApp instalado.",
                )
            }
        } catch (error: Exception) {
            AgentAccessibilityBridge.disarmAutoSend()
            WhatsAppOpenResult(
                ok = false,
                code = "open_chat_failed",
                message = "No se pudo abrir el chat: ${error.message}",
            )
        }
    }

    private fun resolveContactName(phoneDigits: String): String? {
        if (phoneDigits.length < 7) return null
        return try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneDigits),
            )
            context.contentResolver.query(
                uri,
                arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveContactPhone(name: String): String? {
        if (name.isBlank()) return null
        return try {
            val resolved = context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?",
                arrayOf("%$name%"),
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                cursor.getString(0)?.filter { it.isDigit() }
            }
            resolved?.takeIf { it.length >= 7 }
        } catch (_: Exception) {
            null
        }
    }
}
