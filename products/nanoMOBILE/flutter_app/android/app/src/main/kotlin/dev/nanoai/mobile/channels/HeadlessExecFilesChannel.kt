package dev.nanoai.mobile.channels

import android.content.Context
import android.os.Handler
import dev.nanoai.mobile.SecurePathPolicy
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.io.File

/**
 * QUÉ: implementa las consultas de archivos que el runtime usa sin Activity.
 * CÓMO: comparte el sandbox de ExecBin, ejecuta IO en el scope del servicio y
 * devuelve el resultado real; no instala Linux ni crea procesos adicionales.
 * POR QUÉ: getFilesDir por sí solo dejaba tres llamadas de arranque sin handler.
 */
internal class HeadlessExecFilesChannel(
    context: Context, private val scope: CoroutineScope, private val main: Handler,
) : MethodChannel.MethodCallHandler {
    private val base = File(context.filesDir, "nano")
    private val paths = SecurePathPolicy(context.filesDir)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in setOf("getFilesDir", "makeExecutable", "isBootstrapInstalled")) {
            result.notImplemented()
            return
        }
        scope.launch {
            try {
                val value: Any = when (call.method) {
                    "getFilesDir" -> {
                        check(base.isDirectory || base.mkdirs()) { "files/nano no disponible" }
                        base.absolutePath
                    }
                    "makeExecutable" -> {
                        val path = requireNotNull(call.arguments as? String) { "path requerido" }
                        paths.requireInsideNanoFiles(File(path), "path").setExecutable(true, false)
                    }
                    else -> {
                        val path = requireNotNull(call.arguments as? String) { "usrDir requerido" }
                        val bash = paths.requireInsideNanoFiles(File(path, "bin/bash"), "usrDir")
                        bash.exists() && bash.canExecute()
                    }
                }
                main.post { result.success(value) }
            } catch (error: Exception) {
                main.post { result.error("HEADLESS_FILES_FAILED", error.javaClass.simpleName, null) }
            }
        }
    }
}
