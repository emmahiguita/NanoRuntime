package dev.nanoai.mobile

import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Propietario único del motor de inferencia `nanortime` (PIE aarch64).
 *
 * Ciclo de vida:
 *  1. `ensureExtracted` copia assets/bin/nanortime del APK a
 *     files/nano/engine/nanortime + chmod 755. Los assets no llevan bit de
 *     ejecución y el kernel no ejecuta dentro del APK.
 *  2. `start` spawnea el PIE vía worker :nanoshell (WorkerClient.
 *     spawnDetached → fork+exec, setsid). El C ya cubre: anti-duplicados por
 *     binario (worker_jni.c `_swap_daemon_pid` mata al viejo antes del fork)
 *     y reaper thread (waitpid → sin zombis). Aquí se añade una guarda
 *     Kotlin (PID vivo) para no duplicar en carrera.
 *  3. Health poll HTTP a 127.0.0.1:<port>/health con backoff limitado
 *     (máx HEALTH_MAX_ATTEMPTS). El server es model-free con --no-model:
 *     /health responde `status: ok` honesto y /completion devuelve 503
 *     runtime_unavailable hasta que exista un GGUF (B5).
 *  4. `stop` mata limpio: SIGTERM (API 33+) → espera acotada → SIGKILL;
 *     API < 33 solo dispone de Process.killProcess (SIGKILL directo).
 *
 * Estados se entregan por callback desde hilos IO — el handler del canal es
 * responsable de saltar al main thread. Un contador de generación descarta
 * callbacks de un start viejo tras un stop+start rápido.
 */
