package dev.nanoai.mobile.services.whatsapp

import android.graphics.Rect
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import java.text.Normalizer

internal enum class SharePickerProgress {
    NOT_PICKER,
    SEARCH_STARTED,
    WAITING_RESULTS,
    RECIPIENT_SELECTED,
    AMBIGUOUS,
}

/** Automatiza únicamente el selector externo de WhatsApp con coincidencia exacta. */
internal object WhatsAppSharePickerController {
    private const val TAG = "nanoagent_picker"

    private val pickerTitles = setOf("enviar a", "send to", "compartir con", "share with")
    private val searchLabels = setOf("buscar", "search")
    private val advanceLabels = setOf("siguiente", "next", "continuar", "continue")
    private val pickerSearchHints = setOf(
        "nombre numero o nombre de usuario",
        "name number or username",
    )

    fun isPicker(root: AccessibilityNodeInfo, windowClassName: String? = null): Boolean {
        if (isPickerWindowClass(windowClassName)) return true

        val rootBounds = Rect().also(root::getBoundsInScreen)
        if (rootBounds.height() <= 0) return false
        return walk(root) { node ->
            val bounds = Rect().also(node::getBoundsInScreen)
            if (bounds.isEmpty || bounds.centerY() > rootBounds.top + (rootBounds.height() * 0.30f)) {
                return@walk false
            }
            val values = nodeValues(node).map(::normalizeLabel)
            values.any(pickerTitles::contains) ||
                (node.isEditable && values.any(pickerSearchHints::contains))
        }
    }

    fun prepareRecipient(
        root: AccessibilityNodeInfo,
        targetContact: String?,
        expectedAlias: String?,
        pickerPreviouslyDetected: Boolean = false,
    ): SharePickerProgress {
        if (!pickerPreviouslyDetected && !isPicker(root)) return SharePickerProgress.NOT_PICKER
        val candidates = listOfNotNull(expectedAlias, targetContact)
            .map(String::trim)
            .filter(String::isNotEmpty)
            .map(::normalizeIdentity)
            .distinct()
        if (candidates.isEmpty()) return SharePickerProgress.AMBIGUOUS

        val clickableRows = linkedSetOf<String>()
        val rootBounds = Rect().also(root::getBoundsInScreen)
        walk(root) { node ->
            val bounds = Rect().also(node::getBoundsInScreen)
            val isRowArea = rootBounds.height() > 0 &&
                bounds.centerY() > rootBounds.top + (rootBounds.height() * 0.12f)
            if (!node.isEditable && isRowArea && nodeValues(node).any { normalizeIdentity(it) in candidates }) {
                clickableAncestorBounds(node)?.let(clickableRows::add)
            }
            false
        }

        if (clickableRows.size > 1) {
            Log.w(TAG, "Selector ambiguo: más de una fila coincide exactamente con el destinatario")
            return SharePickerProgress.AMBIGUOUS
        }
        val exactRow = clickableRows.singleOrNull()
        if (exactRow != null) {
            val clicked = walk(root) { node ->
                !node.isEditable &&
                    nodeValues(node).any { normalizeIdentity(it) in candidates } &&
                    clickableAncestorBounds(node) == exactRow &&
                    performClick(node)
            }
            if (clicked) {
                Log.i(TAG, "Destinatario exacto seleccionado en el selector de WhatsApp")
                return SharePickerProgress.RECIPIENT_SELECTED
            }
        }

        val query = expectedAlias?.trim().takeUnless { it.isNullOrBlank() }
            ?: targetContact?.trim().orEmpty()
        if (setSearchQuery(root, query)) return SharePickerProgress.WAITING_RESULTS
        if (clickSearch(root)) return SharePickerProgress.SEARCH_STARTED
        return SharePickerProgress.WAITING_RESULTS
    }

    fun clickAdvance(root: AccessibilityNodeInfo): Boolean {
        val clicked = walk(root) { node ->
            nodeValues(node).map(::normalizeLabel).any(advanceLabels::contains) &&
                isBottomControl(root, node) && performClick(node)
        }
        if (clicked) {
            Log.i(TAG, "Selección confirmada; avanzando a la vista previa multimedia")
        }
        return clicked
    }

