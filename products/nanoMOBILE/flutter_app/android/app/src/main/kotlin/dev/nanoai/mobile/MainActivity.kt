package dev.nanoai.mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import dev.nanoai.mobile.appfunctions.AppFunctionChannelHandler
import dev.nanoai.mobile.channels.AgentChannelHandler
import dev.nanoai.mobile.channels.AutomationBackgroundChannelHandler
import dev.nanoai.mobile.channels.AutomationStoreChannelHandler
import dev.nanoai.mobile.channels.ChannelNames
import dev.nanoai.mobile.channels.DeviceMetricsChannelHandler
import dev.nanoai.mobile.channels.DevicePermissionsChannelHandler
import dev.nanoai.mobile.channels.EngineChannelHandler
import dev.nanoai.mobile.channels.ExecBinChannelHandler
import dev.nanoai.mobile.channels.ModelStorageChannelHandler
import dev.nanoai.mobile.channels.NotificationAutomationChannelHandler
import dev.nanoai.mobile.services.NotificationAutomationBridge
import dev.nanoai.mobile.channels.PtyChannelHandler
import dev.nanoai.mobile.channels.RuntimeChannelHandler
import dev.nanoai.mobile.channels.ShareChannelHandler
import dev.nanoai.mobile.channels.SpeechChannelHandler
import dev.nanoai.mobile.channels.SystemInventoryChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

class MainActivity : FlutterActivity() {

    /** WA-PROD-01 — runtime compartido en scope de Application: MainActivity
     *  es UI CLIENT, no dueño. RuntimeScope apaga los supervisores solo cuando
     *  el ÚLTIMO requestor (UI o automation headless) se va. */
    private val runtimeScope: RuntimeScope
        get() = (application as NanoApplication).runtimeScope

    /** Canal hacia Dart para navegación forzada desde el sistema. */
    private var navigationChannel: MethodChannel? = null

    /** Handler del canal model_storage: recibe onActivityResult del picker. */
    private var modelStorageHandler: ModelStorageChannelHandler? = null

    /** Result pendiente de requestStoragePermission — resuelto por
     *  onRequestPermissionsResult cuando el usuario contesta el diálogo. */
    private var pendingStorageResult: MethodChannel.Result? = null

    /** Resultado pendiente del lote micrófono + medios del centro de permisos. */
    private var pendingRuntimePermissionsResult: MethodChannel.Result? = null

