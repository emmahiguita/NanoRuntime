package dev.nanoai.mobile

import android.app.Service
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger

/**
 * Proceso worker `:nanoshell` para ejecución nativa segura.
 *
 * PROBLEMA REAL (verificado en device): fork()+dlopen() de apt en el proceso
 * principal de Flutter crashea SIEMPRE (SIGSEGV, fault addr "USER=nan",
 * "at/usr/..."): el hijo hereda el driver GPU Mali/Impeller en estado
 * inconsistente y apt (con más allocación que bash) lo dispara.
 *
 * SOLUCIÓN: este Service corre en un proceso SEPARADO (`:nanoshell`) sin
 * Flutter ni GPU. fork+dlopen es seguro ahí. El proceso principal envía la
 * tarea (binaryPath, argv, envp, ldPreload) vía Messenger; el worker ejecuta
 * con NanoshellBridge y escribe stdout/stderr/exitCode a archivos temporales
 * en files/ que el principal lee (los punteros nativos no cruzan procesos).
 */
class NanoshellWorkerService : Service() {

    companion object {
        const val MSG_SPAWN = 1
        const val MSG_RESULT = 2
        const val MSG_SPAWN_DETACHED = 3
        const val EXTRA_OUT = "nanoai.worker.out"
        const val EXTRA_ERR = "nanoai.worker.err"
        const val EXTRA_RC = "nanoai.worker.rc"
        const val EXTRA_TASK_ID = "nanoai.worker.task"
        const val EXTRA_PID = "nanoai.worker.pid"
        const val CHANNEL_WORKER = "com.nanoai/worker"
    }

    private val handler = object : Handler(Looper.getMainLooper()) {
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                MSG_SPAWN -> handleSpawn(msg)
                MSG_SPAWN_DETACHED -> handleSpawnDetached(msg)
                else -> android.util.Log.w("nanoshell-worker", "msg desconocido ${msg.what}")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        try {
            System.loadLibrary("nanoshell")
            android.util.Log.i("nanoshell-worker", "libnanoshell.so cargada en worker (sin GPU)")
        } catch (e: Throwable) {
            android.util.Log.e("nanoshell-worker", "loadLibrary falló: $e")
        }
    }

    override fun onBind(intent: Intent?): IBinder = Messenger(handler).binder

    /** Ejecuta la tarea: lee argv/envp de los extras, spawn, escribe a files/. */
    private fun handleSpawn(msg: Message) {
        val b = msg.data
        val binaryPath = b.getString("binaryPath") ?: return
        val argv = b.getStringArrayList("argv") ?: arrayListOf()
        val envPairs = b.getStringArrayList("envp") ?: arrayListOf()
        val ldPreload = b.getString("ldPreload")
        val taskId = b.getString(EXTRA_TASK_ID) ?: "t${System.currentTimeMillis()}"
        val filesDir = b.getString("filesDir") ?: filesDir.absolutePath

        val envp = envPairs.toTypedArray()

        Thread {
            try {
                // Preload de libs versionadas del rootfs: System.load() registra
                // la lib en el namespace del proceso (clns-7), que dlopen luego
                // resuelve. Sin esto, apt falla con "libz.so.1 not found".
                preloadRootfsLibs(filesDir)
                val rc = NanoshellBridge.workerSpawn(
                    binaryPath, argv.toTypedArray(), envp, ldPreload,
                    taskId, filesDir
                )
                android.util.Log.i("nanoshell-worker", "task $taskId rc=$rc")
            } catch (e: Throwable) {
                android.util.Log.e("nanoshell-worker", "spawn $taskId falló: $e")
            }
        }.start()
    }

    /** Spawn sin esperar — para daemons (Xvnc, openbox). Retorna PID al
     *  cliente vía messenger. */
    private fun handleSpawnDetached(msg: Message) {
        val b = msg.data
        val binaryPath = b.getString("binaryPath") ?: return
        val argv = b.getStringArrayList("argv") ?: arrayListOf()
        val envPairs = b.getStringArrayList("envp") ?: arrayListOf()
        val taskId = b.getString(EXTRA_TASK_ID) ?: "d${System.currentTimeMillis()}"

        val envp = envPairs.toTypedArray()
        val pid = NanoshellBridge.workerSpawnDetached(binaryPath, argv.toTypedArray(), envp)
        android.util.Log.i("nanoshell-worker", "detached $taskId pid=$pid -> $binaryPath")

        // Responder al cliente con el PID
        val reply = Message.obtain(null, MSG_RESULT)
        reply.data = Bundle().apply {
            putString(EXTRA_TASK_ID, taskId)
            putInt(EXTRA_PID, pid)
        }
        try { msg.replyTo?.send(reply) } catch (_: Exception) {}
    }

    /** Libs versionadas críticas que apt necesita (System.load las registra
     *  en clns-7). Se cargan desde usr/lib del rootfs. */
    private fun preloadRootfsLibs(filesDir: String) {
        val libDir = java.io.File(filesDir, "usr/lib")
        // Orden topológico de dependencias: las libs base (sin deps del
        // rootfs) primero, luego las que dependen de ellas. System.load
        // resuelve DT_NEEDED al instante — si una dep no está cargada, falla.
        val libs = listOf(
            // Capa 1: libs base (solo dependen de libc/libc++ del sistema)
            "libc++_shared.so", "libffi.so", "libcharset.so",
            // Capa 2: compresión
            "libz.so.1", "libbz2.so.1.0", "liblzma.so.5", "libzstd.so.1",
            "liblz4.so", "libxxhash.so.0",
            // Capa 3: iconv + pcre
            "libiconv.so", "libpcre2-8.so",
            // Capa 4: crypto (libcrypto antes de libssl)
            "libcrypto.so.3", "libssl.so.3",
            // Capa 5: gcrypt/gpg → nettle/hogweed → gnutls
            "libgpg-error.so", "libgcrypt.so",
            "libnettle.so.8", "libhogweed.so.6",
            "libidn2.so", "libunistring.so", "libtasn1.so", "libp11-kit.so",
            "libgnutls.so",
            // Capa 6: ncurses/readline (terminal)
            "libncursesw.so.6", "libreadline.so.8",
            // Capa 7: apt
            "libapt-pkg.so", "libapt-private.so",
        )
        for (lib in libs) {
            val f = java.io.File(libDir, lib)
            if (!f.exists()) continue
            try {
                System.load(f.absolutePath)
            } catch (e: Throwable) {
                android.util.Log.w("nanoshell-worker", "preload $lib falló: ${e.message}")
            }
        }
        android.util.Log.i("nanoshell-worker", "preload de libs rootfs completado (${libDir.path})")
    }
}
