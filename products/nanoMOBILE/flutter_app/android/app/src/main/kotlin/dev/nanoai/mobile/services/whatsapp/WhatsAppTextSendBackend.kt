package dev.nanoai.mobile.services.whatsapp

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
    /** Abre el paquete exacto solicitado. No cambia de cuenta para resolver
     * fallos de lanzamiento; el usuario debe elegir otra app explícitamente. */
    fun openChat(
        contact: String,
        text: String,
        requestedPackage: String = "com.whatsapp",
        autoSend: Boolean = false,
        expectedAliasOverride: String? = null,
        onAutoSendResult: ((Boolean, String) -> Unit)? = null,
    ): WhatsAppOpenResult {
        if (AgentAccessibilityBridge.isAutoSendArmed || WhatsAppReturnController.isReturning) {
            return WhatsAppOpenResult(false, "automation_busy", "Otra tarea de WhatsApp está en curso.")
        }
        val cleanContact = contact
            .replace("@s.whatsapp.net", "")
            .replace("@g.us", "")
            .replace(Regex("[()\"'\\[\\]]"), "")
            .trim()
        val username = cleanContact.takeIf {
            Regex("^@[A-Za-z0-9._]{3,35}$").matches(it) && it.any(Char::isLetter)
        }
        // Un nombre que contiene muchos dígitos no es un número telefónico.
        val phoneInput = Regex("^[+0-9 ().-]+$").matches(cleanContact)
        var digits = if (phoneInput) cleanContact.filter { it.isDigit() } else ""
        if (username == null && digits.length < 7) {
            digits = resolveContactPhone(cleanContact).orEmpty()
        }
        if (username == null && digits.length !in 7..15) {
            AgentAccessibilityBridge.disarmAutoSend()
            return WhatsAppOpenResult(
                ok = false,
                code = "invalid_phone",
                message = "No se encontró un número válido para '$contact'.",
            )
        }

        val uri = Uri.parse(
            // Enlace de usuario documentado por WhatsApp; siempre fijado al
            // paquete instalado. Una clave o función no disponible requiere intervención.
            if (username != null) "https://wa.me/${Uri.encode(username.drop(1))}?text=${Uri.encode(text)}"
            else "https://api.whatsapp.com/send?phone=$digits&text=${Uri.encode(text)}",
        )
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage(requestedPackage)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val expectedAlias = expectedAliasOverride
            ?: if (username == null) resolveContactName(digits) else null
            ?: cleanContact.takeIf { it != digits }

        fun arm(pkg: String): Boolean {
            if (!autoSend) return true
            return AgentAccessibilityBridge.armAutoSendAndReturn(
                    targetPkg = pkg,
                    targetContact = username ?: digits,
                    expectedAlias = expectedAlias,
                    expectedText = text,
                    timeoutMs = 12_000L,
                    onResult = onAutoSendResult,
                )
        }

        // Elegir la app instalada ANTES de armar evita dos intentos y callbacks
        // contradictorios al alternar entre WhatsApp personal y Business.
        // La cuenta solicitada es exacta. Un fallback puede enviar desde
        // otra cuenta: si este paquete falta, se pide elegirla explícitamente.
        val candidates = listOf(requestedPackage)
        val selected = candidates.firstOrNull {
            intent.setPackage(it).resolveActivity(context.packageManager) != null
        } ?: return WhatsAppOpenResult(false, "package_not_found", "No se encontró WhatsApp instalado.")
        intent.setPackage(selected)
        if (!arm(selected)) return WhatsAppOpenResult(false, "accessibility_unavailable",
            "Accesibilidad no está conectada o hay otra tarea en curso.")
        return try {
            context.startActivity(intent)
            WhatsAppOpenResult(ok = true)
        } catch (error: Exception) {
            if (autoSend) AgentAccessibilityBridge.disarmAutoSend("No se pudo abrir WhatsApp.")
            WhatsAppOpenResult(false, "open_chat_failed", "No se pudo abrir el chat: ${error.message}")
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

    /** El nombre debe identificar un solo número antes de abrir el destinatario. */
    private fun resolveContactPhone(name: String): String? =
        dev.nanoai.mobile.services.whatsapp.ExactPhoneContactResolver.resolve(context, name)
}