    private fun setSearchQuery(root: AccessibilityNodeInfo, query: String): Boolean {
        if (query.isBlank()) return false
        val rootBounds = Rect().also(root::getBoundsInScreen)
        return walk(root) { node ->
            val bounds = Rect().also(node::getBoundsInScreen)
            val isTopSearchField = rootBounds.height() > 0 &&
                bounds.centerY() <= rootBounds.top + (rootBounds.height() * 0.35f)
            if (!node.isEditable || !node.isVisibleToUser || !isTopSearchField) return@walk false
            if (normalizeIdentity(node.text?.toString().orEmpty()) == normalizeIdentity(query)) {
                return@walk true
            }
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            val updated = node.performAction(
                AccessibilityNodeInfo.ACTION_SET_TEXT,
                Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, query)
                },
            )
            if (updated) Log.i(TAG, "Búsqueda exacta iniciada en el selector de WhatsApp")
            updated
        }
    }

    private fun clickSearch(root: AccessibilityNodeInfo): Boolean {
        return walk(root) { node ->
            nodeValues(node).map(::normalizeLabel).any(searchLabels::contains) && performClick(node)
        }
    }

    private fun isPickerWindowClass(value: String?): Boolean {
        val className = value.orEmpty()
        return className.contains("ExternalShare", ignoreCase = true) ||
            className.contains("ContactPicker", ignoreCase = true)
    }

    private fun nodeValues(node: AccessibilityNodeInfo): List<String> = listOfNotNull(
        node.text?.toString(),
        node.contentDescription?.toString(),
        node.hintText?.toString(),
    )

    /** Recorre el árbol sin conservar nodos; cada hijo se libera en el mismo frame. */
    private fun walk(root: AccessibilityNodeInfo, predicate: (AccessibilityNodeInfo) -> Boolean): Boolean {
        if (predicate(root)) return true
        for (index in 0 until root.childCount) {
            val child = root.getChild(index) ?: continue
            try {
                if (walk(child, predicate)) return true
            } finally {
                child.recycle()
            }
        }
        return false
    }

    private fun clickableAncestorBounds(node: AccessibilityNodeInfo): String? {
        var current: AccessibilityNodeInfo? = node
        var ownsCurrent = false
        while (current != null) {
            if (current.isClickable) {
                val bounds = Rect().also(current::getBoundsInScreen)
                if (ownsCurrent) current.recycle()
                return "${bounds.left}:${bounds.top}:${bounds.right}:${bounds.bottom}"
            }
            val parent = current.parent
            if (ownsCurrent) current.recycle()
            current = parent
            ownsCurrent = true
        }
        return null
    }

    private fun performClick(node: AccessibilityNodeInfo): Boolean {
        var current: AccessibilityNodeInfo? = node
        var ownsCurrent = false
        while (current != null) {
            if (current.isClickable) {
                val clicked = current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                if (ownsCurrent) current.recycle()
                return clicked
            }
            val parent = current.parent
            if (ownsCurrent) current.recycle()
            current = parent
            ownsCurrent = true
        }
        return false
    }

    private fun isBottomControl(root: AccessibilityNodeInfo, node: AccessibilityNodeInfo): Boolean {
        val rootBounds = Rect().also(root::getBoundsInScreen)
        val nodeBounds = Rect().also(node::getBoundsInScreen)
        return rootBounds.height() > 0 && !nodeBounds.isEmpty &&
            nodeBounds.centerY() >= rootBounds.top + (rootBounds.height() * 0.55f)
    }

    private fun normalizeIdentity(value: String): String {
        val clean = value.replace(Regex("\\p{Cf}"), "").trim()
        val digits = clean.filter(Char::isDigit)
        return if (digits.length >= 7) digits else normalizeLabel(clean)
    }

    private fun normalizeLabel(value: String): String = value
        .replace(Regex("\\p{Cf}"), "")
        .trim()
        .lowercase()
        .replace('…', ' ')
        .replace("...", " ")
        .let { Normalizer.normalize(it, Normalizer.Form.NFD) }
        .replace(Regex("\\p{M}+"), "")
        .replace(Regex("[\\s:,;]+"), " ")
        .trim()
}
