package dev.nanoai.mobile.controllers

import dev.nanoai.mobile.DesktopSessionManager
import dev.nanoai.mobile.RuntimeHeartbeat
import dev.nanoai.mobile.WorkerClient
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Controlador de alto nivel para el escritorio X11.
 *
 * Desacopla la lógica de lanzamiento/parada de DesktopSessionManager de MainActivity:
 *   - [start] ejecuta en IO (no bloquea el main thread).
 *   - [stop] es seguro desde cualquier hilo.
 *   - [getStatus] retorna el resultado via callback.
 */
class DesktopController(
    private val appFilesDir: File,
    private val workerClientProvider: () -> WorkerClient?,
    private val ioScopeProvider: () -> CoroutineScope?,
) {
    private val lock = Any()
    @Volatile private var activeSession: DesktopSessionManager? = null
    private var generation = 0L

    /**
     * Inicia el escritorio en un hilo IO.
     * [vncPassword] vacío = Xvnc sin auth; no vacío = Xvnc con -rfbauth
     * (VNC Auth). Solo se aplica en el arranque: para cambiarla hay que
     * detener y volver a iniciar el escritorio.
     * [onStatus]→ mensajes de progreso (hilo IO).
     * [onReady] → invocado cuando el servidor está listo (hilo IO).
     * [onError] → invocado con mensaje de error si falla (hilo IO).
     */
    fun start(
        vncPassword: String = "",
        width: Int = 0,
        height: Int = 0,
        onStatus: (String) -> Unit = {},
        onReady:  ()       -> Unit = {},
        onError:  (String) -> Unit = {},
    ) {
        val usrDir = File(appFilesDir, "nano/usr")

        val previous: DesktopSessionManager?
        lateinit var session: DesktopSessionManager
        val startGeneration: Long
        synchronized(lock) {
            previous = activeSession
            previous?.stop()
            generation++
            startGeneration = generation
            session = DesktopSessionManager(
                usrDir = usrDir,
                vncPassword = vncPassword,
                spawnBg = { bin, argv, envp ->
                    if (!isCurrent(session, startGeneration)) {
                        -1L
                    } else {
                        val taskId = "desktop_${System.currentTimeMillis()}"
                        val client = workerClientProvider()
                        if (client == null) {
                            android.util.Log.e("desktop", "worker no disponible para $bin")
                            -1L
                        } else {
                            client.spawnDetached(
                                bin,
                                argv,
                                envp.map { "${it.key}=${it.value}" },
                                taskId,
                            ).toLong()
                        }
                    }
                },
                // Liveness de Xvnc delegado al worker: el proceso principal
                // no puede leer /proc de los hijos del worker. Fail-closed:
                // sin worker el arranque aborta con error honesto en vez de
                // matar un Xvnc vivo con SIGKILL propio.
                isPidAlive = { pid ->
                    workerClientProvider()?.isPidAlive(pid.toInt()) ?: false
                },
                // BUG-2 FIX: kill de daemons detached (Xvnc/openbox/terminal)
                // delegado al worker — el proceso principal no puede matar
                // hijos del worker en Android 12+ (SecurityException tragada
                // dejaba Xvnc huérfano ocupando 5901).
                killPidDelegate = { pid ->
                    workerClientProvider()?.killPid(pid.toInt()) ?: false
                },
            )
            activeSession = session
        }

        session.start(
            width = width,
            height = height,
            onStatus = onStatus,
            onReady  = {
                if (isCurrent(session, startGeneration)) {
                    onReady()
                } else {
                    session.stop()
                }
            },
            onError  = { msg ->
                if (clearIfCurrent(session, startGeneration)) {
                    onError(msg)
                }
            },
        )
    }

    /** Para el servidor de escritorio y libera recursos. */
    fun stop() {
        val session: DesktopSessionManager?
        synchronized(lock) {
            generation++
            session = activeSession
            activeSession = null
        }
        if (session != null) {
            session.stop()
        } else {
            // U-10: sin sesión activa (p.ej. proceso resucitado tras un kill
            // del OS) — el "Detener" del usuario es ack implícito del kill:
            // borra el heartbeat para que el aviso de restauración se limpie.
            RuntimeHeartbeat.markCleanShutdown(File(appFilesDir, "nano"))
        }
    }

    /**
     * Lanza una app gráfica del escritorio (allowlist estricta en
     * DesktopSessionManager: lxterminal/pcmanfm/mousepad/xpdf/file-roller/
     * feh). Retorna false si el desktop no está corriendo o el binario no
     * existe.
     */
    fun launchApp(app: String): Boolean {
        val session = synchronized(lock) { activeSession }
        return session?.launchApp(app) ?: false
    }

    /**
     * Retorna el estado actual del servidor.
     */
    fun getStatus(callback: (Map<String, Any?>) -> Unit) {
        val scope = ioScopeProvider()
        // K-8: ioScope null (post-shutdown) hacía `?: return` sin invocar el
        // callback → el Future de Dart esperaba para siempre. Resolver con
        // estado offline inmediato en vez de colgar la UI.
        if (scope == null) {
            callback(buildStatus(null))
            return
        }
        scope.launch {
            callback(buildStatus(activeSession))
        }
    }

    private fun buildStatus(session: DesktopSessionManager?): Map<String, Any?> {
        val running = session?.isRunning == true
        val usrDir  = File(appFilesDir, "nano/usr")

        // Puerto RFB del display (5900 + display number).
        val port = if (running) session?.rfbPort ?: 5901 else 5901

        // P1-11: reachable REAL (proceso Xvnc vivo vía /proc/<pid>/stat),
        // no sinónimo de running — la UI navegaba a un puerto muerto
        // cuando running quedaba stale tras una caída de Xvnc. Prohibido
        // el probe TCP aquí: cada corte a mitad del handshake RFB suma
        // un "security failure" al anti-brute-force de TigerVNC.
        val reachable = running && (session?.isBackendAlive == true)

        return mapOf(
            "running"   to running,
            "reachable" to reachable,
            "ready"     to reachable,
            "port"      to port,
            "installed" to File(usrDir, "bin/Xvnc").exists(),
            // Extras gráficos (dbus/pcmanfm/feh/mousepad): presentes
            // en disco aunque el dpkg status se haya perdido. La UI
            // los usa para disparar installGraphical incremental.
            "graphicalExtras" to (
                File(usrDir, "bin/pcmanfm").exists() &&
                File(usrDir, "bin/feh").exists() &&
                File(usrDir, "bin/mousepad").exists() &&
                File(usrDir, "bin/dbus-launch").exists() &&
                // U-1: papelera (trash://) de pcmanfm vía gvfs. Si falta,
                // installGraphical corre y lo instala (devices existentes
                // también lo reciben, no solo installs limpios).
                File(usrDir, "libexec/gvfsd-trash").exists() &&
                // DESKTOP-FULL-01: panel de tareas tint2. Devices existentes
                // sin él disparan installGraphical incremental al entrar.
                File(usrDir, "bin/tint2").exists()
            ),
            // Estado instalado por app del panel (appId → binario ELF en
            // disco). Verdad por existencia real, no por dpkg status: el
            // status se pierde en extracciones parciales (evidencia device).
            "apps" to mapOf(
                "lxterminal" to File(usrDir, "bin/lxterminal").exists(),
                "pcmanfm" to File(usrDir, "bin/pcmanfm").exists(),
                "mousepad" to File(usrDir, "bin/mousepad").exists(),
                "xpdf" to File(usrDir, "bin/xpdf").exists(),
                "file-roller" to File(usrDir, "bin/file-roller").exists(),
                "feh" to File(usrDir, "bin/feh").exists(),
            ),
            "stage"     to (session?.currentStage ?: "idle"),
            "lastError" to session?.currentError,
            // U-10: kill del OS detectado (heartbeat vivo sin apagado limpio).
            // La UI de lanzamiento muestra el aviso honesto de restauración;
            // el service de accesibilidad lo usa para re-lanzar la app.
            "wasKilledByOs" to RuntimeHeartbeat.wasKilledByOs(File(appFilesDir, "nano")),
        )
    }

    private fun isCurrent(session: DesktopSessionManager, expectedGeneration: Long): Boolean =
        synchronized(lock) { activeSession === session && generation == expectedGeneration }

    private fun clearIfCurrent(session: DesktopSessionManager, expectedGeneration: Long): Boolean =
        synchronized(lock) {
            if (activeSession !== session || generation != expectedGeneration) return@synchronized false
            activeSession = null
            true
        }
}
