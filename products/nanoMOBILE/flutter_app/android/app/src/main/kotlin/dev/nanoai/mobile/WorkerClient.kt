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
import android.util.Log
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

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
    }

    private var bound = false
    private var workerMessenger: Messenger? = null
    @Volatile private var shuttingDown = false

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            workerMessenger = Messenger(service)
            bound = true
            Log.i(TAG, "worker conectado")
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            bound = false
            workerMessenger = null
            Log.w(TAG, "worker desconectado")
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

    @Synchronized
    fun disconnect() {
        if (shuttingDown && workerMessenger == null && !bound) return
        shuttingDown = true
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
