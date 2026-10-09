package dev.nanoai.mobile.runtime

import android.content.Context
import android.os.SystemClock
import android.util.Log
import dev.nanoai.mobile.channels.LiteRtEngineOwner
import dev.nanoai.mobile.channels.LiteRtGeneration
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.io.File

/** QUÉ: dueño Application del LiteRT real, compartido con UI y headless.
 * CÓMO: usa la barrera nativa común y publica readiness de pesos existentes.
 * POR QUÉ: una bandera Flutter no prueba que siga cargado tras liberar RAM. */
class NanoModelRuntimeSupervisor(
    private val appContext: Context,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    private val idleTimeoutMs: Long = 5 * 60 * 1000L,
) {
    enum class State { UNLOADED, LOADING, READY, GENERATING, UNLOADING, FAILED }
    @Volatile private var owner: LiteRtEngineOwner? = null
    @Volatile private var generation: LiteRtGeneration? = null
    @Volatile private var currentState = State.UNLOADED
    @Volatile private var lastActivityAt = 0L
    private var unloadJob: Job? = null
    private val requests = ConcurrentHashMap<String, AtomicBoolean>()
    val state: State get() = currentState

    // Consultar estado no carga un modelo ni presenta memoria liberada como disponible.
    fun status(): Map<String, Any?> = mapOf(
        "loaded" to (owner?.engine != null && generation != null &&
            currentState in listOf(State.READY, State.GENERATING)),
        "modelPath" to owner?.modelPath,
        "backend" to owner?.backend,
        "state" to currentState.name,
    )

    suspend fun ensureReady(modelPath: String, backend: String = "cpu", threads: Int = 4)
        : Pair<LiteRtEngineOwner, LiteRtGeneration> {
        // Android admite alias del mismo archivo; una identidad canónica evita recargar sus pesos.
        val path = File(modelPath).canonicalPath
        LocalModelGate.cancelForReplacement("litert", path)
        return LocalModelGate.mutex.withLock {
            cancelScheduledUnload()
            val currentOwner = owner
            val currentGen = generation
            // Diagnóstico de caché sin prompts: distingue cierre real de identidad distinta.
            Log.i("ModelSupervisor", "ensure loaded=${currentOwner?.engine != null} " +
                "samePath=${currentOwner?.modelPath == path} sameBackend=${currentOwner?.backend == backend}")
            if (currentOwner?.engine != null && currentGen != null &&
                currentOwner.modelPath == path && currentOwner.backend == backend) {
                lastActivityAt = SystemClock.elapsedRealtime()
                scheduleWarmUnload()
                return@withLock currentOwner to currentGen
            }
            InferenceThermalGuard.checkAdmission()
            LocalModelGate.claimLocked("litert", path, ::closeLocked) {
                cancelInference()
            }
            // El reemplazo cierra la conversación antes de cerrar sus pesos JNI.
            closeLocked()
            currentState = State.LOADING
            val nextOwner = LiteRtEngineOwner(appContext)
            try {
                nextOwner.initialize(path, backend, threads)
                val nextGen = LiteRtGeneration(nextOwner)
                owner = nextOwner
                generation = nextGen
                currentState = State.READY
                lastActivityAt = SystemClock.elapsedRealtime()
                scheduleWarmUnload()
                Log.i("ModelSupervisor", "LiteRT listo backend=$backend")
                nextOwner to nextGen
            } catch (error: Throwable) {
                runCatching { nextOwner.close() }
                currentState = State.FAILED
                LocalModelGate.releaseLocked("litert")
                throw error
            }
        }
    }

    suspend fun generate(args: Map<*, *>, cancelled: AtomicBoolean = AtomicBoolean(false),
        emit: (Map<String, Any?>) -> Unit)
        : Map<String, Any?> {
        val id = args["requestId"] as? String ?: error("Falta requestId")
        check(requests.putIfAbsent(id, cancelled) == null) { "requestId LiteRT repetido" }
        try { return LocalModelGate.mutex.withLock {
        check(!cancelled.get()) { "LiteRT request cancelado antes de iniciar" }
        cancelScheduledUnload()
        val gen = generation ?: error("LiteRT descargado: vuelve a asegurar el motor")
        currentState = State.GENERATING
        try {
            // Retiene el terminal hasta confirmar que no hubo aborto térmico.
            var terminal: Map<String, Any?>? = null
            val result = InferenceThermalGuard.protect({ gen.cancel(args["requestId"] as? String) }) {
                gen.generate(args, { event ->
                    if (event["stop"] == true) terminal = event else emit(event)
                }, onStarted = { if (cancelled.get()) gen.cancel(id) })
            }
            check(!cancelled.get()) { "LiteRT generación cancelada" }
            terminal?.let(emit)
            result
        } finally {
            currentState = State.READY
            lastActivityAt = SystemClock.elapsedRealtime()
            scheduleWarmUnload()
        }
        } } finally { requests.remove(id, cancelled) }
    }

    // Alcanza también requests esperando la barrera, sin cancelar otro identificador.
    fun cancelInference(requestId: String? = null): Boolean {
        var found = false
        for ((id, cancelled) in requests) if (requestId == null || requestId == id) {
            cancelled.set(true)
            found = true
        }
        return (generation?.cancel(requestId) ?: false) || found
    }
    fun getMetrics(): Map<String, Any?> = generation?.metrics ?: emptyMap()

    // Cancela antes de esperar al decoder; el mutex garantiza su finalización.
    suspend fun unload() {
        Log.i("ModelSupervisor", "LiteRT liberación explícita solicitada")
        cancelInference()
        LocalModelGate.mutex.withLock {
            cancelScheduledUnload()
            closeLocked()
            LocalModelGate.releaseLocked("litert")
        }
    }

    // Solo bajo LocalModelGate: Conversation -> Engine, sin cerrar decode activo.
    private fun closeLocked() {
        cancelScheduledUnload()
        currentState = State.UNLOADING
        try { generation?.close() } finally {
            generation = null
            try { owner?.close() } finally {
                owner = null
                currentState = State.UNLOADED
            }
        }
    }

    private fun scheduleWarmUnload() {
        cancelScheduledUnload()
        unloadJob = scope.launch {
            delay(idleTimeoutMs)
            LocalModelGate.mutex.withLock {
                if (currentState == State.READY &&
                    SystemClock.elapsedRealtime() - lastActivityAt >= idleTimeoutMs) {
                    unloadJob = null
                    closeLocked()
                    LocalModelGate.releaseLocked("litert")
                    Log.i("ModelSupervisor", "LiteRT liberado por inactividad")
                }
            }
        }
    }

    private fun cancelScheduledUnload() {
        unloadJob?.cancel()
        unloadJob = null
    }
}
