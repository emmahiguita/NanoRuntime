package dev.nanoai.mobile

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import dev.nanoai.mobile.channels.ChannelNames
import dev.nanoai.mobile.channels.DeviceMetricsChannelHandler
import dev.nanoai.mobile.channels.ExecBinChannelHandler
import dev.nanoai.mobile.channels.PtyChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

class MainActivity : FlutterActivity() {

    /** Supervisor único de runtime nativo: worker, paquetes y VNC. */
    private val nativeSupervisor: NativeRuntimeSupervisor by lazy {
        NativeRuntimeSupervisor(this, filesDir, pathPolicy)
    }

    /** Canal hacia Dart para navegación forzada desde el sistema. */
    private var navigationChannel: MethodChannel? = null

    private val pathPolicy: SecurePathPolicy by lazy { SecurePathPolicy(filesDir) }
    private val downloadService: DownloadService by lazy { DownloadService(pathPolicy) }
    private val deviceMetricsProvider: DeviceMetricsProvider by lazy { DeviceMetricsProvider(this) }
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Starting the worker binds a native service and may touch disk. Do it
        // after initial UI work so cold start can render before runtime warmup.
        mainHandler.postDelayed({
            if (!isFinishing && !isDestroyed) nativeSupervisor.start()
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
        nativeSupervisor.shutdown()
        super.onDestroy()
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
                    nativeSupervisor = nativeSupervisor,
                ),
            )

        MethodChannel(messenger, ChannelNames.PTY)
            .setMethodCallHandler(PtyChannelHandler())
    }

    private companion object {
        private const val RUNTIME_WARMUP_DELAY_MS = 1_500L
    }
}
