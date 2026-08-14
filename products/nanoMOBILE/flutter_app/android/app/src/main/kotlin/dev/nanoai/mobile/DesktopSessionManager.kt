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
    // Liveness de Xvnc delegado al worker (padre del proceso). El proceso
    // principal no puede leer /proc de los hijos del worker: isAlive() local
    // devolvía false siempre y mataba a un Xvnc vivo con SIGKILL propio.
    private val isPidAlive: (Long) -> Boolean = { false },
) {
    companion object {
        private const val TAG = "desktop-session"
        const val DEFAULT_WIDTH   = 1280
        const val DEFAULT_HEIGHT  = 720
    }

    @Volatile private var openboxPid: Long = -1
    @Volatile private var terminalPid: Long = -1
    @Volatile private var fehPid: Long     = -1
    @Volatile private var dbusPid: Long   = -1
    @Volatile private var running = false
    @Volatile private var stopRequested = false
    @Volatile private var starting = false

    // Geometría activa del framebuffer (D-1): la resuelve el backend con
    // resolveGeometry(width, height) — el manager la retiene para elegir el
    // wallpaper correcto por aspect (wallpaperForLaunch).
    @Volatile private var fbWidth: Int = DEFAULT_WIDTH
    @Volatile private var fbHeight: Int = DEFAULT_HEIGHT

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

    private val backend: XServerBackend = InternalXvncBackend(usrDir, spawnBg, vncPassword, isPidAlive)

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
            "XCURSOR_SIZE"     to "28",
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
            startInternal(onStatus, onReady, onError, width, height)
        }
        return true
    }

    @Synchronized
    fun stop() {
        stopRequested = true
        // Si no hay nada corriendo ni arrancando, no hay nada que detener.
        // Pero si starting==true, debemos esperar/abortar — no retornar temprano.
        if (!running && !starting && openboxPid <= 0 && terminalPid <= 0) {
            // U-10: nada que detener — pero el usuario pidió apagar: ack
            // implícito del kill anterior (el aviso de restauración se limpia).
            usrDir.parentFile?.let { RuntimeHeartbeat.markCleanShutdown(it) }
            return
        }
        Log.i(TAG, "Deteniendo Desktop…")
        cleanupProcesses()
        runBlocking {
            backend.stop()
        }
        starting = false
        stage = "idle"
        // U-10: apagado limpio — borra el heartbeat (no es kill del OS).
        usrDir.parentFile?.let { RuntimeHeartbeat.markCleanShutdown(it) }
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
    /**
     * Resuelve appId → (binario, argv) con allowlist estricta. Nunca ejecuta
     * binarios arbitrarios desde la capa Dart. Null si el appId no está en
     * la allowlist (lanzamiento e instalación comparten este lookup).
     */
    private fun appBinary(app: String): Pair<File, List<String>>? = when (app) {
        // U-9: aterm del rootfs NO linkea libXft (0 maps fontconfig/freetype
        // en /proc/<pid>/maps, verificado device) — el -fn "xft:..." se
        // ignoraba y aterm caía a "fixed", que no existía porque Xvnc
        // arrancaba sin -fp. Ahora -fp carga misc+75dpi del rootfs y
        // "fixed" (6x13) rinde ~144 columnas en el framebuffer 864px.
        // El appId real es 'lxterminal' (binario lxterminal); 'aterm' fue
        // el nombre histórico del tile del panel y confundía instalación.
        "lxterminal" -> File(usrDir, "bin/lxterminal") to listOf(
            "lxterminal", "-e", "sh", "-c", "exec bash -i",
        )
        "pcmanfm"  -> File(usrDir, "bin/pcmanfm") to listOf("pcmanfm")
        "mousepad" -> File(usrDir, "bin/mousepad") to listOf("mousepad")
        "xpdf"     -> File(usrDir, "bin/xpdf") to listOf("xpdf")
        "file-roller" -> File(usrDir, "bin/file-roller") to listOf("file-roller")
        "feh"      -> File(usrDir, "bin/feh") to listOf("feh")
        else -> null
    }

    /** ¿El binario de la app existe y es ELF? Estado real de instalación. */
    fun isAppInstalled(app: String): Boolean {
        val (binary, _) = appBinary(app) ?: return false
        return isElf(binary)
    }

    fun launchApp(app: String): Boolean {
        if (!running || lastWmEnv.isEmpty()) {
            Log.w(TAG, "launchApp($app): desktop no corriendo o env no listo")
            return false
        }
        val (binary, argv) = appBinary(app) ?: run {
            Log.w(TAG, "launchApp: app fuera de allowlist: $app")
            return false
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
        width: Int,
        height: Int,
    ) {
        // Guard final: una excepción no esperada (no cubierta por los checks
        // internos) no debe dejar starting=true ni el stage a medio camino
        // — la UI quedaría en "starting" para siempre.
        try {
            startInternalImpl(onStatus, onReady, onError, width, height)
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
        width: Int,
        height: Int,
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
        // ANTES de arrancar el backend: Xvnc lo necesita tanto como openbox
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
            if (!backend.start(wmEnv, width, height)) {
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

        val ready = kotlinx.coroutines.runBlocking { backend.awaitReady() }
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

        // Retener la geometría REAL (resuelta por el backend con el cap de
        // memoria) — wallpaperForLaunch la usa para elegir el fondo por aspect.
        if (backend.fbWidth > 0 && backend.fbHeight > 0) {
            fbWidth = backend.fbWidth
            fbHeight = backend.fbHeight
        }

        onStatus("DISPLAY=$displayStr válido — iniciando entorno de escritorio…")
        stage = "wm"
        if (abortIfStopped("before-wm", onError)) return

        setupOpenboxMenu()
        setupOpenboxRc()
        setupWallpaper()
        setupGtkTheme()
        setupLxTerminalConfig()

        // U-1: session bus de D-Bus — gvfs (papelera trash:// de pcmanfm) y
        // los daemons gvfsd lo necesitan. Socket UNIX en el tmp del rootfs
        // (nanoroot redirige /tmp a files/nano/tmp); el address se exporta en
        // wmEnv para que TODOS los hijos (openbox/feh/aterm/pcmanfm)
        // compartan el mismo bus. Sin bus, pcmanfm borra archivos sin
        // papelera (delete directo) — evidencia: bin/dbus-launch instalado
        // pero NADIE lo lanzaba (grep en todo el repo, solo 2 menciones).
        val dbusBin = File(usrDir, "bin/dbus-daemon")
        if (dbusBin.exists()) {
            dbusBin.setExecutable(true, false)
            val dbusSock = File(tmpDir, "dbus-session.sock")
            dbusPid = spawnBg(
                dbusBin.absolutePath,
                listOf(
                    "dbus-daemon", "--session", "--nofork",
                    "--address=unix:path=${dbusSock.absolutePath}",
                ),
                wmEnv,
            )
            if (dbusPid > 0) {
                wmEnv["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=${dbusSock.absolutePath}"
                Log.i(TAG, "dbus-daemon PID=$dbusPid (session bus en $dbusSock)")
            } else {
                Log.w(TAG, "dbus-daemon no arrancó — gvfs/papelera deshabilitados")
            }
        }

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

        // Wallpaper: sin fondo el root de X es ruido de píxeles heredado;
        // feh aplica el pixmap propio sin depender de xsetroot (no instalado).
        val fehBin = File(usrDir, "bin/feh")
        val (wallpaper, wallFlag) = wallpaperForLaunch()
        if (fehBin.exists() && wallpaper.exists()) {
            fehPid = spawnBg(fehBin.absolutePath, listOf("feh", wallFlag, wallpaper.absolutePath), wmEnv)
            Log.i(TAG, "feh wallpaper aplicado ($wallFlag ${wallpaper.name}, PID=$fehPid)")
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
        // U-10: heartbeat de vida — el service de accesibilidad lo usa para
        // re-lanzar la app tras un cached-kill de ColorOS, y la UI de
        // lanzamiento para el aviso honesto de restauración.
        usrDir.parentFile?.let { RuntimeHeartbeat.markAlive(it) }

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
        // U-9: aterm del rootfs NO linkea libXft — el -fn "xft:DejaVu Sans Mono"
        // anterior se ignoraba (0 maps fontconfig/freetype en /proc/<pid>/maps)
        // y aterm caía a "fixed" sin fontpath en el Xvnc: glifos basura
        // (bloques/corchetes, evidencia captura 2026-08-13). Fix doble:
        // -fp con misc+75dpi del rootfs en XServerBackend.kt y aquí -fn fixed,
        // la fuente bitmap con fonts.dir real. En 864px (~144 cols) el HUD y
        // el shell se ven completos sin wrap.
        val bigFont = listOf("-fn", "fixed")
        val colors = listOf("-bg", "#030711", "-fg", "#E9F1FA")
        // Terminal de bienvenida: muestra el HUD (banner nano-sec con info real
        // del sistema vía /proc) y deja el shell interactivo debajo. El
        // watchdog granular re-lanza la terminal con el MISMO argv, así el
        // banner vuelve a aparecer si la terminal muere.
        val hud = "python3 ${File(usrDir.parentFile, "home/.hud.py").absolutePath}"
        val shellCmd = "$hud; exec bash -i"
        // Trim 2026-08-14: fuera el fallback aterm — ya no se instala
        // (DESKTOP_PACKAGES) y el escritorio lo eliminó de la allowlist.
        val candidates = listOf(
            TerminalLaunch(File(usrDir, "bin/lxterminal"), listOf("lxterminal", "-e", "sh", "-c", shellCmd)),
            TerminalLaunch(
                File(usrDir, "bin/xterm"),
                listOf("xterm") + bigFont + colors + listOf("-e", "sh", "-c", shellCmd),
            ),
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
        killPid(openboxPid); openboxPid = -1
        killPid(fehPid);     fehPid     = -1
        killPid(dbusPid);    dbusPid    = -1
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
                    // openbox/feh antes quedaban sin vigilancia: "ready"
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
                    // feh --bg-scale es one-shot: aplica el fondo y SALE
                    // (exit 0). No es daemon persistente — vigilarlo aquí
                    // producía re-spawn infinito cada 5s: feh terminaba su
                    // trabajo, el watchdog lo veía "muerto" y lo re-lanzaba
                    // para siempre (evidencia OPPO 2026-08-13, reaper status=0
                    // + stderr vacío en cadencia exacta de 5s). Si el fondo
                    // se pierde (reset de X), se re-aplica al reconectar la
                    // sesión completa — no en el watchdog.
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
                      <action name="Execute"><execute>lxterminal -e sh -c "python3 $hudPy; exec bash -i"</execute></action>
                    </item>
                    <item label="Terminal">
                      <action name="Execute"><execute>lxterminal -e sh -c "exec bash -i"</execute></action>
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

    // Configuración rc.xml de openbox + tema NanoAI (themerc en ~/.themes).
    // Sin compositor (no picom): transparencias y sombras se SIMULAN con
    // colores semitransparentes y planos — glassmorphism real no existe en
    // X11 sin compositor y el consumo gráfico subiría en VNC.
    private fun setupOpenboxRc() {
        try {
            val homeDir = File(usrDir.parentFile, "home")
            val obDir = File(homeDir, ".config/openbox").also { it.mkdirs() }
            val rcXml = File(obDir, "rc.xml")
            // rc.xml: tema NanoAI, DejaVu Sans. Animaciones/sombras fuera:
            // performance primero en VNC.
            rcXml.writeText("""
                <?xml version="1.0" encoding="UTF-8"?>
                <openbox_config xmlns="http://openbox.org/3.4/rc">
                  <theme>
                    <name>NanoAI</name>
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

            // themerc NanoAI: barra de título azul noche, título activo en
            // verde #21F2B2, borde cyan #42D9FF, menús oscuros con items
            // activos en verde. Paleta de la identidad nanoai (#020611 base).
            val themeDir = File(homeDir, ".themes/NanoAI/openbox-3")
                .also { it.mkdirs() }
            File(themeDir, "themerc").writeText("""
                ! Tema NanoAI — identidad nanoai para openbox 3
                ! Fondo base de la identidad: #020611 (azul noche casi negro)
                window.active.title.bg: flat solid
                window.active.title.bg.color: #07192B
                window.active.title.fg.color: #21F2B2
                window.inactive.title.bg: flat solid
                window.inactive.title.bg.color: #06101E
                window.inactive.title.fg.color: #7A8BA0
                window.active.border.color: #42D9FF
                window.inactive.border.color: #1E3550
                window.client.color: #020611
                window.handle.width: 4
                border.width: 2
                menu.items.bg: flat solid
                menu.items.bg.color: #06101E
                menu.items.text.color: #E9F1FA
                menu.items.active.bg: flat solid
                menu.items.active.bg.color: #0B2438
                menu.items.active.text.color: #21F2B2
                menu.border.color: #42D9FF
                menu.title.bg: flat solid
                menu.title.bg.color: #07192B
                menu.title.text.color: #21F2B2
            """.trimIndent())
            Log.i(TAG, "openbox rc.xml + themerc NanoAI escritos")
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
                gtk-font-name=DejaVu Sans 16
                gtk-application-prefer-dark-theme=1
                gtk-enable-animations=0
                gtk-toolbar-style=GTK_TOOLBAR_ICONS
                gtk-button-images=1
                gtk-menu-images=1
            """.trimIndent())
            Log.i(TAG, "GTK settings.ini escrito (fuente 14px, tema oscuro)")
        } catch (e: Exception) {
            Log.w(TAG, "setupGtkTheme: ${e.message}")
        }
    }

    private fun setupLxTerminalConfig() {
        try {
            val lxDir = File(File(usrDir.parentFile, "home"), ".config/lxterminal")
                .also { it.mkdirs() }
            val lxConf = File(lxDir, "lxterminal.conf")
            lxConf.writeText("""
                [general]
                fontname=DejaVu Sans Mono 14
                bgcolor=#030711
                fgcolor=#E9F1FA
                scrollback=5000
                cursorblinks=true
                disallowbold=true
                selectbyword=true
            """.trimIndent())
            Log.i(TAG, "lxterminal.conf escrito (DejaVu Sans Mono 14, paleta NanoAI)")
        } catch (e: Exception) {
            Log.w(TAG, "setupLxTerminalConfig: ${e.message}")
        }
    }

    // Wallpaper por aspect (D-3): el PNG nano-cyber es 1280x720 landscape.
    // Si el framebuffer es portrait (device móvil), --bg-fill recortaría el
    // PNG a la franja central y --bg-scale estiraría el patrón ~3x — en ambos
    // casos el diseño se destruye. Solo se usa el PNG cuando el aspect casa
    // (±5%, leído del header IHDR); si no, cae al PPM gradiente vertical
    // (32x32, --bg-scale suave sin distorsión visible).
    private fun wallpaperForLaunch(): Pair<File, String> {
        val homeDir = File(usrDir.parentFile, "home")
        val png = File(homeDir, ".nano-wallpaper.png")
        val ppm = File(homeDir, ".nano-wallpaper.ppm")
        if (png.exists() && png.length() > 10000 && pngMatchesAspect(png)) {
            return png to "--bg-fill"
        }
        return ppm to "--bg-scale"
    }

    private fun pngMatchesAspect(png: File): Boolean {
        if (fbWidth <= 0 || fbHeight <= 0) return false
        return try {
            // IHDR: ancho BE u32 en bytes 16-19, alto BE u32 en bytes 20-23.
            val hdr = ByteArray(24)
            png.inputStream().use { ins ->
                var off = 0
                while (off < hdr.size) {
                    val n = ins.read(hdr, off, hdr.size - off)
                    if (n < 0) return false
                    off += n
                }
            }
            fun be32(i: Int): Int = ((hdr[i].toInt() and 0xFF) shl 24) or
                ((hdr[i + 1].toInt() and 0xFF) shl 16) or
                ((hdr[i + 2].toInt() and 0xFF) shl 8) or
                (hdr[i + 3].toInt() and 0xFF)
            val w = be32(16)
            val h = be32(20)
            if (w <= 0 || h <= 0) return false
            val ratio = (w.toDouble() / h) / (fbWidth.toDouble() / fbHeight)
            ratio in 0.95..1.05
        } catch (e: Exception) {
            false
        }
    }

    // Wallpaper: Genera SIEMPRE un PPM P6 (32x32 px) con el gradiente de la
    // identidad nanoai: #020611 (azul noche base) hacia #022A2D (verde azulado
    // profundo). feh --bg-scale lo escala suavemente sin pixelar. Sin
    // early-return: es un archivo diminuto y así los cambios de diseño
    // sobreviven a booteos previos.
    private fun setupWallpaper() {
        try {
            val homeDir = File(usrDir.parentFile, "home").also { it.mkdirs() }
            val ppm = File(homeDir, ".nano-wallpaper.ppm")
            val w = 32
            val h = 32
            val header = "P6\n$w $h\n255\n".toByteArray(Charsets.US_ASCII)
            val pixels = ByteArray(w * h * 3)
            var idx = 0
            for (y in 0 until h) {
                val factor = y.toDouble() / (h - 1)
                // Gradiente: #020611 (2, 6, 17) -> #022A2D (2, 42, 45)
                val r = (2 + factor * (2 - 2)).toInt().coerceIn(0, 255)
                val g = (6 + factor * (42 - 6)).toInt().coerceIn(0, 255)
                val b = (17 + factor * (45 - 17)).toInt().coerceIn(0, 255)
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
            Log.i(TAG, "wallpaper PPM gradiente NanoAI escrito")
        } catch (e: Exception) {
            Log.w(TAG, "setupWallpaper: ${e.message}")
        }
    }
}
