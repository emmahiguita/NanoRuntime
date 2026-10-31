package dev.nanoai.mobile.services

import android.accessibilityservice.AccessibilityService
import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo

/** Escribe en un único editor actual; el teclado o un overlay no eligen la ventana. */
internal object NanoAccessibilityInput {
    /** Revalida el editor enfocado y protege el borrador antes de cada estrategia.
     * Prioriza la conexión accesible verificable; no repite tras resultado incierto.
     * La aceptación solo inicia la comprobación del texto, nunca acredita envío. */
    fun write(service: AccessibilityService, text: String, id: String, bounds: IntArray): Boolean {
        val root = targetRoot(service, id) ?: return false
        val node = try { findEditor(root, id, bounds) } finally { root.recycle() }
            ?: return false
        return try {
            if (!node.refresh() || !matches(node, id, bounds)) return false
            val pkg = node.packageName?.toString().orEmpty()
            if (pkg in setOf("com.whatsapp", "com.whatsapp.w4b") &&
                node.viewIdResourceName == "$pkg:id/entry" &&
                !NanoAccessibilityText.isEmptyEditor(node)) return false
            // La conexión accesible solo se usa cuando acredita el mismo editor.
            // Un resultado incierto nunca permite repetir la escritura por otra ruta.
            when (NanoAccessibleInputConnection.write(service, node, text)) {
                NanoAccessibleInputConnection.Result.DISPATCHED -> return true
                // El canal booleano no representa incertidumbre: aborta sin repetir.
                NanoAccessibleInputConnection.Result.UNCERTAIN -> return false
                NanoAccessibleInputConnection.Result.UNAVAILABLE -> Unit
            }
            // El foco o borrador pueden cambiar mientras se consulta la conexión.
            if (!node.refresh() || !matches(node, id, bounds)) return false
            if (pkg in setOf("com.whatsapp", "com.whatsapp.w4b") &&
                node.viewIdResourceName == "$pkg:id/entry" &&
                !NanoAccessibilityText.isEmptyEditor(node)) return false
            if (!node.actionList.any { it.id == AccessibilityNodeInfo.ACTION_SET_TEXT }) return false
            node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            })
        } finally { node.recycle() }
    }

    /** Mantiene la ventana activa si es del destino; con IME busca una única app enfocada. */
    private fun targetRoot(service: AccessibilityService, id: String): AccessibilityNodeInfo? {
        val pkg = id.substringBefore(":id/", "")
        val active = service.rootInActiveWindow
        if (active != null && (pkg.isEmpty() || active.packageName?.toString() == pkg)) return active
        active?.recycle()
        if (pkg.isEmpty()) return null
        var match: AccessibilityNodeInfo? = null
        for (window in service.windows.orEmpty()) {
            if (window.type != AccessibilityWindowInfo.TYPE_APPLICATION ||
                (!window.isActive && !window.isFocused)) continue
            val root = window.root ?: continue
            if (root.packageName?.toString() != pkg) { root.recycle(); continue }
            if (match != null) {
                root.recycle()
                match.recycle()
                return null
            }
            match = root
        }
        return match
    }

    /** Recorrido acotado con propiedad explícita; dos candidatos rechazan la escritura. */
    private fun findEditor(root: AccessibilityNodeInfo, id: String, bounds: IntArray): AccessibilityNodeInfo? {
        var found: AccessibilityNodeInfo? = null
        val pending = ArrayDeque<AccessibilityNodeInfo>()
        for (i in 0 until root.childCount) root.getChild(i)?.let(pending::addLast)
        if (matches(root, id, bounds)) {
            pending.forEach { it.recycle() }
            return null // Un root editable no acredita un editor único dentro de una app.
        }
        var count = 0
        try {
            while (pending.isNotEmpty() && count++ < 800) {
                val node = pending.removeLast()
                if (matches(node, id, bounds)) {
                    if (found != null) { node.recycle(); found.recycle(); return null }
                    found = node
                } else {
                    for (i in 0 until node.childCount) node.getChild(i)?.let(pending::addLast)
                    node.recycle()
                }
            }
            if (pending.isNotEmpty()) { found?.recycle(); return null }
            return found
        } finally { pending.forEach { it.recycle() } }
    }

    /** Usa la misma tolerancia de ocho píxeles del contrato existente, sin buscar por posición sola. */
    private fun matches(node: AccessibilityNodeInfo, id: String, expected: IntArray): Boolean {
        if (expected.size != 4 || !node.isEditable || !node.isFocused ||
            !node.isEnabled || !node.isVisibleToUser || node.isPassword ||
            (id.isNotBlank() && node.viewIdResourceName != id)) return false
        val actual = Rect().also(node::getBoundsInScreen)
        return kotlin.math.abs(actual.left - expected[0]) <= 8 &&
            kotlin.math.abs(actual.top - expected[1]) <= 8 &&
            kotlin.math.abs(actual.right - expected[2]) <= 8 &&
            kotlin.math.abs(actual.bottom - expected[3]) <= 8
    }
}
