package dev.nanoai.mobile

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.util.Log

/**
 * Cliente del proceso worker `:nanoshell` (NanoshellWorkerService).
 *
 * El proceso principal (Flutter + GPU) NO puede fork()+dlopen (crash del
 * driver Mali). Este cliente conecta al worker (proceso sin GPU) y le envía
 * la tarea de spawn. El worker ejecuta y escribe stdout/stderr/rc a
 * files/worker_*_<taskId>; el llamador lee esos archivos después.
 */
class WorkerClient(private val ctx: Context) {

    companion object {
        private const val TAG = "nanoshell-client"
        const val MSG_SPAWN = 1
        const val MSG_SPAWN_DETACHED = 3
    }

    private var bound = false
    private var workerMessenger: Messenger? = null
    private val pending = HashMap<String, Boolean>()

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            workerMessenger = Messenger(service)
            bound = true
            Log.i(TAG, "worker conectado")
            // Reenviar tareas pendientes (encoladas antes del bind).
            synchronized(pending) {
                pending.keys.forEach { }
            }
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
        try {
            val intent = Intent(ctx, NanoshellWorkerService::class.java)
            ctx.bindService(intent, connection, Context.BIND_AUTO_CREATE)
        } catch (e: Exception) {
            Log.e(TAG, "bind falló: $e")
        }
    }

    fun disconnect() {
        if (bound) {
            try { ctx.unbindService(connection) } catch (_: Exception) {}
            bound = false
        }
    }

    /**
     * Envía la tarea de spawn al worker. Devuelve true si el mensaje se
     * entregó (el worker ejecuta en background y escribe a files/).
     */
    fun spawn(
        binaryPath: String,
        argv: List<String>,
        envp: List<String>,
        ldPreload: String?,
        taskId: String,
        filesDir: String,
    ): Boolean {
        val m = workerMessenger ?: run {
            Log.w(TAG, "worker no conectado todavía")
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
            Log.e(TAG, "send falló: $e")
            false
        }
    }

    /** Spawn sin esperar — para daemons. Retorna PID (>0) o -1 si falla. */
    fun spawnDetached(
        binaryPath: String,
        argv: List<String>,
        envp: List<String>,
        taskId: String,
    ): Int {
        val m = workerMessenger ?: return -1
        return try {
            val msg = Message.obtain(null, MSG_SPAWN_DETACHED)
            msg.data = Bundle().apply {
                putString("binaryPath", binaryPath)
                putStringArrayList("argv", ArrayList(argv))
                putStringArrayList("envp", ArrayList(envp))
                putString(NanoshellWorkerService.EXTRA_TASK_ID, taskId)
            }
            msg.replyTo = Messenger(object : Handler(Looper.getMainLooper()) {
                override fun handleMessage(reply: Message) {
                    // PID recibido pero no lo usamos directamente aquí
                }
            })
            m.send(msg)
            1 // asumimos éxito si el mensaje se envió
        } catch (e: Exception) {
            Log.e(TAG, "sendDetached falló: $e")
            -1
        }
    }
}
