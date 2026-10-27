package dev.nanoai.mobile.services.whatsapp

import android.view.accessibility.AccessibilityNodeInfo

/** IDs observados en la vista previa real de PDF de WhatsApp. Se valida el
 * nombre del archivo y el único chip destinatario; nunca texto de una burbuja. */
internal object WhatsAppDocumentPreview {
    fun matchesFile(root: AccessibilityNodeInfo, expectedName: String): Boolean {
        val nodes = root.findAccessibilityNodeInfosByViewId("${root.packageName}:id/document_file_name").orEmpty()
        return try { nodes.size == 1 && nodes.single().isVisibleToUser &&
            nodes.single().text?.toString() == expectedName }
        finally { nodes.forEach(AccessibilityNodeInfo::recycle) }
    }

    fun matchesRecipient(root: AccessibilityNodeInfo, candidates: List<String>): Boolean {
        val file = root.findAccessibilityNodeInfosByViewId("${root.packageName}:id/document_file_name").orEmpty()
        val isDocument = try { file.any { it.isVisibleToUser } }
            finally { file.forEach(AccessibilityNodeInfo::recycle) }
        if (!isDocument) return false
        val chips = root.findAccessibilityNodeInfosByViewId("${root.packageName}:id/recipients_scroller").orEmpty()
        return try {
            val chip = chips.singleOrNull() ?: return false
            val count = chip.contentDescription?.toString()?.filterNot { it == '\u200e' || it == '\u200f' }?.trim()
            if (!chip.isVisibleToUser || count !in setOf("1 destinatario seleccionado", "1 recipient selected")) return false
            val names = linkedSetOf<String>()
            collectNames(chip, names)
            names.size == 1 && candidates.any { it.equals(names.single(), ignoreCase = true) }
        } finally { chips.forEach(AccessibilityNodeInfo::recycle) }
    }

    private fun collectNames(node: AccessibilityNodeInfo, names: MutableSet<String>) {
        node.text?.toString()?.trim()?.takeIf(String::isNotBlank)?.let(names::add)
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            try { collectNames(child, names) } finally { child.recycle() }
        }
    }
}
