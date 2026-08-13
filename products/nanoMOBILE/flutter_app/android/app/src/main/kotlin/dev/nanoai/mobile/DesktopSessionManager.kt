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

    private val backend: XServerBackend = InternalXvncBackend(usrDir, spawnBg)

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

        // Wallpaper feh (PPM 1x1 color oscuro escalado a pantalla completa).
        // Sin fondo el root de X es un ruido de píxeles heredado; feh aplica
        // el pixmap propio sin depender de xsetroot (no instalado).
        val fehBin = File(usrDir, "bin/feh")
        val wallpaper = File(usrDir.parentFile, "home/.nano-wallpaper.ppm")
        if (fehBin.exists() && wallpaper.exists()) {
            spawnBg(fehBin.absolutePath, listOf("feh", "--bg-scale", wallpaper.absolutePath), wmEnv)
            Log.i(TAG, "feh wallpaper aplicado")
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
        val candidates = listOf(
            TerminalLaunch(File(usrDir, "bin/xterm"), listOf("xterm") + bigFont + listOf("-bg", "#0d1117", "-fg", "#00ff9d")),
            TerminalLaunch(File(usrDir, "bin/aterm"), listOf("aterm") + bigFont + listOf("-bg", "#0d1117", "-fg", "#00ff9d")),
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
                } catch (e: InterruptedException) {
                    // stopWatchdog() llamó interrupt() — salida limpia.
                    break
                } catch (e: Exception) {
                    if (stopRequested || !running) break
                    Log.w(TAG, "Watchdog: puerto VNC $vncPort no responde — Xvnc puede haber caído")
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
            val configDir = File(usrDir, "etc/xdg/tint2").also { it.mkdirs() }
            val tint2Rc   = File(configDir, "tint2rc")
            // Siempre se reescribe: versiones previas de la app escribieron
            // un panel de 36px con fuentes chicas; al existir el archivo, el
            // guard `if (!exists)` de antes lo dejaba congelado en la versión
            // vieja. Config móvil: panel alto (46px) y fuentes DejaVu legibles.
            tint2Rc.writeText("""
                panel_position = bottom center horizontal
                panel_size = 100% 46
                panel_margin = 0 0
                panel_background_id = 1
                panel_dock = 0
                font_shadow = 0
                panel_color = #0f141d 100
                taskbar_mode = single_desktop
                task_text = 1
                task_maximum_size = 280 44
                task_font = DejaVu Sans 11
                clock_enabled = 1
                clock_format = %H:%M
                clock_font = DejaVu Sans 12
                clock_color = #00ff9d 100
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
            // Siempre se reescribe (mismo motivo que tint2rc): el menú quedó
            // congelado en la versión sin la fuente Xft grande del aterm.
            menuXml.writeText("""
                <?xml version="1.0" encoding="UTF-8"?>
                <openbox_menu xmlns="http://openbox.org/3.4/menu">
                  <menu id="root-menu" label="NanoAI">
                    <item label="Terminal">
                      <action name="Execute"><execute>aterm -fn "xft:DejaVu Sans Mono:pixelsize=14" -bg #0d1117 -fg #00ff9d</execute></action>
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

    // Tema GTK móvil: fuente DejaVu Sans 14 + tema oscuro para pcmanfm,
    // mousepad y demás apps GTK3. El DPI viene del servidor X (Xvnc -dpi
    // 110); esta fuente agranda menús y listas para dedos en pantalla.
    private fun setupGtkTheme() {
        try {
            val gtkDir = File(File(usrDir.parentFile, "home"), ".config/gtk-3.0")
                .also { it.mkdirs() }
            val settingsIni = File(gtkDir, "settings.ini")
            if (!settingsIni.exists()) {
                settingsIni.writeText("""
                    [Settings]
                    gtk-font-name=DejaVu Sans 14
                    gtk-application-prefer-dark-theme=1
                """.trimIndent())
                Log.i(TAG, "GTK settings.ini escrito (fuente 14px, tema oscuro)")
            }
        } catch (e: Exception) {
            Log.w(TAG, "setupGtkTheme: ${e.message}")
        }
    }

    // Wallpaper: PPM 1x1 (#0d1117) para que feh --bg-scale pinte el fondo.
    // PPM es texto plano + bytes RGB: no necesita encoder PNG.
    private fun setupWallpaper() {
        try {
            val homeDir = File(usrDir.parentFile, "home").also { it.mkdirs() }
            val ppm = File(homeDir, ".nano-wallpaper.ppm")
            if (!ppm.exists()) {
                val body = byteArrayOf(
                    0x0D, 0x11, 0x17 // #0d1117
                )
                val header = "P6\n1 1\n255\n".toByteArray(Charsets.US_ASCII)
                ppm.outputStream().use { out ->
                    out.write(header)
                    out.write(body)
                }
                Log.i(TAG, "wallpaper PPM escrito")
            }
        } catch (e: Exception) {
            Log.w(TAG, "setupWallpaper: ${e.message}")
        }
    }
}
