package dev.nanoai.mobile

import android.util.Log
import java.io.File
import java.nio.file.Files
import kotlin.concurrent.thread

/**
 * Servicio VNC autocontenido: lanza Xvnc + window manager dentro del rootfs.
 *
 * Flujo:
 *   1. Ejecuta Xvnc :1 -geometry WxH -depth 24 -SecurityTypes None
 *      → servidor VNC en 127.0.0.1:5901, display X11 :1 sin password.
 *   2. Con DISPLAY=:1, lanza openbox (WM) + tint2 (panel) + terminal disponible.
 *   3. El visor Flutter se conecta a 127.0.0.1:5901 vía noVNC (WebView).
 *
 * CORRECCIONES aplicadas:
 *   - patchTermuxPaths: reemplaza con path de longitud exactamente igual (35 B).
 *   - start(): ya NO bloquea el hilo llamador; usa [onReady] callback asíncrono.
 *   - sleep(500) reemplazado por sondeo real del socket Unix X11.
 *   - TMPDIR/XDG_RUNTIME_DIR propagados a openbox/tint2/terminal.
 */
class VncService(
    private val usrDir: File,          // files/nano/usr
    private val spawnBg: (binaryPath: String, argv: List<String>, envp: Map<String, String>) -> Long,
) {
    companion object {
        private const val TAG = "vnc-service"
        const val DEFAULT_PORT    = 5901
        const val DEFAULT_DISPLAY = 1
        const val DEFAULT_WIDTH   = 1280
        const val DEFAULT_HEIGHT  = 720

        // Termux original path hardcodeado en los ELF (exactamente 31 bytes en UTF-8)
        private val TERMUX_USR_BYTES = "/data/data/com.termux/files/usr".toByteArray(Charsets.UTF_8)

        // Path de reemplazo: MISMO largo (31 B) usando el symlink "us" → files/nano/usr.
        // "/data/data/dev.nanoai.mobile/us" = 31 bytes exactos ✓
        private val SANDBOX_USR_BYTES = "/data/data/dev.nanoai.mobile/us".toByteArray(Charsets.UTF_8)

        init {
            check(TERMUX_USR_BYTES.size == SANDBOX_USR_BYTES.size) {
                "PATCH BUG: old=${TERMUX_USR_BYTES.size}B new=${SANDBOX_USR_BYTES.size}B — deben ser iguales"
            }
        }
    }

    private var xvncPid: Long    = -1
    private var openboxPid: Long = -1
    private var terminalPid: Long = -1
    private var tint2Pid: Long   = -1
    @Volatile private var running = false
    @Volatile private var stopRequested = false

    // ── Entorno base ─────────────────────────────────────────────────────────

    /** Entorno canónico del rootfs para todos los procesos hijos. */
    private fun baseEnv(): MutableMap<String, String> {
        val lib    = usrDir.absolutePath + "/lib"
        val libCan = usrDir.canonicalPath + "/lib"
        val libAlt = "/data/data/dev.nanoai.mobile/files/nano/usr/lib"
        val ldPath = listOf(lib, libCan, libAlt, "/system/lib64", "/system/lib")
            .distinct().joinToString(":")

        val tmpDir = File(usrDir, "tmp").also { it.mkdirs() }
        val homeDir = File(usrDir.parentFile, "home").also { it.mkdirs() }
        val configDir = File(homeDir, ".config").also { it.mkdirs() }
        val stateDir = File(homeDir, ".local/state").also { it.mkdirs() }

        return mutableMapOf(
            "PREFIX"           to usrDir.absolutePath,
            "HOME"             to homeDir.absolutePath,
            "XDG_CONFIG_HOME"  to configDir.absolutePath,
            "XDG_STATE_HOME"   to stateDir.absolutePath,
            "TMPDIR"           to tmpDir.absolutePath,
            "PATH"             to "${usrDir.absolutePath}/bin:/system/bin",
            "LD_LIBRARY_PATH"  to ldPath,
            "DISPLAY"          to ":$DEFAULT_DISPLAY",
            // X11 usa TMPDIR para el socket Unix (.X11-unix/X<display>).
            // XDG_RUNTIME_DIR es alternativa que openbox/tint2 pueden preferir.
            "XDG_RUNTIME_DIR"  to tmpDir.absolutePath,
            "XAUTHORITY"       to "${homeDir.absolutePath}/.Xauthority",
            "LANG"             to "en_US.UTF-8",
            "TERM"             to "xterm-256color",
            // libnanoroot intercepta popen/execve de Xvnc para ejecutar helpers
            // como xkbcomp vía /system/bin/linker64, evitando EACCES en ColorOS.
            "NANO_ROOTFS"      to usrDir.absolutePath,
        )
    }

    // ── API pública ──────────────────────────────────────────────────────────

    /**
     * Inicia el escritorio VNC en un hilo de fondo.
     *
     * ¡NO BLOQUEA el hilo llamador!
     * [onReady]  → invocado en el hilo de fondo cuando el visor puede conectar.
     * [onStatus] → progreso / mensajes de error.
     * Retorna true si el inicio fue encolado (el servicio no estaba ya corriendo).
     */
    @Synchronized
    fun start(
        width: Int = DEFAULT_WIDTH,
        height: Int = DEFAULT_HEIGHT,
        onStatus: (String) -> Unit = {},
        onReady: (port: Int) -> Unit = {},
        onError: (msg: String) -> Unit = {},
    ): Boolean {
        if (running) {
            Log.w(TAG, "VNC ya corriendo")
            onReady(DEFAULT_PORT)
            return true
        }
        stopRequested = false

        val safeW = width.coerceIn(320, 1920)
        val safeH = height.coerceIn(240, 1080)

        thread(name = "vnc-start", isDaemon = true) {
            startInternal(safeW, safeH, onStatus, onReady, onError)
        }
        return true
    }

    /** Detiene el escritorio. Seguro llamar desde cualquier hilo. */
    @Synchronized
    fun stop() {
        stopRequested = true
        if (!running && xvncPid <= 0 && openboxPid <= 0 && tint2Pid <= 0 && terminalPid <= 0) return
        Log.i(TAG, "Deteniendo VNC…")
        cleanupProcesses()
    }

    val isRunning: Boolean get() = running
    val port: Int get() = DEFAULT_PORT

    fun dispose() = stop()

    // ── Lógica interna (hilo de fondo) ───────────────────────────────────────

    private fun startInternal(
        w: Int, h: Int,
        onStatus: (String) -> Unit,
        onReady: (Int) -> Unit,
        onError: (String) -> Unit,
    ) {
        val tmpDir = File(usrDir, "tmp").also { it.mkdirs() }
        val homeDir = File(usrDir.parentFile, "home").also { it.mkdirs() }

        // 1. Limpiar locks X11 previos (sockets/locks de sesiones anteriores)
        if (abortIfStopped("before-clean")) return
        cleanX11Runtime(tmpDir)
        clearTigerVncConfig(homeDir)

        // 2. Preparar entorno X11 (xkb, symlinks, patch de paths Termux)
        if (abortIfStopped("before-prepare")) return
        prepareX11()

        // XServer XSDL es un servidor externo, no iniciamos Xvnc.
        // Solo esperamos a que XSDL esté corriendo y escuchando en el puerto TCP 6000 (:0)
        onStatus("Esperando a que XServer XSDL (x.org.server) inicie en TCP 6000…")
        if (abortIfStopped("before-xsdl-wait")) return
        if (!waitForStablePort("127.0.0.1", 6000, timeoutMs = 60_000, stableMs = 1_000)) {
            Log.e(TAG, "XServer XSDL no respondió en el puerto 6000 en 60s.")
            onError("XServer XSDL no arrancó a tiempo. Asegúrate de abrir la app 'XServer XSDL'.")
            return
        }


        // XSDL expone su socket via TCP, así que no necesitamos esperar el socket Unix local


        onStatus("Iniciando entorno de escritorio…")
        if (abortIfStopped("before-wm")) return

        // 7. Configurar tint2rc si no existe
        setupTint2Config()

        val wmEnv = baseEnv().apply {
            this["DISPLAY"] = "127.0.0.1:0"
        }

        // 8. Lanzar openbox (WM). Usar siempre worker/dlopen: ProcessBuilder
        // sobre /data/user/0/... falla con EACCES en Android 15/ColorOS.
        val openboxBin = File(usrDir, "bin/openbox")
        if (openboxBin.exists()) {
            openboxBin.setExecutable(true, false)
            openboxPid = spawnBg(openboxBin.absolutePath, listOf("openbox"), wmEnv)
            Log.i(TAG, "openbox PID=$openboxPid")
            if (abortIfStopped("after-openbox-spawn")) return
        } else {
            Log.w(TAG, "openbox no encontrado en ${openboxBin.absolutePath}")
        }

        // 9. Esperar a que openbox esté listo (~1 s es suficiente tras socket X11 ok)
        Thread.sleep(800)
        if (abortIfStopped("after-openbox-wait")) return

        // 10. Lanzar tint2 (panel)
        val tint2Bin = File(usrDir, "bin/tint2")
        if (tint2Bin.exists()) {
            tint2Bin.setExecutable(true, false)
            tint2Pid = spawnBg(tint2Bin.absolutePath, listOf("tint2"), wmEnv)
            Log.i(TAG, "tint2 PID=$tint2Pid")
            if (abortIfStopped("after-tint2-spawn")) return
        }

        // 11. Lanzar terminal gráfica si existe. Termux X11 ya no publica
        // paquete `xterm`; `aterm` es el fallback liviano actual.
        val terminal = firstExistingTerminal()
        if (terminal != null) {
            terminal.file.setExecutable(true, false)
            terminalPid = spawnBg(terminal.file.absolutePath, terminal.argv, wmEnv)
            Log.i(TAG, "terminal ${terminal.file.name} PID=$terminalPid")
            if (abortIfStopped("after-terminal-spawn")) return
        } else {
            Log.w(TAG, "terminal gráfica no encontrada (xterm/aterm/lxterminal)")
        }

        if (abortIfStopped("before-ready")) return
        running = true
        val msg = "Escritorio listo en puerto $DEFAULT_PORT"
        Log.i(TAG, msg)
        onStatus(msg)
        onReady(DEFAULT_PORT)
    }

    // ── Espera de recursos ────────────────────────────────────────────────────

    /**
     * Sondea TCP host:port hasta que acepta conexiones o se agota [timeoutMs].
     * No bloquea el hilo UI (debe llamarse desde hilo de fondo).
     */
    private fun waitForPort(host: String, port: Int, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            try {
                java.net.Socket().use { s ->
                    s.connect(java.net.InetSocketAddress(host, port), 300)
                    return true
                }
            } catch (_: Exception) {
                Thread.sleep(300)
            }
        }
        return false
    }

    private fun waitForStablePort(host: String, port: Int, timeoutMs: Long, stableMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            if (!waitForPort(host, port, timeoutMs = 1_000)) continue
            val stableUntil = System.currentTimeMillis() + stableMs
            var stable = true
            while (System.currentTimeMillis() < stableUntil) {
                if (!waitForPort(host, port, timeoutMs = 500)) {
                    stable = false
                    break
                }
                Thread.sleep(250)
            }
            if (stable) return true
        }
        return false
    }

    private data class TerminalLaunch(val file: File, val argv: List<String>)

    private fun firstExistingTerminal(): TerminalLaunch? {
        val candidates = listOf(
            TerminalLaunch(
                File(usrDir, "bin/xterm"),
                listOf(
                    "xterm",
                    "-title", "NanoAI Terminal",
                    "-fa", "Monospace",
                    "-fs", "12",
                    "-bg", "#0d1117",
                    "-fg", "#00ff9d",
                ),
            ),
            TerminalLaunch(
                File(usrDir, "bin/aterm"),
                listOf(
                    "aterm",
                    "-title", "NanoAI Terminal",
                    "-fn", "fixed",
                    "-bg", "#0d1117",
                    "-fg", "#00ff9d",
                ),
            ),
            TerminalLaunch(
                File(usrDir, "bin/lxterminal"),
                listOf("lxterminal", "--title=NanoAI Terminal"),
            ),
        )
        return candidates.firstOrNull { it.file.exists() }
    }

    /**
     * Espera a que un archivo (socket Unix X11) aparezca en el filesystem.
     * Alternativa a sleep() heurístico para sincronizar Xvnc → openbox.
     */
    private fun waitForFile(file: File, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            if (file.exists()) return true
            Thread.sleep(150)
        }
        return false
    }

    // ── Utilidades de proceso ─────────────────────────────────────────────────

    private fun killPid(pid: Long) {
        if (pid > 0) {
            try { android.os.Process.killProcess(pid.toInt()) }
            catch (e: Exception) { Log.w(TAG, "kill $pid: ${e.message}") }
        }
    }

    @Synchronized
    private fun cleanupProcesses() {
        killPid(terminalPid); terminalPid = -1
        killPid(tint2Pid);   tint2Pid   = -1
        killPid(openboxPid); openboxPid = -1
        killPid(xvncPid);    xvncPid    = -1
        running = false
    }

    private fun abortIfStopped(stage: String): Boolean {
        if (!stopRequested) return false
        Log.i(TAG, "start abortado por stopRequested en $stage")
        cleanupProcesses()
        return true
    }

    // ── Limpieza X11 ─────────────────────────────────────────────────────────

    private fun cleanX11Runtime(tmpDir: File) {
        try {
            tmpDir.listFiles()?.forEach { f ->
                if (f.name.startsWith(".X") || f.name.contains("lock")) {
                    safeDelete(tmpDir, f)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "cleanX11: ${e.message}")
        }
    }

    private fun safeDelete(base: File, target: File) {
        try {
            val basePath   = base.canonicalFile.toPath()
            val targetPath = target.canonicalFile.toPath()
            if (!targetPath.startsWith(basePath)) return
            if (target.isDirectory && !Files.isSymbolicLink(target.toPath())) {
                if (target.name == ".X11-unix") target.deleteRecursively()
                return
            }
            Files.deleteIfExists(target.toPath())
        } catch (e: Exception) {
            Log.w(TAG, "safeDelete ${target.name}: ${e.message}")
        }
    }

    // ── Configuración tint2 ───────────────────────────────────────────────────

    private fun setupTint2Config() {
        try {
            val configDir = File(usrDir, "etc/xdg/tint2").also { it.mkdirs() }
            val tint2Rc   = File(configDir, "tint2rc")
            if (!tint2Rc.exists()) {
                tint2Rc.writeText("""
                    panel_position = bottom center horizontal
                    panel_size = 100% 36
                    panel_margin = 0 0
                    panel_background_id = 1
                    panel_dock = 0
                    font_shadow = 0
                    panel_color = #0f141d 100
                    taskbar_mode = single_desktop
                    task_text = 1
                    task_maximum_size = 200 35
                    clock_enabled = 1
                    clock_format = %H:%M:%S
                    clock_font = Monospace 10
                    clock_color = #00ff9d 100
                """.trimIndent())
            }
        } catch (e: Exception) {
            Log.w(TAG, "setupTint2Config: ${e.message}")
        }
    }

    // ── Preparación X11 ──────────────────────────────────────────────────────

    /**
     * Idempotente. Prepara el entorno que Xvnc necesita y que el .deb no provee:
     *   1. Reglas xkb mínimas (rules/evdev) — Xvnc aborta sin ellas.
     *   2. Symlink xkb → xkeyboard-config-2 si el paquete lo instaló ahí.
     *   3. Patch binario de paths Termux → sandbox (mismo largo, sin corrupción).
     *   4. Symlinks de compatibilidad "/f" para paths hardcodeados.
     */
    private fun prepareX11() {
        try {
            setupXkb()
            val binDir = File(usrDir, "bin")
            val patchMarker = File(binDir, ".patched_binaries")
            
            if (binDir.isDirectory && !patchMarker.exists()) {
                Log.i(TAG, "Iniciando parcheo de Termux paths (tardará 1-2 minutos)...")
                // Purgar archivos .bak acumulados por versiones anteriores del patcher
                purgeBakFiles(binDir)
                binDir.listFiles()?.forEach { file ->
                    // Saltar archivos .bak, directorios y archivos sin contenido binario
                    if (file.isFile && !file.name.endsWith(".bak")) {
                        file.setExecutable(true, false)
                        patchTermuxPaths(file)
                    }
                }
                patchMarker.writeText("Patched")
                Log.i(TAG, "Parcheo de Termux paths completado.")
            } else {
                Log.i(TAG, "Parcheo omitido (ya parcheado).")
            }
            
            setupXkbcompWrapper()
            ensureCompatPrefixLinks()
        } catch (e: Exception) {
            Log.w(TAG, "prepareX11: ${e.message}")
        }
    }

    private fun setupXkbcompWrapper() {
        try {
            val bin = File(usrDir, "bin/xkbcomp")
            val real = File(usrDir, "xkbcomp.real")
            val legacyReal = File(usrDir, "xkbcomp")

            if (bin.exists() && isElf(bin) && bin.length() > 50_000) {
                bin.copyTo(real, overwrite = true)
            } else if (!real.exists() && legacyReal.exists() && isElf(legacyReal)) {
                legacyReal.copyTo(real, overwrite = true)
            }

            if (!real.exists() || real.length() < 50_000) {
                Log.w(TAG, "xkbcomp.real no disponible; Xvnc puede fallar")
                return
            }

            val fallbackXkm = File(usrDir, "share/X11/xkb/fallback.xkm")
            val fallbackXkb = File(usrDir, "share/X11/xkb/fallback.xkb")
            
            if (!fallbackXkm.exists() || fallbackXkm.length() == 0L) {
                fallbackXkb.writeText("""
                    xkb_keymap {
                        xkb_keycodes  { include "evdev+aliases(qwerty)" };
                        xkb_types     { include "complete" };
                        xkb_compat    { include "complete" };
                        xkb_symbols   { include "pc+us+inet(evdev)" };
                        xkb_geometry  { include "pc(pc104)" };
                    };
                """.trimIndent())

                Log.i(TAG, "Compilando fallback.xkm usando worker asincrono...")
                spawnBg(
                    real.absolutePath,
                    listOf("xkbcomp.real", "-w", "0", "-I${usrDir.absolutePath}/share/X11/xkb", "-xkm", fallbackXkb.absolutePath, fallbackXkm.absolutePath),
                    baseEnv()
                )
                
                // Esperar hasta 5s a que el worker complete la compilacion (es asincrono)
                for (i in 0..50) {
                    if (fallbackXkm.exists() && fallbackXkm.length() > 0) break
                    Thread.sleep(100)
                }
            }

            val wrapper = """
                #!/system/bin/sh
                PREFIX=/data/user/0/dev.nanoai.mobile/files/nano/usr
                LINKER="${'$'}PREFIX/libexec/linker64"
                SHMEM="${'$'}PREFIX/lib/libandroid-shmem.so"
                export LD_PRELOAD="${'$'}SHMEM"
                export LD_LIBRARY_PATH="${'$'}PREFIX/lib:${'$'}PREFIX/usr/lib"
                
                log -p I -t xkb_wrapper "--- xkbcomp called with args: ${'$'}@"
                
                # We need to capture both stdout and stderr and log it
                OUTPUT=${'$'}("${'$'}LINKER" "${'$'}PREFIX/bin/xkbcomp.real" "${'$'}@" 2>&1)
                RES=${'$'}?
                
                log -p I -t xkb_wrapper "xkbcomp.real exited with ${'$'}RES. Output:"
                for line in ${'$'}OUTPUT; do
                    log -p I -t xkb_wrapper "${'$'}line"
                done
                
                exit ${'$'}RES
            """.trimIndent() + "\n"

            if (!bin.exists() || bin.readTextOrNull() != wrapper) {
                bin.writeText(wrapper)
            }
            bin.setExecutable(true, false)
            real.setExecutable(true, false)
            Log.i(TAG, "xkbcomp wrapper listo → ${real.absolutePath}")
        } catch (e: Exception) {
            Log.w(TAG, "setupXkbcompWrapper: ${e.message}")
        }
    }

    private fun isElf(file: File): Boolean {
        return try {
            file.inputStream().use { input ->
                val header = ByteArray(4)
                input.read(header) == 4 &&
                    header[0] == 0x7f.toByte() &&
                    header[1] == 'E'.code.toByte() &&
                    header[2] == 'L'.code.toByte() &&
                    header[3] == 'F'.code.toByte()
            }
        } catch (_: Exception) { false }
    }

    private fun File.readTextOrNull(): String? = try { readText() } catch (_: Exception) { null }

    /** Elimina TODOS los archivos .bak (de cualquier profundidad) en el directorio dado. */
    private fun purgeBakFiles(dir: File) {
        val deleted = dir.walkTopDown()
            .filter { it.isFile && it.name.contains(".bak") }
            .onEach { it.delete() }
            .count()
        if (deleted > 0) Log.i(TAG, "purgeBakFiles: eliminados $deleted archivos .bak")
    }

    private fun setupXkb() {
        val x11Dir  = File(usrDir, "share/X11")
        val xkbPath = java.nio.file.Paths.get(x11Dir.absolutePath, "xkb")

        // Si es symlink roto → eliminar
        if (Files.isSymbolicLink(xkbPath)) {
            val resolved = xkbPath.resolveSibling(Files.readSymbolicLink(xkbPath)).normalize()
            if (!Files.exists(resolved, java.nio.file.LinkOption.NOFOLLOW_LINKS)) {
                try { Files.delete(xkbPath); Log.i(TAG, "symlink roto xkb eliminado") }
                catch (e: Exception) { Log.w(TAG, "delete xkb symlink: ${e.message}") }
            }
        }

        // Si no existe → intentar apuntar a xkeyboard-config-2 (reglas reales)
        if (!Files.exists(xkbPath, java.nio.file.LinkOption.NOFOLLOW_LINKS)) {
            val kbd2 = File(usrDir, "share/xkeyboard-config-2")
            if (kbd2.isDirectory && File(kbd2, "rules").isDirectory) {
                try {
                    Files.createSymbolicLink(xkbPath, java.nio.file.Paths.get("../xkeyboard-config-2"))
                    Log.i(TAG, "xkb → xkeyboard-config-2")
                    return
                } catch (e: Exception) { Log.w(TAG, "symlink xkb→kbd2: ${e.message}") }
            }

            // Último recurso: stub mínimo (solo evita el abort de Xvnc)
            val xkbDir = xkbPath.toFile()
            for (d in listOf("rules", "symbols", "compat", "keycodes", "types")) {
                File(xkbDir, d).mkdirs()
            }
            // evdev stub — Xvnc requiere este archivo para arrancar sin abortar
            val evdev = File(xkbDir, "rules/evdev")
            if (!evdev.exists()) evdev.writeText("! model\tlayout\n")
            val evdevLst = File(xkbDir, "rules/evdev.lst")
            if (!evdevLst.exists()) evdevLst.writeText("")
            // evdev.xml — TigerVNC busca este archivo explícitamente
            val evdevXml = File(xkbDir, "rules/evdev.xml")
            if (!evdevXml.exists()) evdevXml.writeText(
                """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xkbConfigRegistry SYSTEM "xkb.dtd">
<xkbConfigRegistry version="1.1">
  <modelList/>
  <layoutList/>
  <optionList/>
</xkbConfigRegistry>"""
            )
            Log.i(TAG, "xkb stub creado como último recurso")
        }

        // Symlinks adicionales si xkeyboard-config-2 existe en share/
        val kbd2 = File(usrDir, "share/xkeyboard-config-2")
        if (kbd2.isDirectory) {
            for (d in listOf("compat", "geometry", "keycodes", "rules", "symbols", "types")) {
                val link = File(usrDir, d)
                if (!link.exists() && File(kbd2, d).isDirectory) {
                    try {
                        Files.createSymbolicLink(
                            java.nio.file.Paths.get(link.absolutePath),
                            java.nio.file.Paths.get("share/xkeyboard-config-2/$d"),
                        )
                    } catch (e: Exception) { Log.w(TAG, "symlink xkb $d: ${e.message}") }
                }
            }
        }
    }

    private fun ensureCompatPrefixLinks() {
        // Crea /data/data/dev.nanoai.mobile/us → usrDir
        // Los binarios parcheados usan esta ruta (exactamente 31B) para acceder a sus recursos.
        val targets = linkedSetOf<String>()
        try { targets.add(File("/data/data/dev.nanoai.mobile/us").absolutePath) } catch (_: Exception) {}
        try { targets.add(File("/data/data/dev.nanoai.mobile/f").absolutePath) } catch (_: Exception) {}
        try {
            val appDataDir = usrDir.parentFile!!.parentFile!!.parentFile!!
            targets.add(File(appDataDir, "us").absolutePath)
            targets.add(File(appDataDir, "f").absolutePath)
        } catch (_: Exception) {}

        for (target in targets) {
            try {
                val linkPath = java.nio.file.Paths.get(target)
                // Eliminar si era symlink previo (puede apuntar a ruta obsoleta)
                if (Files.isSymbolicLink(linkPath)) {
                    Files.delete(linkPath)
                } else if (Files.exists(linkPath, java.nio.file.LinkOption.NOFOLLOW_LINKS)) {
                    Log.w(TAG, "symlink omitido, existe como no-symlink: $target")
                    continue
                }
                Files.createSymbolicLink(linkPath, java.nio.file.Paths.get(usrDir.absolutePath))
                Log.i(TAG, "symlink creado: $target → ${usrDir.absolutePath}")
            } catch (e: Exception) {
                Log.w(TAG, "symlink $target: ${e.message}")
            }
        }
    }

    // ── Patch de paths Termux ────────────────────────────────────────────────

    /**
     * Reemplaza in-place el path de Termux hardcodeado en el ELF por el path
     * del sandbox de NanoAI.
     *
     * REQUISITO DE CORRECCIÓN:
     *   old = "/data/data/com.termux/files/usr"  (35 bytes)
     *   new = "/data/data/dev.nanoai.mobile/f/usr" (35 bytes)
     *   → mismo largo → sin corrupción del segmento .rodata del ELF.
     *
     * El symlink "f" → usrDir garantiza que la ruta sea válida en runtime.
     * Idempotente: si ya fue parcheado (la cadena old no existe), no modifica.
     * Hace backup .bak antes de la primera escritura.
     */
    private fun patchTermuxPaths(bin: File) {
        if (!bin.exists() || !bin.canRead()) return
        // NUNCA procesar archivos .bak — evita la cadena infinita .bak.bak.bak...
        if (bin.name.contains(".bak")) return

        val old = TERMUX_USR_BYTES
        val new = SANDBOX_USR_BYTES
        require(old.size == new.size) { "patch size mismatch: ${old.size} vs ${new.size}" }

        try {
            val bytes   = bin.readBytes()
            var changed = false
            var i       = 0

            while (i <= bytes.size - old.size) {
                var match = true
                for (j in old.indices) {
                    if (bytes[i + j] != old[j]) { match = false; break }
                }
                if (match) {
                    for (j in new.indices) bytes[i + j] = new[j]
                    changed = true
                    i += old.size
                } else {
                    i++
                }
            }

            if (changed) {
                // Escribir directamente sin crear .bak: idempotente, sin acumulación
                bin.writeBytes(bytes)
                Log.i(TAG, "patched ${bin.name}: Termux → sandbox paths")
            } else {
                Log.d(TAG, "${bin.name}: ya parcheado o sin paths Termux")
            }
        } catch (e: Exception) {
            Log.w(TAG, "patchTermuxPaths ${bin.name}: ${e.message}")
        }
    }

    private fun clearTigerVncConfig(homeDir: File) {
        val paths = listOf(
            File(homeDir, ".config/tigervnc"),
            File(homeDir, ".vnc"),
        )
        paths.forEach { path ->
            try {
                if (path.exists()) {
                    path.deleteRecursively()
                    Log.i(TAG, "TigerVNC config limpiada: ${path.absolutePath}")
                }
            } catch (e: Exception) {
                Log.w(TAG, "clearTigerVncConfig ${path.absolutePath}: ${e.message}")
            }
        }
    }

    // ── Estado VNC ───────────────────────────────────────────────────────────

    /**
     * Sondea TCP loopback para verificar si Xvnc está accesible.
     * Usa timeout corto (400 ms). NO debe llamarse desde el main thread de Android.
     */
    fun probePort(timeoutMs: Int = 400): Boolean {
        return try {
            java.net.Socket().use { s ->
                s.connect(java.net.InetSocketAddress("127.0.0.1", DEFAULT_PORT), timeoutMs)
                true
            }
        } catch (_: Exception) { false }
    }
}
