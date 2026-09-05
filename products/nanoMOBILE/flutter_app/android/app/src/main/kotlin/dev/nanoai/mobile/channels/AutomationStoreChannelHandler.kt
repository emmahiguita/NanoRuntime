package dev.nanoai.mobile.channels

import android.content.Context
import dev.nanoai.mobile.NanoApplication
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** WA-PROD-02 — puente Dart ↔ AutomationStoreDb (estado durable del
 *  pipeline: dedupe, rate limiter, memoria conversacional). Se registra en
 *  el engine de la UI Y en el headless: la base es única por proceso y el
 *  escritor (Kotlin) serializa las secciones entre isolates. */
class AutomationStoreChannelHandler(
    context: Context,
) : MethodChannel.MethodCallHandler {

    private val db = NanoApplication.from(context).automationStoreDb

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadAll" -> result.success(db.loadAll())

            "get" -> {
                val key = call.argument<String>("key")
                if (key == null) {
                    result.error("BAD_ARG", "key requerido", null)
                    return
                }
                result.success(db.section(key))
            }

            "put" -> {
                val key = call.argument<String>("key")
                val json = call.argument<String>("json")
                if (key == null || json == null) {
                    result.error("BAD_ARG", "key y json requeridos", null)
                    return
                }
                result.success(db.putSection(key, json))
            }

            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL_NAME = "com.nanoai/automation_store"
    }
}
