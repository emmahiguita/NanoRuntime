package dev.nanoai.mobile

import android.util.Log

/**
 * Bridge JNI que expone las sesiones PTY de libnanoshell.so a Kotlin.
 *
 * El puente mantiene un registro de sesiones en C. Cada sesión tiene un
 * [PtySession] con master_fd (para I/O) y child_pid (para señales).
 *
 * Package y nombre de clase COMPATIBLES con la convención JNI
 * (Java_dev_nanoai_mobile_NanoshellBridge_*). No renombrar esta clase.
 */
object NanoshellBridge {
    private const val TAG = "NanoshellBridge"
    private var _loaded = false

    /**
     * Carga libnanoshell.so. Idempotente. Debe llamarse antes de cualquier
     * otra native method.
     */
    @Synchronized
    fun ensureLoaded(): Boolean {
        if (_loaded) return true
        return try {
            System.loadLibrary("nanoshell")
            _loaded = true
            Log.i(TAG, "libnanoshell.so cargada")
            true
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "loadLibrary falló: $e")
            false
        }
    }

    val isLoaded: Boolean get() = _loaded

    /**
     * Crea una sesión PTY: openpty + fork + dlopen(bin) en el hijo.
     * @return sessionId (long) > 0 si éxito, 0 si falló.
     */
    @JvmStatic external fun ptySpawn(
        argv: Array<String>,
        envp: Array<String>,
        ldPreload: String?,
        rows: Int,
        cols: Int,
    ): Long

    /** Escribe input del usuario al master PTY. Devuelve bytes escritos. */
    @JvmStatic external fun ptyWrite(id: Long, data: ByteArray): Int

    /** Lectura no bloqueante. Devuelve byte[] o null si no hay datos. */
    @JvmStatic external fun ptyRead(id: Long, maxBytes: Int): ByteArray?

    /** Cambia el tamaño de ventana del PTY. */
    @JvmStatic external fun ptyResize(id: Long, rows: Int, cols: Int): Int

    /** Envía una señal al proceso hijo (ej. 2=SIGINT, 15=SIGTERM, 9=SIGKILL). */
    @JvmStatic external fun ptyKill(id: Long, signal: Int): Int

    /** Cierra el master fd y libera la sesión. */
    @JvmStatic external fun ptyClose(id: Long)

    /** Devuelve el PID del proceso hijo (debugging). */
    @JvmStatic external fun ptyGetPid(id: Long): Int

    /** 1 si el proceso hijo sigue vivo, 0 si terminó (reaps zombie). */
    @JvmStatic external fun ptyIsAlive(id: Long): Int

    /**
     * Ejecuta un binario del rootfs en el proceso WORKER (sin GPU) y escribe
     * stdout/stderr/exitCode a files/worker_out_<taskId> / worker_err_<taskId>
     * / worker_rc_<taskId>. Los punteros nativos no cruzan procesos: la
     * comunicación es por archivos en el sandbox compartido.
     */
    @JvmStatic external fun workerSpawn(
        binaryPath: String,
        argv: Array<String>,
        envp: Array<String>,
        ldPreload: String?,
        taskId: String,
        filesDir: String,
    ): Int

    /** Spawn sin esperar — para daemons (Xvnc, openbox). fork+exec, retorna PID. */
    @JvmStatic external fun workerSpawnDetached(
        binaryPath: String,
        argv: Array<String>,
        envp: Array<String>,
    ): Int

    /**
     * 1 si el proceso detached [pid] sigue vivo, 0 si murió. SOLO desde el
     * worker: el proceso principal no puede leer /proc de los hijos del
     * worker (Android restringe /proc a hijos directos del lector). El worker
     * es el padre — pregunta con kill(pid, 0) y la marca del reaper.
     */
    @JvmStatic external fun workerIsProcessAlive(pid: Int): Int

    /**
     * Kill switch: manda SIGKILL al group del worker. El worker corre tareas
     * en threads con fork+waitpid; un binario colgado (apt esperando input)
     * bloquea el waitpid indefinidamente. Como el hijo vive en el group del
     * worker, kill(-pgid) lo tumba y desbloquea el waitpid. Solicitudes desde
     * MSG_KILL (timeout de execRootfsWorker).
     * Nota: daemons detached hacen setsid() → grupo propio → NO se matan aquí.
     */
    @JvmStatic external fun workerKillGroup(): Int
}