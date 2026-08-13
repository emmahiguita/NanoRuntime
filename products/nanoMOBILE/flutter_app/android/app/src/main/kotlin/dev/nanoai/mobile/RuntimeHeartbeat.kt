package dev.nanoai.mobile

import android.util.Log
import java.io.File

/**
 * U-10: Heartbeat de vida del runtime desktop — convierte el cached-kill de
 * ColorOS en una señal útil en vez de un crash silencioso.
 *
 * ColorOS (TimedProcessReaper) mata la app al pasar a cached (pantalla
 * apagada) y con ella todo el runtime (Xvnc/openbox/lxterminal, mismo
 * cgroup). Los hijos mueren juntos: cero zombies, cero CPU oculta — el kill
 * ES un apagado limpio forzado. Este heartbeat detecta ese kill y lo expone
 * a dos consumidores:
 *
 * - AgentAccessibilityService: tras el kill, el sistema re-vincula el
 *   service él mismo (los accessibility services habilitados se reinician
 *   sin acción del usuario) y re-lanza MainActivity. Kill = reset
 *   automático.
 * - DesktopController.buildStatus: expone wasKilledByOs a la UI de
 *   lanzamiento, que muestra el aviso honesto de restauración.
 *
 * Archivos (files/nano/state/):
 * - alive.timestamp: epoch ms del último ready. Se escribe cuando el
 *   escritorio llega a ready y se borra SOLO en apagado limpio (stop del
 *   usuario) o en el ack implícito de "Detener" sin runtime vivo.
 * - resurrect.timestamp: epoch ms del último relanzamiento hecho por el
 *   service. Ventana anti-loop: si ColorOS mata en bucle el proceso recién
 *   revivido (sin actividad en foreground), no relanzamos en cada rebind.
 */
object RuntimeHeartbeat {
    private const val TAG = "nano-heartbeat"

    // Si el service ya resucitó la app hace menos de esta ventana, el
    // rebind siguiente no relanza — evita kill-loop (reaper mata proceso
    // revivido, system re-vincula, re-lanza, reaper mata...).
    private const val RESURRECT_WINDOW_MS = 120_000L

    /** files/nano/state/alive.timestamp — [nanoDir] es files/nano. */
    fun stateFile(nanoDir: File): File {
        val dir = File(nanoDir, "state").apply { mkdirs() }
        return File(dir, "alive.timestamp")
    }

    private fun resurrectFile(nanoDir: File): File {
        val dir = File(nanoDir, "state").apply { mkdirs() }
        return File(dir, "resurrect.timestamp")
    }

    /** Runtime llegó a ready: heartbeat vivo. Resetea contador de resurrección. */
    fun markAlive(nanoDir: File) {
        try {
            stateFile(nanoDir).writeText(System.currentTimeMillis().toString())
            resurrectFile(nanoDir).delete()
            Log.i(TAG, "heartbeat ALIVE")
        } catch (e: Exception) {
            Log.w(TAG, "markAlive: ${e.message}")
        }
    }

    /** Apagado limpio (stop del usuario): borra el heartbeat. */
    fun markCleanShutdown(nanoDir: File) {
        try {
            stateFile(nanoDir).delete()
            Log.i(TAG, "heartbeat clean-shutdown")
        } catch (e: Exception) {
            Log.w(TAG, "markCleanShutdown: ${e.message}")
        }
    }

    /** Kill del OS: heartbeat presente sin apagado limpio. */
    fun wasKilledByOs(nanoDir: File): Boolean =
        try { stateFile(nanoDir).exists() } catch (e: Exception) { false }

    /**
     * ¿Resurrección permitida? true si no hubo otra en RESURRECT_WINDOW_MS.
     * Al permitirla registra el intento (escribe resurrect.timestamp).
     */
    fun beginResurrect(nanoDir: File): Boolean {
        val f = resurrectFile(nanoDir)
        val now = System.currentTimeMillis()
        val last = try { f.readText().trim().toLongOrNull() ?: 0L } catch (e: Exception) { 0L }
        if (now - last < RESURRECT_WINDOW_MS) return false
        try { f.writeText(now.toString()) } catch (e: Exception) {
            Log.w(TAG, "beginResurrect: ${e.message}")
        }
        return true
    }
}
