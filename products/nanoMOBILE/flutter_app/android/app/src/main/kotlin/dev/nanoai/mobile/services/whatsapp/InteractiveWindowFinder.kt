package dev.nanoai.mobile.services.whatsapp

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo

/**
 * QUÉ HACE: Localizador de ventanas interactuables para aplicaciones específicas (WhatsApp/WhatsApp Business).
 * CÓMO FUNCIONA: Utiliza [AccessibilityService.getWindows] habilitado por FLAG_RETRIEVE_INTERACTIVE_WINDOWS.
 * POR QUÉ: Permite encontrar la ventana de WhatsApp incluso si el Overlay de Nano está en primer plano,
 *          superando la limitación de `rootInActiveWindow` que se vuelve nula o apunta al overlay.
 * SOLID: Sigue el Principio de Responsabilidad Única (SRP) en la inspección del árbol de ventanas.
 */
object InteractiveWindowFinder {
    private const val TAG = "nanoagent_win"

    /**
     * Paquetes de destino soportados para la búsqueda.
     */
    val SUPPORTED_PACKAGES = setOf("com.whatsapp", "com.whatsapp.w4b")

    /**
     * QUÉ HACE: Obtiene el nodo raíz de la ventana interactuable de WhatsApp.
     * CÓMO FUNCIONA: Filtra las ventanas por tipo TYPE_APPLICATION y verifica que el paquete coincida.
     * POR QUÉ: Evita interactuar con ventanas secundarias del sistema o teclados virtuales (IME).
     *
     * @param service Instancia activa de [AccessibilityService]
     * @param targetPackage Paquete opcional a buscar; si es null, busca cualquier paquete soportado.
     * @return El [AccessibilityNodeInfo] raíz de WhatsApp o null si no se encuentra.
     */
    fun findTargetRootNode(
        service: AccessibilityService,
        targetPackage: String? = null
    ): AccessibilityNodeInfo? {
        val windows = try {
            service.windows
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo obtener ventanas de Accesibilidad: ${e.message}")
            return null
        }

        if (windows.isNullOrEmpty()) {
            // Fallback directo a rootInActiveWindow si getWindows retorna vacío
            val activeRoot = service.rootInActiveWindow ?: return null
            val pkg = activeRoot.packageName?.toString() ?: ""
            return if (isTargetPackage(pkg, targetPackage)) activeRoot else null
        }

        // Iteración sobre ventanas devueltas por FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        for (window in windows) {
            // Solo nos interesan ventanas principales de aplicación (TYPE_APPLICATION)
            if (window.type != AccessibilityWindowInfo.TYPE_APPLICATION) {
                continue
            }

            val root = window.root ?: continue
            val pkgName = root.packageName?.toString() ?: ""

            if (isTargetPackage(pkgName, targetPackage)) {
                Log.d(TAG, "Ventana de destino localizada: $pkgName (id=${window.id})")
                return root
            }
        }

        return null
    }

    /**
     * QUÉ HACE: Evalúa si un nombre de paquete pertenece a las apps de WhatsApp aceptadas.
     */
    private fun isTargetPackage(pkgName: String, targetPackage: String?): Boolean {
        return if (!targetPackage.isNullOrBlank()) {
            pkgName.equals(targetPackage, ignoreCase = true)
        } else {
            SUPPORTED_PACKAGES.contains(pkgName)
        }
    }
}
