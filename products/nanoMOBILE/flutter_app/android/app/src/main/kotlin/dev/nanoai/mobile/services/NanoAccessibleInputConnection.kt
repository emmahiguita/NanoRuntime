package dev.nanoai.mobile.services

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.text.InputType
import android.view.accessibility.AccessibilityNodeInfo

/** Entrada de Android 13 para el compositor WhatsApp ya verificado por Nano.
 * No posee servicio, foco ni texto: solo utiliza la conexión mientras es válida. */
internal object NanoAccessibleInputConnection {
    /** UNAVAILABLE permite SET_TEXT; UNCERTAIN prohíbe una segunda escritura. */
    enum class Result { UNAVAILABLE, DISPATCHED, UNCERTAIN }

    /** Comprueba paquete, id real del campo, foco y contenido antes de insertar.
     * commitText no confirma escritura: el consumidor debe observar el borrador. */
    fun write(service: AccessibilityService, node: AccessibilityNodeInfo, text: String): Result {
        if (Build.VERSION.SDK_INT < 33) return Result.UNAVAILABLE
        val pkg = node.packageName?.toString().orEmpty()
        if (pkg !in setOf("com.whatsapp", "com.whatsapp.w4b") ||
            node.viewIdResourceName != "$pkg:id/entry" || !node.isFocused ||
            node.isPassword || !NanoAccessibilityText.isEmptyEditor(node)) return Result.UNAVAILABLE
        val input = service.inputMethod ?: return Result.UNAVAILABLE
        if (!input.currentInputStarted) return Result.UNAVAILABLE
        val info = input.currentInputEditorInfo ?: return Result.UNAVAILABLE
        if (info.packageName != pkg || sensitive(info.inputType)) return Result.UNAVAILABLE
        val fieldId = try {
            service.packageManager.getResourcesForApplication(pkg)
                .getIdentifier("entry", "id", pkg)
        } catch (_: Exception) { 0 }
        if (fieldId == 0 || info.fieldId != fieldId) return Result.UNAVAILABLE
        val connection = input.currentInputConnection ?: return Result.UNAVAILABLE
        val latest = input.currentInputEditorInfo
        if (!input.currentInputStarted || latest?.packageName != pkg ||
            latest.fieldId != fieldId || !node.refresh() || !node.isFocused ||
            node.packageName?.toString() != pkg ||
            node.viewIdResourceName != "$pkg:id/entry" ||
            !NanoAccessibilityText.isEmptyEditor(node)) {
            return Result.UNAVAILABLE
        }
        return try {
            connection.commitText(text, 1, null)
            Result.DISPATCHED
        } catch (_: Exception) {
            // La llamada pudo cruzar el proceso antes del error: no repetir.
            Result.UNCERTAIN
        }
    }

    /** Excluye contraseñas de texto y numéricas de cualquier inserción. */
    private fun sensitive(type: Int): Boolean {
        val klass = type and InputType.TYPE_MASK_CLASS
        val variation = type and InputType.TYPE_MASK_VARIATION
        return (klass == InputType.TYPE_CLASS_TEXT && variation in setOf(
            InputType.TYPE_TEXT_VARIATION_PASSWORD,
            InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD,
            InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD,
        )) || (klass == InputType.TYPE_CLASS_NUMBER &&
            variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD)
    }
}
