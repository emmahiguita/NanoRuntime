package dev.nanoai.mobile.input

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.inputmethod.InputMethodManager
import dev.nanoai.mobile.services.AgentAccessibilityBridge
import dev.nanoai.mobile.services.AgentAccessibilityService

/** Consulta Android y la instancia viva por separado; no modifica ajustes. */
internal object NanoInputStatus {
    /** Devuelve estados sin texto de pantalla, contactos ni contenido de teclado. */
    fun snapshot(context: Context): Map<String, Any> {
        val accessibility = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val component = ComponentName(context, AgentAccessibilityService::class.java)
        val reportedEnabled = accessibility.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { it.resolveInfo.serviceInfo.let { item ->
                item.packageName == component.packageName && item.name == component.className
            } }
        val connected = AgentAccessibilityBridge.service != null
        // UiAutomation puede ocultar los servicios al AccessibilityManager sin
        // revocar la elección del usuario. Leer Secure no concede ni cambia permisos.
        val configured = Settings.Secure.getString(
            context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        )?.split(':')?.any { ComponentName.unflattenFromString(it) == component }
        val enabled = configured ?: reportedEnabled
        val keyboards = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        val ime = ComponentName(context, NanoInputMethodService::class.java)
        val selected = Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
        val imeEnabled = keyboards.enabledInputMethodList.any {
            ComponentName.unflattenFromString(it.id) == ime
        }
        return mapOf(
            "accessibilityEnabled" to enabled,
            "accessibilityConnected" to connected,
            "accessibilityReportedByManager" to reportedEnabled,
            "imeEnabled" to imeEnabled,
            "imeSelected" to (selected?.let(ComponentName::unflattenFromString) == ime),
        )
    }

    /** Abre la configuración pública; solo la persona habilita un teclado. */
    fun openKeyboardSettings(context: Context) {
        context.startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
