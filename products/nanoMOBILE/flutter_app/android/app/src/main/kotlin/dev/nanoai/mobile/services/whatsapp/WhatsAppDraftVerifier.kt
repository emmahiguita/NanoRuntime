package dev.nanoai.mobile.services.whatsapp

import android.view.accessibility.AccessibilityNodeInfo

/** Comprueba el contenido real del editor antes del único clic autorizado.
 * No escribe ni busca coincidencias en burbujas; un borrador distinto bloquea el envío. */
internal object WhatsAppDraftVerifier {
    fun matches(root: AccessibilityNodeInfo, expected: String): Boolean {
        if (expected.isBlank()) return false
        val pkg = root.packageName?.toString() ?: return false
        if (pkg != "com.whatsapp" && pkg != "com.whatsapp.w4b") return false
        val editors = root.findAccessibilityNodeInfosByViewId("$pkg:id/entry").orEmpty()
        return try {
            editors.any { it.isVisibleToUser && it.isEditable &&
                it.text?.toString()?.replace("\r\n", "\n") == expected.replace("\r\n", "\n") }
        } finally { editors.forEach(AccessibilityNodeInfo::recycle) }
    }
}
