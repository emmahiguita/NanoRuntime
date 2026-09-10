package dev.nanoai.mobile

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.util.Log
import dev.nanoai.mobile.services.XServerBackend
import dev.nanoai.mobile.services.InternalXvncBackend
import java.io.File
import java.nio.file.Files
import java.nio.file.Paths
import java.nio.file.StandardCopyOption
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
    // BUG-2 FIX: kill de daemons detached delegado al worker. Android 12+
    // restringe Process.killProcess a procesos propios — los daemons son
    // hijos del worker (:nanoshell), el kill local lanzaba SecurityException
    // (tragada) y dejaba Xvnc huérfano ocupando 5901. False = no se pudo.
    // (Nombre *_Delegate: hay un método privado killPid(pid) en esta clase.)
    private val killPidDelegate: (Long) -> Boolean = { false },
) {
    companion object {
        private const val TAG = "desktop-session"
        const val DEFAULT_WIDTH   = 1280
        const val DEFAULT_HEIGHT  = 720
        const val DESKTOP_CONFIG_VERSION = 8
        private const val DESKTOP_CONFIG_MARKER =
            "nano/home/.nano-managed/desktop-config.version"

        /** Estado persistido de los archivos Nano-managed, incluso si la
         * sesión que los creó ya no pertenece al proceso Android actual. */
        fun isManagedConfigCurrent(appFilesDir: File): Boolean = try {
            File(appFilesDir, DESKTOP_CONFIG_MARKER).readText().trim().toIntOrNull() ==
                DESKTOP_CONFIG_VERSION
        } catch (_: Exception) {
            false
        }
    }

    @Volatile private var openboxPid: Long = -1
    @Volatile private var terminalPid: Long = -1
    @Volatile private var tint2Pid: Long   = -1
    @Volatile private var pcmanfmPid: Long = -1
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
    @Volatile private var lastWmEnv: MutableMap<String, String> = mutableMapOf()

    val currentStage: String get() = stage
    val currentError: String? get() = lastError

    // Watchdog: monitoriza salud del proceso Xvnc. Si el puerto VNC deja de
    // responder, resetea `running` para que la próxima llamada a start()
    // pueda reiniciar todo limpiamente.
    private var watchdogThread: Thread? = null

    private val backend: XServerBackend = InternalXvncBackend(usrDir, spawnBg, vncPassword, isPidAlive, killPidDelegate)

    // ── Entorno base ─────────────────────────────────────────────────────────

    private fun baseEnv(display: String): MutableMap<String, String> {
        val lib    = usrDir.absolutePath + "/lib"
        val libCan = usrDir.canonicalPath + "/lib"
        // BUG-4 FIX: estaba hardcodeado "/data/data/dev.nanoai.mobile/files/
        // nano/usr/lib". Android expone files/ como /data/user/0/<pkg> pero
        // algunos loaders nativos resuelven /data/data/<pkg> (symlink).
        // Derivar la variante del usrDir real: sin hardcodear el package y
        // sin romper si el path ya viene por /data/data/ (replace no-op).
        val libAlt = usrDir.path.replace("/data/user/0/", "/data/data/") + "/lib"
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
            // DESKTOP-FULL-01: NO cambiar a es_ES.UTF-8 — el rootfs Termux no
            // trae ese locale (verificado device: 0 archivos .mo en usr/share/
            // locale) y setlocale fallaría a "C" rompiendo el UTF-8 en TODAS
            // las apps. LANGUAGE=es es gettext-only (no pasa por setlocale):
            // hoy es no-op honesto, mañana activa español si llegan .mo.
            // El español visible es el de los textos PROPIOS: menú openbox,
            // hud.py, lanzadores del panel tint2.
            "LANG"             to "en_US.UTF-8",
            "LANGUAGE"         to "es",
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

    // AND-012 FIX: Extraer funciones de startInternalImpl para cumplir SRP
    
    private fun setupX11Environment(tmpDir: File): String {
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
        return displayStr
    }
    
    private fun launchDBusSession(tmpDir: File, wmEnv: MutableMap<String, String>) {
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
    }
    
    private fun launchWindowManager(wmEnv: Map<String, String>, onStatus: (String) -> Unit): Boolean {
        // Lanzar openbox
        val openboxBin = File(usrDir, "bin/openbox")
        if (openboxBin.exists()) {
            openboxBin.setExecutable(true, false)
            openboxPid = spawnBg(openboxBin.absolutePath, listOf("openbox"), wmEnv)
            Log.i(TAG, "openbox PID=$openboxPid")
            onStatus("openbox arrancado (PID=$openboxPid)")
            return true
        } else {
            Log.w(TAG, "openbox no encontrado")
            return false
        }
    }
    
    private fun launchWallpaper(wmEnv: Map<String, String>) {
        // Wallpaper: sin fondo el root de X es ruido de píxeles heredado;
        // feh aplica el pixmap propio sin depender de xsetroot (no instalado).
        val fehBin = File(usrDir, "bin/feh")
        val (wallpaper, wallFlag) = wallpaperForLaunch()
        if (fehBin.exists() && wallpaper.exists()) {
            val pid = spawnBg(
                fehBin.absolutePath,
                listOf("feh", wallFlag, wallpaper.absolutePath),
                wmEnv,
            )
            // feh --bg-* es one-shot: no conservar un PID ya reapeado que
            // podría reutilizarse y terminar otro proceso durante cleanup.
            Log.i(TAG, "feh wallpaper aplicado ($wallFlag ${wallpaper.name}, PID=$pid)")
        }
    }

    private fun launchDesktopIcons(wmEnv: Map<String, String>) {
        // DESKTOP-FIT-01: iconos del escritorio vía pcmanfm --desktop
        // (gestor real LXDE: muestra ~/Escritorio con los .desktop propios).
        // Transparente: el fondo lo pinta feh en el root de X, sin conflicto.
        val pcBin = File(usrDir, "bin/pcmanfm")
        if (pcBin.exists()) {
            pcBin.setExecutable(true, false)
            pcmanfmPid = spawnBg(pcBin.absolutePath, listOf("pcmanfm", "--desktop"), wmEnv)
            Log.i(TAG, "pcmanfm --desktop PID=$pcmanfmPid")
        } else {
            Log.w(TAG, "pcmanfm no instalado — escritorio sin iconos este arranque")
        }
    }

    private fun launchTint2(wmEnv: Map<String, String>) {
        // DESKTOP-FULL-01: panel inferior (lanzadores + tareas + reloj).
        // Si no está instalado (device existente antes del incremental),
        // se omite en silencio — el gate graphicalExtras lo instala y el
        // próximo arranque lo trae. tint2 es daemon persistente: sí entra
        // al watchdog granular.
        val tint2Bin = File(usrDir, "bin/tint2")
        if (tint2Bin.exists()) {
            tint2Bin.setExecutable(true, false)
            val config = File(usrDir.parentFile, "home/.config/tint2/tint2rc")
            tint2Pid = spawnBg(
                tint2Bin.absolutePath,
                listOf("tint2", "-c", config.absolutePath),
                wmEnv,
            )
            Log.i(TAG, "tint2 panel PID=$tint2Pid")
        } else {
            Log.w(TAG, "tint2 no instalado — panel omitido este arranque")
        }
    }
    
    private fun launchTerminal(wmEnv: Map<String, String>, onStatus: (String) -> Unit) {
        // Lanzar terminal gráfica
        val terminal = firstExistingTerminal()
        if (terminal != null) {
            terminal.file.setExecutable(true, false)
            terminalPid = spawnBg(terminal.file.absolutePath, terminal.argv, wmEnv)
            Log.i(TAG, "terminal ${terminal.file.name} PID=$terminalPid")
            onStatus("terminal ${terminal.file.name} arrancada (PID=$terminalPid)")
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

        // 2. Configurar entorno X11
        val displayStr = setupX11Environment(tmpDir)

        onStatus("Iniciando backend gráfico (Xvnc)...")
        stage = "xvnc"

        // BUG-1 FIX: el `return@runBlocking` anterior solo salía del lambda
        // del runBlocking — el flujo CONTINUABA a stage="rfb" y awaitReady()
        // tras el fallo, produciendo doble onError y cleanup doble. Manejar
        // el fallo FUERA del bloque y retornar de startInternalImpl de verdad.
        val backendOk = runBlocking { backend.start(baseEnv(displayStr), width, height) }
        if (!backendOk) {
            val msg = "Fallo al iniciar el backend del servidor X11."
            lastError = msg
            stage = "failed"
            onError(msg)
            cleanupProcesses()
            runBlocking { backend.stop() }
            starting = false
            return
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

        provisionManagedDesktopConfig()

        // 3. Lanzar D-Bus session bus
        launchDBusSession(tmpDir, lastWmEnv)

        // 4. Lanzar window manager
        if (!launchWindowManager(lastWmEnv, onStatus)) {
            // Continuar aunque openbox falle
        }
        
        // BUG-5 FIX: sleep fijo no es criterio de readiness. Tras la espera,
        // verificar salud del openboxPid vía worker y re-lanzar UNA vez si
        // murió (mismo patrón que la terminal en launchTerminal: /proc check
        // a los 500ms con re-spawn).
        Thread.sleep(800)
        if (openboxPid > 0 && !isPidAlive(openboxPid)) {
            Log.w(TAG, "openbox PID=$openboxPid murió tras el spawn — re-lanzando")
            launchWindowManager(lastWmEnv, onStatus)
        }
        if (abortIfStopped("after-openbox-wait", onError)) return

        // 5. Aplicar wallpaper (feh pinta el root; pcmanfm --desktop es
        // transparente y deja verlo — sin conflicto de fondos).
        launchWallpaper(lastWmEnv)

        // 5.4 Iconos del escritorio (pcmanfm --desktop, look LXDE real)
        launchDesktopIcons(lastWmEnv)

        // 5.5 Panel de tareas inferior (lanzadores + tareas + reloj)
        launchTint2(lastWmEnv)

        // 6. Lanzar terminal
        launchTerminal(lastWmEnv, onStatus)
        if (abortIfStopped("after-terminal-spawn", onError)) return

        // Readiness del producto, no sólo del socket Xvnc. Sin esta barrera
        // se reportaba "ready" aunque tint2 hubiese caído por su config/icono
        // o la terminal hubiese muerto inmediatamente, dejando exactamente el
        // framebuffer negro/incompleto observado en el dispositivo.
        Thread.sleep(700)
        val deadComponents = listOf(
            "openbox" to openboxPid,
            "tint2" to tint2Pid,
            "pcmanfm" to pcmanfmPid,
            "terminal" to terminalPid,
        ).filter { (_, pid) -> pid <= 0 || !isPidAlive(pid) }
        if (deadComponents.isNotEmpty()) {
            throw java.io.IOException(
                "Componentes gráficos no permanecieron vivos: " +
                    deadComponents.joinToString { it.first },
            )
        }

        if (abortIfStopped("before-ready", onError)) return
        // K-6: raza start/stop. `running=true` se escribía FUERA del lock tras
        // el último abortIfStopped: un stop() concurrente (ve starting=true →
        // procede a matar PIDs y pone starting=false) podía intercalarse entre
        // el check y estas líneas → desktop "ready" con PIDs muertos. La
        // transición final debe ser atómica con stopRequested bajo el MISMO
        // lock que stop().
        // AND-014: synchronized(this) es el MISMO monitor que @Synchronized
        // (azúcar sintáctica). Inline es obligatorio aquí: la sección crítica
        // está dentro de una función, no en un método completo.
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
        if (pid <= 0) return
        // BUG-2 FIX: todos los daemons del desktop (openbox/terminal/feh/
        // dbus/Xvnc) son hijos del worker :nanoshell. El kill local
        // Process.killProcess falla en Android 12+ (proceso ajeno) — delegar
        // al worker, que los valida contra g_daemons y hace SIGKILL real.
        if (killPidDelegate(pid)) return
        // Fallback: cubre un spawn local o worker caído. No puede matar
        // hijos del worker, pero es lo único disponible en ese caso.
        try { android.os.Process.killProcess(pid.toInt()) }
        catch (e: Exception) { Log.w(TAG, "kill $pid: ${e.message}") }
    }

    @Synchronized
    private fun cleanupProcesses() {
        stopWatchdog()
        killPid(terminalPid); terminalPid = -1
        killPid(openboxPid); openboxPid = -1
        killPid(tint2Pid);   tint2Pid   = -1
        killPid(pcmanfmPid); pcmanfmPid = -1
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
            var terminalRestarts = 0
            var openboxRestarts = 0
            var tint2Restarts = 0
            var pcmanfmRestarts = 0
            val maxComponentRestarts = 2
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
                    if (tPid > 0 && !isPidAlive(tPid)) {
                        if (terminalRestarts >= maxComponentRestarts) {
                            Log.e(TAG, "Watchdog: terminal agotó $maxComponentRestarts reintentos")
                            terminalPid = -1
                            continue
                        }
                        terminalRestarts++
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
                    if (obPid > 0 && !isPidAlive(obPid)) {
                        if (openboxRestarts >= maxComponentRestarts) {
                            throw java.io.IOException(
                                "openbox agotó $maxComponentRestarts reintentos",
                            )
                        }
                        openboxRestarts++
                        Log.w(TAG, "Watchdog: openbox PID=$obPid muerto — re-lanzando")
                        openboxPid = -1
                        val ob = File(usrDir, "bin/openbox")
                        if (ob.exists() && lastWmEnv.isNotEmpty()) {
                            ob.setExecutable(true, false)
                            openboxPid = spawnBg(ob.absolutePath, listOf("openbox"), lastWmEnv)
                            Log.i(TAG, "Watchdog: openbox re-lanzado PID=$openboxPid")
                        }
                    }
                    // tint2 es daemon persistente — mismo patrón que openbox.
                    val t2Pid = tint2Pid
                    if (t2Pid > 0 && !isPidAlive(t2Pid)) {
                        if (tint2Restarts >= maxComponentRestarts) {
                            throw java.io.IOException(
                                "tint2 agotó $maxComponentRestarts reintentos",
                            )
                        }
                        tint2Restarts++
                        Log.w(TAG, "Watchdog: tint2 PID=$t2Pid muerto — re-lanzando")
                        tint2Pid = -1
                        val t2 = File(usrDir, "bin/tint2")
                        if (t2.exists() && lastWmEnv.isNotEmpty()) {
                            t2.setExecutable(true, false)
                            val config = File(usrDir.parentFile, "home/.config/tint2/tint2rc")
                            tint2Pid = spawnBg(
                                t2.absolutePath,
                                listOf("tint2", "-c", config.absolutePath),
                                lastWmEnv,
                            )
                            Log.i(TAG, "Watchdog: tint2 re-lanzado PID=$tint2Pid")
                        }
                    }
                    // pcmanfm --desktop es daemon persistente — mismo patrón.
                    val pcPid = pcmanfmPid
                    if (pcPid > 0 && !isPidAlive(pcPid)) {
                        if (pcmanfmRestarts >= maxComponentRestarts) {
                            Log.e(TAG, "Watchdog: pcmanfm agotó $maxComponentRestarts reintentos")
                            pcmanfmPid = -1
                            continue
                        }
                        pcmanfmRestarts++
                        Log.w(TAG, "Watchdog: pcmanfm --desktop PID=$pcPid muerto — re-lanzando")
                        pcmanfmPid = -1
                        val pc = File(usrDir, "bin/pcmanfm")
                        if (pc.exists() && lastWmEnv.isNotEmpty()) {
                            pc.setExecutable(true, false)
                            pcmanfmPid = spawnBg(pc.absolutePath, listOf("pcmanfm", "--desktop"), lastWmEnv)
                            Log.i(TAG, "Watchdog: pcmanfm --desktop re-lanzado PID=$pcmanfmPid")
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
                    Log.w(TAG, "Watchdog: sesión gráfica inválida: ${e.message}")
                    running = false
                    stage = "failed"
                    lastError =
                        "Sesión gráfica dejó de responder: ${e.message} (puerto $vncPort)"
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

    /** Provisiona exclusivamente archivos que pertenecen a Nano. Se ejecuta
     * antes de lanzar Openbox para que una actualización nunca reutilice una
     * sesión con configuración anterior. Los documentos y dotfiles ajenos a
     * esta lista no se leen ni se sobrescriben. */
    private fun provisionManagedDesktopConfig() {
        setupOpenboxMenu()
        setupOpenboxRc()
        setupWallpaper()
        setupGtkTheme()
        setupLxTerminalConfig()
        setupTint2Config()
        setupPcmanfmDesktop()

        val homeDir = File(usrDir.parentFile, "home")
        val required = listOf(
            ".config/openbox/menu.xml",
            ".config/openbox/rc.xml",
            ".themes/NanoMobile/openbox-3/themerc",
            ".config/gtk-3.0/settings.ini",
            ".config/lxterminal/lxterminal.conf",
            ".config/tint2/tint2rc",
            ".config/pcmanfm/default/pcmanfm.conf",
            ".config/libfm/libfm.conf",
            ".nano-wallpaper.png",
        ).map { File(homeDir, it) }
        val missing = required.filter { !it.isFile || it.length() == 0L }
        if (missing.isNotEmpty()) {
            throw java.io.IOException(
                "Configuración Nano incompleta: ${missing.joinToString { it.name }}",
            )
        }

        writeManagedText(
            File(homeDir, ".nano-managed/desktop-config.version"),
            "$DESKTOP_CONFIG_VERSION\n",
        )
        Log.i(TAG, "desktop config version=$DESKTOP_CONFIG_VERSION aplicada")
    }

    /** Reemplazo atomic-ish en el mismo filesystem. Si ATOMIC_MOVE no está
     * disponible, REPLACE_EXISTING mantiene el target acotado al archivo
     * Nano-managed recibido. */
    private fun writeManagedText(target: File, content: String) {
        target.parentFile?.mkdirs()
        val temporary = File(target.parentFile, ".${target.name}.nano-tmp")
        temporary.writeText(content)
        try {
            Files.move(
                temporary.toPath(),
                target.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } catch (_: Exception) {
            Files.move(
                temporary.toPath(),
                target.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
        }
    }

    // Menú de openbox (clic derecho en el escritorio) con las apps gráficas
    // instaladas. openbox lee $HOME/.config/openbox/menu.xml por defecto.
    private fun setupOpenboxMenu() {
        try {
            val homeDir = File(usrDir.parentFile, "home")
            val obDir = File(homeDir, ".config/openbox").also { it.mkdirs() }
            val menuXml = File(obDir, "menu.xml")
            writeManagedText(menuXml, """
                <?xml version="1.0" encoding="UTF-8"?>
                <openbox_menu xmlns="http://openbox.org/3.4/menu">
                  <menu id="root-menu" label="Nano Linux">
                    <separator label="APLICACIONES"/>
                    <item label="Terminal">
                      <action name="Execute"><execute>lxterminal -e sh -c "exec bash -i"</execute></action>
                    </item>
                    <item label="Archivos">
                      <action name="Execute"><execute>pcmanfm</execute></action>
                    </item>
                    <item label="Editor">
                      <action name="Execute"><execute>mousepad</execute></action>
                    </item>
                    <separator label="SISTEMA"/>
                    <item label="Información de Nano">
                      <action name="Execute"><execute>lxterminal -e sh -c "nano-info; printf '\n'; exec bash -i"</execute></action>
                    </item>
                    <item label="Recargar escritorio">
                      <action name="Reconfigure"/>
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
            val panelHeight = desktopPanelHeight()
            val availableHeight = (fbHeight - panelHeight).coerceAtLeast(320)
            val terminalWidth = (fbWidth * 88 / 100)
                .coerceIn(320, (fbWidth - 32).coerceAtLeast(320))
            val terminalHeight = (availableHeight * 46 / 100)
                .coerceIn(260, (availableHeight - 32).coerceAtLeast(260))
            // rc.xml: tema NanoAI, DejaVu Sans. Animaciones/sombras fuera:
            // performance primero en VNC.
            writeManagedText(rcXml, """
                <?xml version="1.0" encoding="UTF-8"?>
                <openbox_config xmlns="http://openbox.org/3.4/rc">
                  <theme>
                    <name>NanoMobile</name>
                    <titleLayout>NLIMC</titleLayout>
                    <keepBorder>yes</keepBorder>
                    <font place="ActiveWindow">
                      <name>DejaVu Sans</name>
                      <size>16</size>
                      <weight>Bold</weight>
                    </font>
                    <font place="InactiveWindow">
                      <name>DejaVu Sans</name>
                      <size>16</size>
                      <weight>Normal</weight>
                    </font>
                    <font place="MenuHeader">
                      <name>DejaVu Sans</name>
                      <size>16</size>
                      <weight>Bold</weight>
                    </font>
                    <font place="MenuItem">
                      <name>DejaVu Sans</name>
                      <size>16</size>
                      <weight>Normal</weight>
                    </font>
                    <font place="OnScreenDisplay">
                      <name>DejaVu Sans</name>
                      <size>16</size>
                      <weight>Bold</weight>
                    </font>
                  </theme>
                  <focus>
                    <focusNew>yes</focusNew>
                    <followMouse>no</followMouse>
                    <raiseOnFocus>no</raiseOnFocus>
                  </focus>
                  <placement>
                    <policy>Smart</policy>
                    <center>yes</center>
                    <monitor>Primary</monitor>
                  </placement>
                  <!-- Reserva administrada por Nano. tint2 corre fuera del
                       dock interno de Openbox para no generar un strut lateral
                       inválido en framebuffers portrait. -->
                  <margins>
                    <top>$panelHeight</top>
                    <bottom>0</bottom>
                    <left>0</left>
                    <right>0</right>
                  </margins>
                  <keyboard>
                    <chainQuitKey>C-g</chainQuitKey>
                    <keybind key="A-F4"><action name="Close"/></keybind>
                    <keybind key="A-Tab"><action name="NextWindow"/></keybind>
                    <keybind key="C-Menu S-F10">
                      <action name="ShowMenu"><menu>root-menu</menu></action>
                    </keybind>
                  </keyboard>
                  <mouse>
                    <context name="Root">
                      <mousebind button="Right" action="Press">
                        <action name="ShowMenu"><menu>root-menu</menu></action>
                      </mousebind>
                    </context>
                    <context name="Titlebar">
                      <mousebind button="Left" action="Press">
                        <action name="Focus"/><action name="Raise"/>
                      </mousebind>
                      <mousebind button="Left" action="Drag">
                        <action name="Move"/>
                      </mousebind>
                      <mousebind button="Left" action="DoubleClick">
                        <action name="ToggleMaximize"/>
                      </mousebind>
                    </context>
                    <context name="Close">
                      <mousebind button="Left" action="Release"><action name="Close"/></mousebind>
                    </context>
                    <context name="Iconify">
                      <mousebind button="Left" action="Release"><action name="Iconify"/></mousebind>
                    </context>
                    <context name="Maximize">
                      <mousebind button="Left" action="Release"><action name="ToggleMaximize"/></mousebind>
                    </context>
                  </mouse>
                  <applications>
                    <application class="Lxterminal" type="normal">
                      <position force="yes">
                        <x>center</x>
                        <y>${panelHeight + 24}</y>
                        <monitor>all</monitor>
                      </position>
                      <size>
                        <width>$terminalWidth</width>
                        <height>$terminalHeight</height>
                      </size>
                      <maximized>no</maximized>
                      <decor>yes</decor>
                    </application>
                  </applications>
                  <menu>
                    <file>menu.xml</file>
                    <hideDelay>250</hideDelay>
                    <middle>no</middle>
                  </menu>
                </openbox_config>
            """.trimIndent())

            // Tema completo sin texturas/alpha: barato para Xvnc y con
            // controles suficientemente contrastados para interacción táctil.
            val themeDir = File(homeDir, ".themes/NanoMobile/openbox-3")
                .also { it.mkdirs() }
            writeManagedText(File(themeDir, "themerc"), """
                ! Nano Linux Mobile — Openbox 3
                border.width: 1
                padding.width: 12
                padding.height: 10
                window.handle.width: 6
                window.active.title.bg: flat solid
                window.active.title.bg.color: #0B1B2B
                window.inactive.title.bg: flat solid
                window.inactive.title.bg.color: #08131F
                window.active.label.bg: parentrelative
                window.inactive.label.bg: parentrelative
                window.active.label.text.color: #F2F7FB
                window.inactive.label.text.color: #8091A3
                window.active.border.color: #2CB7D8
                window.inactive.border.color: #203447
                window.active.client.color: #0A111A
                window.inactive.client.color: #0A111A
                window.active.handle.bg: flat solid
                window.active.handle.bg.color: #0B1B2B
                window.inactive.handle.bg: flat solid
                window.inactive.handle.bg.color: #08131F
                window.active.grip.bg: parentrelative
                window.inactive.grip.bg: parentrelative
                window.active.button.unpressed.bg: flat solid
                window.active.button.unpressed.bg.color: #123047
                window.active.button.hover.bg: flat solid
                window.active.button.hover.bg.color: #19607A
                window.active.button.pressed.bg: flat solid
                window.active.button.pressed.bg.color: #22A7C7
                window.active.button.unpressed.image.color: #E8F7FB
                window.active.button.hover.image.color: #FFFFFF
                window.active.button.pressed.image.color: #041017
                window.inactive.button.unpressed.bg: flat solid
                window.inactive.button.unpressed.bg.color: #101E2B
                window.inactive.button.unpressed.image.color: #718397
                menu.items.bg: flat solid
                menu.items.bg.color: #0A1521
                menu.items.text.color: #E8F0F6
                menu.items.active.bg: flat solid
                menu.items.active.bg.color: #12364A
                menu.items.active.text.color: #78E4F6
                menu.items.disabled.text.color: #536476
                menu.border.width: 1
                menu.border.color: #28506A
                menu.overlap.x: 0
                menu.overlap.y: 0
                menu.title.bg: flat solid
                menu.title.bg.color: #0B1B2B
                menu.title.text.color: #78E4F6
                osd.bg: flat solid
                osd.bg.color: #0A1521
                osd.label.bg: parentrelative
                osd.label.text.color: #F2F7FB
                osd.border.width: 1
                osd.border.color: #2CB7D8
            """.trimIndent())
            Log.i(TAG, "openbox rc.xml + themerc NanoMobile escritos")
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
            writeManagedText(settingsIni, """
                [Settings]
                gtk-theme-name=Adwaita-dark
                gtk-icon-theme-name=Adwaita
                gtk-font-name=DejaVu Sans 18
                gtk-application-prefer-dark-theme=1
                gtk-enable-animations=0
                gtk-toolbar-style=GTK_TOOLBAR_ICONS
                gtk-button-images=1
                gtk-menu-images=1
            """.trimIndent())
            Log.i(TAG, "GTK settings.ini escrito (fuente 18, tema oscuro)")
        } catch (e: Exception) {
            Log.w(TAG, "setupGtkTheme: ${e.message}")
        }
    }

    private fun setupLxTerminalConfig() {
        try {
            val lxDir = File(File(usrDir.parentFile, "home"), ".config/lxterminal")
                .also { it.mkdirs() }
            val lxConf = File(lxDir, "lxterminal.conf")
            writeManagedText(lxConf, """
                [general]
                fontname=DejaVu Sans Mono 18
                bgcolor=#030711
                fgcolor=#E9F1FA
                scrollback=5000
                cursorblinks=true
                disallowbold=true
                selectbyword=true
            """.trimIndent())
            Log.i(TAG, "lxterminal.conf escrito (DejaVu Sans Mono 18, paleta NanoAI)")
        } catch (e: Exception) {
            Log.w(TAG, "setupLxTerminalConfig: ${e.message}")
        }
    }

    private fun writeLauncherIcon(target: File, kind: String) {
        target.parentFile?.mkdirs()
        val bitmap = Bitmap.createBitmap(112, 112, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.scale(1.75f, 1.75f)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = Color.rgb(11, 27, 43)
        canvas.drawRoundRect(RectF(2f, 2f, 62f, 62f), 15f, 15f, paint)
        paint.color = Color.rgb(91, 218, 241)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 4.5f
        paint.strokeCap = Paint.Cap.ROUND
        when (kind) {
            "terminal" -> {
                canvas.drawLine(18f, 22f, 28f, 32f, paint)
                canvas.drawLine(28f, 32f, 18f, 42f, paint)
                canvas.drawLine(34f, 42f, 47f, 42f, paint)
            }
            "files" -> {
                val path = android.graphics.Path().apply {
                    moveTo(14f, 23f); lineTo(28f, 23f); lineTo(33f, 28f)
                    lineTo(50f, 28f); lineTo(47f, 45f); lineTo(14f, 45f)
                    close()
                }
                canvas.drawPath(path, paint)
            }
            "editor" -> {
                canvas.drawLine(20f, 44f, 43f, 21f, paint)
                canvas.drawLine(18f, 46f, 25f, 44f, paint)
                canvas.drawLine(43f, 21f, 47f, 25f, paint)
            }
            else -> {
                canvas.drawCircle(32f, 32f, 18f, paint)
                canvas.drawCircle(32f, 23f, 1.5f, paint)
                canvas.drawLine(32f, 31f, 32f, 42f, paint)
            }
        }
        target.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }

    // Panel inferior real de tint2. Los fondos usan el formato secuencial
    // documentado por tint2; background_1/2/3 no son claves válidas. Los
    // iconos son PNG administrados por Nano para no pasar por librsvg, que
    // cae bajo nanoroot en el rootfs actual.
    private fun setupTint2Config() {
        try {
            val homeDir = File(usrDir.parentFile, "home")
            val panelHeight = desktopPanelHeight()
            val launcherIconSize = (panelHeight * 68 / 100).coerceIn(48, 78)
            val taskHeight = (panelHeight - 20).coerceAtLeast(52)
            val appsDir = File(homeDir, ".local/share/applications")
                .also { it.mkdirs() }
            val iconDir = File(homeDir, ".local/share/icons/nano-mobile")
            val terminalIcon = File(iconDir, "terminal.png")
            val filesIcon = File(iconDir, "files.png")
            val editorIcon = File(iconDir, "editor.png")
            val infoIcon = File(iconDir, "info.png")
            writeLauncherIcon(terminalIcon, "terminal")
            writeLauncherIcon(filesIcon, "files")
            writeLauncherIcon(editorIcon, "editor")
            writeLauncherIcon(infoIcon, "info")

            fun desktop(name: String, exec: String, icon: String) =
                """
                [Desktop Entry]
                Type=Application
                Name=$name
                Exec=$exec
                Icon=$icon
                Terminal=false
                Categories=Utility;
                """.trimIndent()
            writeManagedText(
                File(appsDir, "nano-terminal.desktop"),
                desktop("Terminal", "lxterminal -e sh -c \"exec bash -i\"", terminalIcon.absolutePath),
            )
            writeManagedText(
                File(appsDir, "nano-archivos.desktop"),
                desktop("Archivos", "pcmanfm", filesIcon.absolutePath),
            )
            writeManagedText(
                File(appsDir, "nano-info.desktop"),
                desktop(
                    "Nano Info",
                    "lxterminal -e sh -c \"nano-info; printf '\\n'; exec bash -i\"",
                    infoIcon.absolutePath,
                ),
            )
            writeManagedText(
                File(appsDir, "nano-editor.desktop"),
                desktop("Editor", "mousepad", editorIcon.absolutePath),
            )

            val tint2Dir = File(homeDir, ".config/tint2").also { it.mkdirs() }
            writeManagedText(File(tint2Dir, "tint2rc"), """
                # Nano Linux Mobile — tint2

                # Background 1: panel (ids are assigned by declaration order)
                rounded = 0
                border_width = 1
                border_sides = T
                background_color = #08131F 100
                border_color = #23465D 100

                # Background 2: active task
                rounded = 10
                border_width = 1
                background_color = #12364A 100
                border_color = #2CB7D8 100

                # Background 3: urgent task
                rounded = 10
                border_width = 1
                background_color = #593044 100
                border_color = #F0718C 100

                panel_items = LTC
                panel_size = 100% $panelHeight
                panel_margin = 0 0
                panel_padding = 8 5 8
                panel_background_id = 1
                panel_position = top center horizontal
                panel_layer = top
                # panel_dock=1 entrega el panel al dock interno de Openbox.
                # En Xvnc portrait ese dock cachea un strut derecho de media
                # pantalla aunque tint2 quite _NET_WM_STRUT. Verificado en
                # dispositivo: 432px -> 864px al usar una ventana EWMH normal.
                panel_dock = 0
                panel_monitor = all
                # Openbox reserva 112px mediante rc.xml. No duplicar esa
                # reserva mediante EWMH: el panel es una capa visual superior.
                strut_policy = none
                wm_menu = 1

                launcher_icon_theme = hicolor
                launcher_icon_size = $launcherIconSize
                launcher_padding = 14 8 14
                launcher_background_id = 0
                launcher_tooltip = 1
                launcher_item_app = ${File(appsDir, "nano-terminal.desktop").absolutePath}
                launcher_item_app = ${File(appsDir, "nano-archivos.desktop").absolutePath}
                launcher_item_app = ${File(appsDir, "nano-info.desktop").absolutePath}

                taskbar_padding = 5 3 5
                taskbar_background_id = 0
                task_icon = 1
                task_text = 1
                task_centered = 1
                task_maximum_size = 260 $taskHeight
                task_font = DejaVu Sans 17
                task_font_color = #D7E4EC 100
                task_active_font_color = #78E4F6 100
                task_iconified_font_color = #74879A 85
                task_background_id = 0
                task_active_background_id = 2
                task_urgent_background_id = 3
                task_iconified_background_id = 0

                time1_format = %H:%M
                time1_font = DejaVu Sans Bold 18
                clock_font_color = #78E4F6 100
                clock_padding = 14 16
                clock_background_id = 0
                clock_tooltip = Nano Linux

                tooltip_font = DejaVu Sans 16
                tooltip_background_id = 1
                tooltip_font_color = #E8F0F6 100
                tooltip_padding = 8 6
            """.trimIndent())
            Log.i(TAG, "tint2rc mobile ${panelHeight}px undocked + 3 launchers PNG escritos")
        } catch (e: Exception) {
            Log.w(TAG, "setupTint2Config: ${e.message}")
        }
    }

    /** Altura física del panel Linux, derivada del framebuffer activo. */
    private fun desktopPanelHeight(): Int =
        (minOf(fbWidth, fbHeight) * 12 / 100).coerceIn(72, 112)

    // DESKTOP-FIT-01: escritorio con iconos — pcmanfm --desktop muestra el
    // directorio especial Desktop de GLib. Termux no trae xdg-user-dirs, así
    // que GLib caería a ~/Desktop (locale C); forzamos ~/Escritorio con
    // user-dirs.dirs propio y copiamos ahí los .desktop del panel (misma
    // allowlist: binarios verificados, no exec arbitrario).
    private fun setupPcmanfmDesktop() {
        try {
            val homeDir = File(usrDir.parentFile, "home")
            val userDirs = File(homeDir, ".config/user-dirs.dirs")
            val configuredDesktop = if (userDirs.isFile) {
                userDirs.readLines().firstOrNull {
                    it.trimStart().startsWith("XDG_DESKTOP_DIR=")
                }?.substringAfter('=')?.trim()?.trim('"')
                    ?.replace("\$HOME", homeDir.absolutePath)
            } else {
                null
            }
            val deskDir = File(
                configuredDesktop?.takeIf { it.isNotBlank() }
                    ?: File(homeDir, "Escritorio").absolutePath,
            ).also { it.mkdirs() }
            // user-dirs.dirs es potencialmente del usuario: solo se crea si
            // no existe; una migración Nano nunca reemplaza su contenido.
            if (!userDirs.exists()) {
                writeManagedText(
                    userDirs,
                    "XDG_DESKTOP_DIR=\"${deskDir.absolutePath}\"\n",
                )
            }
            val appsDir = File(homeDir, ".local/share/applications")
            listOf(
                "nano-terminal.desktop",
                "nano-archivos.desktop",
                "nano-editor.desktop",
                "nano-info.desktop",
            )
                .forEach { name ->
                    val src = File(appsDir, name)
                    val dst = File(deskDir, name)
                    // Estos nombres son Nano-managed: reemplazarlos evita el
                    // bug seed-only que dejaba accesos de versiones previas.
                    if (src.exists()) Files.copy(
                        src.toPath(),
                        dst.toPath(),
                        StandardCopyOption.REPLACE_EXISTING,
                    )
                }
            // Desktop sin papelera ni carpetas especiales (gvfs incompleto
            // en este rootfs — honesto: trash:// no funciona aún).
            val confDir = File(homeDir, ".config/pcmanfm/default").also { it.mkdirs() }
            writeManagedText(File(confDir, "desktop-items-0.conf"), """
                [*]
                show_trash=0
                show_documents=0
            """.trimIndent())
            // DESKTOP-FIX-01: pcmanfm --desktop es el desktop manager y pinta
            // SU fondo sobre el root window — sin pcmanfm.conf usaba su
            // default (wallpaper ausente en Termux = NEGRO) y tapaba el feh.
            // Aquí pinta el mismo wallpaper. El tamaño de iconos pertenece a
            // libfm.conf, no a pcmanfm.conf; escribir big_icon_size aquí no
            // tenía efecto y dejaba el valor stock de 48 px en el teléfono.
            writeManagedText(File(confDir, "pcmanfm.conf"), """
                [desktop]
                wallpaper_mode=fit
                wallpaper=${homeDir.absolutePath}/.nano-wallpaper.png
                desktop_font=DejaVu Sans 18
            """.trimIndent())
            val libfmDir = File(homeDir, ".config/libfm").also { it.mkdirs() }
            writeManagedText(File(libfmDir, "libfm.conf"), """
                [config]
                single_click=1
                use_trash=0
                confirm_del=1
                thumbnail_local=1
                thumbnail_max=2048

                [ui]
                big_icon_size=112
                small_icon_size=48
                thumbnail_size=144
                pane_icon_size=48
                show_thumbnail=1
            """.trimIndent())
            Log.i(TAG, "pcmanfm desktop: ${deskDir.absolutePath} con ${deskDir.listFiles()?.size ?: 0} iconos")
        } catch (e: Exception) {
            Log.w(TAG, "setupPcmanfmDesktop: ${e.message}")
        }
    }

    // El fondo se genera siempre a la resolución real del framebuffer.
    // a la resolución REAL del framebuffer — feh --bg-scale la aplica 1:1
    // como capa base del root window. El pintor principal es pcmanfm --desktop
    // (desktop manager: cubre el root; sin pcmanfm.conf pintaba su default
    // negro — DESKTOP-FIX-01). Mismo PNG para ambos, un solo archivo fuente.
    private fun wallpaperForLaunch(): Pair<File, String> {
        val homeDir = File(usrDir.parentFile, "home")
        val png = File(homeDir, ".nano-wallpaper.png")
        return png to "--bg-scale"
    }

    // Wallpaper estático y sobrio: gradiente grafito/azul, un único halo y
    // geometría sutil. Se pinta una vez al start; no deja procesos ni consume
    // CPU/GPU en idle. PNG es compatible con pcmanfm y feh del rootfs actual.
    private fun setupWallpaper() {
        try {
            val homeDir = File(usrDir.parentFile, "home").also { it.mkdirs() }
            val png = File(homeDir, ".nano-wallpaper.png")
            val w = if (fbWidth > 0) fbWidth else 1080
            val h = if (fbHeight > 0) fbHeight else 1920
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.shader = LinearGradient(
                0f, 0f, w.toFloat(), h.toFloat(),
                intArrayOf(
                    Color.rgb(5, 12, 20),
                    Color.rgb(8, 22, 34),
                    Color.rgb(5, 14, 23),
                ),
                floatArrayOf(0f, 0.52f, 1f),
                Shader.TileMode.CLAMP,
            )
            canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)

            val minDim = minOf(w, h).toFloat()
            paint.shader = RadialGradient(
                w * 0.82f, h * 0.18f, minDim * 0.58f,
                intArrayOf(Color.argb(62, 29, 154, 190), Color.TRANSPARENT),
                floatArrayOf(0f, 1f),
                Shader.TileMode.CLAMP,
            )
            canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)

            paint.shader = null
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1.5f
            paint.color = Color.argb(34, 91, 218, 241)
            val spacing = (minDim * 0.10f).coerceAtLeast(56f)
            var offset = -h.toFloat()
            while (offset < w + h) {
                canvas.drawLine(offset, h.toFloat(), offset + h, 0f, paint)
                offset += spacing
            }

            paint.style = Paint.Style.FILL
            paint.typeface = android.graphics.Typeface.DEFAULT_BOLD
            paint.textSize = (minDim * 0.065f).coerceIn(34f, 78f)
            paint.color = Color.argb(210, 225, 241, 247)
            canvas.drawText("NANO", minDim * 0.08f, minDim * 0.14f, paint)
            paint.typeface = android.graphics.Typeface.DEFAULT
            paint.textSize = (minDim * 0.020f).coerceIn(14f, 25f)
            paint.letterSpacing = 0.12f
            paint.color = Color.argb(175, 91, 218, 241)
            canvas.drawText(
                "LINUX MOBILE WORKSPACE",
                minDim * 0.085f,
                minDim * 0.19f,
                paint,
            )
            png.outputStream().use { out ->
                bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            bmp.recycle()
            Log.i(TAG, "wallpaper Nano Mobile escrito: ${w}x${h} PNG")
        } catch (e: Exception) {
            Log.w(TAG, "setupWallpaper: ${e.message}")
        }
    }
}