class EngineSupervisor(
    private val context: android.content.Context,
    private val appFilesDir: File,
    private val pathPolicy: SecurePathPolicy,
    private val workerClientProvider: () -> WorkerClient?,
) {

    sealed class EngineState {
        object Idle : EngineState()
        data class Starting(val port: Int) : EngineState()
        data class Ready(val pid: Int, val port: Int) : EngineState()
        data class Failed(val reason: String) : EngineState()
    }

    private data class EngineHandle(val pid: Int, val port: Int)

    private val lock = Any()
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Volatile private var handle: EngineHandle? = null
    @Volatile private var generation = 0
    @Volatile private var shuttingDown = false

    private val engineDir: File
        get() = File(appFilesDir, "nano/engine")

    /**
     * Extrae el PIE del APK si no existe o el tamaño difiere del asset
     * (idempotente). Los assets Flutter viven bajo flutter_assets/ en el APK;
     * se prueban ambos prefijos por robustez ante cambios de AGP.
     */
    fun ensureExtracted(onResult: (Result<File>) -> Unit) {
        ioScope.launch {
            onResult(runCatching { extractEngineBlocking() })
        }
    }

    private fun extractEngineBlocking(): File {
        val dest = pathPolicy.requireInsideNanoFiles(File(engineDir, "nanortime"), "engineBinary")
        if (!dest.parentFile!!.exists()) dest.parentFile!!.mkdirs()

        val (assetPath, assetSize) = findEngineAsset() ?: run {
            throw IllegalStateException("asset nanortime no encontrado en el APK (¿assets/bin/ en pubspec?)")
        }

        if (dest.exists() && dest.length() == assetSize) return dest

        context.assets.open(assetPath).use { input ->
            val tmp = File(dest.parentFile, "nanortime.tmp")
            FileOutputStream(tmp).use { output ->
                val buffer = ByteArray(64 * 1024)
                var total = 0L
                var len: Int
                while (input.read(buffer).also { len = it } > 0) {
                    output.write(buffer, 0, len)
                    total += len
                }
                if (total != assetSize) {
                    tmp.delete()
                    throw IllegalStateException(
                        "extracción incompleta: $total de $assetSize bytes (¿asset corrupto?)",
                    )
                }
            }
            // Rename atómico: Dart/Kotlin nunca ven un binario a medio escribir.
            if (!tmp.renameTo(dest)) {
                tmp.delete()
                throw IllegalStateException("rename atómico falló para ${dest.name}")
            }
        }
        if (!dest.setExecutable(true, false)) {
            Log.w(TAG, "setExecutable devolvió false — verificando flag real")
        }
        check(dest.canExecute()) { "PIE extraído sin bit de ejecución: ${dest.absolutePath}" }
        Log.i(TAG, "PIE listo: ${dest.absolutePath} (${dest.length()} bytes, exec=${dest.canExecute()})")
        return dest
    }

    /** Localiza el asset y su tamaño. openFd es O(1) cuando no está comprimido. */
    private fun findEngineAsset(): Pair<String, Long>? {
        for (candidate in ASSET_CANDIDATES) {
            try {
                val fd = context.assets.openFd(candidate)
                val size = fd.length
                fd.close()
                if (size > 0) return candidate to size
            } catch (_: Exception) {
                // openFd falla en assets comprimidos; medir por stream.
                try {
                    val len = context.assets.open(candidate).use { it.available().toLong() }
                    if (len > 0) return candidate to len
                } catch (_: Exception) {
                }
            }
        }
        return null
    }

    /** PID vivo según procfs — sin dependencias externas, honesto. */
    fun isPidAlive(pid: Int): Boolean = pid > 0 && File("/proc/$pid").exists()

    /** Snapshot sin IO de red — útil para la UI entre polls. */
    fun currentState(): EngineState {
        val h = handle ?: return EngineState.Idle
        return if (isPidAlive(h.pid)) EngineState.Ready(h.pid, h.port)
        else EngineState.Idle
    }

    /**
     * Arranca el motor. Idempotente: si el PID registrado sigue vivo devuelve
     * Ready sin re-spawn (la guarda del C mata duplicados por binario de
     * todos modos). `modelPath` null = server model-free (--no-model); en B5
     * pasará la ruta del GGUF descargado.
     */
    fun start(port: Int, modelPath: String?, onState: (EngineState) -> Unit) {
        synchronized(lock) {
            if (shuttingDown) {
                onState(EngineState.Failed("supervisor en shutdown"))
                return
            }
            val h = handle
            if (h != null && isPidAlive(h.pid)) {
                onState(EngineState.Ready(h.pid, h.port))
                return
            }
        }

        val gen = synchronized(lock) { ++generation }
        onState(EngineState.Starting(port))

        ioScope.launch {
            try {
                val binary = withContext(Dispatchers.IO) { extractEngineBlocking() }
                val worker = workerClientProvider()
                if (worker == null) {
                    failIfCurrent(gen, onState, "worker :nanoshell no disponible (¿runtime no iniciado?)")
                    return@launch
                }
                // argv[0] = basename: el fallback linker64 de nanoshell.c
                // dropea el duplicado del nombre (strcmp con basename); con la
                // ruta completa, clap la vería como argumento y abortaría.
                val argv = buildList {
                    add(binary.name)
                    add("--server")
                    add("--port"); add(port.toString())
                    // Local-only SIEMPRE: el engine no debe escuchar en la red.
                    add("--bind"); add("127.0.0.1")
                    if (modelPath.isNullOrEmpty()) {
                        add("--no-model")
                    } else {
                        add("--model"); add(modelPath)
                    }
                    add("--quiet")
                }
                val taskId = "engine-$gen-${System.currentTimeMillis()}"
                val pid = withContext(Dispatchers.IO) {
                    // spawnDetached espera hasta 20s el latch del worker
                    // (awaitConnected + replyTo) — bloqueante por diseño.
                    worker.spawnDetached(binary.absolutePath, argv, emptyList(), taskId)
                }
                if (pid <= 0) {
                    failIfCurrent(gen, onState, "spawnDetached falló (pid=$pid, worker no disponible o fork error)")
                    return@launch
                }

                synchronized(lock) {
                    if (generation != gen) return@launch // stop() ocurrió mientras tanto
                    handle = EngineHandle(pid, port)
                }
                Log.i(TAG, "engine pid=$pid port=$port taskId=$taskId — health poll")

                // Health poll con backoff limitado. Si el proceso muere antes,
                // no se sigue esperando el máximo.
                var delayMs = HEALTH_BASE_DELAY_MS
                for (attempt in 1..HEALTH_MAX_ATTEMPTS) {
                    if (!isPidAlive(pid)) {
                        failIfCurrent(gen, onState, "proceso murió antes de estar sano (pid=$pid)")
                        return@launch
                    }
                    val body = withContext(Dispatchers.IO) { probeHealth(port, HEALTH_TIMEOUT_MS) }
                    if (body != null) {
                        synchronized(lock) {
                            if (generation != gen) return@launch
                            handle = EngineHandle(pid, port)
                        }
                        Log.i(TAG, "engine sano pid=$pid port=$port intento=$attempt")
                        onState(EngineState.Ready(pid, port))
                        return@launch
                    }
                    delay(delayMs)
                    delayMs = minOf(delayMs * 2, HEALTH_MAX_DELAY_MS)
                }
                // El proceso sigue vivo pero no responde /health — un server
                // inservible no debe quedar de huérfano ocupando el PID.
                failIfCurrent(
                    gen, onState,
                    "health timeout tras $HEALTH_MAX_ATTEMPTS intentos (pid=$pid)",
                    pidToKill = pid,
                )
            } catch (e: Exception) {
                Log.w(TAG, "start falló: $e")
                // Si el spawn ya devolvió PID y algo falló después, matarlo.
                val pidToKill = synchronized(lock) {
                    if (generation != gen) return@synchronized null
                    handle?.pid.also { handle = null }
                }
                if (pidToKill != null && isPidAlive(pidToKill)) {
                    Log.w(TAG, "start falló con pid=$pidToKill vivo — SIGKILL de limpieza")
                    sendSignal(pidToKill, SIGKILL)
                }
                onState(EngineState.Failed("${e.javaClass.simpleName}: ${e.message}"))
            }
        }
    }

    private fun failIfCurrent(
        gen: Int,
        onState: (EngineState) -> Unit,
        reason: String,
        pidToKill: Int? = null,
    ) {
        synchronized(lock) {
            if (generation != gen) return
            handle = null
        }
        if (pidToKill != null && isPidAlive(pidToKill)) {
            Log.w(TAG, "Failed: matando pid=$pidToKill (proceso inservible)")
            sendSignal(pidToKill, SIGKILL)
        }
        onState(EngineState.Failed(reason))
    }

    /** GET /health con timeout. Devuelve el body si 200 + status ok, null si no. */
    fun probeHealth(port: Int, timeoutMs: Int): String? {
        var conn: HttpURLConnection? = null
        return try {
            conn = URL("http://127.0.0.1:$port/health").openConnection() as HttpURLConnection
            conn.connectTimeout = timeoutMs
            conn.readTimeout = timeoutMs
            conn.requestMethod = "GET"
            if (conn.responseCode != 200) return null
            val body = conn.inputStream.readBytes().toString(Charsets.UTF_8)
            if (!body.contains("\"status\":\"ok\"")) null else body
        } catch (_: Exception) {
            null
        } finally {
            conn?.disconnect()
        }
    }

    /** Kill limpio escalonado: SIGTERM → gracia → SIGKILL. Idempotente. */
    fun stop(onDone: (Boolean) -> Unit) {
        val h: EngineHandle
        synchronized(lock) {
            generation++ // invalida cualquier start en vuelo
            h = handle ?: run {
                onDone(true) // nada corriendo: ya estaba detenido
                return
            }
            handle = null
        }
        Log.i(TAG, "stop: pid=${h.pid} — SIGTERM y espera $TERM_GRACE_MS ms")

        ioScope.launch {
            val pid = h.pid
            if (isPidAlive(pid)) sendSignal(pid, SIGTERM)

            var waited = 0L
            while (waited < TERM_GRACE_MS) {
                if (!isPidAlive(pid)) {
                    Log.i(TAG, "engine pid=$pid terminó con SIGTERM")
                    onDone(true)
                    return@launch
                }
                delay(KILL_POLL_MS)
                waited += KILL_POLL_MS
            }

            if (isPidAlive(pid)) {
                Log.w(TAG, "engine pid=$pid no murió con SIGTERM — SIGKILL")
                sendSignal(pid, SIGKILL)
            }
            // Espera corta post-SIGKILL para confirmar reaper del worker.
            var killed = !isPidAlive(pid)
            repeat(10) {
                if (killed) return@repeat
                delay(KILL_POLL_MS)
                killed = !isPidAlive(pid)
            }
            Log.i(TAG, "engine pid=$pid ${if (killed) "muerto" else "sigue vivo tras SIGKILL"}")
            onDone(killed)
        }
    }

    /** SIGTERM vía Process.sendSignal (API 33+); API < 33 solo SIGKILL directo. */
    private fun sendSignal(pid: Int, signal: Int) {
        try {
            if (android.os.Build.VERSION.SDK_INT >= 33) {
                android.os.Process.sendSignal(pid, signal)
            } else {
                // Sin sendSignal público en < 33: killProcess envía SIGKILL.
                android.os.Process.killProcess(pid)
            }
        } catch (e: Exception) {
            Log.w(TAG, "señal $signal a pid=$pid falló: ${e.message}")
            if (signal == SIGTERM) {
                try { android.os.Process.killProcess(pid) } catch (_: Exception) {}
            }
        }
    }

    fun shutdown() {
        synchronized(lock) {
            if (shuttingDown) return
            shuttingDown = true
            generation++
        }
        val h = handle
        handle = null
        if (h != null && isPidAlive(h.pid)) {
            // Sin corrutinas tras cancel — kill directo y honesto.
            sendSignal(h.pid, SIGKILL)
            Log.i(TAG, "shutdown: SIGKILL a pid=${h.pid}")
        }
        ioScope.cancel()
    }

    companion object {
        private const val TAG = "EngineSupervisor"
        /** Puerto por defecto del server HTTP del motor (127.0.0.1).
         *  Coherente con el default del CLI (--port 8080) y LLMEngineClient. */
        const val ENGINE_PORT_DEFAULT = 8080
        private const val HEALTH_MAX_ATTEMPTS = 24
        private const val HEALTH_BASE_DELAY_MS = 250L
        private const val HEALTH_MAX_DELAY_MS = 1_000L
        private const val HEALTH_TIMEOUT_MS = 2_000
        private const val TERM_GRACE_MS = 3_000L
        private const val KILL_POLL_MS = 100L
        private const val SIGTERM = 15
        private const val SIGKILL = 9
        private val ASSET_CANDIDATES = listOf(
            "flutter_assets/assets/bin/nanortime",
            "assets/bin/nanortime",
        )
    }
}
