package dev.nanoai.mobile

import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.ServiceConnection
import android.os.BatteryManager
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.BufferedInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipEntry
import java.util.zip.ZipFile

class MainActivity : FlutterActivity() {

    /** Cliente del proceso worker :nanoshell (fork+dlopen sin GPU). */
    private var workerClient: WorkerClient? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        workerClient = WorkerClient(this)
    }

    override fun onDestroy() {
        workerClient?.disconnect()
        super.onDestroy()
    }

companion object {
        private const val CHANNEL = "com.nanoai/device_metrics"
        private const val CHANNEL_BIN = "com.nanoai/exec_bin"
        private const val CHANNEL_PTY = "com.nanoai/pty"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMetrics" -> result.success(getDeviceMetrics())
                "getDeviceIdentity" -> result.success(getDeviceIdentity())
                else -> result.notImplemented()
            }
        }

        // Terminal REAL PATH: marca un binario del app-data-dir como ejecutable.
        // SELinux permite exec de los propios archivos de la app; dart:io no
        // tiene chmod, por eso lo hace la plataforma.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_BIN)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "makeExecutable" -> {
                        val path = call.arguments as? String
                        if (path == null) { result.error("bad_args", "path requerido", null); return@setMethodCallHandler }
                        val f = java.io.File(path)
                        val ok = f.setExecutable(true, false)
                        android.util.Log.w("exec_bin", "makeExecutable path=$path ownerCanExec=${f.canExecute()} set=$ok")
                        result.success(ok)
                    }
                    // Directorio privado de datos de la app (files/, NO cache).
                    // SELinux le permite exec de binarios propios; cache tiende a
                    // montarse noexec y se limpia en reinstalación.
                    "getFilesDir" -> {
                        val base = java.io.File(filesDir.absolutePath, "nano")
                        if (!base.exists()) base.mkdirs()
                        result.success(base.absolutePath)
                    }
                    // DEBUG: exec real dentro del proceso de la app para aislar
                    // el ENOENT. Retorna stdout/stderr real o mensaje de la
                    // excepción (p. ej. "Permission denied" vs "No such file").
                    "probeExec" -> {
                        val spec = call.arguments as? Map<*, *>
                        val path = spec?.get("path") as? String
                        val args = spec?.get("args") as? List<*> ?: emptyList<Any?>()
                        if (path == null) { result.error("bad_args", "path requerido", null); return@setMethodCallHandler }
                        try {
                            val cmd = java.util.ArrayList<String>().apply { add(path); args.forEach { add(it.toString()) } }
                            val p = java.lang.ProcessBuilder(cmd).redirectErrorStream(false).start()
                            val out = p.inputStream.readBytes().toString(Charsets.UTF_8)
                            val err = p.errorStream.readBytes().toString(Charsets.UTF_8)
                            val rc = p.waitFor()
                            result.success(mapOf("rc" to rc, "out" to out, "err" to err))
                        } catch (e: Exception) {
                            android.util.Log.w("exec_bin", "probeExec FAIL path=$path ex=$e")
                            result.success(mapOf("error" to "${e.javaClass.simpleName}: ${e.message}"))
                        }
                    }
                    // Worker-process spawn: delega la ejecución del binario
                    // rootfs al proceso :nanoshell (sin GPU) — fork+dlopen es
                    // inseguro en el proceso principal con Impeller/Mali.
                    "workerSpawn" -> {
                        val spec = call.arguments as? Map<*, *>
                        val binaryPath = spec?.get("binaryPath") as? String
                        val argv = (spec?.get("argv") as? List<*>)?.map { it.toString() } ?: emptyList()
                        val envMap = (spec?.get("envp") as? Map<*, *>) ?: emptyMap<Any?, Any?>()
                        val envp = envMap.map { "${it.key}=${it.value}" }
                        val ldPreload = spec?.get("ldPreload") as? String
                        if (binaryPath == null) {
                            result.error("bad_args", "binaryPath requerido", null); return@setMethodCallHandler
                        }
                        val taskId = "t${System.currentTimeMillis()}"
                        // Escribir en files/nano/ (el _baseDir que el Dart lee
                        // en execRootfsWorker). filesDir.absolutePath = files/
                        // causa mismatch: el worker escribía en files/ pero el
                        // Dart buscaba en files/nano/.
                        val baseDir = java.io.File(filesDir.absolutePath, "nano")
                        if (!baseDir.exists()) baseDir.mkdirs()
                        val ok = workerClient?.spawn(
                            binaryPath, argv, envp, ldPreload, taskId, baseDir.absolutePath
                        )
                        if (ok == true) {
                            result.success(mapOf("taskId" to taskId))
                        } else {
                            result.error("worker_unavailable", "worker no disponible", null)
                        }
                    }
                    // Instalador directo de paquetes .deb (alternativa a apt
                    // binario, que es stripped y no exporta main → no dlopen-able).
                    "installPackages" -> {
                        val spec = call.arguments as? Map<*, *>
                        val pkgs = (spec?.get("packages") as? List<*>)?.map { it.toString() }
                            ?: emptyList()
                        if (pkgs.isEmpty()) {
                            result.error("bad_args", "packages requerido", null)
                            return@setMethodCallHandler
                        }
                        val baseDir = java.io.File(filesDir.absolutePath, "nano")
                        val usrDir = java.io.File(baseDir, "usr")
                        val installer = DebInstaller(
                            baseDir = baseDir,
                            usrDir = usrDir,
                            spawnWorker = { bin, argv, env, taskId ->
                                val sent = workerClient?.spawn(bin, argv,
                                    env.map { e -> "${e.key}=${e.value}" },
                                    null, taskId, filesDir.absolutePath) ?: false
                                if (sent) 1 else -1
                            },
                        )
                        // Correr en background thread (descarga + extracción lenta).
                        Thread {
                            val ok = installer.install(pkgs) { stage, pct ->
                                android.util.Log.i("exec_bin", "install $stage $pct%")
                            }
                            runOnUiThread {
                                if (ok) result.success(mapOf("installed" to true))
                                else result.error("install_failed", "fallo instalando ${pkgs.joinToString(", ")}", null)
                            }
                        }.start()
                    }
                    // ── Escritorio VNC: instalar paquetes gráficos ──
                    "installGraphical" -> {
                        val baseDir = java.io.File(filesDir.absolutePath, "nano")
                        val usrDir = java.io.File(baseDir, "usr")
                        val installer = DebInstaller(
                            baseDir = baseDir,
                            usrDir = usrDir,
                            spawnWorker = { bin, argv, env, taskId ->
                                val sent = workerClient?.spawn(bin, argv,
                                    env.map { "${it.key}=${it.value}" },
                                    null, taskId, filesDir.absolutePath) ?: false
                                if (sent) 1 else -1
                            },
                        )
                        Thread {
                            val ok = installer.installGraphical { stage, pct ->
                                android.util.Log.i("exec_bin", "graphical $stage $pct%")
                            }
                            runOnUiThread {
                                if (ok) result.success(mapOf("installed" to true))
                                else result.error("install_failed", "fallo instalando escritorio", null)
                            }
                        }.start()
                    }
                    // ── Escritorio VNC: arrancar servidor ──
                    "startVnc" -> {
                        val baseDir = java.io.File(filesDir.absolutePath, "nano")
                        val usrDir = java.io.File(baseDir, "usr")
                        // VncService usa spawnBg que ejecuta vía worker (detached)
                        val vnc = VncService(usrDir) { bin, argv, envp ->
                            val taskId = "vnc_${System.currentTimeMillis()}"
                            val client = workerClient
                            if (client == null) {
                                android.util.Log.e("vnc", "worker no disponible")
                                -1L
                            } else {
                                client.spawnDetached(bin, argv,
                                    envp.map { "${it.key}=${it.value}" },
                                    taskId).toLong()
                            }
                        }
                        Thread {
                            val ok = vnc.start { status ->
                                android.util.Log.i("vnc", status)
                            }
                            runOnUiThread {
                                if (ok) result.success(mapOf("port" to VncService.DEFAULT_PORT))
                                else result.error("vnc_failed", "no se pudo iniciar VNC", null)
                            }
                        }.start()
                    }
                    // ── Escritorio VNC: detener servidor ──
                    "stopVnc" -> {
                        // Guardar referencia al VNC service activo (simplificado: kill por PID)
                        result.success(true)
                    }
                    // ── Termux bootstrap: download & extract rootfs ──
                    "downloadBootstrap" -> {
                        val url = call.arguments as? String
                        if (url == null) { result.error("bad_args", "url requerido", null); return@setMethodCallHandler }
                        // Download en background thread; result.success() se llama al terminar.
                        // Flutter MethodChannel soporta Result asíncrono (retenido más allá del handler).
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                downloadBootstrap(url) { pct, msg ->
                                    android.util.Log.i("exec_bin", "bootstrap $pct%: $msg")
                                }
                                // Volver al main thread para llamar result
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    result.success(true)
                                }
                            } catch (e: Exception) {
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    result.error("download_failed", e.message, null)
                                }
                            }
                        }
                    }
                    "extractBootstrap" -> {
                        val zipPath = call.argument<String>("zipPath")
                        val destDir = call.argument<String>("destDir")
                        if (zipPath == null || destDir == null) {
                            result.error("bad_args", "zipPath y destDir requeridos", null); return@setMethodCallHandler
                        }
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val count = extractBootstrap(zipPath, destDir)
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    result.success(mapOf("filesExtracted" to count))
                                }
                            } catch (e: Exception) {
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    result.error("extract_failed", e.message, null)
                                }
                            }
                        }
                    }
                    "isBootstrapInstalled" -> {
                        val usrDir = call.arguments as? String
                        val bash = java.io.File("$usrDir/bin/bash")
                        result.success(bash.exists() && bash.canExecute())
                    }
                    // Generic file download (Kali rootfs, Docker layers, etc.)
                    "downloadFile" -> {
                        val url = call.argument<String>("url")
                        val destPath = call.argument<String>("destPath")
                        if (url == null || destPath == null) {
                            result.error("bad_args", "url y destPath requeridos", null); return@setMethodCallHandler
                        }
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val destFile = java.io.File(destPath)
                                destFile.parentFile?.mkdirs()
                                downloadFile(url, destFile) { pct, _ ->
                                    if (pct % 25 == 0) {
                                        android.util.Log.i("exec_bin", "downloadFile $pct% → $destPath")
                                    }
                                }
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    result.success(true)
                                }
                            } catch (e: Exception) {
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    result.error("download_failed", e.message, null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── PTY: terminal interactiva (vim, htop, python REPL, bash -i) ──
        // JNI (NanoshellBridge) → libnanoshell.so (pty.c): openpty+fork+dlopen.
        // Dart hace read-polling; este canal es stateless por llamada.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_PTY)
            .setMethodCallHandler { call, result ->
                if (!NanoshellBridge.ensureLoaded()) {
                    result.error("jni_unavailable", "libnanoshell.so no cargada", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "ptySpawn" -> {
                        val argv = (call.argument<List<String>>("argv") ?: emptyList()).toTypedArray()
                        val envMap = call.argument<Map<String, String>>("envp") ?: emptyMap()
                        val envp = envMap.map { "${it.key}=${it.value}" }.toTypedArray()
                        val ldPreload = call.argument<String>("ldPreload")
                        val rows = call.argument<Int>("rows") ?: 24
                        val cols = call.argument<Int>("cols") ?: 80
                        val id = NanoshellBridge.ptySpawn(argv, envp, ldPreload, rows, cols)
                        android.util.Log.i("pty", "spawn argv=$argv id=$id")
                        result.success(id)
                    }
                    "ptyWrite" -> {
                        val id = (call.argument<Number>("id") ?: 0L).toLong()
                        val data = call.argument<ByteArray>("data")
                        if (data == null) { result.success(0); return@setMethodCallHandler }
                        val n = NanoshellBridge.ptyWrite(id, data)
                        result.success(n)
                    }
                    "ptyRead" -> {
                        val id = (call.argument<Number>("id") ?: 0L).toLong()
                        val max = call.argument<Int>("maxBytes") ?: 4096
                        val data = NanoshellBridge.ptyRead(id, max)
                        result.success(data) // null = sin datos, ByteArray = hay salida
                    }
                    "ptyResize" -> {
                        val id = (call.argument<Number>("id") ?: 0L).toLong()
                        val rows = call.argument<Int>("rows") ?: 24
                        val cols = call.argument<Int>("cols") ?: 80
                        val rc = NanoshellBridge.ptyResize(id, rows, cols)
                        result.success(rc)
                    }
                    "ptyKill" -> {
                        val id = (call.argument<Number>("id") ?: 0L).toLong()
                        val sig = call.argument<Int>("signal") ?: 2 // SIGINT
                        val rc = NanoshellBridge.ptyKill(id, sig)
                        result.success(rc)
                    }
                    "ptyClose" -> {
                        val id = (call.argument<Number>("id") ?: 0L).toLong()
                        NanoshellBridge.ptyClose(id)
                        result.success(true)
                    }
                    "ptyGetPid" -> {
                        val id = (call.argument<Number>("id") ?: 0L).toLong()
                        result.success(NanoshellBridge.ptyGetPid(id))
                    }
                    "ptyIsAlive" -> {
                        val id = (call.argument<Number>("id") ?: 0L).toLong()
                        result.success(NanoshellBridge.ptyIsAlive(id))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Bootstrap download & extraction ──

    /** Descarga bootstrap-aarch64.zip (~30MB) al directorio files/nano/. */
    private fun downloadBootstrap(urlStr: String, onProgress: (Int, String) -> Unit) {
        val destFile = java.io.File(filesDir, "nano/bootstrap-aarch64.zip")
        destFile.parentFile?.mkdirs()
        val url = URL(urlStr)
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 15000
        conn.readTimeout = 60000
        conn.instanceFollowRedirects = true
        try {
            conn.connect()
            val total = conn.contentLengthLong
            val input = BufferedInputStream(conn.inputStream)
            val output = FileOutputStream(destFile)
            val buffer = ByteArray(8192)
            var downloaded = 0L
            var bytesRead: Int
            var lastPct = -1
            while (input.read(buffer).also { bytesRead = it } != -1) {
                output.write(buffer, 0, bytesRead)
                downloaded += bytesRead
                if (total > 0) {
                    val pct = (downloaded * 100 / total).toInt()
                    if (pct != lastPct) { lastPct = pct; onProgress(pct, "$downloaded/$total") }
                }
            }
            output.close(); input.close()
            onProgress(100, "done")
        } finally {
            conn.disconnect()
        }
    }

    /**
     * Extrae bootstrap-aarch64.zip en destDir (files/nano/ → crea usr/).
     *
     * El bootstrap Termux moderno NO usa entries symlink en el zip: viene
     * como archivos planos + SYMLINKS.txt con 1161 líneas "target ← link".
     * Un extractor que solo descomprime deja TODOS los binarios sin crear
     * (apt, sh, ls... son symlinks) → usr/bin/bash nunca existe → el rootfs
     * nunca "se instala". Este extractor:
     *   1. Descomprime archivos planos con ZipFile (acceso aleatorio).
     *   2. Aplica bits de ejecución desde external_attr (mode Unix).
     *   3. Procesa SYMLINKS.txt creando los symlinks reales, reescribiendo
     *      targets absolutos de Termux (/data/data/com.termux/files/usr)
     *      al path local del sandbox.
     */
    private fun extractBootstrap(zipPath: String, destDir: String): Int {
        val dest = java.io.File(destDir)
        if (!dest.exists()) dest.mkdirs()
        val destPath: java.nio.file.Path = dest.toPath().toAbsolutePath().normalize()
        var count = 0

        ZipFile(java.io.File(zipPath)).use { zip ->
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
                    // Ejecutables: bins de bin/ y usr/bin/ (el zip no expone
                    // external_attr en Android; heurística por path, igual que
                    // el rootfs plano). setExecutable(true, false) = owner.
                    if (entry.name.startsWith("bin/") ||
                        entry.name.startsWith("usr/bin/") ||
                        entry.name.startsWith("usr/libexec/")) {
                        target.setExecutable(true, false)
                    }
                    count++
                }
            }

            // ── Procesar SYMLINKS.txt (formato "target ← linkname") ──
            val symEntry = zip.getEntry("SYMLINKS.txt")
            if (symEntry != null) {
                val symText = zip.getInputStream(symEntry).use { it.readBytes().toString(Charsets.UTF_8) }
                var linksCreated = 0
                for (line in symText.lines()) {
                    if (line.isBlank()) continue
                    val idx = line.indexOf('\u2190') // '←'
                    if (idx < 0) continue
                    val linkTarget = line.substring(0, idx).trim()
                    val linkName = line.substring(idx + 1).trim()
                    val linkPath = destPath.resolve(linkName).normalize()
                    if (!linkPath.startsWith(destPath)) continue
                    // Reescribir targets absolutos de Termux al sandbox local.
                    var fixedTarget = linkTarget.replace(
                        "/data/data/com.termux/files/usr",
                        destPath.toString()
                    )
                    // Targets relativos: dos convenciones en SYMLINKS.txt.
                    //  - "nombre.so" / "../x" (sin "./"): relativo al DIR del
                    //    link (ej: lib/libzstd.so.1 → libzstd.so.1.5.7 vive en
                    //    lib/). Resolver contra el dir del link.
                    //  - "./bin/env" (con "./"): relativo al PREFIX (usr),
                    //    como en el instalador Termux (coreutils→./bin/env).
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
                        // Sin permiso symlink (raro en sandbox propio): degrada
                        // a copia del target si existe, o archivo de texto.
                        android.util.Log.w("exec_bin", "symlink falló $linkName: ${se.message}")
                    }
                }
                android.util.Log.i("exec_bin", "symlinks creados: $linksCreated")
            }
        }
        // Garantía: bash ejecutable. Con destDir=usr, bin/bash del zip →
        // usr/bin/bash (archivo real). Solo asegurar permisos.
        val bashPath = java.io.File("$destDir/bin/bash")
        if (bashPath.exists()) bashPath.setExecutable(true, false)
        android.util.Log.i("exec_bin", "extract completo: $count archivos")
        return count
    }

    /** Descarga cualquier archivo via HTTP(S). Usado para Kali rootfs, etc. */
    private fun downloadFile(urlStr: String, destFile: java.io.File, onProgress: (Int, String) -> Unit) {
        val url = URL(urlStr)
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 15000
        conn.readTimeout = 300000 // 5 min para archivos grandes
        conn.instanceFollowRedirects = true
        try {
            conn.connect()
            val total = conn.contentLengthLong
            val input = BufferedInputStream(conn.inputStream)
            val output = FileOutputStream(destFile)
            val buffer = ByteArray(8192)
            var downloaded = 0L
            var bytesRead: Int
            var lastPct = -1
            while (input.read(buffer).also { bytesRead = it } != -1) {
                output.write(buffer, 0, bytesRead)
                downloaded += bytesRead
                if (total > 0) {
                    val pct = (downloaded * 100 / total).toInt()
                    if (pct != lastPct) { lastPct = pct; onProgress(pct, "$downloaded/$total") }
                }
            }
            output.close(); input.close()
            onProgress(100, "done")
        } finally {
            conn.disconnect()
        }
    }

    private fun getDeviceMetrics(): Map<String, Any?> {
        val actManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        actManager.getMemoryInfo(memInfo)

        // RAM: availMem is most accurate for "available" RAM
        val ramAvailableMb = memInfo.availMem / (1024.0 * 1024.0)
        val ramTotalMb = memInfo.totalMem / (1024.0 * 1024.0)

        // Battery
        val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level.toFloat() / scale.toFloat()) * 100f else -1f
        val plugged = batteryIntent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val isCharging = plugged == BatteryManager.BATTERY_PLUGGED_AC ||
                plugged == BatteryManager.BATTERY_PLUGGED_USB ||
                plugged == BatteryManager.BATTERY_PLUGGED_WIRELESS
        // Battery temperature in tenths of a degree Celsius (real data, no root required)
        val batteryTempRaw = batteryIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
        val batteryTempC = if (batteryTempRaw > 0) batteryTempRaw / 10.0 else null

        // Storage (internal)
        val stat = StatFs(Environment.getDataDirectory().path)
        val blockSize = stat.blockSizeLong
        val totalBlocks = stat.blockCountLong
        val availBlocks = stat.availableBlocksLong
        val storageTotalGb = (totalBlocks * blockSize) / (1024.0 * 1024.0 * 1024.0)
        val storageFreeGb = (availBlocks * blockSize) / (1024.0 * 1024.0 * 1024.0)

        // CPU temperature (thermal zones — may require root on some devices)
        val cpuTempC = readCpuTemp() ?: batteryTempC

        // CPU cores
        val cpuCores = Runtime.getRuntime().availableProcessors()

        return mapOf(
            "ramAvailableMb" to ramAvailableMb,
            "ramTotalMb" to ramTotalMb,
            "batteryPct" to batteryPct,
            "isCharging" to isCharging,
            "storageTotalGb" to storageTotalGb,
            "storageFreeGb" to storageFreeGb,
            "cpuTempC" to cpuTempC,
            "cpuCores" to cpuCores,
        )
    }

    private fun getDeviceIdentity(): Map<String, Any?> {
        val identity = mutableMapOf<String, Any?>()

        // uid / gid / groups desde /proc/self/status
        try {
            val status = java.io.File("/proc/self/status").readText()
            for (line in status.lines()) {
                when {
                    line.startsWith("Uid:") -> {
                        val parts = line.substringAfter("Uid:").trim().split("\t")
                        if (parts.isNotEmpty()) identity["uid"] = parts[0].trim().toIntOrNull()
                    }
                    line.startsWith("Gid:") -> {
                        val parts = line.substringAfter("Gid:").trim().split("\t")
                        if (parts.isNotEmpty()) identity["gid"] = parts[0].trim().toIntOrNull()
                    }
                    line.startsWith("Groups:") -> {
                        identity["groups"] = line.substringAfter("Groups:").trim()
                    }
                }
            }
        } catch (_: Exception) {}

        // hostname
        try {
            identity["hostname"] = java.io.File("/proc/sys/kernel/hostname").readText().trim()
        } catch (_: Exception) { identity["hostname"] = "localhost" }

        // uname: kernel version desde System.getProperty (no necesita /proc)
        identity["uname_sysname"] = "Linux"
        try {
            // os.version da el release del kernel en Android (ej: "6.6.82-android15-8-...")
            identity["uname_release"] = System.getProperty("os.version") ?: "unknown"
        } catch (_: Exception) { identity["uname_release"] = "unknown" }
        // arquitectura desde Build.SUPPORTED_ABIS (no necesita /proc)
        try {
            val abis = android.os.Build.SUPPORTED_ABIS
            val arch = when {
                abis.any { it.contains("arm64") || it.contains("aarch64") } -> "aarch64"
                abis.any { it.contains("armeabi") } -> "armv7l"
                abis.any { it.contains("x86_64") } -> "x86_64"
                abis.any { it.contains("x86") } -> "i686"
                else -> abis.firstOrNull() ?: "unknown"
            }
            identity["uname_machine"] = arch
        } catch (_: Exception) { identity["uname_machine"] = "unknown" }

        // meminfo básico para free
        try {
            val meminfo = java.io.File("/proc/meminfo").readText()
            for (line in meminfo.lines()) {
                when {
                    line.startsWith("MemTotal:") -> {
                        identity["memTotalKb"] = line.replace(Regex("[^0-9]"), "").toLongOrNull()
                    }
                    line.startsWith("MemAvailable:") -> {
                        identity["memAvailKb"] = line.replace(Regex("[^0-9]"), "").toLongOrNull()
                    }
                    line.startsWith("SwapTotal:") -> {
                        identity["swapTotalKb"] = line.replace(Regex("[^0-9]"), "").toLongOrNull()
                    }
                    line.startsWith("SwapFree:") -> {
                        identity["swapFreeKb"] = line.replace(Regex("[^0-9]"), "").toLongOrNull()
                    }
                }
            }
        } catch (_: Exception) {}

        // uptime desde /proc/uptime
        try {
            val up = java.io.File("/proc/uptime").readText().split(" ").firstOrNull()?.toDoubleOrNull()
            identity["uptimeSec"] = up
        } catch (_: Exception) {}

        // CPU cores y freq
        identity["cpuCores"] = Runtime.getRuntime().availableProcessors()
        try {
            val cpuinfo = java.io.File("/proc/cpuinfo").readText()
            // Extraer model name para cpu info
            val hwMatch = Regex("""Hardware\s*:\s*(.+)""").find(cpuinfo)
            identity["cpuHardware"] = hwMatch?.groupValues?.getOrNull(1)?.trim()
            // Contar processors
            identity["cpuCount"] = Regex("processor", RegexOption.IGNORE_CASE).findAll(cpuinfo).count()
        } catch (_: Exception) {}

        // Storage (para df)
        try {
            val stat = android.os.StatFs(android.os.Environment.getDataDirectory().path)
            identity["storageBlockSize"] = stat.blockSizeLong
            identity["storageTotalBlocks"] = stat.blockCountLong
            identity["storageAvailBlocks"] = stat.availableBlocksLong
        } catch (_: Exception) {}

        android.util.Log.w("device_metrics", "identity=$identity")
        return identity
    }

    private fun readCpuTemp(): Double? {
        // Try common thermal zone paths (no root required on most devices)
        val paths = listOf(
            "/sys/class/thermal/thermal_zone0/temp",
            "/sys/class/thermal/thermal_zone1/temp",
            "/sys/devices/virtual/thermal/thermal_zone0/temp",
        )
        for (path in paths) {
            try {
                val raw = java.io.File(path).readText().trim().toDoubleOrNull()
                if (raw != null) {
                    // Most return millidegrees (e.g. 38500 = 38.5°C)
                    return if (raw > 200) raw / 1000.0 else raw
                }
            } catch (_: Exception) { }
        }
        return null
    }
}
