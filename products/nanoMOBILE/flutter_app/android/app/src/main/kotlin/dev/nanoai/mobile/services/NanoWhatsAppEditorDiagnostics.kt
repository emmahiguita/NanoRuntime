package dev.nanoai.mobile.services

import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import dev.nanoai.mobile.BuildConfig

/** Metadatos de desarrollo del compositor; nunca registra mensajes, hints ni contactos. */
internal object NanoWhatsAppEditorDiagnostics {
    private var last = ""

    /** Explica las precondiciones del clasificador sin repetir estados idénticos. */
    fun report(node: AccessibilityNodeInfo, empty: Boolean) {
        if (!BuildConfig.DEBUG) return
        val pkg = node.packageName?.toString().orEmpty()
        if (pkg !in setOf("com.whatsapp", "com.whatsapp.w4b") ||
            node.viewIdResourceName != "$pkg:id/entry") return
        val path = mutableListOf<String>()
        var parent = node.parent
        try {
            repeat(8) {
                val current = parent ?: return@repeat
                path.add(current.viewIdResourceName?.substringAfter(":id/") ?: "?")
                parent = current.parent
                current.recycle()
            }
        } finally { parent?.recycle() }
        val state = "window=${node.windowId} editable=${node.isEditable} " +
            "enabled=${node.isEnabled} visible=${node.isVisibleToUser} focused=${node.isFocused} " +
            "length=${node.text?.length ?: 0} hintLength=${node.hintText?.length ?: 0} " +
            "showingHint=${node.isShowingHintText} selection=${node.textSelectionStart},${node.textSelectionEnd} " +
            "setText=${node.actionList.any { it.id == AccessibilityNodeInfo.ACTION_SET_TEXT }} " +
            "empty=$empty ancestors=${path.joinToString(",") }"
        if (state == last) return
        last = state
        Log.i("nano_wa_editor", state)
    }
}
