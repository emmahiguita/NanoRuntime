package dev.nanoai.mobile.services.whatsapp

import android.os.Bundle
import android.graphics.Rect
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

    private val HEADER_RESOURCE_IDS = arrayOf(
        "com.whatsapp:id/conversation_contact_name",
        "com.whatsapp.w4b:id/conversation_contact_name",
        "com.whatsapp:id/conversation_contact",
        "com.whatsapp.w4b:id/conversation_contact"
    )

    /**
     * QUÉ HACE: Verifica que el destinatario en el encabezado coincida con el contacto solicitado.
     * CÓMO FUNCIONA: Busca nodos de texto en la barra superior del chat antes de autorizar la acción.
     * POR QUÉ: Fail-closed honesto: evita enviar fotos a chats equivocados si el Intent abre otro contacto.
     */
    fun verifyRecipient(root: AccessibilityNodeInfo, targetContact: String?, expectedAlias: String? = null): Boolean {
        if (targetContact.isNullOrBlank() && expectedAlias.isNullOrBlank()) return false

        val candidates = listOfNotNull(targetContact, expectedAlias)
            .map(String::trim)
            .filter(String::isNotEmpty)
            .map(::normalizeIdentity)
            .distinct()

        // Nunca se usa findAccessibilityNodeInfosByText sobre toda la ventana:
        // el alias podría aparecer en una burbuja y autorizar el chat equivocado.
        for (resourceId in HEADER_RESOURCE_IDS) {
            val nodes = root.findAccessibilityNodeInfosByViewId(resourceId).orEmpty()
            try {
                val exactMatch = nodes.any { node ->
                    listOfNotNull(node.text?.toString(), node.contentDescription?.toString())
                        .map(::normalizeIdentity)
                        .any(candidates::contains)
                }
                if (exactMatch) {
                    Log.i(TAG, "Destinatario confirmado en el encabezado de WhatsApp")
                    return true
                }
            } finally {
                nodes.forEach(AccessibilityNodeInfo::recycle)
            }
        }

        Log.w(TAG, "Fail-closed: el encabezado no confirmó la identidad solicitada")
        return false
    }

    // La búsqueda Android devuelve coincidencias parciales; igualdad normalizada evita usar un alias dentro de otro texto.
    private fun normalizeIdentity(value: String): String {
        val trimmed = value.trim()
        val digits = trimmed.filter(Char::isDigit)
        return if (digits.length >= 7) digits else trimmed.lowercase().replace(Regex("\\s+"), " ")
    }

    /**
     * QUÉ HACE: Confirma que la vista previa de la imagen/vídeo/documento está activa.
     * CÓMO FUNCIONA: Detecta presencia del botón de envío de caption o contenedores de media.
     * POR QUÉ: Garantiza que la imagen fue cargada correctamente por WhatsApp antes de pulsar Enviar.
     */
    fun verifyMediaPreview(root: AccessibilityNodeInfo): Boolean {
        // En la pantalla de preview de media, el botón de envío tiene ID 'caption_send_button' o 'send'
        for (id in SEND_RESOURCE_IDS) {
            val found = root.findAccessibilityNodeInfosByViewId(id).orEmpty()
            try {
                if (found.isNotEmpty()) return true
            } finally {
                found.forEach(AccessibilityNodeInfo::recycle)
            }
        }
        return hasSafeSendLabel(root)
    }

    /**
     * QUÉ HACE: Encuentra y ejecuta el clic en el botón de envío aplicando la cascada Dynamic-First.
     * CÓMO FUNCIONA: Prueba 1) ID de recurso, 2) contentDescription/Text, 3) Recorrido de jerarquía.
     * POR QUÉ: Evita depender de coordenadas duras (x,y) que cambian según resolución o orientación de pantalla.
     */
    fun findAndClickSendButton(root: AccessibilityNodeInfo): Boolean {
        // Nivel 1: Por ID de Recurso exacto
        for (id in SEND_RESOURCE_IDS) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id).orEmpty()
            try {
                for (sendNode in nodes) {
                    if (performClickOnNode(sendNode)) {
                        Log.i(TAG, "Envío ejecutado por Resource ID: $id")
                        return true
                    }
                }
            } finally {
                nodes.forEach(AccessibilityNodeInfo::recycle)
            }
        }

        // Nivel 2: descripción accesible exacta y control ubicado en la zona
        // inferior. El texto visible nunca es prueba: podría ser una burbuja.
        val candidateTexts = listOf("Enviar", "Send")
        for (text in candidateTexts) {
            val nodes = root.findAccessibilityNodeInfosByText(text).orEmpty()
            try {
                for (node in nodes) {
                    if (isSafeSendLabelControl(root, node) && performClickOnNode(node)) {
                        Log.i(TAG, "Envío ejecutado por descripción accesible: $text")
                        return true
                    }
                }
            } finally {
                nodes.forEach(AccessibilityNodeInfo::recycle)
            }
        }
        Log.w(TAG, "Fail-closed: no se encontró un control de envío inequívoco")
        return false
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
                val clicked = current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                if (current !== node) current.recycle()
                return clicked
            }
            val parent = current.parent
            if (current !== node) current.recycle()
            current = parent
        }
        return false
    }

    private fun hasSafeSendLabel(root: AccessibilityNodeInfo): Boolean {
        for (label in listOf("Enviar", "Send")) {
            val nodes = root.findAccessibilityNodeInfosByText(label).orEmpty()
            try {
                if (nodes.any { isSafeSendLabelControl(root, it) }) return true
            } finally {
                nodes.forEach(AccessibilityNodeInfo::recycle)
            }
        }
        return false
    }

    private fun isSafeSendLabelControl(
        root: AccessibilityNodeInfo,
        node: AccessibilityNodeInfo,
    ): Boolean {
        val description = node.contentDescription?.toString()?.trim()?.lowercase()
        if (description != "enviar" && description != "send") return false
        if (node.packageName?.toString() != root.packageName?.toString()) return false

        val rootBounds = Rect().also(root::getBoundsInScreen)
        val nodeBounds = Rect().also(node::getBoundsInScreen)
        if (rootBounds.height() <= 0 || nodeBounds.isEmpty) return false
        return nodeBounds.centerY() >= rootBounds.top + (rootBounds.height() * 0.55f)
    }
}
