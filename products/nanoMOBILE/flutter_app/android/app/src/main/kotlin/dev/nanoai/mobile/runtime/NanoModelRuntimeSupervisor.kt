package dev.nanoai.mobile.runtime

import android.content.Context
import android.os.SystemClock
import android.util.Log
import dev.nanoai.mobile.channels.LiteRtEngineOwner
import dev.nanoai.mobile.channels.LiteRtGeneration
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * NanoModelRuntimeSupervisor — Supervisor singleton del modelo LiteRT a nivel Application.
 *
 * QUÉ: Administra el ciclo de vida del motor LiteRT (Qwen3) como único dueño en el proceso Android.
 * CÓMO: 
 *   1. Exclusión mutua (runtimeMutex para carga/descarga, inferenceMutex para generación).
 *   2. Reutilización del motor nativo JNI evitando duplicar buffers/pesos en RAM (evita OOM).
 *   3. Warm Mode con auto-descarga tras 5 minutos de inactividad basada en timestamp real.
 * POR QUÉ:
 *   Garantiza que la UI, el servicio headless (AutomationRuntimeService) y el búho flotante
 *   usen una sola instancia del modelo sin pisarse ni duplicar consumo de memoria.
 * SOLID: Single Responsibility Principle (SRP) — Gestión exclusiva del ciclo de vida del modelo.
 */
class NanoModelRuntimeSupervisor(
    private val appContext: Context,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    private val idleTimeoutMs: Long = 5 * 60 * 1000L // 5 minutos de Warm Mode
) {
    companion object {
        private const val TAG = "ModelSupervisor"
    }

    /** Estados explícitos del runtime local. */
    enum class State {
        UNLOADED,
        LOADING,
        READY,
        GENERATING,
        UNLOADING,
        FAILED
    }

    // Exclusión mutua: separa la inicialización estructural de los turnos de inferencia.
    private val runtimeMutex = Mutex()
    private val inferenceMutex = Mutex()

    // Dueño único de los pesos nativos en JNI y controlador de turnos.
    @Volatile private var owner: LiteRtEngineOwner? = null
    @Volatile private var generation: LiteRtGeneration? = null

    @Volatile private var currentState = State.UNLOADED
    @Volatile private var lastActivityAt = 0L
    private var unloadJob: Job? = null

    val state: State get() = currentState

    /**
     * Asegura que el motor esté cargado y listo para inferir.
     * Retorna un par con el propietario del motor y el controlador de turnos.
     */
    suspend fun ensureReady(
        modelPath: String,
        backend: String = "cpu",
        threads: Int = 4
    ): Pair<LiteRtEngineOwner, LiteRtGeneration> = runtimeMutex.withLock {
        cancelScheduledUnload()
        val currentOwner = owner
        val currentGen = generation

        // Si ya está listo y coincide la ruta/backend, lo reutilizamos directamente.
        if (currentOwner != null && currentGen != null && currentState == State.READY) {
            if (currentOwner.modelPath == modelPath && currentOwner.backend == backend) {
                lastActivityAt = SystemClock.elapsedRealtime()
                return Pair(currentOwner, currentGen)
            }
        }

        currentState = State.LOADING
        Log.i(TAG, "Cargando motor LiteRT: $modelPath [$backend] (threads=$threads)")

        try {
            val engineOwner = currentOwner ?: LiteRtEngineOwner(appContext)
            engineOwner.initialize(modelPath, backend, threadCount = threads)
            
            val gen = currentGen ?: LiteRtGeneration(engineOwner)
            
            owner = engineOwner
            generation = gen
            currentState = State.READY
            lastActivityAt = SystemClock.elapsedRealtime()
            Log.i(TAG, "Motor LiteRT listo y warm")
            Pair(engineOwner, gen)
        } catch (t: Throwable) {
            currentState = State.FAILED
            Log.e(TAG, "Fallo al inicializar motor LiteRT", t)
            runCatching { currentOwner?.close() }
            owner = null
            generation = null
            throw t
        }
    }

    /**
     * Ejecuta una generación con exclusión mutua de inferencia.
     */
    suspend fun generate(
        args: Map<*, *>,
        emit: (Map<String, Any?>) -> Unit
    ): Map<String, Any?> = inferenceMutex.withLock {
        cancelScheduledUnload()
        val gen = generation ?: error("El supervisor no tiene motor listo para generar")
        
        currentState = State.GENERATING
        lastActivityAt = SystemClock.elapsedRealtime()
        try {
            gen.generate(args, emit)
        } finally {
            currentState = State.READY
            lastActivityAt = SystemClock.elapsedRealtime()
            scheduleWarmUnload()
        }
    }

    /** Cancela la inferencia activa si coincide con el requestId. */
    fun cancelInference(requestId: String? = null): Boolean {
        return generation?.cancel(requestId) ?: false
    }

    /** Obtiene métricas del último turno ejecutado. */
    fun getMetrics(): Map<String, Any?> {
        return generation?.metrics ?: emptyMap()
    }

    /**
     * Descarga el modelo y libera buffers nativos de JNI.
     */
    suspend fun unload(): Unit = runtimeMutex.withLock {
        cancelScheduledUnload()
        if (currentState != State.UNLOADED) {
            currentState = State.UNLOADING
            Log.i(TAG, "Descargando motor LiteRT de memoria RAM/GPU")
            try {
                generation?.close()
                owner?.close()
            } finally {
                generation = null
                owner = null
                currentState = State.UNLOADED
                Log.i(TAG, "Motor LiteRT descargado exitosamente")
            }
        }
    }

    /**
     * Programa la descarga en caliente tras inactividad.
     */
    private fun scheduleWarmUnload() {
        cancelScheduledUnload()
        unloadJob = scope.launch {
            delay(idleTimeoutMs)
            val idleFor = SystemClock.elapsedRealtime() - lastActivityAt
            if (idleFor >= idleTimeoutMs && currentState == State.READY) {
                Log.i(TAG, "Inactividad de ${idleFor / 1000}s superada -> liberando RAM")
                unload()
            }
        }
    }

    private fun cancelScheduledUnload() {
        unloadJob?.cancel()
        unloadJob = null
    }
}
