package dev.nanoai.mobile.services

import kotlinx.coroutines.delay

enum class XTransport {
    TCP, UNIX
}

data class XDisplayEndpoint(
    val display: Int,
    val host: String?,
    val transport: XTransport
)

interface XServerBackend {
    /** Inicia el servidor X. [env] debe incluir PREFIX/HOME/LD_LIBRARY_PATH/
     *  XDG_CONFIG_HOME — Xvnc los necesita para resolver share/X11/xkb/rules
     *  y sus libs; sin ellos aborta silenciosamente antes de abrir el puerto RFB. */
    suspend fun start(env: Map<String, String> = emptyMap()): Boolean

    /** Espera activamente a que el servidor reporte estar listo. */
    suspend fun awaitReady(): Boolean

    /** Detiene el servidor X. */
    suspend fun stop()

    /** Retorna el estado y configuración actual de display. */
    fun getEndpoint(): XDisplayEndpoint

    /** Puerto RFB del display (5900 + número de display). */
    val rfbPort: Int get() = 5900 + getEndpoint().display

    /** Último error de start/awaitReady (null si el último intento fue limpio). */
    val lastError: String?

    /** ¿Proceso del servidor X vivo? Lee /proc/<pid>/stat, SIN tocar el socket.
     * Un probe TCP que corta a mitad del handshake RFB cuenta como "security
     * failure" para el anti-brute-force de TigerVNC — tras ~5 cortes rechaza
     * TODA conexión ("Too many security failures"). Los checks periódicos
     * (watchdog, getStatus) DEBEN usar esto, nunca tcpReachable. */
    fun isAlive(): Boolean
}

/**
 * Backend interno de X11 que usa VNC.
 * Se inicia de forma independiente usando un proceso nativo desvinculado (Xvnc).
 */
