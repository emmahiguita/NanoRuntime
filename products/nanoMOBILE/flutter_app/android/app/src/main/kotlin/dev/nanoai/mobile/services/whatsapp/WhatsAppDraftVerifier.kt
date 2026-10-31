package dev.nanoai.mobile.services.whatsapp

import android.view.accessibility.AccessibilityNodeInfo

/** Comprueba el contenido real del editor antes del único clic autorizado.
 * No escribe ni busca coincidencias en burbujas; un borrador distinto bloquea el envío. */
internal object WhatsAppDraftVerifier {
    /** Relee candidatos de la ventana actual y exige un unico editor real antes del clic. */
    fun matches(root: AccessibilityNodeInfo, expected: String): Boolean {
        if (expected.isBlank()) return false
        val pkg = root.packageName?.toString() ?: return false
        if (pkg != "com.whatsapp" && pkg != "com.whatsapp.w4b") return false
        val editors = root.findAccessibilityNodeInfosByViewId("$pkg:id/entry").orEmpty()
        return try {
            editors.singleOrNull()?.let { it.isVisibleToUser && it.isEditable &&
                it.isEnabled && !it.isPassword && !it.isShowingHintText &&
                it.windowId == root.windowId &&
                it.text?.toString()?.replace("\r\n", "\n") == expected.replace("\r\n", "\n") } == true
        } finally { editors.forEach(AccessibilityNodeInfo::recycle) }
    }
}
