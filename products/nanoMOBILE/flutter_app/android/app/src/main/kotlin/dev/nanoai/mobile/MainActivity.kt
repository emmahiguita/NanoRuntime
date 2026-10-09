package dev.nanoai.mobile

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Rational
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import dev.nanoai.mobile.appfunctions.AppFunctionChannelHandler
import dev.nanoai.mobile.channels.AgentChannelHandler
import dev.nanoai.mobile.channels.AutomationBackgroundChannelHandler
import dev.nanoai.mobile.channels.AutomationStoreChannelHandler
import dev.nanoai.mobile.channels.BrowserCompatibilityChannelHandler
import dev.nanoai.mobile.channels.ChannelNames
import dev.nanoai.mobile.channels.ContactsChannelHandler
import dev.nanoai.mobile.channels.DataStudioChannelHandler
import dev.nanoai.mobile.channels.DeviceMetricsChannelHandler
import dev.nanoai.mobile.channels.DevicePermissionsChannelHandler
import dev.nanoai.mobile.channels.EngineChannelHandler
import dev.nanoai.mobile.channels.ExecBinChannelHandler
import dev.nanoai.mobile.channels.LanguageAssistChannelHandler
import dev.nanoai.mobile.channels.LiteRtChannelHandler
import dev.nanoai.mobile.channels.MnnChannelHandler
import dev.nanoai.mobile.channels.MediaCaptureChannelHandler
import dev.nanoai.mobile.channels.ModelStorageChannelHandler
import dev.nanoai.mobile.channels.NanoFloatingChannel
import dev.nanoai.mobile.channels.NanoNativeAiChannel
import dev.nanoai.mobile.channels.NotificationAutomationChannelHandler
import dev.nanoai.mobile.channels.PerformanceChannelHandler
import dev.nanoai.mobile.channels.PtyChannelHandler
import dev.nanoai.mobile.channels.RuntimeChannelHandler
import dev.nanoai.mobile.channels.ShareChannelHandler
import dev.nanoai.mobile.channels.SpeechChannelHandler
import dev.nanoai.mobile.channels.SystemInventoryChannelHandler
import dev.nanoai.mobile.performance.NanoPerformanceEngine
import dev.nanoai.mobile.performance.NanoThermalMonitor
import dev.nanoai.mobile.services.NotificationAutomationBridge
import dev.nanoai.mobile.services.NotificationHistoryBridge
import dev.nanoai.mobile.services.NanoOverlayBridge
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

// Comparte el motor Flutter con la sesión multimedia para que la notificación
// controle el mismo navegador al salir de Nano, sin iniciar otro isolate de UI.
class MainActivity : AudioServiceActivity() {

    /** WA-PROD-01 — runtime compartido en scope de Application: MainActivity
     *  es UI CLIENT, no dueño. RuntimeScope apaga los supervisores solo cuando
     *  el ÚLTIMO requestor (UI o automation headless) se va. */
    private val runtimeScope: RuntimeScope
        get() = (application as NanoApplication).runtimeScope

    /** Canal hacia Dart para navegación forzada desde el sistema. */
    private var navigationChannel: MethodChannel? = null

    /** Canal para Picture-in-Picture nativo del sistema. */
    private var pipChannel: MethodChannel? = null

    /** Handler del canal model_storage: recibe onActivityResult del picker. */
    private var modelStorageHandler: ModelStorageChannelHandler? = null

    /** Handler de contactos: lectura de WhatsApp y gestión de permisos. */
    private var contactsHandler: ContactsChannelHandler? = null

    /** Único dueño de los diálogos runtime para evitar resultados huérfanos. */
    private var runtimePermissions: RuntimePermissionCoordinator? = null

    /** Puente Android del navegador; se desconecta junto con el engine Flutter. */
    private var browserCompatibilityHandler: BrowserCompatibilityChannelHandler? = null

    /** A03-A06 — coprocesador lingüístico (cerrado en onDestroy, A13). */
    private var languageAssistHandler: LanguageAssistChannelHandler? = null

    /** Voz (cerrado en onDestroy, A13): recognizer zombie + TTS vivo. */
    private var speechChannelHandler: SpeechChannelHandler? = null

    /** Captura de cámara delegada al sistema; resuelve su Future al cerrar. */
    private var mediaCaptureHandler: MediaCaptureChannelHandler? = null

    /** Canal del overlay flotante (tipo Gemini) — requiere SYSTEM_ALERT_WINDOW. */
    private var nanoFloatingChannel: NanoFloatingChannel? = null