class InternalXvncBackend(
    private val usrDir: java.io.File,
    private val spawnBg: (binaryPath: String, argv: List<String>, envp: Map<String, String>) -> Long
) : XServerBackend {
    companion object {
        private const val TAG = "InternalXvncBackend"
    }

    private var xvncPid: Long = -1
    private val endpoint = XDisplayEndpoint(
        display = 1,
        host = "127.0.0.1",
        transport = XTransport.TCP
    )

    @Volatile override var lastError: String? = null
        private set

    override suspend fun start(env: Map<String, String>): Boolean {
        // K-1: un Xvnc residual de NUESTRO uid (huérfano setsid de un ciclo
        // previo, o SIGKILL asíncrono de un stop() reciente) puede retener el
        // puerto 5901 → el nuevo Xvnc muere EADDRINUSE y la UI entra en loop
        // de reintento. Matar el residual y esperar a que libere el puerto
        // antes de spawn.
        killLingeringXvnc()

        val vncPort = rfbPort
        val argv = listOf(
            ":${endpoint.display}",
            "-geometry", "1280x720",
            "-depth", "24",
            "-rfbport", "$vncPort",
            "-SecurityTypes", "None",
            "-localhost", "yes",
            "-listen", "tcp",
        )
        // NOTA (evidencia device 2026-08-12): este binario Xvnc de Termux NO
        // soporta "-kb" — "Unrecognized option: -kb" y exit 1 antes de abrir
        // el puerto RFB. El flag estaba oculto por el bug de argv desplazado
        // (NAT-2); con el argv correcto aborta en el parseo de opciones.
        // El fallback de xkbcomp lo cubre el wrapper desplegado en
        // usr/bin/xkbcomp (ver boot_orchestrator).
        // Sin -nodaemon: Xvnc de TigerVNC invocado directamente queda en
        // foreground (el fork lo hace el wrapper vncserver, no Xvnc) — pasar
        // un flag inexistente lo haría abortar en el arranque.
        // Xvnc necesita el mismo entorno que openbox/tint2 (PREFIX, HOME,
        // LD_LIBRARY_PATH, XDG_CONFIG_HOME...) para resolver sus libs y las
        // reglas XKB en share/X11/xkb/rules/evdev. Sin esto aborta antes de
        // abrir el puerto RFB (fallo silencioso bajo Android/ColorOS).
        lastError = null
        xvncPid = spawnBg("${usrDir.absolutePath}/bin/Xvnc", argv, env)
        if (xvncPid <= 0) lastError = "spawnBg de Xvnc devolvió PID inválido ($xvncPid)"
        return xvncPid > 0
    }

    override suspend fun awaitReady(): Boolean {
        val maxTimeoutMs = 15_000L
        val start = System.currentTimeMillis()

        // Readiness SIN tocar TCP: un probe que corta a mitad del handshake
        // RFB suma un "security failure" al anti-brute-force de TigerVNC
        // (tras ~5 cortes rechaza TODA conexión). Además, con daemons
        // huérfanos de ciclos previos, el puerto abierto no prueba que el
        // Xvnc PROPIO (xvncPid) sea el que escucha — evidencia device
        // 2026-08-12: "VNC listo y estable" con xvncPid muerto status=1
        // (bind fail) y un servidor ajeno respondiendo.
        //
        // Señales locales de readiness:
        //   1. xvncPid vivo (/proc/<pid>/stat, sin tocar sockets).
        //   2. Socket X11 del display creado por el proceso: Xvnc crea
        //      usr/tmp/.X11-unix/X<display> al abrir el display, incluso con
        //      -listen tcp (verificado en device).
        //   3. Estabilización: ambos siguen bien 2s después (cubre el fallo
        //      de libs/xkb post-bind del P0-2 sin probe de red).
        val xSock = java.io.File(usrDir, "tmp/.X11-unix/X${endpoint.display}")
        while (System.currentTimeMillis() - start < maxTimeoutMs) {
            if (!isAlive()) {
                lastError = "Xvnc (PID $xvncPid) murió durante el arranque " +
                    "(status capturado por el reaper del worker en logcat)"
                android.util.Log.e(TAG, lastError!!)
                return false
            }
            if (xSock.exists()) {
                delay(2000)
                if (!isAlive()) {
                    lastError = "Xvnc (PID $xvncPid) murió tras crear el socket X11 " +
                        "(fallo post-bind de libs/xkb)"
                    android.util.Log.e(TAG, lastError!!)
                    return false
                }
                android.util.Log.i(TAG, "Xvnc listo: PID vivo + socket X11 + 2s estable")
                return true
            }
            delay(200)
        }
        lastError = "Xvnc no creó el socket X11 en $maxTimeoutMs ms"
        android.util.Log.e(TAG, lastError!!)
        return false
    }

    override suspend fun stop() {
        if (xvncPid > 0) {
            try {
                android.os.Process.killProcess(xvncPid.toInt())
                android.util.Log.i("InternalXvncBackend", "Xvnc PID $xvncPid terminated")
            } catch (e: Exception) {
                android.util.Log.w("InternalXvncBackend", "kill Xvnc PID $xvncPid: ${e.message}")
            }
            // K-1: SIGKILL es asíncrono. Esperar (bounded) a que /proc/<pid>
            // desaparezca para que el puerto 5901 quede libre antes del próximo
            // start(); sin esto el nuevo Xvnc muere EADDRINUSE.
            val deadline = System.currentTimeMillis() + 2000
            while (System.currentTimeMillis() < deadline && isAlive()) {
                delay(50)
            }
            xvncPid = -1
        }
    }

    /**
     * K-1: localiza y mata cualquier Xvnc residual de NUESTRO uid que siga
     * reteniendo el puerto RFB (huérfano setsid de un force-stop, o proceso
     * previo cuyo SIGKILL aún no se reapea). Espera bounded a que libere el
     * puerto. No toca el xvncPid propio (re-start idempotente).
     */
    private suspend fun killLingeringXvnc() {
        val lingering = findLingeringXvncPids()
        if (lingering.isEmpty()) return
        for (pid in lingering) {
            android.util.Log.w(TAG, "K-1: Xvnc residual PID=$pid reteniendo puerto — matando")
            try { android.os.Process.killProcess(pid) } catch (_: Exception) {}
        }
        val deadline = System.currentTimeMillis() + 3000
        while (System.currentTimeMillis() < deadline && findLingeringXvncPids().isNotEmpty()) {
            delay(100)
        }
    }

    private fun findLingeringXvncPids(): List<Int> {
        val myUid = android.os.Process.myUid()
        val procs = java.io.File("/proc").listFiles() ?: return emptyList()
        val result = mutableListOf<Int>()
        for (dir in procs) {
            val pid = dir.name.toIntOrNull() ?: continue
            if (pid <= 0 || pid.toLong() == xvncPid) continue
            val status = try { dir.resolve("status").readText() } catch (_: Exception) { continue }
            val uid = Regex("^Uid:\\s+(\\d+)", RegexOption.MULTILINE)
                .find(status)?.groupValues?.get(1)?.toIntOrNull()
            if (uid != myUid) continue
            val cmdline = try { dir.resolve("cmdline").readText().replace('\u0000', ' ') } catch (_: Exception) { continue }
            if (cmdline.contains("/bin/Xvnc")) result.add(pid)
        }
        return result
    }

    override fun getEndpoint(): XDisplayEndpoint = endpoint

    override fun isAlive(): Boolean {
        val pid = xvncPid
        if (pid <= 0) return false
        return try {
            val stat = java.io.File("/proc/$pid/stat").readText()
            val end = stat.lastIndexOf(')')
            // Formato "<pid> (comm) <state> ..." — estado es el char tras ") ".
            // 'Z' = zombie (proceso muerto sin reaper): funcionalmente caído.
            end >= 0 && end + 2 < stat.length && stat[end + 2] != 'Z'
        } catch (e: Exception) {
            // /proc/<pid> ausente o ilegible: proceso muerto.
            false
        }
    }
}
