package dev.nanoai.mobile.services.whatsapp

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityNodeInfo

/** Vincula el usuario solicitado al perfil real antes de enviar. Solo observa
 * IDs de cabecera/perfil: no acepta un @usuario escrito dentro de una burbuja.
 * El estado vive un único intento y se libera con resetSession del ejecutor. */
internal object WhatsAppUsernameVerifier {
    private var profileRequested = false
    private var verifiedAlias: String? = null
    private var backRequested = false

    fun reset() {
        profileRequested = false
        verifiedAlias = null
        backRequested = false
    }

    /** Devuelve el alias del chat únicamente tras observar el usuario exacto en
     * su perfil y volver a la conversación. No busca ni adivina claves privadas. */
    fun prepare(root: AccessibilityNodeInfo, service: AccessibilityService, username: String): String? {
        val pkg = root.packageName?.toString() ?: return null
        if (pkg != "com.whatsapp" && pkg != "com.whatsapp.w4b") return null
        val profileUser = text(root, "$pkg:id/contact_subtitle")
        if (profileUser != null) {
            if (profileUser != username) return null
            val alias = text(root, "$pkg:id/contact_title") ?: return null
            verifiedAlias = alias
            if (!backRequested) {
                backRequested = service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
            }
            return null
        }
        val header = root.findAccessibilityNodeInfosByViewId("$pkg:id/conversation_contact_name").orEmpty()
        return try {
            val node = header.singleOrNull() ?: return null
            if (!node.isVisibleToUser) return null
            if (backRequested && node.text?.toString() == verifiedAlias) return verifiedAlias
            if (!profileRequested) profileRequested = clickHeader(node)
            null
        } finally { header.forEach(AccessibilityNodeInfo::recycle) }
    }

    /** El nombre observado es TextView no pulsable; la acción pertenece al
     * contenedor inmediato de contacto, no al toolbar completo ni sus llamadas. */
    private fun clickHeader(label: AccessibilityNodeInfo): Boolean {
        var current: AccessibilityNodeInfo? = label
        repeat(4) {
            val node = current ?: return false
            if (node.isClickable && node.isEnabled && node.isVisibleToUser) {
                val accepted = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                if (node !== label) node.recycle()
                return accepted
            }
            current = node.parent
            if (node !== label) node.recycle()
        }
        current?.takeIf { it !== label }?.recycle()
        return false
    }

    private fun text(root: AccessibilityNodeInfo, id: String): String? {
        val nodes = root.findAccessibilityNodeInfosByViewId(id).orEmpty()
        return try { nodes.singleOrNull()?.takeIf { it.isVisibleToUser }?.text?.toString()?.trim() }
            finally { nodes.forEach(AccessibilityNodeInfo::recycle) }
    }
}
