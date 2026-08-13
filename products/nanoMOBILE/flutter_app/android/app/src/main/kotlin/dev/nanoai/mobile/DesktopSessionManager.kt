package dev.nanoai.mobile

import android.util.Log
import dev.nanoai.mobile.services.XServerBackend
import dev.nanoai.mobile.services.InternalXvncBackend
import java.io.File
import java.nio.file.Files
import java.nio.file.Paths
import kotlin.concurrent.thread
import kotlinx.coroutines.runBlocking

/**
 * Servicio Desktop autocontenido: lanza window manager y terminal 
 * conectándolos a un XServerBackend.
 */
class DesktopSessionManager(
    private val usrDir: File,
    private val vncPassword: String = "",
    private val spawnBg: (binaryPath: String, argv: List<String>, envp: Map<String, String>) -> Long,
) {
    companion object {
        private const val TAG = "desktop-session"
        const val DEFAULT_WIDTH   = 1280
        const val DEFAULT_HEIGHT  = 720
    }

    @Volatile private var openboxPid: Long = -1
    @Volatile private var terminalPid: Long = -1
    @Volatile private var tint2Pid: Long   = -1
    @Volatile private var fehPid: Long     = -1
    @Volatile private var running = false
    @Volatile private var stopRequested = false
    @Volatile private var starting = false

    // Etapa real del arranque (idle/starting/xvnc/rfb/wm/ready/failed/stopped)
    // y último error — la UI Flutter los consume vía getDesktopStatus en vez
    // de un progress falso.
    @Volatile private var stage: String = "idle"
    @Volatile private var lastError: String? = null

    // Entorno del último arranque — el watchdog granular lo usa para
    // re-lanzar SOLO el terminal (no toda la sesión) cuando muere.
    @Volatile private var lastWmEnv: Map<String, String> = emptyMap()

    val currentStage: String get() = stage
    val currentError: String? get() = lastError

    // Watchdog: monitoriza salud del proceso Xvnc. Si el puerto VNC deja de
    // responder, resetea `running` para que la próxima llamada a start()
    // pueda reiniciar todo limpiamente.
    private var watchdogThread: Thread? = null

    private val backend: XServerBackend = InternalXvncBackend(usrDir, spawnBg, vncPassword)

    // ── Entorno base ─────────────────────────────────────────────────────────

    private fun baseEnv(display: String): MutableMap<String, String> {
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
            "DISPLAY"          to display,
            "XDG_RUNTIME_DIR"  to tmpDir.absolutePath,
            "LANG"             to "en_US.UTF-8",
            "TERM"             to "xterm-256color",
            // aterm lanza $SHELL como hijo; sin SHELL cae a /bin/sh que
            // nanoroot resuelve pero aterm muere en silencio tras el spawn
            // (evidencia device 2026-08-12: PID reap sin stderr).
            "SHELL"            to "${usrDir.absolutePath}/bin/bash",
            "NANO_ROOTFS"      to usrDir.absolutePath,
            // GSettings de las apps GTK (mousepad, pcmanfm): sin esta ruta,
            // g_settings_schema_source_lookup() falla con source NULL y las
            // apps corren sin defaults (evidencia device 2026-08-12).
            "GSETTINGS_SCHEMA_DIR" to "${usrDir.absolutePath}/share/glib-2.0/schemas",
            // Iconos y datos XDG (temas de pcmanfm, iconos de openbox menu).
            "XDG_DATA_DIRS"    to "${usrDir.absolutePath}/share",
            // Backend GSettings de Xfconf (mousepad/GTK). GIO dlopen()ea los
            // módulos desde un path Termux compilado en el binario; sin esta
            // variable busca en /data/data/com.termux/... y no carga el
            // backend (evidencia device 2026-08-12).
            "GIO_EXTRA_MODULES" to "${usrDir.absolutePath}/lib/gio/modules",
            // Cursor X11 grande para pantalla táctil móvil (libXcursor lee
            // XCURSOR_SIZE del entorno; sin xrdb instalado es la vía directa).
            // Verificado device 2026-08-12: aterm con este env renderiza
            // cursor 24px en el framebuffer.
            "XCURSOR_SIZE"     to "24",
        )
    }

    // ── API pública ──────────────────────────────────────────────────────────

    @Synchronized
    fun start(
        width: Int = DEFAULT_WIDTH,
        height: Int = DEFAULT_HEIGHT,
        onStatus: (String) -> Unit = {},
        onReady: () -> Unit = {},
        onError: (msg: String) -> Unit = {},
    ): Boolean {
        if (running || starting) {
            Log.w(TAG, "Desktop ya corriendo o arrancando")
            if (running) onReady()
            return true
        }
        stopRequested = false
        starting = true
        stage = "starting"
        lastError = null

        thread(name = "desktop-start", isDaemon = true) {
            startInternal(onStatus, onReady, onError)
        }
        return true
    }

    @Synchronized
    fun stop() {
        stopRequested = true
        // Si no hay nada corriendo ni arrancando, no hay nada que detener.
        // Pero si starting==true, debemos esperar/abortar — no retornar temprano.
        if (!running && !starting && openboxPid <= 0 && tint2Pid <= 0 && terminalPid <= 0) return
        Log.i(TAG, "Deteniendo Desktop…")
        cleanupProcesses()
        runBlocking {
            backend.stop()
        }
        starting = false
        stage = "idle"
    }

    val isRunning: Boolean get() = running
    val endpoint get() = backend.getEndpoint()
    val rfbPort get() = backend.rfbPort
    val isBackendAlive get() = backend.isAlive()

    fun dispose() = stop()

    /**
     * Lanza una app gráfica sobre el escritorio proyectado con el env del WM
     * (mismo display, LD_PRELOAD, GTK env). Allowlist estricta — nunca ejecuta
     * binarios arbitrarios desde la capa Dart.
     */
    fun launchApp(app: String): Boolean {
        if (!running || lastWmEnv.isEmpty()) {
            Log.w(TAG, "launchApp($app): desktop no corriendo o env no listo")
            return false
        }
        val (binary, argv) = when (app) {
            // Fuente Xft 14px verificada device 2026-08-12 (tamaño móvil).
            "aterm"    -> File(usrDir, "bin/aterm") to listOf(
                "aterm", "-fn", "xft:DejaVu Sans Mono:pixelsize=14",
                "-bg", "#0d1117", "-fg", "#00ff9d",
            )
            "pcmanfm"  -> File(usrDir, "bin/pcmanfm") to listOf("pcmanfm")
            "mousepad" -> File(usrDir, "bin/mousepad") to listOf("mousepad")
            "feh"      -> File(usrDir, "bin/feh") to listOf("feh")
            else -> {
                Log.w(TAG, "launchApp: app fuera de allowlist: $app")
                return false
            }
        }
        if (!isElf(binary)) {
            Log.w(TAG, "launchApp: $app no existe o no es ELF")
            return false
        }
        binary.setExecutable(true, false)
        val pid = spawnBg(binary.absolutePath, argv, lastWmEnv)
        Log.i(TAG, "launchApp($app) PID=$pid")
        return pid > 0
    }

    // ── Lógica interna (hilo de fondo) ───────────────────────────────────────

    private fun startInternal(
        onStatus: (String) -> Unit,
        onReady: () -> Unit,
        onError: (String) -> Unit,
    ) {
        // Guard final: una excepción no esperada (no cubierta por los checks
        // internos) no debe dejar starting=true ni el stage a medio camino
        // — la UI quedaría en "starting" para siempre.
        try {
            startInternalImpl(onStatus, onReady, onError)
        } catch (e: Exception) {
            Log.e(TAG, "startInternal: excepción no esperada", e)
            lastError = "Error interno al iniciar escritorio: ${e.javaClass.simpleName}: ${e.message}"
            stage = "failed"
            starting = false
            try { cleanupProcesses() } catch (ignored: Exception) { }
            try { runBlocking { backend.stop() } } catch (ignored: Exception) { }
            onError(lastError!!)
        }
    }

    private fun startInternalImpl(
        onStatus: (String) -> Unit,
        onReady: () -> Unit,
        onError: (String) -> Unit,
    ) {
        val tmpDir = File(usrDir, "tmp").also { it.mkdirs() }

        // 1. Limpiar locks X11 previos
        if (abortIfStopped("before-clean", onError)) return
        cleanX11Runtime(tmpDir)

        // El socket X11 UNIX: Xvnc crea usr/tmp/.X11-unix (su path hardcodeado
        // de Termux, redirigido por libnanoroot en mkdir/bind). openbox/libX11
        // buscan el display en /tmp/.X11-unix/X1, y nanoroot redirige /tmp a
        // files/nano/tmp. El enlace cierra el círculo: /tmp → usr/tmp.
        ensureTmpLink(tmpDir)

        // El entorno (PREFIX/HOME/LD_LIBRARY_PATH/XDG_CONFIG_HOME...) se calcula
        // ANTES de arrancar el backend: Xvnc lo necesita tanto como openbox/tint2
        // para resolver sus libs y las reglas XKB (share/X11/xkb/rules/evdev).
        // Pasarle emptyMap() a Xvnc lo hace abortar en silencio antes de abrir
        // el puerto RFB.
        val endpointInfo = backend.getEndpoint()
        val displayHost = endpointInfo.host ?: ""
        val displayStr = if (displayHost.isNotEmpty()) "$displayHost:${endpointInfo.display}" else ":${endpointInfo.display}"
        val wmEnv = baseEnv(displayStr)
        lastWmEnv = wmEnv

        onStatus("Iniciando backend gráfico (Xvnc)...")
        stage = "xvnc"

        runBlocking {
            if (!backend.start(wmEnv)) {
                val msg = "Fallo al iniciar el backend del servidor X11."
                lastError = msg
                stage = "failed"
                onError(msg)
                starting = false
                return@runBlocking
            }
        }

        onStatus("Esperando puerto RFB/VNC...")
        stage = "rfb"
        if (abortIfStopped("before-vnc-wait", onError)) return

        val ready = runBlocking { backend.awaitReady() }
        if (!ready) {
            Log.e(TAG, "El servidor X no respondió.")
            val msg = backend.lastError
                ?: "Servidor X11 no arrancó a tiempo (Xvnc no abrió el puerto RFB). Revisa dependencias nativas (libs/xkb)."
            lastError = msg
            stage = "failed"
            onError(msg)
            cleanupProcesses()
            runBlocking { backend.stop() }
            starting = false
            return
        }

        onStatus("DISPLAY=$displayStr válido — iniciando entorno de escritorio…")
        stage = "wm"
        if (abortIfStopped("before-wm", onError)) return

        setupTint2Config()
        setupOpenboxMenu()
        setupOpenboxRc()
        setupWallpaper()
        setupGtkTheme()

        // Lanzar openbox
        val openboxBin = File(usrDir, "bin/openbox")
        if (openboxBin.exists()) {
            openboxBin.setExecutable(true, false)
            openboxPid = spawnBg(openboxBin.absolutePath, listOf("openbox"), wmEnv)
            Log.i(TAG, "openbox PID=$openboxPid")
            onStatus("openbox arrancado (PID=$openboxPid)")
            if (abortIfStopped("after-openbox-spawn", onError)) return
        } else {
            Log.w(TAG, "openbox no encontrado")
        }

        Thread.sleep(800)
        if (abortIfStopped("after-openbox-wait", onError)) return

        // Lanzar tint2
        val tint2Bin = File(usrDir, "bin/tint2")
        if (tint2Bin.exists()) {
            tint2Bin.setExecutable(true, false)
            tint2Pid = spawnBg(tint2Bin.absolutePath, listOf("tint2"), wmEnv)
            Log.i(TAG, "tint2 PID=$tint2Pid")
            onStatus("tint2 arrancado (PID=$tint2Pid)")
            if (abortIfStopped("after-tint2-spawn", onError)) return
        }

        // Wallpaper: PNG nano-cyber desplegado por el boot (assets/exe/
        // nano-wallpaper.png → home/.nano-wallpaper.png) aplicado con
        // --bg-fill (resolución exacta 1280x720, sin escalado). Si el PNG no
        // está (primer boot sin asset), cae al PPM degradado de setupWallpaper.
        // Sin fondo el root de X es un ruido de píxeles heredado; feh aplica
        // el pixmap propio sin depender de xsetroot (no instalado).
        val fehBin = File(usrDir, "bin/feh")
        val wallpaper = wallpaperTarget()
        if (fehBin.exists() && wallpaper.exists()) {
            val flag = if (wallpaper.name.endsWith(".png")) "--bg-fill" else "--bg-scale"
            fehPid = spawnBg(fehBin.absolutePath, listOf("feh", flag, wallpaper.absolutePath), wmEnv)
            Log.i(TAG, "feh wallpaper aplicado ($flag ${wallpaper.name}, PID=$fehPid)")
        }

        // Lanzar terminal gráfica
        val terminal = firstExistingTerminal()
        if (terminal != null) {
            terminal.file.setExecutable(true, false)
            terminalPid = spawnBg(terminal.file.absolutePath, terminal.argv, wmEnv)
            Log.i(TAG, "terminal ${terminal.file.name} PID=$terminalPid")
            onStatus("terminal ${terminal.file.name} arrancada (PID=$terminalPid)")
            if (abortIfStopped("after-terminal-spawn", onError)) return
            // Supervisión de spawn (P1): el aterm ha muerto en silencio tras
            // el spawn en ciclos previos (sin stderr propio, sin reap visible
            // en logcat — evidencia device 2026-08-12, ciclos 16:33/16:35/
            // 16:51). Verificar /proc/<pid> 500 ms después: si ya murió, se
            // re-lanza UNA vez antes de declarar ready. Si vuelve a morir,
            // el watchdog granular (cada 5s) lo re-lanza sin tocar el resto.
            Thread.sleep(500)
            if (terminalPid > 0 && !File("/proc/$terminalPid").exists()) {
                Log.w(TAG, "terminal ${terminal.file.name} PID=$terminalPid murió a los 500ms — re-lanzando")
                terminalPid = spawnBg(terminal.file.absolutePath, terminal.argv, wmEnv)
                Log.i(TAG, "terminal ${terminal.file.name} re-lanzado PID=$terminalPid")
            }
        } else {
            Log.w(TAG, "terminal gráfica no encontrada")
        }

        if (abortIfStopped("before-ready", onError)) return
        // K-6: raza start/stop. `running=true` se escribía FUERA del lock tras
        // el último abortIfStopped: un stop() concurrente (ve starting=true →
        // procede a matar PIDs y pone starting=false) podía intercalarse entre
        // el check y estas líneas → desktop "ready" con PIDs muertos. La
        // transición final debe ser atómica con stopRequested bajo el MISMO
        // lock que stop().
        val abortedByStop = synchronized(this) {
            if (stopRequested) true
            else {
                running = true
                starting = false
                stage = "ready"
                lastError = null
                false
            }
        }
        if (abortedByStop) {
            Log.i(TAG, "start abortado por stopRequested en before-ready (lock)")
            cleanupProcesses()
            runBlocking { backend.stop() }
            starting = false
            stage = "stopped"
            onError("Desktop start abortado en before-ready")
            return
        }
        startWatchdog()
        val msg = "Escritorio listo en $displayStr"
        Log.i(TAG, msg)
        onStatus(msg)
        onReady()
    }

    private data class TerminalLaunch(val file: File, val argv: List<String>)

    /**
     * El xterm de Termux es un script wrapper (shebang), no un ELF: el spawn
     * detached falla siempre con "bad ELF magic: 23212f64" (evidencia device
     * 2026-08-12). Se exige magic ELF real; aterm lo es y acepta -bg/-fg.
     */
    private fun isElf(file: File): Boolean {
        if (!file.exists() || !file.isFile) return false
        return try {
            val magic = ByteArray(4)
            file.inputStream().use { ins ->
                var off = 0
                while (off < magic.size) {
                    val n = ins.read(magic, off, magic.size - off)
                    if (n < 0) return false
                    off += n
                }
            }
            magic[0] == 0x7F.toByte() && magic[1] == 'E'.code.toByte() &&
                magic[2] == 'L'.code.toByte() && magic[3] == 'F'.code.toByte()
        } catch (e: Exception) {
            Log.w(TAG, "isElf(${file.name}): ${e.message}")
            false
        }
    }

    private fun firstExistingTerminal(): TerminalLaunch? {
        // Fuente Xft 14px: la "fixed" integrada de Xvnc es ilegible en móvil
        // (verificado device 2026-08-12: -fn "xft:DejaVu Sans Mono:pixelsize=14"
        // renderiza con DejaVuSansMono.ttf del rootfs).
        val bigFont = listOf("-fn", "xft:DejaVu Sans Mono:pixelsize=14")
        val colors = listOf("-bg", "#0f172a", "-fg", "#38bdf8")
        // Terminal de bienvenida: muestra el HUD (banner nano-sec con info real
        // del sistema vía /proc) y deja el shell interactivo debajo. El
        // watchdog granular re-lanza la terminal con el MISMO argv, así el
        // banner vuelve a aparecer si la terminal muere.
        val hud = "python3 ${File(usrDir.parentFile, "home/.hud.py").absolutePath}"
        val shellCmd = "$hud; exec bash -i"
        val candidates = listOf(
            TerminalLaunch(
                File(usrDir, "bin/xterm"),
                listOf("xterm") + bigFont + colors + listOf("-e", "sh", "-c", shellCmd),
            ),
            TerminalLaunch(
                File(usrDir, "bin/aterm"),
                listOf("aterm") + bigFont + colors + listOf("-e", "sh", "-c", shellCmd),
            ),
            TerminalLaunch(File(usrDir, "bin/lxterminal"), listOf("lxterminal")),
        )
        return candidates.firstOrNull { isElf(it.file) }
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
        stopWatchdog()
        killPid(terminalPid); terminalPid = -1
        killPid(tint2Pid);   tint2Pid   = -1
        killPid(openboxPid); openboxPid = -1
        killPid(fehPid);     fehPid     = -1
        running = false
    }

    private fun abortIfStopped(stageName: String, onError: (String) -> Unit = {}): Boolean {
        if (!stopRequested) return false
        Log.i(TAG, "start abortado por stopRequested en $stageName")
        val msg = "Desktop start abortado en $stageName"
        lastError = msg
        stage = "stopped"
        onError(msg)
        cleanupProcesses()
        runBlocking { backend.stop() }
        starting = false
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

    /**
     * Crea files/nano/tmp → usr/tmp si no existe. La redirección de nanoroot
     * mapea /tmp a files/nano/tmp; sin este enlace, openbox no encuentra el
     * socket .X11-unix que Xvnc crea en usr/tmp.
     */
    private fun ensureTmpLink(tmpDir: File) {
        val nanoDir = tmpDir.parentFile ?: return
        val nanoTmp = File(nanoDir, "tmp")
        try {
            if (!nanoTmp.exists()) {
                Files.createSymbolicLink(
                    nanoTmp.toPath(),
                    Paths.get(tmpDir.absolutePath),
                )
                Log.i(TAG, "tmp link creado: ${nanoTmp.path} -> ${tmpDir.path}")
            }
        } catch (e: Exception) {
            Log.w(TAG, "tmp link falló: ${e.message}")
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

    // ── Watchdog de proceso ─────────────────────────────────────────────────

    private fun startWatchdog() {
        stopWatchdog()
        watchdogThread = thread(name = "desktop-watchdog", isDaemon = true) {
            val vncPort = rfbPort
            while (running && !stopRequested) {
                try {
                    Thread.sleep(5000)
                    if (stopRequested || !running) break
                    if (!backend.isAlive()) {
                        throw java.io.IOException("proceso Xvnc muerto (isAlive=false)")
                    }
                    // Watchdog granular (sección 10 del informe): si el
                    // terminal murió, se re-lanza SOLO el terminal — no toda
                    // la sesión. Xvnc es la raíz gráfica: su caída invalida
                    // la sesión entera (el catch de abajo).
                    val tPid = terminalPid
                    if (tPid > 0 && !File("/proc/$tPid").exists()) {
                        Log.w(TAG, "Watchdog: terminal PID=$tPid muerto — re-lanzando solo el terminal")
                        terminalPid = -1
                        val terminal = firstExistingTerminal()
                        if (terminal != null && lastWmEnv.isNotEmpty()) {
                            terminal.file.setExecutable(true, false)
                            terminalPid = spawnBg(terminal.file.absolutePath, terminal.argv, lastWmEnv)
                            Log.i(TAG, "Watchdog: terminal re-lanzado PID=$terminalPid")
                        }
                    }
                    // openbox/tint2/feh antes quedaban sin vigilancia: "ready"
                    // con WM muerto = ventanas sin decorar; feh muerto = fondo
                    // de ruido de píxeles sin restauración. Mismo patrón que
                    // el terminal: re-lanzar solo el proceso caído.
                    val obPid = openboxPid
                    if (obPid > 0 && !File("/proc/$obPid").exists()) {
                        Log.w(TAG, "Watchdog: openbox PID=$obPid muerto — re-lanzando")
                        openboxPid = -1
                        val ob = File(usrDir, "bin/openbox")
                        if (ob.exists() && lastWmEnv.isNotEmpty()) {
                            ob.setExecutable(true, false)
                            openboxPid = spawnBg(ob.absolutePath, listOf("openbox"), lastWmEnv)
                            Log.i(TAG, "Watchdog: openbox re-lanzado PID=$openboxPid")
                        }
                    }
                    val tiPid = tint2Pid
                    if (tiPid > 0 && !File("/proc/$tiPid").exists()) {
                        Log.w(TAG, "Watchdog: tint2 PID=$tiPid muerto — re-lanzando")
                        tint2Pid = -1
                        val ti = File(usrDir, "bin/tint2")
                        if (ti.exists() && lastWmEnv.isNotEmpty()) {
                            ti.setExecutable(true, false)
                            tint2Pid = spawnBg(ti.absolutePath, listOf("tint2"), lastWmEnv)
                            Log.i(TAG, "Watchdog: tint2 re-lanzado PID=$tint2Pid")
                        }
                    }
                    val fePid = fehPid
                    val wallpaper = wallpaperTarget()
                    if (fePid > 0 && !File("/proc/$fePid").exists()) {
                        Log.w(TAG, "Watchdog: feh PID=$fePid muerto — re-aplicando wallpaper")
                        fehPid = -1
                        val feh = File(usrDir, "bin/feh")
                        if (feh.exists() && wallpaper.exists() && lastWmEnv.isNotEmpty()) {
                            val flag = if (wallpaper.name.endsWith(".png")) "--bg-fill" else "--bg-scale"
                            feh.setExecutable(true, false)
                            fehPid = spawnBg(feh.absolutePath, listOf("feh", flag, wallpaper.absolutePath), lastWmEnv)
                            Log.i(TAG, "Watchdog: feh re-lanzado PID=$fehPid")
                        }
                    }
                } catch (e: InterruptedException) {
                    // stopWatchdog() llamó interrupt() — salida limpia.
                    break
                } catch (e: Exception) {
                    if (stopRequested || !running) break
                    Log.w(TAG, "Watchdog: proceso Xvnc muerto (IOException en isAlive)")
                    running = false
                    stage = "failed"
                    lastError = "Xvnc dejó de responder (watchdog, puerto $vncPort)"
                    // No llamamos cleanup aquí — el VncScreen en Dart
                    // detectará la desconexión y disparará auto-reconnect.
                    break
                }
            }
            Log.i(TAG, "Watchdog terminado")
        }
    }

    private fun stopWatchdog() {
        watchdogThread?.interrupt()
        watchdogThread = null
    }

    private fun setupTint2Config() {
        try {
            // BUG tint2 (2026-08-12): se escribía a usr/etc/xdg/tint2 pero tint2
            // lee $HOME/.config/tint2/tint2rc (XDG_CONFIG_HOME=home/.config) →
            // "could not find a config file" y tint2 creaba un default propio.
            // Además el config viejo usaba opciones que ESTE tint2 de Termux no
            // soporta: panel_color/clock_enabled/clock_format/clock_font/clock_color
            // → "invalid option" x5 → "panel items: (null)" → tint2 exit.
            // Opciones correctas (tint2 17.x): reloj = time1_format/time1_font/
            // clock_font_color; fondo del panel = panel_background_id + bloque
            // background (background_color/rounded/border_width).
            val homeDir   = File(usrDir.parentFile, "home")
            val configDir = File(homeDir, ".config/tint2").also { it.mkdirs() }
            val tint2Rc   = File(configDir, "tint2rc")
            val appsDir = File(homeDir, ".local/share/applications").also { it.mkdirs() }

            // Crear .desktop files para los launchers del panel (Terminal, Archivos, Editor, Imágenes)
            File(appsDir, "aterm.desktop").writeText("""
                [Desktop Entry]
                Name=Terminal
                Exec=aterm -fn "xft:DejaVu Sans Mono:pixelsize=14" -bg #0f172a -fg #38bdf8
                Icon=utilities-terminal
                Type=Application
            """.trimIndent())

            File(appsDir, "pcmanfm.desktop").writeText("""
                [Desktop Entry]
                Name=Archivos
                Exec=pcmanfm
                Icon=system-file-manager
                Type=Application
            """.trimIndent())

            File(appsDir, "mousepad.desktop").writeText("""
                [Desktop Entry]
                Name=Editor
                Exec=mousepad
                Icon=accessories-text-editor
                Type=Application
            """.trimIndent())

            File(appsDir, "feh.desktop").writeText("""
                [Desktop Entry]
                Name=Imágenes
                Exec=feh
                Icon=image-x-generic
                Type=Application
            """.trimIndent())

            // Monitor del sistema: re-ejecuta el HUD (banner nano-sec) en su
            // propia terminal. Ruta absoluta: tint2 hace execvp sin shell, no
            // expande "~".
            val hudPy = File(homeDir, ".hud.py").absolutePath
            File(appsDir, "nano-info.desktop").writeText("""
                [Desktop Entry]
                Name=Monitor
                Exec=aterm -fn "xft:DejaVu Sans Mono:pixelsize=14" -bg #0f172a -fg #38bdf8 -e python3 $hudPy
                Icon=utilities-system-monitor
                Type=Application
            """.trimIndent())

            // Panel móvil: Slate Navy (#1e293b), reloj Sky Blue (#38bdf8),
            // fuentes DejaVu Sans escaladas. Se reescribe siempre para que los
            // cambios de UX sobrevivan a booteos previos.
            tint2Rc.writeText("""
                panel_items = LTSC
                panel_position = bottom center horizontal
                panel_size = 100% 46
                panel_margin = 0 0
                panel_background_id = 1
                panel_dock = 0
                font_shadow = 0
                wm_menu = 1

                # Launchers
                launcher_padding = 4 4 4
                launcher_background_id = 0
                launcher_icon_background_id = 0
                launcher_icon_size = 24
                launcher_icon_asb = 100 0 0
                launcher_icon_theme_override = 0
                startup_notifications = 1
                launcher_tooltip = 1
                launcher_item_app = ~/.local/share/applications/nano-info.desktop
                launcher_item_app = ~/.local/share/applications/aterm.desktop
                launcher_item_app = ~/.local/share/applications/pcmanfm.desktop
                launcher_item_app = ~/.local/share/applications/mousepad.desktop
                launcher_item_app = ~/.local/share/applications/feh.desktop

                taskbar_mode = single_desktop
                task_text = 1
                task_maximum_size = 280 44
                task_font = DejaVu Sans 11
                task_font_color = #e2e8f0 100
                task_background_id = 1
                task_active_background_id = 1

                systray = 1
                systray_background_id = 1

                time1_format = %H:%M
                time1_font = DejaVu Sans 12
                clock_font_color = #38bdf8 100

                # Background 1: panel/taskbar (Slate Navy)
                rounded = 0
                border_width = 0
                background_color = #1e293b 100
                border_color = #1e293b 100
            """.trimIndent())
        } catch (e: Exception) {
            Log.w(TAG, "setupTint2Config: ${e.message}")
        }
    }

    // Menú de openbox (clic derecho en el escritorio) con las apps gráficas
    // instaladas. openbox lee $HOME/.config/openbox/menu.xml por defecto.
    private fun setupOpenboxMenu() {
        try {
            val homeDir = File(usrDir.parentFile, "home")
            val obDir = File(homeDir, ".config/openbox").also { it.mkdirs() }
            val menuXml = File(obDir, "menu.xml")
            val hudPy = File(homeDir, ".hud.py").absolutePath
            menuXml.writeText("""
                <?xml version="1.0" encoding="UTF-8"?>
                <openbox_menu xmlns="http://openbox.org/3.4/menu">
                  <menu id="root-menu" label="NanoAI Linux Desktop">
                    <item label="Monitor del Sistema">
                      <action name="Execute"><execute>aterm -fn "xft:DejaVu Sans Mono:pixelsize=14" -bg #0f172a -fg #38bdf8 -e python3 $hudPy</execute></action>
                    </item>
                    <item label="Terminal">
                      <action name="Execute"><execute>aterm -fn "xft:DejaVu Sans Mono:pixelsize=14" -bg #0f172a -fg #38bdf8</execute></action>
                    </item>
                    <item label="Archivos">
                      <action name="Execute"><execute>pcmanfm</execute></action>
                    </item>
                    <item label="Editor">
                      <action name="Execute"><execute>mousepad</execute></action>
                    </item>
                    <item label="Imágenes">
                      <action name="Execute"><execute>feh</execute></action>
                    </item>
                    <separator/>
                    <item label="Reconfigurar">
                      <action name="Reconfigure"/>
                    </item>
                    <item label="Salir">
                      <action name="Exit"/>
                    </item>
                  </menu>
                </openbox_menu>
            """.trimIndent())
            Log.i(TAG, "openbox menu.xml escrito")
        } catch (e: Exception) {
            Log.w(TAG, "setupOpenboxMenu: ${e.message}")
        }
    }

    // Configuración rc.xml de openbox (temas de ventana y fuentes)
    private fun setupOpenboxRc() {
        try {
            val homeDir = File(usrDir.parentFile, "home")
            val obDir = File(homeDir, ".config/openbox").also { it.mkdirs() }
            val rcXml = File(obDir, "rc.xml")
            // rc.xml para Openbox: Configura el tema Onyx, desactiva animaciones/sombras
            // innecesarias para mejorar performance en VNC, y setea DejaVu Sans.
            rcXml.writeText("""
                <?xml version="1.0" encoding="UTF-8"?>
                <openbox_config xmlns="http://openbox.org/3.4/rc">
                  <theme>
                    <name>Onyx</name>
                    <cornerRadius>4</cornerRadius>
                    <font place="ActiveWindow">
                      <name>DejaVu Sans</name>
                      <size>10</size>
                      <weight>Bold</weight>
                    </font>
                    <font place="InactiveWindow">
                      <name>DejaVu Sans</name>
                      <size>10</size>
                      <weight>Normal</weight>
                    </font>
                    <font place="MenuHeader">
                      <name>DejaVu Sans</name>
                      <size>10</size>
                      <weight>Bold</weight>
                    </font>
                    <font place="MenuItem">
                      <name>DejaVu Sans</name>
                      <size>10</size>
                      <weight>Normal</weight>
                    </font>
                    <font place="OnScreenDisplay">
                      <name>DejaVu Sans</name>
                      <size>10</size>
                      <weight>Bold</weight>
                    </font>
                  </theme>
                  <keyboard>
                    <chainQuitKey>C-g</chainQuitKey>
                  </keyboard>
                </openbox_config>
            """.trimIndent())
            Log.i(TAG, "openbox rc.xml escrito (Tema Onyx + DejaVu Sans)")
        } catch (e: Exception) {
            Log.w(TAG, "setupOpenboxRc: ${e.message}")
        }
    }

    // Tema GTK móvil: fuente DejaVu Sans 14 + tema oscuro para pcmanfm,
    // mousepad y demás apps GTK3. El DPI viene del servidor X (Xvnc -dpi
    // 110); esta fuente agranda menús y listas para dedos en pantalla.
    private fun setupGtkTheme() {
        try {
            val gtkDir = File(File(usrDir.parentFile, "home"), ".config/gtk-3.0")
                .also { it.mkdirs() }
            val settingsIni = File(gtkDir, "settings.ini")
            settingsIni.writeText("""
                [Settings]
                gtk-theme-name=Adwaita-dark
                gtk-icon-theme-name=Adwaita
                gtk-font-name=DejaVu Sans 14
                gtk-application-prefer-dark-theme=1
            """.trimIndent())
            Log.i(TAG, "GTK settings.ini escrito (fuente 14px, tema oscuro)")
        } catch (e: Exception) {
            Log.w(TAG, "setupGtkTheme: ${e.message}")
        }
    }

    // Wallpaper: PNG nano-cyber 1280x720 desplegado por el boot
    // (assets/exe/nano-wallpaper.png → home/.nano-wallpaper.png) con prioridad;
    // si no está, el PPM degradado de setupWallpaper() es el fallback.
    private fun wallpaperTarget(): File {
        val png = File(File(usrDir.parentFile, "home"), ".nano-wallpaper.png")
        if (png.exists() && png.length() > 10000) return png
        return File(File(usrDir.parentFile, "home"), ".nano-wallpaper.ppm")
    }

    // Wallpaper: Genera un archivo PPM P6 (32x32 px) con un gradiente visual
    // profesional desde Slate Navy (#0F172A) a Deep Ocean Teal (#0369A1).
    // feh --bg-scale lo escala suavemente sin pixelar el framebuffer.
    // SOLO es el fallback: el boot despliega el PNG de alta resolución y
    // wallpaperTarget() lo prefiere (--bg-fill, sin escalado).
    private fun setupWallpaper() {
        try {
            if (wallpaperTarget().name.endsWith(".png")) {
                Log.i(TAG, "wallpaper PNG nano-cyber presente — se omite PPM fallback")
                return
            }
            val homeDir = File(usrDir.parentFile, "home").also { it.mkdirs() }
            val ppm = File(homeDir, ".nano-wallpaper.ppm")
            val w = 32
            val h = 32
            val header = "P6\n$w $h\n255\n".toByteArray(Charsets.US_ASCII)
            val pixels = ByteArray(w * h * 3)
            var idx = 0
            for (y in 0 until h) {
                val factor = y.toDouble() / (h - 1)
                // Gradiente: #0F172A (15, 23, 42) -> #0284C7 (2, 132, 199)
                val r = (15 + factor * (2 - 15)).toInt().coerceIn(0, 255)
                val g = (23 + factor * (132 - 23)).toInt().coerceIn(0, 255)
                val b = (42 + factor * (199 - 42)).toInt().coerceIn(0, 255)
                for (x in 0 until w) {
                    pixels[idx++] = r.toByte()
                    pixels[idx++] = g.toByte()
                    pixels[idx++] = b.toByte()
                }
            }
            ppm.outputStream().use { out ->
                out.write(header)
                out.write(pixels)
            }
            Log.i(TAG, "wallpaper PPM gradiente escrito")
        } catch (e: Exception) {
            Log.w(TAG, "setupWallpaper: ${e.message}")
        }
    }
}
