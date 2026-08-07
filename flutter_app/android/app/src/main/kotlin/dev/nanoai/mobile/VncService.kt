package dev.nanoai.mobile

import android.util.Log
import java.io.File
import java.lang.Process
import kotlin.concurrent.thread

/**
 * Servicio VNC autocontenido: lanza Xvnc + window manager dentro del rootfs.
 *
 * Flujo:
 *   1. Ejecuta Xvnc :1 -geometry WxH -depth 24 -SecurityTypes None
 *      → servidor VNC en 127.0.0.1:5901, display X11 :1 accesible sin password.
 *   2. Con DISPLAY=:1, lanza openbox (window manager) + xterm (terminal).
 *   3. El visor Flutter se conecta a 127.0.0.1:5901 vía noVNC (WebView).
 *
 * SIN dependencia de tigervnc systemd/service files — lanzamiento manual.
 */
class VncService(
    private val usrDir: File,          // files/nano/usr
    private val spawnBg: (binaryPath: String, argv: List<String>, envp: Map<String, String>) -> Long,
                                       // retorna PID (>0) o -1 si falla
) {
    companion object {
        private const val TAG = "vnc-service"
        const val DEFAULT_PORT = 5901
        const val DEFAULT_DISPLAY = 1
        const val DEFAULT_WIDTH = 1280
        const val DEFAULT_HEIGHT = 720
    }

    private var xvncPid: Long = -1
    private var openboxPid: Long = -1
    private var xtermPid: Long = -1
    private var tint2Pid: Long = -1
    private var running = false

    /** Entorno base del rootfs (paths, LD_PRELOAD, etc.). */
    private fun baseEnv(): Map<String, String> = mapOf(
        "PREFIX" to usrDir.absolutePath,
        "HOME" to File(usrDir.parentFile, "home").absolutePath,
        "TMPDIR" to File(usrDir, "tmp").absolutePath,
        "PATH" to "${usrDir.absolutePath}/bin:/system/bin",
        "LD_LIBRARY_PATH" to "${usrDir.absolutePath}/lib",
        "DISPLAY" to ":$DEFAULT_DISPLAY",
    )

    /**
     * Inicia el escritorio VNC. Bloquea hasta que Xvnc acepta conexiones
     * (~2-5 segundos). Retorna true si el servidor arrancó.
     */
    fun start(
        width: Int = DEFAULT_WIDTH,
        height: Int = DEFAULT_HEIGHT,
        onStatus: (String) -> Unit = {},
    ): Boolean {
        if (running) {
            Log.w(TAG, "VNC ya está corriendo")
            return true
        }

        // Limpiar socket previo si existe
        val socketDir = File(usrDir, "tmp/.X11-unix")
        socketDir.mkdirs()
        File(socketDir, "X$DEFAULT_DISPLAY").delete()
        File(usrDir, "tmp/.X${DEFAULT_DISPLAY}-lock").delete()

        val xvncBin = "${usrDir.absolutePath}/bin/Xvnc"
        if (!File(xvncBin).exists()) {
            Log.e(TAG, "Xvnc no encontrado en $xvncBin. Instala tigervnc primero.")
            onStatus("Xvnc no instalado. Usa 'Instalar Escritorio' primero.")
            return false
        }

        onStatus("Iniciando servidor VNC...")

        // 1. Lanzar Xvnc
        val xvncEnv = baseEnv().toMutableMap()
        xvncPid = spawnBg(
            xvncBin,
            listOf("Xvnc", ":$DEFAULT_DISPLAY",
                "-geometry", "${width}x${height}",
                "-depth", "24",
                "-SecurityTypes", "None",
                "-localhost", "yes",        // solo conexiones locales
                "-alwaysshared",
                "-fp", "built-ins",
            ),
            xvncEnv,
        )

        if (xvncPid < 0) {
            Log.e(TAG, "Xvnc no arrancó")
            onStatus("Error al iniciar Xvnc")
            return false
        }
        Log.i(TAG, "Xvnc PID=$xvncPid en :$DEFAULT_DISPLAY")

        // Esperar a que Xvnc esté listo (~3 seg)
        Thread.sleep(3000)

        onStatus("Iniciando escritorio...")

        // 2. Lanzar openbox (window manager)
        val wmEnv = baseEnv().toMutableMap()
        openboxPid = spawnBg("${usrDir.absolutePath}/bin/openbox", listOf("openbox"), wmEnv)
        Log.i(TAG, "openbox PID=$openboxPid")

        Thread.sleep(1000)

        // 3. Lanzar tint2 (panel/taskbar) — opcional
        val tint2Bin = File(usrDir, "bin/tint2")
        if (tint2Bin.exists()) {
            tint2Pid = spawnBg(tint2Bin.absolutePath, listOf("tint2"), wmEnv)
            Log.i(TAG, "tint2 PID=$tint2Pid")
        }

        // 4. Terminar X11 (opcional — puede no estar instalado)
        val xtermBin = File(usrDir, "bin/xterm")
        if (xtermBin.exists()) {
            xtermPid = spawnBg(
                xtermBin.absolutePath,
                listOf("xterm", "-fa", "Monospace", "-fs", "14", "-bg", "black", "-fg", "white"),
                wmEnv,
            )
            Log.i(TAG, "xterm PID=$xtermPid")
        }

        running = true
        onStatus("Escritorio listo en puerto $DEFAULT_PORT")
        return true
    }

    /** Detiene el servidor VNC y todos sus procesos. */
    fun stop() {
        if (!running) return
        Log.i(TAG, "Deteniendo VNC...")
        // Kill en orden inverso
        killPid(xtermPid); xtermPid = -1
        killPid(tint2Pid); tint2Pid = -1
        killPid(openboxPid); openboxPid = -1
        killPid(xvncPid); xvncPid = -1
        running = false
    }

    val isRunning: Boolean get() = running
    val port: Int get() = DEFAULT_PORT

    /** Limpia estado — llamar al destruir el servicio. */
    fun dispose() {
        stop()
    }

    private fun killPid(pid: Long) {
        if (pid > 0) {
            try {
                android.os.Process.killProcess(pid.toInt())
            } catch (e: Exception) {
                Log.w(TAG, "kill $pid: ${e.message}")
            }
        }
    }
}