    /** Canal para compartir prompts con apps nativas de IA (ChatGPT, Gemini…). */
    private var nanoNativeAiChannel: NanoNativeAiChannel? = null

    /** Handler de LiteRT-LM (Google AI Edge): inferencia local con modelos .litertlm. */
    private var liteRtChannelHandler: LiteRtChannelHandler? = null

    /** MNN owner is retained for the Activity lifetime and releases native state on destroy. */
    private var mnnChannelHandler: MnnChannelHandler? = null

    /** ADPF + Thermal engine handler (cerrado en onDestroy). */
    private var performanceChannelHandler: PerformanceChannelHandler? = null

    /** Handler para el almacén persistente de automatizaciones y conversaciones SQLite. */
    private var automationStoreHandler: AutomationStoreChannelHandler? = null

    /** EventSink vivo de la UI para reenrutar eventos cuando la Activity pasa a foreground. */
    private var currentUiSink: EventChannel.EventSink? = null

    private val pathPolicy: SecurePathPolicy by lazy { SecurePathPolicy(filesDir) }
    private val downloadService: DownloadService by lazy { DownloadService(pathPolicy) }
    private val deviceMetricsProvider: DeviceMetricsProvider by lazy { DeviceMetricsProvider(this) }
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // WA-REG-01 — registramos la UI sin iniciar procesos nativos. El worker
        // se crea al primer uso de GGUF, terminal o Desktop; LiteRT no lo usa y
        // así conserva memoria para el modelo y su caché KV.
        runtimeScope.acquire(RuntimeScope.Holder.UI)
        // Barras del sistema oscuras + inmersión total sticky: ocultar status bar para aprovechar pantalla
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        applyImmersiveMode()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        applyImmersiveMode()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applyImmersiveMode()
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        applyImmersiveMode()
    }

    private fun applyImmersiveMode() {
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        window.decorView.post {
            WindowCompat.getInsetsController(window, window.decorView).apply {
                systemBarsBehavior =
                    WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsetsCompat.Type.systemBars())
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.insetsController?.let { controller ->
                    controller.systemBarsBehavior =
                        android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    controller.hide(android.view.WindowInsets.Type.systemBars())
                }
            }
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                    or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            )
            @Suppress("DEPRECATION")
            window.decorView.setOnSystemUiVisibilityChangeListener { visibility ->
                if ((visibility and android.view.View.SYSTEM_UI_FLAG_FULLSCREEN) == 0) {
                    window.decorView.postDelayed({ applyImmersiveMode() }, 500)
                }
            }
        }
    }

    /**
     * Entrada "Configuración" desde Ajustes → Apps → NanoAI Local.
     * Cuando el sistema lanza esta activity con ACTION_APPLICATION_PREFERENCES,
     * Flutter arranca directo en /settings en vez del dashboard.
     */
    override fun getInitialRoute(): String? =
        when {
            intent?.getStringExtra("action") == "open_assistant" -> "/chat"
            intent?.hasExtra("route") == true -> intent?.getStringExtra("route")
            intent?.action == Intent.ACTION_APPLICATION_PREFERENCES -> "/settings"
            else -> super.getInitialRoute()
        }

    /** Warm start: navegamos vía canal si se activa desde Ajustes o con extra de ruta. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_APPLICATION_PREFERENCES) {
            navigationChannel?.invokeMethod("openSettings", null)
        } else if (intent.hasExtra("route")) {
            intent.getStringExtra("route")?.let { route ->
                navigationChannel?.invokeMethod("navigate", route)
            }
        } else if (intent.getStringExtra("action") == "open_owl_hub" || intent.getStringExtra("action") == "open_assistant") {
            navigationChannel?.invokeMethod("openOwlHub", null)
        }
        val prompt = intent.getStringExtra("nano.entry.prompt")
        if (!prompt.isNullOrBlank()) {
            intent.removeExtra("nano.entry.prompt")
            navigationChannel?.invokeMethod("submitPrompt", prompt)
        }
    }

    override fun onStart() {
        super.onStart()
        currentUiSink?.let { NotificationAutomationBridge.setSink(SINK_UI, it) }
    }

    override fun onPause() {
        super.onPause()
        isForeground = false
    }

    override fun onStop() {
        NotificationAutomationBridge.clearSink(SINK_UI)
        super.onStop()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        NotificationAutomationBridge.clearSink(SINK_UI)
        currentUiSink = null
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AutomationStoreChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(null)
        automationStoreHandler = null
        browserCompatibilityHandler?.close()
        browserCompatibilityHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        NotificationAutomationBridge.clearSink(SINK_UI)
        currentUiSink = null
        automationStoreHandler = null
        languageAssistHandler?.close()
        languageAssistHandler = null
        speechChannelHandler?.close()
        speechChannelHandler = null
        mediaCaptureHandler?.close()
        mediaCaptureHandler = null
        // Desregistrar canales del overlay — evita leaks de MethodChannel.
        nanoFloatingChannel?.detach()
        nanoFloatingChannel = null
        nanoNativeAiChannel?.detach()
        nanoNativeAiChannel = null
        liteRtChannelHandler = null
        mnnChannelHandler?.close()
        mnnChannelHandler = null
        performanceChannelHandler?.close()
        performanceChannelHandler = null
        NanoOverlayBridge.detach() // OVERLAY-03: limpiar puente al engine Flutter.
        ioScope.cancel()
        browserCompatibilityHandler?.close()
        browserCompatibilityHandler = null
        runtimePermissions?.close()
        runtimePermissions = null
        // WA-PROD-01: la UI suelta su requestor; el shutdown real ocurre en
        // RuntimeScope solo si automation no sigue activo (orden interno:
        // engine antes que worker).
        runtimeScope.release(RuntimeScope.Holder.UI)
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (contactsHandler?.onRequestPermissionsResult(requestCode, permissions, grantResults) == true) {
            return
        }
        runtimePermissions?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine? {
        val flutterEngine = super.provideFlutterEngine(context) ?: return null
        registerAutomationStoreChannel(flutterEngine, context)
        return flutterEngine
    }

    private fun registerAutomationStoreChannel(
        flutterEngine: FlutterEngine,
        context: android.content.Context,
    ) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val handler = AutomationStoreChannelHandler(context.applicationContext).also {
            automationStoreHandler = it
        }
        MethodChannel(messenger, AutomationStoreChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(handler)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Este canal es usado durante el arranque del Centro de Mensajería.
        // Registrarlo antes de trabajo de runtime/plugins evita que Dart
        // solicite las conversaciones mientras el handler aún no existe.
        registerAutomationStoreChannel(flutterEngine, this)
        runtimeScope.acquire(RuntimeScope.Holder.UI)
        dev.nanoai.mobile.automation.AutomationRuntimeService.onUiEngineAttached()
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val permissions = runtimePermissions ?: RuntimePermissionCoordinator(this).also {
            runtimePermissions = it
        }

        val contacts = ContactsChannelHandler(this, ioScope).also { contactsHandler = it }
        MethodChannel(messenger, ContactsChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(contacts)

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
                    onRequestStoragePermission = permissions::requestStorage,
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
                    currentUiSink = events
                    NotificationAutomationBridge.setSink(SINK_UI, events)
                }
                override fun onCancel(arguments: Any?) {
                    currentUiSink = null
                    NotificationAutomationBridge.clearSink(SINK_UI)
                }
            },
        )
        // Mantiene SQLite observable sin reenviar estos avisos al motor de automatización.
        EventChannel(messenger, "com.nanoai/notification_history_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationHistoryBridge.attach(events)
                }
                override fun onCancel(arguments: Any?) {
                    NotificationHistoryBridge.attach(null)
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

        MethodChannel(messenger, ChannelNames.DEVICE_PERMISSIONS)
            .setMethodCallHandler(
                DevicePermissionsChannelHandler(this) { result ->
                    permissions.requestDefaults(result)
                },
            )

        browserCompatibilityHandler?.close()
        browserCompatibilityHandler = BrowserCompatibilityChannelHandler(
            flutterEngine = flutterEngine,
            requestWebMedia = permissions::requestWebMedia,
        )

        val speechHandler = SpeechChannelHandler(this)
        speechChannelHandler = speechHandler
        MethodChannel(messenger, ChannelNames.SPEECH)
            .setMethodCallHandler(speechHandler)
        EventChannel(messenger, SpeechChannelHandler.PARTIAL_CHANNEL_NAME)
            .setStreamHandler(speechHandler)

        val mediaHandler = MediaCaptureChannelHandler(this)
        mediaCaptureHandler = mediaHandler
        MethodChannel(messenger, ChannelNames.MEDIA_CAPTURE)
            .setMethodCallHandler(mediaHandler)

        MethodChannel(messenger, ChannelNames.ENGINE).also { engineChannel ->
            EngineChannelHandler(runtimeScope.engineSupervisor, ioScope, mainHandler)
                .also { handler ->
                    handler.attach(engineChannel)
                    engineChannel.setMethodCallHandler(handler)
                }
        }

        // ADPF + Thermal: Motor de rendimiento adaptativo para inferencia IA
        val thermalMonitor = NanoThermalMonitor(this).also { it.start() }
        val performanceEngine = NanoPerformanceEngine(this, thermalMonitor)
        val perfHandler = PerformanceChannelHandler(performanceEngine, thermalMonitor).also {
            performanceChannelHandler = it
        }
        MethodChannel(messenger, ChannelNames.PERFORMANCE)
            .setMethodCallHandler(perfHandler)
        EventChannel(messenger, PerformanceChannelHandler.THERMAL_STREAM_NAME)
            .setStreamHandler(perfHandler)

        // LiteRT-LM: Registro del canal nativo para modelos .litertlm con ADPF y Thermal
        val supervisor = NanoApplication.from(this).modelRuntimeSupervisor
        val liteRtHandler = LiteRtChannelHandler(this, ioScope, mainHandler, supervisor, performanceEngine, thermalMonitor)
        liteRtChannelHandler = liteRtHandler
        MethodChannel(messenger, LiteRtChannelHandler.METHOD_CHANNEL_NAME)
            .setMethodCallHandler(liteRtHandler)
        EventChannel(messenger, LiteRtChannelHandler.STREAM_CHANNEL_NAME)
            .setStreamHandler(liteRtHandler)

        // MNN-LLM is an independent CPU route for the downloaded Omni package.
        val mnnHandler = MnnChannelHandler(ioScope, mainHandler)
        mnnChannelHandler = mnnHandler
        MethodChannel(messenger, MnnChannelHandler.METHOD_CHANNEL_NAME)
            .setMethodCallHandler(mnnHandler)
        EventChannel(messenger, MnnChannelHandler.STREAM_CHANNEL_NAME)
            .setStreamHandler(mnnHandler)

        MethodChannel(messenger, ChannelNames.SHARE)
            .setMethodCallHandler(ShareChannelHandler(this))

        MethodChannel(messenger, ChannelNames.SYSTEM)
            .setMethodCallHandler(SystemInventoryChannelHandler(this))

        MethodChannel(
            messenger,
            ChannelNames.DATA_STUDIO,
            io.flutter.plugin.common.StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler(DataStudioChannelHandler(this))

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

        // A03-A06: ICU + spell + language + conversation actions.
        MethodChannel(messenger, LanguageAssistChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(LanguageAssistChannelHandler(this).also {
                languageAssistHandler = it
            })

        // OVERLAY-01: búho flotante sobre otras apps (tipo Gemini).
        // Requiere SYSTEM_ALERT_WINDOW — el canal verifica el permiso antes de show().
        nanoFloatingChannel = NanoFloatingChannel(this, messenger)

        // OVERLAY-02: handoff de prompts a apps nativas de IA (ChatGPT, Gemini app…).
        nanoNativeAiChannel = NanoNativeAiChannel(this, messenger)

        // OVERLAY-03: puente singleton que enruta overlayQuery del servicio nativo
        // al NanoAiController de Flutter. Sin esto, el overlay abre Nano vía Intent.
        NanoOverlayBridge.attach(messenger)

        // BROWSER-PIP: soporte para Picture-in-Picture nativo del sistema.
        val pipChan = MethodChannel(messenger, "com.nanoai/browser_pip")
        pipChannel = pipChan
        pipChan.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterSystemPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                    ) {
                        try {
                            val builder = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(16, 9))
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                builder.setAutoEnterEnabled(true)
                            }
                            val entered = enterPictureInPictureMode(builder.build())
                            result.success(entered)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "isPipSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                    result.success(supported)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("pipModeChanged", isInPictureInPictureMode)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        ) {
            pipChannel?.invokeMethod("onUserLeaveHint", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (mediaCaptureHandler?.onActivityResult(requestCode, resultCode) == true) return
        modelStorageHandler?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onResume() {
        super.onResume()
        isForeground = true
        // Al estar en Nano, el asistente in-app ya existe; detener overlay nativo para evitar doble ventana
        try { stopService(Intent(this, dev.nanoai.mobile.services.NanoFloatingService::class.java)) }
        catch (_: Exception) {}
        // Resuelve requestAllFilesAccess (MANAGE_EXTERNAL_STORAGE) al
        // volver de la pantalla del sistema.
        modelStorageHandler?.onResume()
        applyImmersiveMode()
    }

    companion object {
        @Volatile
        var isForeground: Boolean = false

        private val SINK_UI = Any()
    }
}
