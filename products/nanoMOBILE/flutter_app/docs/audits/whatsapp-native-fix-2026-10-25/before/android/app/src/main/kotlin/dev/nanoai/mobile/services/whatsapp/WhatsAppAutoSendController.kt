package dev.nanoai.mobile.services.whatsapp

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import dev.nanoai.mobile.MainActivity

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
        expectedAlias: String? = null
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

            val recipientOk = WhatsAppMediaVerifier.verifyRecipient(rootNode, targetContact, expectedAlias)
            if (!recipientOk) {
                Log.d(TAG, "Destinatario aún no coincide en la UI de WhatsApp")
                return false
            }

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

    /**
     * QUÉ HACE: Ejecuta el retorno hacia Nano AI tras completar la automatización.
     * CÓMO FUNCIONA: Dispara GLOBAL_ACTION_BACK tras un breve delay (300ms) para permitir que WhatsApp
     *                procese la animación de envío. Si falla, relanza MainActivity con FLAG_ACTIVITY_REORDER_TO_FRONT.
     * POR QUÉ: Evita saltos bruscos en la UI y confirma que el mensaje entró en la cola de salida de WhatsApp.
     */
    private fun scheduleReturnToNano(service: AccessibilityService) {
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        handler.postDelayed({
            try {
                // Primer intento: Acción de retorno global
                val backExecuted = service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
                if (!backExecuted) {
                    // Segundo intento: Re-lanzar MainActivity de Nano al frente
                    val intent = Intent(service, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    }
                    service.startActivity(intent)
                }
            } catch (e: Exception) {
                Log.w(TAG, "No se pudo completar el retorno automático a Nano: ${e.message}")
            }
        }, 350L) // Delay táctico de 350ms para permitir al OS registrar la acción
    }
}
