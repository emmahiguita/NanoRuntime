package dev.nanoai.mobile.automation

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import dev.nanoai.mobile.NanoApplication
import dev.nanoai.mobile.RuntimeScope
import dev.nanoai.mobile.services.NotificationAutomationBridge
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import kotlinx.coroutines.*

/** QUÉ: procesa notificaciones con el mismo grafo Flutter cuando no hay pantalla.
 * CÓMO: arranque bajo demanda, heartbeat, inbox durable y un único consumidor.
 * POR QUÉ: la vida del trabajo no depende de la Activity ni de mensajes simulados. */
class AutomationRuntimeService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var engine: FlutterEngine? = null
    private var channels: AutomationRuntimeChannels? = null
    private val watchdog = Runnable { requestStop("watchdog_no_heartbeat") }

    private fun refreshWatchdog() {
        mainHandler.removeCallbacks(watchdog)
        mainHandler.postDelayed(watchdog, WATCHDOG_MS)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        AutomationForegroundNotice.start(this)
        if (running || NotificationAutomationBridge.notificationEventsSink != null) {
            stopSelf()
            return
        }
        instance = this
        running = true
        val app = NanoApplication.from(this)
        val recovered = app.durableInbox.recoverExpiredLeases()
        if (recovered > 0) Log.i(TAG, "Leases recuperados=$recovered")
        app.runtimeScope.acquire(RuntimeScope.Holder.AUTOMATION)
        app.runtimeScope.nativeSupervisor.start()
        mainHandler.post(this::bootEngine)
        refreshWatchdog()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY
    override fun onTimeout(startId: Int, fgsType: Int) { requestStop("timeout") }

    override fun onDestroy() {
        if (instance === this) instance = null
        mainHandler.removeCallbacksAndMessages(null)
        channels?.close()
        channels = null
        ioScope.cancel()
        engine?.destroy()
        engine = null
        NotificationAutomationBridge.clearSink(SINK_AUTOMATION)
        if (running) {
            running = false
            NanoApplication.from(this).runtimeScope.release(RuntimeScope.Holder.AUTOMATION)
        }
        super.onDestroy()
    }

    private fun bootEngine() {
        if (engine != null || !running) return
        val e = FlutterEngine(this)
        engine = e
        val control = AutomationRuntimeControl(this, ::refreshWatchdog) {
            mainHandler.post { requestStop("dart_idle") }
        }
        channels = AutomationRuntimeChannels(this, ioScope, mainHandler, SINK_AUTOMATION, control)
            .also { it.register(e) }
        e.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        Log.i(TAG, "headless engine booted")
    }

    // El consumidor cierra sus leases; el supervisor Application conserva un modelo warm válido.
    private fun requestStop(reason: String) {
        if (!running) return
        running = false
        Log.i(TAG, "requestStop: $reason")
        channels?.close()
        channels = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        val e = engine
        engine = null
        e?.destroy()
        NotificationAutomationBridge.clearSink(SINK_AUTOMATION)
        NanoApplication.from(this).runtimeScope.release(RuntimeScope.Holder.AUTOMATION)
        stopSelf()
    }

    companion object {
        private const val TAG = "automation-runtime"
        const val HEADLESS_CHANNEL = "com.nanoai/headless"
        const val NOTIFICATION_EVENTS_CHANNEL = "com.nanoai/notification_events"
        private const val ACTION_START = "dev.nanoai.mobile.action.AUTOMATION_RUNTIME_START"
        private const val WATCHDOG_MS = 120_000L
        private val SINK_AUTOMATION = Any()

        /** @Volatile: lectura de estado desde el canal de Ajustes (UI). */
        @Volatile
        var running = false
            private set

        @Volatile
        private var instance: AutomationRuntimeService? = null

        /**
         * Arranque bajo demanda desde el NLS. Fail honesto si Android bloquea
         * el FGS desde background (sin exención de batería): la fila queda en
         * el inbox y el próximo wake la procesa (PENDING_WAKE documentado).
         */
        fun request(context: Context, reason: String = "notification_posted") {
            val sinkActive = NotificationAutomationBridge.notificationEventsSink != null
            if (running || sinkActive) {
                Log.d(TAG, "Skipping FGS request ($reason): running=$running, sinkActive=$sinkActive")
                return
            }
            try {
                context.startForegroundService(
                    Intent(context, AutomationRuntimeService::class.java)
                        .setAction(ACTION_START)
                        .putExtra("reason", reason),
                )
            } catch (e: RuntimeException) {
                Log.w(TAG, "FGS start bloqueado desde background (reason=$reason): ${e.message}")
            }
        }

        /** La UI que se abre destrona al engine headless (single consumer):
         *  su sink de eventos vivos reemplaza al nuestro y el drenado restante
         *  lo retomará el próximo wake (filas RESERVED se re-reclaman viejas). */
        fun onUiEngineAttached() {
            val active = instance ?: return
            if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) {
                active.requestStop("ui_attached")
            } else {
                active.mainHandler.post { active.requestStop("ui_attached") }
            }
        }
    }
}
