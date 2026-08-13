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
 * Proceso worker `:nanoshell` para ejecuciÃ³n nativa segura.
 *
 * PROBLEMA REAL (verificado en device): fork()+dlopen() de apt en el proceso
 * principal de Flutter crashea SIEMPRE (SIGSEGV, fault addr "USER=nan",
 * "at/usr/..."): el hijo hereda el driver GPU Mali/Impeller en estado
 * inconsistente y apt (con mÃ¡s allocaciÃ³n que bash) lo dispara.
 *
 * SOLUCIÃ“N: este Service corre en un proceso SEPARADO (`:nanoshell`) sin
 * Flutter ni GPU. fork+dlopen es seguro ahÃ­. El proceso principal envÃ­a la
 * tarea (binaryPath, argv, envp, ldPreload) vÃ­a Messenger; el worker ejecuta
 * con NanoshellBridge y escribe stdout/stderr/exitCode a archivos temporales
 * en files/ que el principal lee (los punteros nativos no cruzan procesos).
 */
class NanoshellWorkerService : Service() {

companion object {
        const val MSG_SPAWN = 1
        const val MSG_RESULT = 2
        const val MSG_SPAWN_DETACHED = 3
        const val MSG_KILL = 4
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
                MSG_KILL -> handleKill(msg)
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
            android.util.Log.e("nanoshell-worker", "loadLibrary fallÃ³: $e")
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
                android.util.Log.e("nanoshell-worker", "spawn $taskId fallÃ³: $e")
            }
        }.start()
    }

    /** Spawn sin esperar â€” para daemons (Xvnc, openbox). Retorna PID al
     *  cliente vÃ­a messenger. */
    private fun handleSpawnDetached(msg: Message) {
        val b = msg.data
        val binaryPath = b.getString("binaryPath") ?: return
        val argv = b.getStringArrayList("argv") ?: arrayListOf()
        val envPairs = b.getStringArrayList("envp") ?: arrayListOf()
        val taskId = b.getString(EXTRA_TASK_ID) ?: "d${System.currentTimeMillis()}"
        val filesDir = b.getString("filesDir") ?: filesDir.absolutePath
        // Extraer el Messenger ANTES del Thread: msg lo recicla el Looper al
        // salir de handleMessage; acceder a msg.replyTo desde otro hilo tras
        // el return es una carrera con el pool de Message.obtain.
        val replyTo = msg.replyTo

        // K-2: preloadRootfsLibs (System.load ~70 libs x 4 passes) + fork en el
        // MAIN looper del worker bloqueaba el latch de conexion (WorkerClient
        // awaitConnected 20s) -> falso negativo -> Xvnc huerfano reteniendo 5901.
        // Mover a un Thread (como handleSpawn): System.load y fork son seguros
        // fuera del looper.
        Thread {
            val envp = withNativeRuntimeEnv(envPairs, filesDir).toTypedArray()
            // En ColorOS/OPPO execve() sobre binarios del sandbox devuelve EACCES.
            // Xvnc entonces cae al fallback dlopen(), que necesita las DT_NEEDED del
            // rootfs ya cargadas en el namespace del worker (clns-7).
            // Sin esta precarga, el detached muere con rc=127 antes de abrir 5901.
            preloadRootfsLibs(filesDir)
            val pid = NanoshellBridge.workerSpawnDetached(binaryPath, argv.toTypedArray(), envp)
            android.util.Log.i("nanoshell-worker", "detached $taskId pid=$pid -> $binaryPath")

            // Responder al cliente con el PID
            val reply = Message.obtain(null, MSG_RESULT)
            reply.data = Bundle().apply {
                putString(EXTRA_TASK_ID, taskId)
                putInt(EXTRA_PID, pid)
            }
            try { replyTo?.send(reply) } catch (_: Exception) {}
        }.start()
    }

    /**
     * Kill switch remoto (requested por MainActivity / timeout de execRootfsWorker).
     *
     * El worker ejecuta tareas en threads con _spawn_internal (fork + waitpid).
     * Un binario colgado (apt esperando input, tar gigante) bloquea el waitpid
     * indefinidamente. Para desbloquearlo hay que matar el HIJO colgado. Como
     * el hijo vive en el group del worker (no hace setsid), SIGKILL al grupo
     * entero los mata; luego este proceso termina con stopSelf().
     *
     * Atentos: daemons detached (Xvnc, openbox) llaman setsid() y viven en
     * grupo propio. No se matan aquí: NativeRuntimeSupervisor detiene el
     * DesktopSessionManager antes de matar el worker.
     */
    private fun handleKill(msg: Message) {
        android.util.Log.w("nanoshell-worker", "MSG_KILL recibido â€” matando group + worker")
        try { NanoshellBridge.workerKillGroup() } catch (_: Throwable) {}
        // stopSelf() si el SIGKILL anterior no tumbÃ³ el proceso (fallback).
        this.stopSelf()
    }

    /** Libs versionadas criticas que apt y Xvnc necesitan (System.load las registra
     *  en clns-7). Se cargan desde usr/lib del rootfs. */
    private fun preloadRootfsLibs(filesDir: String) {
        var libDir = java.io.File(filesDir, "nano/usr/lib")
        if (!libDir.exists()) {
            libDir = java.io.File(filesDir, "usr/lib")
        }
        if (libDir.exists()) {
            libDir.listFiles()?.forEach { f ->
                if (f.name.contains(".so.")) {
                    val baseName = f.name.substringBefore(".so.") + ".so"
                    val target = java.io.File(libDir, baseName)
                    if (!target.exists()) {
                        try { f.copyTo(target) } catch (_: Exception) {}
                    }
                }
            }
        }

        val libs = listOf(
            "libc++_shared.so", "libandroid-support.so", "libffi.so", "libcharset.so",
            "libz.so.1", "libz.so", "libbz2.so.1.0", "liblzma.so.5", "libzstd.so.1",
            "liblz4.so", "libxxhash.so.0", "libpng16.so", "libbrotlicommon.so", "libbrotlidec.so",
            "libiconv.so", "libpcre2-8.so", "libfreetype.so",
            "libcrypto.so.3", "libcrypto.so", "libssl.so.3", "libssl.so",
            "libgpg-error.so", "libgcrypt.so",
            "libnettle.so.8", "libhogweed.so.6",
            "libidn2.so", "libidn2.so.0", "libunistring.so", "libunistring.so.5", "libunistring.so.2",
            "libtasn1.so", "libp11-kit.so", "libgnutls.so",
            "libncursesw.so.6", "libreadline.so.8",
            "libXau.so.6", "libXau.so",
            "libXdmcp.so.6", "libXdmcp.so",
            "libxcb.so.1", "libxcb.so",
            "libX11.so.6", "libX11.so",
            "libXext.so.6", "libXext.so",
            "libXrender.so.1", "libXrender.so",
            "libpixman-1.so.0", "libpixman-1.so",
            "libfontenc.so.1", "libfontenc.so",
            "libxfont2.so.2", "libxfont2.so",
            "libxkbfile.so.1", "libxkbfile.so",
            "libexpat.so.1", "libexpat.so",
            "libfontconfig.so.1", "libfontconfig.so",
            "libandroid-shmem.so", // requerida por libcairo.so.2 (dep de tint2) — sin ella dlopen(tint2) falla con rc=127
            "libcairo.so.2", "libcairo.so",
            "libGLdispatch.so.0", "libGLdispatch.so",
            "libOpenGL.so.0", "libOpenGL.so",
            "libGLX.so.0", "libGLX.so",
            "libGL.so.1", "libGL.so",
            "libEGL.so.1", "libEGL.so"
        )

        val loaded = mutableSetOf<String>()
        fun tryLoad(file: java.io.File, label: String, verboseFailure: Boolean) {
            try {
                val canonical = file.canonicalPath
                if (!loaded.add(canonical)) return
                System.load(canonical)
            } catch (e: Throwable) {
                if (verboseFailure) {
                    android.util.Log.w("nanoshell-worker", "preload $label fallo: ${e.message}")
                }
            }
        }

        // El set crítico con verboseFailure=true spameaba ~50 líneas WARN por
        // spawn × 4 daemons → "LOGS OVER PROC QUOTA, rows DROPPED" en el worker
        // (evidencia device 2026-08-12: reaps de aterm invisibles por la cuota).
        // Se cuenta el resumen en UNA línea en vez de loguear lib por lib.
        var criticalFailed = 0
        for (lib in libs) {
            val f = java.io.File(libDir, lib)
            if (!f.exists()) continue
            val before = loaded.size
            tryLoad(f, lib, false)
            if (loaded.size == before) criticalFailed++
        }
        if (criticalFailed > 0) {
            android.util.Log.w("nanoshell-worker",
                "preload set crítico: $criticalFailed/${libs.size} sin cargar (esperado en worker sin GPU)")
        }

        repeat(4) { pass ->
            var progress = false
            val libFiles = libDir.listFiles()
                ?.filter { it.isFile && it.name.contains(".so") }
                ?.sortedBy { it.name }
                ?: emptyList()
            for (f in libFiles) {
                val before = loaded.size
                tryLoad(f, f.name, false)
                if (loaded.size > before) progress = true
            }
            if (!progress) return@repeat
            android.util.Log.i("nanoshell-worker", "preload pass ${pass + 1}: ${loaded.size} libs")
        }

        android.util.Log.i("nanoshell-worker", "preload de libs rootfs completado (${libDir.path})")
    }

    private fun withNativeRuntimeEnv(envPairs: List<String>, filesDir: String): List<String> {
        val out = envPairs.toMutableList()
        fun hasKey(key: String): Boolean = out.any { it.startsWith("$key=") }

        val rootfs = java.io.File(filesDir, "nano/usr").absolutePath
        val nativeDir = applicationInfo.nativeLibraryDir
        if (!hasKey("NANO_ROOTFS")) out.add("NANO_ROOTFS=$rootfs")
        if (!hasKey("NANO_NATIVE_LIB_DIR")) out.add("NANO_NATIVE_LIB_DIR=$nativeDir")
        if (!hasKey("LD_PRELOAD")) out.add("LD_PRELOAD=$nativeDir/libnanoroot.so")
        return out
    }

    /** Graceful shutdown: detiene el servicio. Llamado desde MainActivity.onDestroy
     *  para evitar que el worker siga ejecutando tareas huÃ©rfanas. */
    private fun handleKill() {
        android.util.Log.i("nanoshell-worker", "recibido MSG_KILL â€” deteniendo worker")
        stopSelf()
    }
}
