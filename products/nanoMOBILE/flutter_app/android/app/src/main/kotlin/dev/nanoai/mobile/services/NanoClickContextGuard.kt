package dev.nanoai.mobile.services

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityNodeInfo

/** Revalida la cabecera del chat justo antes de ACTION_CLICK. Se ejecuta en
 * el hilo del servicio, con raíces Android nuevas; no confía en un dump Dart. */
internal object NanoClickContextGuard {
    /** Sin contrato preserva clics existentes. Un contrato inválido o una raíz
     * que cambió aborta el clic sin convertirlo en gesto por coordenadas. */
    fun matches(service: AccessibilityService, contract: Map<*, *>?,
        identity: (AccessibilityNodeInfo, Int) -> String): Boolean {
        if (contract == null) return true
        val pkg = contract["package"] as? String ?: return false
        val rootKey = contract["rootIdentity"] as? String ?: return false
        val title = contract["headerText"] as? String ?: return false
        val headerId = contract["headerId"] as? String ?: return false
        val windowId = (contract["windowId"] as? Number)?.toInt() ?: return false
        if (rootKey.isBlank() || title.isBlank() || headerId.isBlank()) return false
        val window = service.windows.orEmpty().singleOrNull { it.id == windowId } ?: return false
        val root = window.root ?: return false
        try {
            if (root.packageName?.toString() != pkg || identity(root, windowId) != rootKey) return false
            val headers = root.findAccessibilityNodeInfosByViewId(headerId).orEmpty()
            try {
                return headers.count { it.isVisibleToUser && it.isEnabled &&
                    it.packageName?.toString() == pkg && it.text?.toString() == title } == 1
            } finally { headers.forEach(AccessibilityNodeInfo::recycle) }
        } finally { root.recycle() }
    }
}
