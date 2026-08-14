package dev.nanoai.mobile

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Message
import android.os.Messenger
import android.os.ParcelFileDescriptor
import android.util.Log
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/**
 * Cliente del proceso worker `:nanoshell` (NanoshellWorkerService).
 *
 * El proceso principal (Flutter + GPU) no puede fork()+dlopen sin riesgo en
 * algunos dispositivos Mali/ColorOS. Este cliente delega el spawn al worker.
 */
class WorkerClient(private val ctx: Context) {

    companion object {
        private const val TAG = "nanoshell-client"
        const val MSG_SPAWN = 1
        const val MSG_SPAWN_DETACHED = 3
        const val MSG_KILL = 4
        const val MSG_OPEN_FD = 5
        const val MSG_IS_PID_ALIVE = 6
        // El proceso :nanoshell corre en un proceso Android separado (aislado
        // de la GPU/Flutter); bindService() es async y Android puede tardar
        // varios cientos de ms en arrancarlo en frío. Sin esta espera, la
        // primera llamada a spawn/spawnDetached tras el arranque de la app
        // (instalar paquetes, iniciar Desktop, abrir terminal) fallaba con
        // "worker no conectado todavía" aunque el worker conectaría un
        // instante después — un falso bloqueo por pura carrera de tiempos.
        private const val CONNECT_TIMEOUT_MS = 8_000L
        private const val REBIND_INITIAL_DELAY_MS = 1_000L
        private const val REBIND_INTERVAL_MS = 3_000L
    }

    private var bound = false
    @Volatile private var workerMessenger: Messenger? = null
    @Volatile private var shuttingDown = false

    private val mainHandler = Handler(android.os.Looper.getMainLooper())

