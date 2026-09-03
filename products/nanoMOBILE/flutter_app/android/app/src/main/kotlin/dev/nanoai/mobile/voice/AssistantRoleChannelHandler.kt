package dev.nanoai.mobile.voice

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * ROLE-01 — canal del Assistant Role (ROLE_ASSISTANT, API 29+).
 *
 * Reglas duras:
 * - La solicitud NUNCA es automática: `requestRole` solo se invoca desde un
 *   botón explícito del usuario; abre el selector del sistema y jamás fuerza
 *   la concesión.
 * - Negar no rompe nada: `isHoldingRole` sigue false y no hay reintentos
 *   silenciosos en ningún lado.
 * - `isHoldingRole`/`isSessionActive` son consultas pasivas: no abren
 *   diálogos.
 */
class AssistantRoleChannelHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isHoldingRole" -> result.success(isHoldingRole())
            "isSessionActive" -> result.success(
                NanoVoiceInteractionSession.isSessionActive,
            )
            "requestRole" -> result.success(requestRole())
            else -> result.notImplemented()
        }
    }

    /** Consulta pasiva del role. < API 29 no existe el role -> false. */
    private fun isHoldingRole(): Boolean {
        if (Build.VERSION.SDK_INT < 29) return false
        val roleManager = context.getSystemService(RoleManager::class.java)
            ?: return false
        return runCatching {
            roleManager.isRoleHeld(RoleManager.ROLE_ASSISTANT)
        }.getOrDefault(false)
    }

    /** Abre el selector del sistema. Solo acción explícita del usuario. */
    private fun requestRole(): Boolean {
        if (Build.VERSION.SDK_INT < 29) return false
        val roleManager = context.getSystemService(RoleManager::class.java)
            ?: return false
        val intent = runCatching {
            roleManager.createRequestRoleIntent(RoleManager.ROLE_ASSISTANT)
        }.getOrNull() ?: return false
        return runCatching {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        }.getOrDefault(false)
    }

    companion object {
        const val CHANNEL_NAME = "com.nanoai/assistant_role"
    }
}
