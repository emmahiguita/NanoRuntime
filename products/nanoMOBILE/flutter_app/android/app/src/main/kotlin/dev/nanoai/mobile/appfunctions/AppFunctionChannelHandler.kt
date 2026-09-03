package dev.nanoai.mobile.appfunctions

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * APPFN-01 — canal de consulta de App Functions. v1 expone ÚNICAMENTE
 * `probe`: disponibilidad factual para que el CapabilityResolver pueda
 * puntuar el camino. Cualquier otro método (p. ej. un intento de ejecución)
 * es notImplemented: el fast path de ejecución no existe en v1.
 */
class AppFunctionChannelHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "probe" -> {
                val availability = AppFunctionProbe.probe(context)
                result.success(
                    mapOf(
                        "sdkInt" to availability.sdkInt,
                        "apiSupported" to availability.apiSupported,
                        "permissionDeclared" to availability.permissionDeclared,
                        "permissionGranted" to availability.permissionGranted,
                        "available" to availability.available,
                        "reason" to availability.reason,
                    ),
                )
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL_NAME = "appfunctions/probe"
    }
}