    // P0-3: si Android mata el proceso :nanoshell (OOM, crash nativo), el
    // ServiceConnection muere y sin rebind el cliente queda inútil hasta
    // reiniciar la app — todo spawn posterior fallaba con "worker no
    // conectado". Reintentamos el bind con backoff hasta reconectar.
    private val rebindRunnable = object : Runnable {
        override fun run() {
            if (shuttingDown) return
            if (workerMessenger == null) {
                Log.w(TAG, "reintentando bind del worker :nanoshell")
                bind()
                mainHandler.postDelayed(this, REBIND_INTERVAL_MS)
            }
        }
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            workerMessenger = Messenger(service)
            bound = true
            mainHandler.removeCallbacks(rebindRunnable)
            Log.i(TAG, "worker conectado")
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            bound = false
            workerMessenger = null
            Log.w(TAG, "worker desconectado — reintentando bind en ${REBIND_INITIAL_DELAY_MS}ms")
            if (!shuttingDown) {
                mainHandler.removeCallbacks(rebindRunnable)
                mainHandler.postDelayed(rebindRunnable, REBIND_INITIAL_DELAY_MS)
            }
        }
    }

    init {
        bind()
    }

    private fun bind() {
        if (shuttingDown) return
        try {
            val intent = Intent(ctx, NanoshellWorkerService::class.java)
            ctx.bindService(intent, connection, Context.BIND_AUTO_CREATE)
        } catch (e: Exception) {
            Log.e(TAG, "bind fallo: $e")
        }
    }

    /**
     * Espera acotada (polling, no ocupa el main thread del caller porque
     * spawn/spawnDetached siempre corren en hilos de fondo) a que
     * [onServiceConnected] entregue el Messenger del worker.
     *
     * Sin esto, la primera llamada tras arrancar la app (o tras killWorker())
     * falla en carrera aunque el bind vaya a completarse enseguida.
     */
    private fun awaitConnected(timeoutMs: Long): Boolean {
        if (workerMessenger != null) return true
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            if (shuttingDown) return false
            if (workerMessenger != null) return true
            Thread.sleep(30)
        }
        return workerMessenger != null
    }

    @Synchronized
    fun disconnect() {
        if (shuttingDown && workerMessenger == null && !bound) return
        shuttingDown = true
        mainHandler.removeCallbacks(rebindRunnable)
        kill()
        unbindWorker()
    }

    fun kill() {
        val m = workerMessenger ?: return
        try {
            val msg = Message.obtain(null, MSG_KILL)
            m.send(msg)
            Log.i(TAG, "MSG_KILL enviado al worker")
        } catch (e: Exception) {
            Log.w(TAG, "kill fallo: $e")
        }
    }

    fun spawn(
        binaryPath: String,
        argv: List<String>,
        envp: List<String>,
        ldPreload: String?,
        taskId: String,
        filesDir: String,
    ): Boolean {
        if (shuttingDown) {
            Log.w(TAG, "spawn rechazado: worker en shutdown")
            return false
        }
        if (!awaitConnected(CONNECT_TIMEOUT_MS)) {
            Log.e(TAG, "spawn abortado: worker :nanoshell no conectó a tiempo bin=$binaryPath")
            return false
        }
        val m = workerMessenger ?: run {
            Log.w(TAG, "worker no conectado todavia")
            return false
        }
        return try {
            val msg = Message.obtain(null, MSG_SPAWN)
            msg.data = Bundle().apply {
                putString("binaryPath", binaryPath)
                putStringArrayList("argv", ArrayList(argv))
                putStringArrayList("envp", ArrayList(envp))
                putString("ldPreload", ldPreload)
                putString(NanoshellWorkerService.EXTRA_TASK_ID, taskId)
                putString("filesDir", filesDir)
            }
            m.send(msg)
            true
        } catch (e: Exception) {
            Log.e(TAG, "send fallo: $e")
            false
        }
    }

    /** Spawn sin esperar para daemons. Retorna PID (>0) o -1 si falla. */
    fun spawnDetached(
        binaryPath: String,
        argv: List<String>,
        envp: List<String>,
        taskId: String,
    ): Int {
        if (shuttingDown) return -1
        if (!awaitConnected(CONNECT_TIMEOUT_MS)) {
            Log.e(TAG, "spawnDetached abortado: worker :nanoshell no conectó a tiempo bin=$binaryPath")
            return -1
        }
        val m = workerMessenger ?: return -1
        var replyThread: HandlerThread? = null
        return try {
            val pidRef = AtomicInteger(-1)
            val latch = CountDownLatch(1)
            replyThread = HandlerThread("nano-detached-$taskId").apply { start() }

            val msg = Message.obtain(null, MSG_SPAWN_DETACHED)
            msg.data = Bundle().apply {
                putString("binaryPath", binaryPath)
                putStringArrayList("argv", ArrayList(argv))
                putStringArrayList("envp", ArrayList(envp))
                putString(NanoshellWorkerService.EXTRA_TASK_ID, taskId)
                putString("filesDir", ctx.filesDir.absolutePath)
            }
            msg.replyTo = Messenger(object : Handler(replyThread.looper) {
                override fun handleMessage(reply: Message) {
                    if (reply.data.getString(NanoshellWorkerService.EXTRA_TASK_ID) == taskId) {
                        pidRef.set(reply.data.getInt(NanoshellWorkerService.EXTRA_PID, -1))
                        latch.countDown()
                    }
                }
            })
            m.send(msg)

            if (!latch.await(20, TimeUnit.SECONDS)) {
                Log.e(TAG, "spawnDetached timeout taskId=$taskId bin=$binaryPath")
                -1
            } else {
                pidRef.get()
            }
        } catch (e: Exception) {
            Log.e(TAG, "sendDetached fallo: $e")
            -1
        } finally {
            try {
                replyThread?.quitSafely()
            } catch (_: Exception) {
            }
        }
    }

    /**
     * ¿El proceso detached [pid] sigue vivo? Delega al worker (el padre):
     * el proceso principal no puede leer /proc de los hijos del worker —
     * Android restringe /proc a los hijos directos del lector. El backend
     * Xvnc usa esto para awaitReady/watchdog en vez de leer /proc él mismo.
     * False ante timeout o worker desconectado (fail-closed: se trata como
     * muerto y el arranque aborta con error honesto).
     */
    fun isPidAlive(pid: Int): Boolean {
        if (shuttingDown || pid <= 0) return false
        if (!awaitConnected(CONNECT_TIMEOUT_MS)) {
            Log.e(TAG, "isPidAlive abortado: worker no conectó a tiempo pid=$pid")
            return false
        }
        val m = workerMessenger ?: return false
        var replyThread: HandlerThread? = null
        return try {
            val aliveRef = AtomicReference<Boolean?>(null)
            val latch = CountDownLatch(1)
            val taskId = "alive${System.currentTimeMillis()}"
            replyThread = HandlerThread("nano-alive").apply { start() }

            val msg = Message.obtain(null, MSG_IS_PID_ALIVE)
            msg.data = Bundle().apply {
                putInt("pid", pid)
                putString(NanoshellWorkerService.EXTRA_TASK_ID, taskId)
            }
            msg.replyTo = Messenger(object : Handler(replyThread.looper) {
                override fun handleMessage(reply: Message) {
                    if (reply.data.getString(NanoshellWorkerService.EXTRA_TASK_ID) == taskId) {
                        aliveRef.set(reply.data.getBoolean("alive", false))
                        latch.countDown()
                    }
                }
            })
            m.send(msg)

            if (!latch.await(3, TimeUnit.SECONDS)) {
                Log.e(TAG, "isPidAlive timeout pid=$pid")
                false
            } else {
                aliveRef.get() == true
            }
        } catch (e: Exception) {
            Log.e(TAG, "isPidAlive fallo: $e")
            false
        } finally {
            try {
                replyThread?.quitSafely()
            } catch (_: Exception) {
            }
        }
    }

    /**
     * Transfiere un fd de modelo (SAF, abierto por el proceso principal) al
     * worker :nanoshell. El worker lo duplica y lo registra por uri para que
     * el engine (hijo del worker) lo herede y lea el GGUF vía /proc/self/fd/N
     * sin copiar el archivo. Devuelve el path fd del worker, o null si falla.
     */
    fun openModelFd(uri: String, pfd: ParcelFileDescriptor): String? {
        if (shuttingDown) return null
        if (!awaitConnected(CONNECT_TIMEOUT_MS)) {
            Log.e(TAG, "openModelFd abortado: worker no conectó a tiempo")
            return null
        }
        val m = workerMessenger ?: return null
        var replyThread: HandlerThread? = null
        return try {
            val pathRef = AtomicReference<String?>()
            val latch = CountDownLatch(1)
            val taskId = "fd${System.currentTimeMillis()}"
            replyThread = HandlerThread("nano-openfd").apply { start() }

            val msg = Message.obtain(null, MSG_OPEN_FD)
            msg.data = Bundle().apply {
                putString("uri", uri)
                putParcelable("fd", pfd)
                putString(NanoshellWorkerService.EXTRA_TASK_ID, taskId)
            }
            msg.replyTo = Messenger(object : Handler(replyThread.looper) {
                override fun handleMessage(reply: Message) {
                    if (reply.data.getString(NanoshellWorkerService.EXTRA_TASK_ID) == taskId) {
                        pathRef.set(reply.data.getString("fdPath"))
                        latch.countDown()
                    }
                }
            })
            m.send(msg)

            if (!latch.await(10, TimeUnit.SECONDS)) {
                Log.e(TAG, "openModelFd timeout uri=$uri")
                null
            } else {
                pathRef.get()
            }
        } catch (e: Exception) {
            Log.e(TAG, "openModelFd falló: $e")
            null
        } finally {
            try {
                replyThread?.quitSafely()
            } catch (_: Exception) {
            }
        }
    }

    fun killWorker(): Boolean {
        if (shuttingDown && workerMessenger == null) return false
        val m = workerMessenger ?: return false
        return try {
            m.send(Message.obtain(null, MSG_KILL))
            shuttingDown = true
            unbindWorker()
            true
        } catch (e: Exception) {
            Log.e(TAG, "sendKill fallo: $e")
            false
        }
    }

    @Synchronized
    private fun unbindWorker() {
        if (bound) {
            try {
                ctx.unbindService(connection)
            } catch (_: Exception) {
            }
        }
        bound = false
        workerMessenger = null
    }
}
