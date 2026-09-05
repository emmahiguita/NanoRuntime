package dev.nanoai.mobile.automation

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import dev.nanoai.mobile.MainActivity
import dev.nanoai.mobile.NanoApplication
import dev.nanoai.mobile.R
import dev.nanoai.mobile.RuntimeScope
import dev.nanoai.mobile.channels.AgentChannelHandler
import dev.nanoai.mobile.channels.AutomationStoreChannelHandler
import dev.nanoai.mobile.channels.EngineChannelHandler
import dev.nanoai.mobile.channels.NotificationAutomationChannelHandler
import dev.nanoai.mobile.channels.RuntimeChannelHandler
import dev.nanoai.mobile.services.NotificationAutomationBridge
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/**
 * WA-PROD-01 — AutomationRuntimeService: runtime de automatización INDEPENDIENTE
 * de la UI (Variante 1 aprobada).
 *
 * El NotificationListener persiste el evento en el DurableInbox y, si nadie
 * escucha (sink null), pide este service. El service arranca UN FlutterEngine
 * headless (mismo proceso main, sin Activity): Dart ejecuta el MISMO main();
 * el canal `com.nanoai/headless` le dice que corra el bootstrap de
 * automatización (barrera de stores → claim/drenado del inbox → RulePipeline
 * intacto → journal), sin runApp.
 *
 * FGS tipo dataSync de vida ACOTADA: solo mientras procesa (Dart pide
 * "finish" al quedar idle; watchdog de seguridad a los 120s). Sin notificación
 * eterna — el trabajo es perceptible mientras existe.
 *
 * Single consumer: nunca hay dos engines con sink de eventos vivo. Si la UI
 * se abre, su engine reemplaza el sink y este service se detiene.
 */
