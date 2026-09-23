package dev.nanoai.mobile.services

import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo

/**
 * NanoScreenReader — Extractor contextual de pantalla estilo Gemini.
 *
 * QUÉ: Lee el árbol de accesibilidad de la ventana activa fuera de Nano.
 * CÓMO: Extrae textos legibles, botones y URLs de la app subyacente evitando
 *       capturar los controles del propio overlay (dev.nanoai.mobile).
 * POR QUÉ: Permite al búho flotante responder preguntas sobre la app que el usuario
 *          está usando sin necesidad de capturar pantalla por píxeles ni requerir root.
 * SOLID-S: Responsabilidad única: inspeccionar y estructurar el contexto visual de la app activa.
 */
internal object NanoScreenReader {

    data class ScreenData(
        val packageName: String,
        val visibleText: String,
        val links: List<String>,
        val interactiveElements: List<String>,
    )

    fun readCurrentScreen(): ScreenData? {
        val service = AgentAccessibilityBridge.service ?: return null
        val roots = service.windows.orEmpty().mapNotNull { it.root }.ifEmpty {
            listOfNotNull(service.rootInActiveWindow)
        }
        if (roots.isEmpty()) return null

        val texts = mutableListOf<String>()
        val links = mutableListOf<String>()
        val interactives = mutableListOf<String>()
        var targetPackage = ""

        val bounds = Rect()
        for (root in roots) {
            val stack = ArrayDeque<AccessibilityNodeInfo>()
            stack.add(root)

            while (stack.isNotEmpty()) {
                val node = stack.removeLast()
                val pkg = node.packageName?.toString().orEmpty()

                // Ignorar los elementos del propio overlay de Nano
                if (pkg != "dev.nanoai.mobile") {
                    if (targetPackage.isEmpty() && pkg.isNotEmpty()) {
                        targetPackage = pkg
                    }

                    node.getBoundsInScreen(bounds)
                    // Solo considerar nodos que tengan área positiva en pantalla
                    if (bounds.width() > 0 && bounds.height() > 0 && node.isVisibleToUser) {
                        val text = node.text?.toString()?.trim().orEmpty()
                        val desc = node.contentDescription?.toString()?.trim().orEmpty()
                        val content = if (text.isNotEmpty()) text else desc

                        if (content.isNotEmpty()) {
                            if (!texts.contains(content)) {
                                texts.add(content)
                            }
                            if (content.startsWith("http://") || content.startsWith("https://")) {
                                if (!links.contains(content)) links.add(content)
                            }
                        }

                        if (node.isClickable && content.isNotEmpty()) {
                            if (!interactives.contains(content)) {
                                interactives.add(content)
                            }
                        }
                    }
                }

                for (i in 0 until node.childCount) {
                    node.getChild(i)?.let(stack::add)
                }
                if (node !== root) node.recycle()
            }
            root.recycle()
        }

        if (texts.isEmpty() && targetPackage.isEmpty()) return null

        // Truncar texto consolidado a un máximo prudente de 2500 caracteres
        val combined = texts.joinToString("\n")
        val safeText = if (combined.length > 2500) combined.substring(0, 2500) + "…" else combined

        return ScreenData(
            packageName = targetPackage,
            visibleText = safeText,
            links = links.take(10),
            interactiveElements = interactives.take(12),
        )
    }
}
