package dev.nanoai.mobile

import android.content.Context
import java.io.File

/**
 * WA-PROD-01 — RuntimeScope: ownership compartido del runtime nativo.
 *
 * Antes MainActivity creaba y destruía EngineSupervisor + NativeRuntimeSupervisor
 * en su onDestroy: con la UI cerrada no quedaba runtime para la automatización.
 * Ahora los supervisores viven en el scope de Application y cada requestor
 * (UI, automation headless) adquiere/release. El shutdown real ocurre solo
 * cuando el ÚLTIMO requestor se va; el arranque sigue siendo bajo demanda
 * (sin residentes permanentes — filosofía de runtime del proyecto).
 */
class RuntimeScope(context: Context) {
    private val appContext = context.applicationContext
    private val filesDir: File = appContext.filesDir
    private val pathPolicy: SecurePathPolicy = SecurePathPolicy(filesDir)

    val nativeSupervisor: NativeRuntimeSupervisor by lazy {
        NativeRuntimeSupervisor(appContext, filesDir, pathPolicy)
    }

    val engineSupervisor: EngineSupervisor by lazy {
        EngineSupervisor(appContext, filesDir, pathPolicy) { nativeSupervisor.workerClient() }
    }

    enum class Holder { UI, AUTOMATION }

    private val lock = Any()
    private val holders = mutableSetOf<Holder>()

    /** Registra al requestor. Devuelve true si es el PRIMERO (el llamador
     *  decide cuándo arrancar el worker: la UI lo difiere para no pelear el
     *  primer frame; automation arranca de inmediato). */
    fun acquire(holder: Holder): Boolean = synchronized(lock) {
        val first = holders.isEmpty()
        holders.add(holder)
        first
    }

    /** El último requestor en irse apaga el runtime (orden: motor antes que
     *  worker — el engine corre en el worker). No-op si nada se adquirió. */
    fun release(holder: Holder) {
        val last = synchronized(lock) {
            if (holders.isEmpty()) return
            holders.remove(holder)
            holders.isEmpty()
        }
        if (!last) return
        engineSupervisor.shutdown()
        nativeSupervisor.shutdown()
    }
}
