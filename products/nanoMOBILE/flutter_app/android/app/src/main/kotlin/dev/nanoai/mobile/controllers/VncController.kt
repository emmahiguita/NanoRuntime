package dev.nanoai.mobile

import java.io.File
import java.net.InetSocketAddress
import java.net.Socket
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Controlador de alto nivel para el escritorio VNC.
 *
 * Desacopla la lógica de lanzamiento/parada de VncService de MainActivity:
 *   - [start] ejecuta en IO (no bloquea el main thread).
 *   - [stop] es seguro desde cualquier hilo.
 *   - [getStatus] sondea loopback en IO y retorna el resultado via callback.
 */
class VncController(
    private val appFilesDir: File,
    private val workerClientProvider: () -> WorkerClient?,
    private val ioScopeProvider: () -> CoroutineScope?,
) {
    private val lock = Any()
    @Volatile private var activeVncService: VncService? = null
    private var generation = 0L

    /**
     * Inicia el escritorio en un hilo IO.
     * [onPort]  → invocado con el puerto cuando el servidor está listo (hilo IO).
     * [onError] → invocado con mensaje de error si falla (hilo IO).
     * [onStatus]→ mensajes de progreso (hilo IO).
     */
    fun start(
        onStatus: (String) -> Unit = {},
        onPort:   (Int)    -> Unit = {},
        onError:  (String) -> Unit = {},
    ) {
        val usrDir = File(appFilesDir, "nano/usr")

        val previous: VncService?
        lateinit var vnc: VncService
        val startGeneration: Long
        synchronized(lock) {
            previous = activeVncService
            previous?.stop()
            generation++
            startGeneration = generation
            vnc = VncService(
                usrDir = usrDir,
                spawnBg = { bin, argv, envp ->
                    if (!isCurrent(vnc, startGeneration)) {
                        -1L
                    } else {
                        val taskId = "vnc_${System.currentTimeMillis()}"
                        val client = workerClientProvider()
                        if (client == null) {
                            android.util.Log.e("vnc", "worker no disponible para $bin")
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
            )
            activeVncService = vnc
        }

        vnc.start(
            onStatus = onStatus,
            onReady  = { port ->
                if (isCurrent(vnc, startGeneration)) {
                    onPort(port)
                } else {
                    vnc.stop()
                }
            },
            onError  = { msg ->
                if (clearIfCurrent(vnc, startGeneration)) {
                    onError(msg)
                }
            },
        )
    }

    /** Para el servidor VNC y libera recursos. */
    fun stop() {
        val vnc: VncService?
        synchronized(lock) {
            generation++
            vnc = activeVncService
            activeVncService = null
        }
        vnc?.stop()
    }

    /**
     * Retorna el estado actual del servidor.
     * Ejecuta el sondeo TCP en [scope] (IO) para no bloquear el main thread.
     * [callback] se invoca con el resultado en el mismo scope.
     */
    fun getStatus(callback: (Map<String, Any>) -> Unit) {
        val scope = ioScopeProvider() ?: return
        scope.launch {
            val vnc       = activeVncService
            val port      = vnc?.port ?: VncService.DEFAULT_PORT
            val running   = vnc?.isRunning == true
            val reachable = if (running) vnc!!.probePort() else false
            callback(
                mapOf(
                    "running"   to running,
                    "reachable" to reachable,
                    "ready"     to reachable,
                    "port"      to port,
                )
            )
        }
    }

    private fun isCurrent(vnc: VncService, expectedGeneration: Long): Boolean =
        synchronized(lock) { activeVncService === vnc && generation == expectedGeneration }

    private fun clearIfCurrent(vnc: VncService, expectedGeneration: Long): Boolean =
        synchronized(lock) {
            if (activeVncService !== vnc || generation != expectedGeneration) return@synchronized false
            activeVncService = null
            true
        }
}
