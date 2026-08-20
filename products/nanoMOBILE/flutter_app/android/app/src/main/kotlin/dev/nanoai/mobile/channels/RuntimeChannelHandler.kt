package dev.nanoai.mobile.channels

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handler del canal `com.nanoai/runtime`: versión y capacidades del runtime.
 *
 * Handshake con Dart: la app consulta la versión antes de usar los demás
 * canales. Si Dart es más nuevo que el runtime (o viceversa), degrada con
 * warning en vez de fallar llamadas a ciegas.
 */
class RuntimeChannelHandler : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/runtime"

        /**
         * Versión del contrato de runtime. Incrementar SOLO con cambios que
         * rompan compatibilidad de métodos/argumentos en los canales
         * exec_bin / pty / device_metrics. Debe reflejarse en
         * NanoRuntimeApi.supportedRuntimeVersion (Dart).
         */
        const val RUNTIME_VERSION = 1

        /** Capacidades que este runtime expone al handshake. */
        val CAPABILITIES = listOf(
            "rootfs",   // downloadBootstrap / extractBootstrap / isBootstrapInstalled / downloadFile
            "exec",     // probeExec / makeExecutable / getFilesDir
            "worker",   // workerSpawn / workerKill
            "packages", // installPackages / installGraphical
            "desktop",  // startDesktop / stopDesktop / getDesktopStatus
            "pty",      // ptySpawn / ptyWrite / ptyRead / ptyResize / ptyKill / ptyClose
            "agent",    // AgentAccessibilityService: dumpScreen / findText / tap / swipe / inputText
            "engine",   // EngineSupervisor: start / state / health / stop / ensureExtracted
            "notifications", // NotificationListener: leer y responder con confirmación
            "device-permissions", // estado y paneles de permisos usados por la app
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getRuntimeVersion" -> result.success(RUNTIME_VERSION)
            "getCapabilities" -> result.success(CAPABILITIES)
            else -> result.notImplemented()
        }
    }
}
