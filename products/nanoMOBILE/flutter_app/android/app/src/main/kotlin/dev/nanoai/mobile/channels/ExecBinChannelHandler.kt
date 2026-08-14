package dev.nanoai.mobile.channels

import android.util.Log
import dev.nanoai.mobile.DownloadService
import dev.nanoai.mobile.NativeRuntimeSupervisor
import dev.nanoai.mobile.SecurePathPolicy
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit
import java.util.zip.ZipFile

/**
 * Handler dedicado para el canal exec_bin.
 * Todas las operaciones de IO bloqueantes se ejecutan en ioScope.
 * Nunca bloquea el main thread.
 */
class ExecBinChannelHandler(
    private val activity: android.app.Activity,
    private val filesDir: File,
    private val pathPolicy: SecurePathPolicy,
    private val downloadService: DownloadService,
    private val ioScope: CoroutineScope,
    private val mainHandler: android.os.Handler,
    private val nativeSupervisor: NativeRuntimeSupervisor,
    private val onRequestStoragePermission: ((MethodChannel.Result) -> Unit)? = null,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val PROBE_TIMEOUT_SECONDS = 30L
        private const val PROBE_TIMEOUT_RC = 124
        private const val MAX_PROBE_OUTPUT_BYTES = 64 * 1024
        private const val TAG = "ExecBinChannel"
        const val CHANNEL_NAME = "com.nanoai/exec_bin"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "makeExecutable" -> handleMakeExecutable(call, result)
            "getFilesDir" -> handleGetFilesDir(result)
            "probeExec" -> handleProbeExec(call, result)
            "workerSpawn" -> handleWorkerSpawn(call, result)
            "workerKill" -> handleWorkerKill(result)
            "installPackages" -> handleInstallPackages(call, result)
            "installGraphical" -> handleInstallGraphical(result)
            "startDesktop" -> handleStartDesktop(call, result)
            "stopDesktop" -> handleStopDesktop(result)
            "launchApp" -> handleLaunchApp(call, result)
            "getDesktopStatus" -> handleGetDesktopStatus(result)
            "requestStoragePermission" -> handleRequestStoragePermission(result)
            "downloadBootstrap" -> handleDownloadBootstrap(call, result)
            "extractBootstrap" -> handleExtractBootstrap(call, result)
            "isBootstrapInstalled" -> handleIsBootstrapInstalled(call, result)
            "downloadFile" -> handleDownloadFile(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleMakeExecutable(call: MethodCall, result: MethodChannel.Result) {
        val path = call.arguments as? String
        if (path == null) {
            result.error("bad_args", "path requerido", null)
            return
        }
        try {
            val f = pathPolicy.requireInsideNanoFiles(File(path), "path")
            val ok = f.setExecutable(true, false)
            Log.w(TAG, "makeExecutable path=${f.name} ownerCanExec=${f.canExecute()} set=$ok")
            result.success(ok)
        } catch (e: IllegalArgumentException) {
            result.error("bad_path", e.message, null)
        }
    }

    private fun handleGetFilesDir(result: MethodChannel.Result) {
        val base = File(filesDir.absolutePath, "nano")
        if (!base.exists()) base.mkdirs()
        result.success(base.absolutePath)
    }

    /**
     * EJECUTA probeExec EN BACKGROUND - NO BLOQUEA MAIN THREAD
     * Esto era el problema principal: ProcessBuilder.start() + waitFor() + readBytes()
     * bloqueaban el MethodChannel handler que corre en el main thread.
     */
    private fun handleProbeExec(call: MethodCall, result: MethodChannel.Result) {
        val spec = call.arguments as? Map<*, *>
        val path = spec?.get("path") as? String
        val args = spec?.get("args") as? List<*> ?: emptyList<Any?>()

        if (path == null) {
            result.error("bad_args", "path requerido", null)
            return
        }

        ioScope.launch {
            try {
                val executable = pathPolicy.requireInsideNanoFiles(File(path), "path")
                val cmd = java.util.ArrayList<String>().apply {
                    add(executable.absolutePath)
                    args.forEach { add(it.toString()) }
                }

                val process = ProcessBuilder(cmd)
                    .redirectErrorStream(false)
                    .start()

                val stdoutDeferred = ioScope.async(Dispatchers.IO) {
                    readLimited(process.inputStream, MAX_PROBE_OUTPUT_BYTES)
                }
                val stderrDeferred = ioScope.async(Dispatchers.IO) {
                    readLimited(process.errorStream, MAX_PROBE_OUTPUT_BYTES)
                }

                val finished = withContext(Dispatchers.IO) {
                    process.waitFor(PROBE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                }

                var rc = if (finished) process.exitValue() else PROBE_TIMEOUT_RC
                if (!finished) {
                    Log.w(TAG, "probeExec timeout ${PROBE_TIMEOUT_SECONDS}s path=$path ? terminando proceso")
                    process.destroy()
                    if (!withContext(Dispatchers.IO) { process.waitFor(2, TimeUnit.SECONDS) }) {
                        process.destroyForcibly()
                        withContext(Dispatchers.IO) { process.waitFor() }
                    }
                    rc = PROBE_TIMEOUT_RC
                }

                val out = stdoutDeferred.await()
                val err = stderrDeferred.await()
                postResult(result) { it.success(mapOf("rc" to rc, "out" to out, "err" to err)) }
            } catch (e: IllegalArgumentException) {
                postResult(result) { it.error("bad_path", e.message, null) }
            } catch (e: Exception) {
                Log.w(TAG, "probeExec FAIL path=$path ex=$e")
                postResult(result) { it.success(mapOf("error" to "${e.javaClass.simpleName}: ${e.message}")) }
            }
        }
    }

    private fun readLimited(input: java.io.InputStream, limitBytes: Int): String {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(8 * 1024)
        var total = 0
        while (true) {
            val remaining = limitBytes - total
            if (remaining <= 0) break
            val read = input.read(buffer, 0, minOf(buffer.size, remaining))
            if (read < 0) break
            output.write(buffer, 0, read)
            total += read
        }
        if (input.read() >= 0) {
            output.write("\n[truncated]".toByteArray(Charsets.UTF_8))
        }
        return output.toString(Charsets.UTF_8)
    }

    private inline fun postResult(
        result: MethodChannel.Result,
        crossinline block: (MethodChannel.Result) -> Unit,
    ) {
        mainHandler.post { block(result) }
    }

    private fun handleWorkerSpawn(call: MethodCall, result: MethodChannel.Result) {
        val spec = call.arguments as? Map<*, *>
        val binaryPath = spec?.get("binaryPath") as? String
        val argv = (spec?.get("argv") as? List<*>)?.map { it.toString() } ?: emptyList()
        val envMap = (spec?.get("envp") as? Map<*, *>) ?: emptyMap<Any?, Any?>()
        val envp = envMap.map { "${it.key}=${it.value}" }
        val ldPreload = spec?.get("ldPreload") as? String

        if (binaryPath == null) {
            result.error("bad_args", "binaryPath requerido", null)
            return
        }

        // nativeSupervisor.spawnWorker() puede esperar hasta CONNECT_TIMEOUT_MS
        // a que el proceso :nanoshell termine de conectar (WorkerClient.
        // awaitConnected). Esto es cada comando de la terminal (shell_executor.
        // dart -> workerSpawn): NUNCA debe correr en el main thread o congela
        // toda la UI mientras el worker arranca en frio.
        ioScope.launch {
            try {
                val taskId = withContext(Dispatchers.IO) {
                    nativeSupervisor.spawnWorker(binaryPath, argv, envp, ldPreload)
                }
                mainHandler.post {
                    if (taskId != null) {
                        result.success(mapOf("taskId" to taskId))
                    } else {
                        result.error("worker_unavailable", "worker no disponible", null)
                    }
                }
            } catch (e: IllegalArgumentException) {
                mainHandler.post { result.error("bad_path", e.message, null) }
            }
        }
    }

    private fun handleWorkerKill(result: MethodChannel.Result) {
        if (nativeSupervisor.killWorker()) result.success(true)
        else result.error("worker_kill_failed", "worker no conectado", null)
    }

    private fun handleInstallPackages(call: MethodCall, result: MethodChannel.Result) {
        val spec = call.arguments as? Map<*, *>
        val pkgs = (spec?.get("packages") as? List<*>)?.map { it.toString() } ?: emptyList()

        if (pkgs.isEmpty()) {
            result.error("bad_args", "packages requerido", null)
            return
        }

        ioScope.launch {
            val ok = nativeSupervisor.installPackages(pkgs) { stage, pct ->
                Log.i(TAG, "install $stage $pct%")
            }
            mainHandler.post {
                if (ok) result.success(mapOf("installed" to true))
                else result.error("install_failed", "fallo instalando ${pkgs.joinToString(", ")}", null)
            }
        }
    }

    private fun handleInstallGraphical(result: MethodChannel.Result) {
        ioScope.launch {
            val ok = nativeSupervisor.installGraphical { stage, pct ->
                Log.i(TAG, "graphical $stage $pct%")
            }
            mainHandler.post {
                if (ok) result.success(mapOf("installed" to true))
                else result.error("install_failed", "fallo instalando escritorio", null)
            }
        }
    }

    private fun handleStartDesktop(call: MethodCall, result: MethodChannel.Result) {
        val vncPassword = call.argument<String>("vncPassword") ?: ""
        // D-1: geometría del viewport lógico (px) — 0 = fallback 1280x720 en
        // XServerBackend.resolveGeometry. El framebuffer nace con el aspect
        // del device para que el visor no deje bandas ni distorsione.
        val width = call.argument<Int>("width") ?: 0
        val height = call.argument<Int>("height") ?: 0
        // AtomicBoolean: se escribe desde el thread "desktop-start" (onReady/
        // onError) y se lee desde main (timeoutRunnable); con un Boolean plano
        // podía haber doble result o timeout fantasma por falta de visibilidad.
        val done = java.util.concurrent.atomic.AtomicBoolean(false)
        // Timeout guard: si el desktop no arranca en 60s, liberar el MethodChannel.
        val timeoutRunnable = Runnable {
            if (done.compareAndSet(false, true)) {
                result.error("desktop_timeout", "Timeout esperando inicio de desktop (60s)", null)
            }
        }
        mainHandler.postDelayed(timeoutRunnable, 60_000)

        nativeSupervisor.startDesktop(
            vncPassword = vncPassword,
            width = width,
            height = height,
            onStatus = { status -> Log.i(TAG, status) },
            onReady = {
                if (done.compareAndSet(false, true)) {
                    mainHandler.removeCallbacks(timeoutRunnable)
                    activity.runOnUiThread { result.success(true) }
                }
            },
            onError = { msg ->
                if (done.compareAndSet(false, true)) {
                    mainHandler.removeCallbacks(timeoutRunnable)
                    activity.runOnUiThread { result.error("desktop_failed", msg, null) }
                }
            },
        )
    }

    /**
     * Permisos de medios compartidos (READ_MEDIA_* / READ_EXTERNAL_STORAGE).
     * La resolución real la hace MainActivity (diálogo del sistema + callback
     * onRequestPermissionsResult); aquí solo se reenvía el Result.
     */
    private fun handleRequestStoragePermission(result: MethodChannel.Result) {
        val callback = onRequestStoragePermission
        if (callback == null) {
            result.error("unavailable", "requestStoragePermission no registrado", null)
            return
        }
        callback(result)
    }

    private fun handleStopDesktop(result: MethodChannel.Result) {
        ioScope.launch {
            nativeSupervisor.stopDesktop()
            mainHandler.post { result.success(true) }
        }
    }

    private fun handleLaunchApp(call: MethodCall, result: MethodChannel.Result) {
        val app = (call.arguments as? Map<*, *>)?.get("app") as? String
        if (app == null) {
            result.error("bad_args", "app requerido", null)
            return
        }
        ioScope.launch {
            val ok = nativeSupervisor.launchApp(app)
            mainHandler.post { result.success(ok) }
        }
    }

    private fun handleGetDesktopStatus(result: MethodChannel.Result) {
        nativeSupervisor.getDesktopStatus { status ->
            activity.runOnUiThread { result.success(status) }
        }
    }

    private fun handleDownloadBootstrap(call: MethodCall, result: MethodChannel.Result) {
        val url = call.arguments as? String
        if (url == null) {
            result.error("bad_args", "url requerido", null)
            return
        }

        ioScope.launch {
            try {
                downloadBootstrap(url) { pct, msg ->
                    Log.i(TAG, "bootstrap $pct%: $msg")
                }
                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                Log.e(TAG, "downloadBootstrap fallo: $url", e)
                mainHandler.post {
                    result.error("download_failed", e.message, e.stackTraceToString())
                }
            }
        }
    }

    private fun handleExtractBootstrap(call: MethodCall, result: MethodChannel.Result) {
        val zipPath = call.argument<String>("zipPath")
        val destDir = call.argument<String>("destDir")

        if (zipPath == null || destDir == null) {
            result.error("bad_args", "zipPath y destDir requeridos", null)
            return
        }

        ioScope.launch {
            try {
                val count = extractBootstrap(zipPath, destDir)
                mainHandler.post {
                    result.success(mapOf("filesExtracted" to count))
                }
            } catch (e: Exception) {
                Log.e(TAG, "extractBootstrap fallo: zip=$zipPath dest=$destDir", e)
                mainHandler.post {
                    result.error("extract_failed", e.message, e.stackTraceToString())
                }
            }
        }
    }

    private fun handleIsBootstrapInstalled(call: MethodCall, result: MethodChannel.Result) {
        val usrDir = call.arguments as? String
        val bash = File("$usrDir/bin/bash")
        result.success(bash.exists() && bash.canExecute())
    }

    private fun handleDownloadFile(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val destPath = call.argument<String>("destPath")

        if (url == null || destPath == null) {
            result.error("bad_args", "url y destPath requeridos", null)
            return
        }

        ioScope.launch {
            try {
                val destFile = pathPolicy.requireInsideNanoFiles(File(destPath), "destPath")
                downloadFile(url, destFile) { pct, _ ->
                    if (pct % 25 == 0) {
                        Log.i(TAG, "downloadFile $pct% -> $destPath")
                    }
                }
                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("download_failed", e.message, null)
                }
            }
        }
    }

    // ========== Helper methods (moved from MainActivity) ==========

    private fun downloadBootstrap(urlStr: String, onProgress: (Int, String) -> Unit) {
        val destFile = pathPolicy.requireInsideNanoFiles(
            File(filesDir, "nano/bootstrap-aarch64.zip"),
            "bootstrap destino",
        )
        downloadService.downloadToFile(
            urlStr,
            destFile,
            readTimeoutMs = 60_000,
            maxBytes = DownloadService.BOOTSTRAP_MAX_DOWNLOAD_BYTES,
            onProgress = onProgress,
        )
    }

    private fun extractBootstrap(zipPath: String, destDir: String): Int {
        val zipFile = pathPolicy.requireInsideNanoFiles(File(zipPath), "zipPath")
        val dest = pathPolicy.requireInsideNanoFiles(File(destDir), "destDir")
        if (!dest.exists()) dest.mkdirs()
        val destPath: java.nio.file.Path = dest.toPath().toAbsolutePath().normalize()
        var count = 0

        ZipFile(zipFile).use { zip ->
            val entries = zip.entries()
            while (entries.hasMoreElements()) {
                val entry = entries.nextElement()
                val targetPath = destPath.resolve(entry.name).normalize()
                if (!targetPath.startsWith(destPath)) continue
                val target = targetPath.toFile()
                if (entry.isDirectory) {
                    target.mkdirs()
                } else {
                    target.parentFile?.mkdirs()
                    zip.getInputStream(entry).use { input ->
                        FileOutputStream(target).use { output ->
                            val buffer = ByteArray(64 * 1024)
                            var len: Int
                            while (input.read(buffer).also { len = it } > 0) {
                                output.write(buffer, 0, len)
                            }
                        }
                    }
                    if (entry.name.startsWith("bin/") ||
                        entry.name.startsWith("usr/bin/") ||
                        entry.name.startsWith("usr/libexec/")) {
                        target.setExecutable(true, false)
                    }
                    count++
                }
            }

            val symEntry = zip.getEntry("SYMLINKS.txt")
            if (symEntry != null) {
                val symText = zip.getInputStream(symEntry).use { it.readBytes().toString(Charsets.UTF_8) }
                var linksCreated = 0
                for (line in symText.lines()) {
                    if (line.isBlank()) continue
                    val idx = line.indexOf('\u2190')
                    if (idx < 0) continue
                    val linkTarget = line.substring(0, idx).trim()
                    val linkName = line.substring(idx + 1).trim()
                    val linkPath = destPath.resolve(linkName).normalize()
                    if (!linkPath.startsWith(destPath)) continue
                    var fixedTarget = linkTarget.replace(
                        "/data/data/com.termux/files/usr",
                        destPath.toString()
                    )
                    val t = java.nio.file.Paths.get(fixedTarget)
                    if (!t.isAbsolute) {
                        val isPrefixRel = fixedTarget.startsWith("./") ||
                            fixedTarget.startsWith("../")
                        val base = if (isPrefixRel) destPath
                                    else linkPath.parent ?: destPath
                        val resolved = base.resolve(fixedTarget).normalize()
                        if (!resolved.startsWith(destPath)) continue
                        fixedTarget = resolved.toString()
                    }
                    linkPath.parent?.toFile()?.mkdirs()
                    try {
                        java.nio.file.Files.deleteIfExists(linkPath)
                        java.nio.file.Files.createSymbolicLink(
                            linkPath, java.nio.file.Paths.get(fixedTarget)
                        )
                        linksCreated++
                    } catch (se: Exception) {
                        Log.w(TAG, "symlink fallo $linkName: ${se.message}")
                    }
                }
                Log.i(TAG, "symlinks creados: $linksCreated")
            }
        }
        val bashPath = File("$destDir/bin/bash")
        if (bashPath.exists()) bashPath.setExecutable(true, false)
        Log.i(TAG, "extract completo: $count archivos")
        return count
    }

    private fun downloadFile(urlStr: String, destFile: File, onProgress: (Int, String) -> Unit) {
        downloadService.downloadToFile(urlStr, destFile, onProgress = onProgress)
    }
}
