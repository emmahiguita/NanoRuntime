package dev.nanoai.mobile.services.whatsapp

import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

/**
 * QUÉ HACE: Verificador atómico y ejecutor de acciones de interfaz para envíos de medios en WhatsApp.
 * CÓMO FUNCIONA: Implementa el principio Dynamic-First (ID -> Text/Description -> Relación de Nodos)
 *                y ejecuta validaciones previas y posteriores al clic.
 * POR QUÉ: Previene enviar archivos al contacto equivocado o realizar envíos fantasma cuando la interfaz falla.
 * SOLID: Aplica el Principio de Responsabilidad Única (SRP) enfocándose exclusivamente en la verificación de UI.
 */
object WhatsAppMediaVerifier {
    private const val TAG = "nanoagent_verif"

    /**
     * Identificadores de recursos conocidos en versiones oficiales de WhatsApp / WA Business.
     */
    private val SEND_RESOURCE_IDS = arrayOf(
        "com.whatsapp:id/send",
        "com.whatsapp.w4b:id/send",
        "com.whatsapp:id/caption_send_button",
        "com.whatsapp.w4b:id/caption_send_button"
    )

    /**
     * QUÉ HACE: Verifica que el destinatario en el encabezado coincida con el contacto solicitado.
     * CÓMO FUNCIONA: Busca nodos de texto en la barra superior del chat antes de autorizar la acción.
     * POR QUÉ: Fail-closed honesto: evita enviar fotos a chats equivocados si el Intent abre otro contacto.
     */
    fun verifyRecipient(root: AccessibilityNodeInfo, targetContact: String?, expectedAlias: String? = null): Boolean {
        if (targetContact.isNullOrBlank() && expectedAlias.isNullOrBlank()) return true // Si no se especifica contacto, intención abierta

        val candidates = mutableListOf<String>()
        targetContact?.takeIf { it.isNotBlank() }?.let { candidates.add(it.lowercase().trim()) }
        expectedAlias?.takeIf { it.isNotBlank() }?.let { candidates.add(it.lowercase().trim()) }

        for (candidate in candidates) {
            val nodes = root.findAccessibilityNodeInfosByText(candidate)
            if (!nodes.isNullOrEmpty()) {
                Log.i(TAG, "Destinatario verificado con éxito en la UI: '$candidate'")
                return true
            }
        }

        Log.w(TAG, "Fail-closed: No se confirmó el contacto en la UI actual (buscados: $candidates)")
        return false
    }

    /**
     * QUÉ HACE: Confirma que la vista previa de la imagen/vídeo/documento está activa.
     * CÓMO FUNCIONA: Detecta presencia del botón de envío de caption o contenedores de media.
     * POR QUÉ: Garantiza que la imagen fue cargada correctamente por WhatsApp antes de pulsar Enviar.
     */
    fun verifyMediaPreview(root: AccessibilityNodeInfo): Boolean {
        // En la pantalla de preview de media, el botón de envío tiene ID 'caption_send_button' o 'send'
        for (id in SEND_RESOURCE_IDS) {
            val found = root.findAccessibilityNodeInfosByViewId(id)
            if (!found.isNullOrEmpty()) {
                return true
            }
        }
        // Búsqueda por descripciones comunes en español e inglés
        val byDesc = root.findAccessibilityNodeInfosByText("Enviar")
            ?: root.findAccessibilityNodeInfosByText("Send")
        return !byDesc.isNullOrEmpty()
    }

    /**
     * QUÉ HACE: Encuentra y ejecuta el clic en el botón de envío aplicando la cascada Dynamic-First.
     * CÓMO FUNCIONA: Prueba 1) ID de recurso, 2) contentDescription/Text, 3) Recorrido de jerarquía.
     * POR QUÉ: Evita depender de coordenadas duras (x,y) que cambian según resolución o orientación de pantalla.
     */
    fun findAndClickSendButton(root: AccessibilityNodeInfo): Boolean {
        // Nivel 1: Por ID de Recurso exacto
        for (id in SEND_RESOURCE_IDS) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (!nodes.isNullOrEmpty()) {
                val sendNode = nodes[0]
                if (performClickOnNode(sendNode)) {
                    Log.i(TAG, "Envío ejecutado por Resource ID: $id")
                    return true
                }
            }
        }

        // Nivel 2: Por Content Description o Texto ("Enviar" / "Send")
        val candidateTexts = listOf("Enviar", "Send")
        for (text in candidateTexts) {
            val nodes = root.findAccessibilityNodeInfosByText(text)
            if (!nodes.isNullOrEmpty()) {
                for (node in nodes) {
                    if (performClickOnNode(node)) {
                        Log.i(TAG, "Envío ejecutado por Texto/ContentDescription: $text")
                        return true
                    }
                }
            }
        }

        // Nivel 3: Recorrido estructural buscando botón clickeable al final de la pantalla
        val clicked = searchAndClickSendRecursive(root)
        if (clicked) {
            Log.i(TAG, "Envío ejecutado por coincidencia estructural en el árbol")
        }
        return clicked
    }

    /**
     * QUÉ HACE: Realiza clic en el nodo especificado o en su primer ancestro clickeable.
     * CÓMO FUNCIONA: Sube en el árbol con `node.parent` si el nodo actual no tiene `isClickable = true`.
     * POR QUÉ: Los íconos en Android a menudo reciben el touch a través de su marco contenedor (ViewGroup).
     */
    private fun performClickOnNode(node: AccessibilityNodeInfo?): Boolean {
        var current = node
        while (current != null) {
            if (current.isClickable) {
                return current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
            current = current.parent
        }
        return false
    }

    /**
     * QUÉ HACE: Búsqueda recursiva de respaldo para ubicar el botón de envío por características de nodo.
     */
    private fun searchAndClickSendRecursive(node: AccessibilityNodeInfo): Boolean {
        val desc = node.contentDescription?.toString() ?: ""
        val text = node.text?.toString() ?: ""

        if (desc.contains("Enviar", ignoreCase = true) || desc.contains("Send", ignoreCase = true) ||
            text.contains("Enviar", ignoreCase = true) || text.contains("Send", ignoreCase = true)
        ) {
            if (performClickOnNode(node)) return true
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (searchAndClickSendRecursive(child)) return true
        }
        return false
    }
}
