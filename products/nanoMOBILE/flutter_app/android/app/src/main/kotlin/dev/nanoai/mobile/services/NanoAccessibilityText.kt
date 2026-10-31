package dev.nanoai.mobile.services

import android.view.accessibility.AccessibilityNodeInfo
import android.graphics.Rect

/** Separa ayuda y contenido usando Android y la estructura observada del compositor. */
internal object NanoAccessibilityText {
    /** Conserva rawText por separado; nunca decide por palabras como Mensaje o Message. */
    fun value(node: AccessibilityNodeInfo): String =
        if (isEmptyEditor(node)) "" else node.text?.toString().orEmpty()

    /** El control de voz sustituye al de enviar en el editor vacío observado.
     * Exige además selección no positiva, contenedor propio y ausencia de envío visible;
     * cualquier señal contradictoria conserva el contenido. No pulsa controles. */
    fun isEmptyEditor(node: AccessibilityNodeInfo): Boolean {
        if (!node.isEditable || node.isPassword || !node.isEnabled || !node.isVisibleToUser) return false
        if (node.isShowingHintText || node.text.isNullOrEmpty()) return true
        val pkg = node.packageName?.toString().orEmpty()
        if (pkg !in setOf("com.whatsapp", "com.whatsapp.w4b") ||
            node.viewIdResourceName != "$pkg:id/entry" ||
            node.textSelectionStart > 0 || node.textSelectionEnd > 0) return false
        val editorBounds = Rect().also(node::getBoundsInScreen)
        if (editorBounds.isEmpty) return false
        var parent = node.parent
        try {
            // edit_layout o conversation_root_layout es el ancestro común observado de entry y voice_note_btn.
            for (depth in 0 until 8) {
                val current = parent ?: return false
                if (current.windowId != node.windowId || current.packageName?.toString() != pkg) return false
                if (current.viewIdResourceName in setOf(
                        "$pkg:id/edit_layout",
                        "$pkg:id/conversation_root_layout",
                        "$pkg:id/input_layout",
                        "$pkg:id/root"
                    )) {
                    return hasEmptyControls(current, pkg, editorBounds,
                        node.textSelectionStart, node.textSelectionEnd)
                }
                parent = current.parent
                current.recycle()
            }
            return false
        } finally { parent?.recycle() }
    }

    /** Solo consulta controles de la misma fila; la descripción localizada no participa. */
    private fun hasEmptyControls(
        root: AccessibilityNodeInfo, pkg: String, editor: Rect,
        selectionStart: Int, selectionEnd: Int,
    ): Boolean {
        val send = root.findAccessibilityNodeInfosByViewId("$pkg:id/send").orEmpty()
        val voice = root.findAccessibilityNodeInfosByViewId("$pkg:id/voice_note_btn").orEmpty()
        return try {
            NanoWhatsAppComposerEvidence.isEmpty(
                nodeSelectionStart = selectionStart,
                nodeSelectionEnd = selectionEnd,
                visibleSendCount = send.count { it.isVisibleToUser },
                visibleVoiceCount = voice.count {
                val bounds = Rect().also(it::getBoundsInScreen)
                it.isVisibleToUser && it.isEnabled && it.windowId == root.windowId &&
                    it.packageName?.toString() == pkg && !bounds.isEmpty &&
                    bounds.top < editor.bottom && bounds.bottom > editor.top
                },
            )
        } finally {
            send.forEach { it.recycle() }
            voice.forEach { it.recycle() }
        }
    }
}
