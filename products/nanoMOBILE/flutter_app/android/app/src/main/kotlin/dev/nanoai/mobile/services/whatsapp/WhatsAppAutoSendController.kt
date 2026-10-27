package dev.nanoai.mobile.services.whatsapp

import android.accessibilityservice.AccessibilityService
import android.util.Log

/**
 * QUÉ HACE: Controlador del ciclo de auto-envío y retorno automático para Accesibilidad en WhatsApp.
 * CÓMO FUNCIONA: Encuentra la ventana interactuable de WhatsApp, verifica los elementos y pulsa el botón
 *                de envío. Tras enviar exitosamente, ejecuta un retorno automático a la UI de Nano.
 * POR QUÉ: Mantiene la experiencia de usuario dentro de Nano AI ("Nano sigue presente"), evitando que
 *          el usuario quede atascado en WhatsApp tras compartir un archivo multimedia.
 * SOLID: Cumple SRP (Responsabilidad Única en la automatización del flujo de retorno).
 */
object WhatsAppAutoSendController {
    private const val TAG = "nanoagent_autosend"

    private var sessionKey: String = ""
    private var pickerSessionDetected = false
    private var pickerRecipientSelected = false
    private var pickerAdvanceClicked = false

    fun resetSession() {
        WhatsAppUsernameVerifier.reset()
        sessionKey = ""
        pickerSessionDetected = false
        pickerRecipientSelected = false
        pickerAdvanceClicked = false
    }

    /**
     * QUÉ HACE: Intenta encontrar el botón de envío en la ventana interactuable y retornar a Nano.
     * CÓMO FUNCIONA: Utiliza [InteractiveWindowFinder] para evitar ser bloqueado por overlays de Nano,
     *                ejecuta [WhatsAppMediaVerifier.findAndClickSendButton] y realiza el retorno.
     *
     * @param service Instancia activa de [AccessibilityService].
     * @param targetPkg Paquete de WhatsApp objetivo (`com.whatsapp` o `com.whatsapp.w4b`).
     * @return Boolean `true` si el envío se ejecutó y se inició el retorno; `false` si no estaba listo.
     */
    fun performAutoSendAndReturn(
        service: AccessibilityService,
        targetPkg: String? = null,
        targetContact: String? = null,
        expectedAlias: String? = null,
        expectedText: String? = null,
        documentName: String? = null
    ): Boolean {
        if (dev.nanoai.mobile.BuildConfig.PLAY_STORE_BUILD) {
            Log.i(TAG, "Auto-send deshabilitado en build de Google Play para cumplir la política de Accesibilidad")
            return false
        }
        // Step 1: Obtener la ventana interactuable de WhatsApp
        val rootNode = InteractiveWindowFinder.findTargetRootNode(service, targetPkg)
        if (rootNode == null) {
            Log.d(TAG, "Ventana de WhatsApp no lista o no visible aún")
            return false
        }
        try {
            val currentKey = listOf(targetPkg, targetContact, expectedAlias).joinToString("|")
            if (sessionKey != currentKey) {
                resetSession()
                sessionKey = currentKey
            }

            // La identidad exacta se comprueba antes de buscar cualquier botón que pueda enviar.
            if (targetContact.isNullOrBlank() && expectedAlias.isNullOrBlank()) {
                Log.w(TAG, "Autoenvío bloqueado: falta identidad explícita del destinatario")
                return false
            }
            val lastWhatsAppEvent = dev.nanoai.mobile.services.AgentAccessibilityBridge.lastEvent
                ?.takeIf { event ->
                    targetPkg.isNullOrBlank() || event.packageName.equals(targetPkg, ignoreCase = true)
                }
            val pickerWindow = WhatsAppSharePickerController.isPicker(
                rootNode,
                lastWhatsAppEvent?.className,
            )
            if (pickerWindow) pickerSessionDetected = true
            if (pickerSessionDetected && !pickerAdvanceClicked) {
                if (!pickerRecipientSelected) {
                    when (
                        WhatsAppSharePickerController.prepareRecipient(
                            rootNode,
                            targetContact,
                            expectedAlias,
                            pickerPreviouslyDetected = true,
                        )
                    ) {
                        SharePickerProgress.RECIPIENT_SELECTED -> pickerRecipientSelected = true
                        SharePickerProgress.AMBIGUOUS -> Log.w(
                            TAG,
                            "Autoenvío bloqueado: el selector contiene destinatarios ambiguos",
                        )
                        else -> Unit
                    }
                    return false
                }
                if (!pickerAdvanceClicked && WhatsAppSharePickerController.clickAdvance(rootNode)) {
                    pickerAdvanceClicked = true
                    pickerSessionDetected = false
                }
                return false
            }
            // Tras pulsar Siguiente, esperar a que WhatsApp abandone realmente el selector.
            if (pickerWindow) return false

            val recipientOk = if (targetContact?.startsWith("@") == true) {
                val alias = WhatsAppUsernameVerifier.prepare(rootNode, service, targetContact) ?: return false
                WhatsAppMediaVerifier.verifyRecipient(rootNode, null, alias)
            } else WhatsAppMediaVerifier.verifyRecipient(rootNode, targetContact, expectedAlias)
            if (!recipientOk) {
                Log.d(TAG, "Destinatario aún no coincide en la UI de WhatsApp")
                return false
            }

            // El Intent puede tardar en reemplazar un borrador anterior. No se pulsa
            // Enviar hasta que el editor exponga exactamente el texto autorizado.
            if (expectedText != null && !WhatsAppDraftVerifier.matches(rootNode, expectedText)) return false

            if (documentName != null && !WhatsAppDocumentPreview.matchesFile(rootNode, documentName)) return false

            // El click solo acredita la acción de envío; WhatsApp no expone aquí entrega/lectura.
            val clicked = WhatsAppMediaVerifier.findAndClickSendButton(rootNode)
            if (!clicked) {
                Log.d(TAG, "Botón de envío no encontrado o no clickeable en este intento")
                return false
            }

            Log.i(TAG, "Acción de envío pulsada; entrega no confirmada por WhatsApp")

            // Regresa a Nano sin conservar el AccessibilityNodeInfo de WhatsApp.
            scheduleReturnToNano(service)
            return true
        } finally {
            // Las búsquedas se repiten durante el arranque de WhatsApp; liberar el root evita fugas nativas.
            rootNode.recycle()
        }
    }

    /** Reutiliza el único dueño del retorno; no confunde Atrás aceptado con Nano visible. */
    private fun scheduleReturnToNano(service: AccessibilityService) =
        WhatsAppReturnController.schedule(service)
}