class AutomationRuntimeService : Service(), MethodChannel.MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var engine: FlutterEngine? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (running) {
            stopSelf()
            return
        }
        instance = this
        running = true
        startInForeground()
        val app = NanoApplication.from(this)
        app.runtimeScope.acquire(RuntimeScope.Holder.AUTOMATION)
        // El worker :nanoshell se arranca ya: el engine headless puede pedir
        // el LLM on-demand apenas drene la primera fila (sin latencia extra).
        app.runtimeScope.nativeSupervisor.start()
        Log.i(TAG, "onCreate: booting headless engine")
        mainHandler.post(this::bootEngine)
        mainHandler.postDelayed({ requestStop("watchdog") }, WATCHDOG_MS)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // El arranque ocurre en onCreate (startForegroundService → onCreate).
        return START_NOT_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Tope de plataforma del dataSync FGS (Android 15+): parar limpio.
        requestStop("timeout")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance === this) instance = null
        mainHandler.removeCallbacksAndMessages(null)
        ioScope.cancel()
        val e = engine
        engine = null
        e?.destroy()
        NotificationAutomationBridge.clearSink(SINK_AUTOMATION)
        if (running) {
            running = false
            NanoApplication.from(this).runtimeScope.release(RuntimeScope.Holder.AUTOMATION)
        }
        Log.i(TAG, "onDestroy")
    }

    private fun bootEngine() {
        if (engine != null || !running) return
        val e = FlutterEngine(this)
        engine = e
        registerChannels(e)
        e.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        Log.i(TAG, "headless engine booted")
    }

    /** Subset de channels que el runtime headless necesita: notificaciones
     *  (eventos + reply + avisos), engine LLM, agente y runtime. Los handlers
     *  atados a la Activity (speech/pty/media/permisos) NO se registran. */
    private fun registerChannels(e: FlutterEngine) {
        val messenger = e.dartExecutor.binaryMessenger
        val notificationHandler = NotificationAutomationChannelHandler(this)
        MethodChannel(messenger, NotificationAutomationChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(notificationHandler)
        EventChannel(messenger, NotificationAutomationChannelHandler.CONFIRMATION_EVENTS_CHANNEL_NAME)
            .setStreamHandler(notificationHandler)
        EventChannel(messenger, NOTIFICATION_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationAutomationBridge.setSink(SINK_AUTOMATION, events)
                }

                override fun onCancel(arguments: Any?) {
                    NotificationAutomationBridge.clearSink(SINK_AUTOMATION)
                }
            },
        )

        val app = NanoApplication.from(this)
        val engineHandler = EngineChannelHandler(app.runtimeScope.engineSupervisor, ioScope, mainHandler)
        MethodChannel(messenger, EngineChannelHandler.CHANNEL_NAME).also { channel ->
            engineHandler.attach(channel)
            channel.setMethodCallHandler(engineHandler)
        }
        MethodChannel(messenger, AgentChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(AgentChannelHandler())
        MethodChannel(messenger, RuntimeChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(RuntimeChannelHandler())
        MethodChannel(messenger, AutomationStoreChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(AutomationStoreChannelHandler(this))
        MethodChannel(messenger, HEADLESS_CHANNEL).setMethodCallHandler(this)
    }

    // ------------------------------------------------------------------
    // Canal de control headless (Dart → Kotlin)
    // ------------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isHeadless" -> result.success(true)

            "claim" -> {
                val limit = call.argument<Number>("limit")?.toInt() ?: CLAIM_LIMIT
                result.success(claimInbox(limit))
            }

            "complete" -> {
                val eventId = call.argument<String>("eventId")
                if (!eventId.isNullOrEmpty()) {
                    NanoApplication.from(this).durableInbox.complete(eventId)
                }
                result.success(true)
            }

            "pendingCount" -> result.success(NanoApplication.from(this).durableInbox.pendingCount())

            "finish" -> {
                result.success(true)
                mainHandler.post { requestStop("dart_idle") }
            }

            else -> result.notImplemented()
        }
    }

    /** Reclama filas del inbox y las rehidrata SOLO desde notificaciones
     *  activas (nada de contenido persistido). Fila sin notificación activa =
     *  descarte honesto (SKIP_GONE): sin contenido no hay draft posible. */
    private fun claimInbox(limit: Int): List<Map<String, Any?>> {
        val service = NotificationAutomationBridge.service ?: return emptyList()
        val inbox = NanoApplication.from(this).durableInbox
        return inbox.claim(limit).mapNotNull { row ->
            val payload = service.byKey(row.notificationKey)
            if (payload == null) {
                inbox.complete(row.eventId)
                null
            } else {
                mapOf("eventId" to row.eventId, "notification" to payload)
            }
        }
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            FGS_CHANNEL_ID,
            "Automatización",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Procesamiento de mensajes en segundo plano"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)

        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val openPending = PendingIntent.getActivity(
            this,
            FGS_NOTIFICATION_ID,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, FGS_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_nano_confirmation)
            .setContentTitle("Nano procesando mensajes")
            .setContentText("Automatización activa en segundo plano")
            .setOngoing(true)
            .setContentIntent(openPending)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(FGS_NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(FGS_NOTIFICATION_ID, notification)
        }
    }

    private fun requestStop(reason: String) {
        if (!running) return
        running = false
        Log.i(TAG, "requestStop: $reason")
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
        private const val FGS_CHANNEL_ID = "nano_automation_fgs"
        private const val FGS_NOTIFICATION_ID = 0x4E43
        private const val WATCHDOG_MS = 120_000L
        private const val CLAIM_LIMIT = 10
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
        fun request(context: Context) {
            if (running) return
            try {
                context.startForegroundService(
                    Intent(context, AutomationRuntimeService::class.java)
                        .setAction(ACTION_START),
                )
            } catch (e: RuntimeException) {
                Log.w(TAG, "FGS start bloqueado desde background: ${e.message}")
            }
        }

        /** La UI que se abre destrona al engine headless (single consumer):
         *  su sink de eventos vivos reemplaza al nuestro y el drenado restante
         *  lo retomará el próximo wake (filas RESERVED se re-reclaman viejas). */
        fun onUiEngineAttached() {
            val active = instance ?: return
            active.mainHandler.post { active.requestStop("ui_attached") }
        }
    }
}
