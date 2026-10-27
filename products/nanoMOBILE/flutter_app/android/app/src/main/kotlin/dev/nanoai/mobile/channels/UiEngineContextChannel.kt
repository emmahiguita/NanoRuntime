package dev.nanoai.mobile.channels

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * QUÉ: identifica inmediatamente el engine visible de Flutter.
 * CÓMO: responde `false` al mismo canal que el servicio headless responde `true`.
 * POR QUÉ: sin este handler, la UI esperaba un timeout de 1,5 s antes de runApp.
 */
object UiEngineContextChannel {
    private const val CHANNEL = "com.nanoai/headless"

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isHeadless") result.success(false)
            else result.notImplemented()
        }
    }
}
