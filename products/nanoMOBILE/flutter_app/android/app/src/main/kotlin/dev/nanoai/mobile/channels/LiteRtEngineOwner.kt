package dev.nanoai.mobile.channels

import android.content.Context
import android.os.SystemClock
import android.util.Log
import com.google.ai.edge.litertlm.*
import java.io.File

// Dueño único de pesos JNI. Texto solamente: no carga visión/audio ni promete esas modalidades.
@OptIn(ExperimentalApi::class)
internal class LiteRtEngineOwner(private val context: Context) {
    var engine: Engine? = null
        private set
    var modelPath: String? = null
        private set
    var backend: String? = null
        private set

    fun initialize(path: String, requested: String): Map<String, Any> {
        val file = File(path).canonicalFile
        require(file.isFile && file.length() > 0 && file.extension == "litertlm") {
            "Se requiere un archivo .litertlm completo"
        }
        val models = File(context.filesDir, "nano/models").canonicalFile
        require(file.path.startsWith(models.path + File.separator)) { "Modelo fuera de nano/models" }
        require(requested in listOf("cpu", "gpu")) { "Backend no soportado" }
        if (engine != null && modelPath == file.path && backend == requested) {
            return mapOf("success" to true, "backend" to requested, "modelPath" to file.path)
        }
        close()
        ExperimentalFlags.enableBenchmark = true
        ExperimentalFlags.enableSpeculativeDecoding = false
        val candidate = Engine(EngineConfig(
            modelPath = file.path,
            backend = if (requested == "gpu") Backend.GPU() else Backend.CPU(threadCount = 4),
            maxNumTokens = 8192,
            cacheDir = File(context.cacheDir, "litert").apply { mkdirs() }.path,
        ))
        try {
            val started = SystemClock.elapsedRealtime()
            // Mide carga real sin registrar prompts ni datos privados.
            Log.i("LiteRtChannel", "initialize backend=$requested file="+file.name)
            candidate.initialize()
            Log.i("LiteRtChannel", "initialized ms="+(SystemClock.elapsedRealtime()-started))
            engine = candidate
            modelPath = file.path
            backend = requested
            return mapOf("success" to true, "backend" to requested, "modelPath" to file.path)
        } catch (error: Throwable) {
            runCatching { candidate.close() }
            throw error
        }
    }

    // close() libera el motor real; System.gc() no es liberación JNI.
    fun close() {
        val previous = engine
        engine = null
        modelPath = null
        backend = null
        previous?.close()
    }
}
