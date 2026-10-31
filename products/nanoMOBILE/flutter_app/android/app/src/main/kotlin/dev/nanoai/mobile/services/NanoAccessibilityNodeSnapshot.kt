package dev.nanoai.mobile.services

import android.graphics.Rect
import android.os.Build
import android.view.Display
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo

/** Serializa senales del mismo nodo sin inferir borradores a partir de etiquetas localizadas. */
internal object NanoAccessibilityNodeSnapshot {
    /** Conserva identidad y capacidades junto al texto; no retiene referencias del arbol. */
    fun toMap(
        node: AccessibilityNodeInfo,
        depth: Int? = null,
        windowId: Int = 0,
        windowType: Int = AccessibilityWindowInfo.TYPE_APPLICATION,
        displayId: Int = Display.DEFAULT_DISPLAY,
        rootIdentity: String = "",
        parentIndex: Int? = null,
        siblingIndex: Int = 0,
    ): Map<String, Any?> {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        val emptyEditor = NanoAccessibilityText.isEmptyEditor(node)
        NanoWhatsAppEditorDiagnostics.report(node, emptyEditor)
        val rawText = node.text?.toString().orEmpty()
        return buildMap {
            put("id", node.viewIdResourceName ?: "")
            put("type", node.className?.toString() ?: "")
            // Un hint visual no es un borrador: preserva el hint por separado.
            put("text", if (emptyEditor) "" else rawText)
            put("desc", node.contentDescription?.toString() ?: "")
            put("clickable", node.isClickable)
            put("editable", node.isEditable)
            put("scrollable", node.isScrollable)
            put("checkable", node.isCheckable)
            put("checked", node.isChecked)
            put("selected", node.isSelected)
            put("focusable", node.isFocusable)
            put("focused", node.isFocused)
            put("visible", node.isVisibleToUser)
            put("enabled", node.isEnabled)
            put("longClickable", node.isLongClickable)
            put("password", node.isPassword)
            put("drawingOrder", node.drawingOrder)
            put("hint", node.hintText?.toString() ?: "")
            put("rawText", rawText)
            put("emptyEditor", emptyEditor)
            put("selectionStart", node.textSelectionStart)
            put("selectionEnd", node.textSelectionEnd)
            put("showingHint", node.isShowingHintText)
            put("supportsSetText", node.actionList.any { it.id == AccessibilityNodeInfo.ACTION_SET_TEXT })
            put("error", node.error?.toString() ?: "")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                put("heading", node.isHeading)
                put("screenReaderFocusable", node.isScreenReaderFocusable)
                put("paneTitle", node.paneTitle?.toString() ?: "")
                put("tooltip", node.tooltipText?.toString() ?: "")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                put("stateDescription", node.stateDescription?.toString() ?: "")
            }
            put("package", node.packageName?.toString() ?: "")
            put("bounds", intArrayOf(bounds.left, bounds.top, bounds.right, bounds.bottom))
            // Solo dumpSnapshot incluye depth; dumpScreen conserva su contrato.
            if (depth != null) {
                put("depth", depth)
                put("windowId", windowId)
                put("windowType", windowType)
                put("displayId", displayId)
                put("rootIdentity", rootIdentity)
                put("parentIndex", parentIndex)
                put("siblingIndex", siblingIndex)
            }
        }
    }

}