    private val pathPolicy: SecurePathPolicy by lazy { SecurePathPolicy(filesDir) }
    private val downloadService: DownloadService by lazy { DownloadService(pathPolicy) }
    private val deviceMetricsProvider: DeviceMetricsProvider by lazy { DeviceMetricsProvider(this) }
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // WA-REG-01 — acquire(UI) SÍNCRONO: cierra la ventana de handoff
        // headless→UI. Antes el acquire iba dentro del postDelayed de warmup:
        // si el service headless soltaba AUTOMATION en esos 1500ms, holders
        // quedaba vacío y RuntimeScope apagaba el runtime completo (engine LLM
        // incluido, que no podía re-arrancar en el mismo proceso). Acquire es
        // solo un add a un set sincronizado — no toca disco ni pelea el
        // primer frame.
        runtimeScope.acquire(RuntimeScope.Holder.UI)
        // Barras del sistema oscuras + edge-to-edge: el dashboard dibuja
        // bajo la barra de estado (SafeArea en Flutter evita superposición).
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.parseColor("#020611")
        WindowInsetsControllerCompat(window, window.decorView).apply {
            isAppearanceLightStatusBars = false
            isAppearanceLightNavigationBars = false
        }
        // Starting the worker binds a native service and may touch disk. Do it
        // after initial UI work so cold start can render before runtime warmup.
        mainHandler.postDelayed({
            if (!isFinishing && !isDestroyed) {
                runtimeScope.nativeSupervisor.start()
            }
        }, RUNTIME_WARMUP_DELAY_MS)
    }

    /**
     * Entrada "Configuración" desde Ajustes → Apps → NanoAI Local.
     * Cuando el sistema lanza esta activity con ACTION_APPLICATION_PREFERENCES,
     * Flutter arranca directo en /settings en vez del dashboard.
     */
    override fun getInitialRoute(): String? =
        if (intent?.action == Intent.ACTION_APPLICATION_PREFERENCES) "/settings"
        else super.getInitialRoute()

    /** Warm start: navegamos vía canal si se activa desde Ajustes. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_APPLICATION_PREFERENCES) {
            navigationChannel?.invokeMethod("openSettings", null)
        }
    }

    override fun onDestroy() {
        ioScope.cancel()
        // Si el diálogo de permisos quedó abierto al destruirse la Activity,
        // resolver el Result pendiente — un Future Dart colgado para siempre.
        pendingStorageResult?.error(
            "activity_destroyed", "Activity destruida antes de contestar permisos", null,
        )
        pendingStorageResult = null
        pendingRuntimePermissionsResult?.error(
            "activity_destroyed", "Activity destruida antes de contestar permisos", null,
        )
        pendingRuntimePermissionsResult = null
        // WA-PROD-01: la UI suelta su requestor; el shutdown real ocurre en
        // RuntimeScope solo si automation no sigue activo (orden interno:
        // engine antes que worker).
        runtimeScope.release(RuntimeScope.Holder.UI)
        super.onDestroy()
    }

    /**
     * Permisos de lectura de medios compartidos para el gestor de archivos
     * del escritorio (pcmanfm monta /storage/emulated/0 vía nanoroot).
     * API 33+: READ_MEDIA_*; API 23-32: READ_EXTERNAL_STORAGE. < 23: concedido
     * en instalación. Si ya están concedidos responde de inmediato; si no,
     * guarda el Result y lo resuelve onRequestPermissionsResult.
     */
    private fun requestStoragePermission(result: MethodChannel.Result) {
        val sdk = Build.VERSION.SDK_INT
        if (sdk < 23) {
            result.success(true)
            return
        }
        val perms = if (sdk >= 33) {
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
                Manifest.permission.READ_MEDIA_AUDIO,
            )
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        val granted = perms.all {
            checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
        if (granted) {
            result.success(true)
            return
        }
        // El Result se resuelve cuando el usuario contesta el diálogo; si hay
        // uno previo colgado (raza doble-tap), fallar el viejo primero.
        pendingStorageResult?.error("permission_pending", "solicitud anterior aún abierta", null)
        pendingStorageResult = result
        requestPermissions(perms, REQ_STORAGE_PERMISSION)
    }

    /** Solicita únicamente permisos runtime usados: micrófono y medios. */
    private fun requestRuntimePermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 23) {
            result.success(true)
            return
        }
        val permissions = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= 33) {
            // Notificaciones propias del agente (avisos T3). Sin request runtime
            // el sistema suprime las notificaciones (POST_NOTIFICATION=ignore).
            permissions += Manifest.permission.POST_NOTIFICATIONS
            permissions += Manifest.permission.READ_MEDIA_IMAGES
            permissions += Manifest.permission.READ_MEDIA_VIDEO
            permissions += Manifest.permission.READ_MEDIA_AUDIO
        } else {
            permissions += Manifest.permission.READ_EXTERNAL_STORAGE
        }
        val missing = permissions.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        if (pendingStorageResult != null || pendingRuntimePermissionsResult != null) {
            result.error("permission_pending", "solicitud anterior aún abierta", null)
            return
        }
        pendingRuntimePermissionsResult = result
        requestPermissions(missing.toTypedArray(), REQ_RUNTIME_PERMISSIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_STORAGE_PERMISSION) {
            val ok = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingStorageResult?.success(ok)
            pendingStorageResult = null
        } else if (requestCode == REQ_RUNTIME_PERMISSIONS) {
            val ok = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingRuntimePermissionsResult?.success(ok)
            pendingRuntimePermissionsResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        navigationChannel = MethodChannel(messenger, ChannelNames.NAVIGATION)

        MethodChannel(messenger, ChannelNames.DEVICE_METRICS)
            .setMethodCallHandler(DeviceMetricsChannelHandler(deviceMetricsProvider))

        MethodChannel(messenger, ChannelNames.EXEC_BIN)
            .setMethodCallHandler(
                ExecBinChannelHandler(
                    activity = this,
                    filesDir = filesDir,
                    pathPolicy = pathPolicy,
                    downloadService = downloadService,
                    ioScope = ioScope,
                    mainHandler = mainHandler,
                    nativeSupervisor = runtimeScope.nativeSupervisor,
                    onRequestStoragePermission = { result -> requestStoragePermission(result) },
                ),
            )

        MethodChannel(messenger, ChannelNames.PTY)
            .setMethodCallHandler(PtyChannelHandler())

        MethodChannel(messenger, ChannelNames.RUNTIME)
            .setMethodCallHandler(RuntimeChannelHandler())

        MethodChannel(messenger, ChannelNames.AGENT)
            .setMethodCallHandler(AgentChannelHandler())

        val notificationHandler = NotificationAutomationChannelHandler(this)
        MethodChannel(messenger, ChannelNames.NOTIFICATIONS)
            .setMethodCallHandler(notificationHandler)
        // WA-PROD-01: sink con dueño — la UI que escucha destrona al engine
        // headless (single consumer). El token evita que un clear ajeno borre
        // el sink propio.
        EventChannel(messenger, "com.nanoai/notification_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationAutomationBridge.setSink(SINK_UI, events)
                }
                override fun onCancel(arguments: Any?) {
                    NotificationAutomationBridge.clearSink(SINK_UI)
                }
            },
        )
        EventChannel(
            messenger,
            NotificationAutomationChannelHandler.CONFIRMATION_EVENTS_CHANNEL_NAME,
        ).setStreamHandler(notificationHandler)
        // WA-PROD-01: estado/config del runtime en segundo plano (solo UI).
        MethodChannel(messenger, AutomationBackgroundChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(AutomationBackgroundChannelHandler(this))
        // WA-PROD-02: estado durable del pipeline (dedupe/rate/memoria).
        MethodChannel(messenger, AutomationStoreChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(AutomationStoreChannelHandler(this))

        MethodChannel(messenger, ChannelNames.DEVICE_PERMISSIONS)
            .setMethodCallHandler(
                DevicePermissionsChannelHandler(this) { result ->
                    requestRuntimePermissions(result)
                },
            )

        val speechHandler = SpeechChannelHandler(this)
        MethodChannel(messenger, ChannelNames.SPEECH)
            .setMethodCallHandler(speechHandler)
        EventChannel(messenger, SpeechChannelHandler.PARTIAL_CHANNEL_NAME)
            .setStreamHandler(speechHandler)

        MethodChannel(messenger, ChannelNames.ENGINE).also { engineChannel ->
            EngineChannelHandler(runtimeScope.engineSupervisor, ioScope, mainHandler)
                .also { handler ->
                    handler.attach(engineChannel)
                    engineChannel.setMethodCallHandler(handler)
                }
        }

        MethodChannel(messenger, ChannelNames.SHARE)
            .setMethodCallHandler(ShareChannelHandler(this))

        MethodChannel(messenger, ChannelNames.SYSTEM)
            .setMethodCallHandler(SystemInventoryChannelHandler(this))

        MethodChannel(messenger, ChannelNames.MODEL_STORAGE)
            .setMethodCallHandler(
                ModelStorageChannelHandler(
                    activity = this,
                    ioScope = ioScope,
                    mainHandler = mainHandler,
                    openFdInWorker = { uri, pfd ->
                        runtimeScope.nativeSupervisor.workerClient()?.openModelFd(uri, pfd)
                    },
                ).also { modelStorageHandler = it },
            )

        // APPFN-01: sonda de App Functions (Android 16+). SOLO consulta de
        // disponibilidad; el canal no expone ejecución en v1.
        MethodChannel(messenger, AppFunctionChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(AppFunctionChannelHandler(this))

    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        modelStorageHandler?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onResume() {
        super.onResume()
        // Resuelve requestAllFilesAccess (MANAGE_EXTERNAL_STORAGE) al
        // volver de la pantalla del sistema.
        modelStorageHandler?.onResume()
    }

    private companion object {
        private val SINK_UI = Any()
        private const val RUNTIME_WARMUP_DELAY_MS = 1_500L
        private const val REQ_STORAGE_PERMISSION = 4101
        private const val REQ_RUNTIME_PERMISSIONS = 4102
    }
}
