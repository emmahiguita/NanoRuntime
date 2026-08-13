package dev.nanoai.mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import dev.nanoai.mobile.channels.AgentChannelHandler
import dev.nanoai.mobile.channels.ChannelNames
import dev.nanoai.mobile.channels.DeviceMetricsChannelHandler
import dev.nanoai.mobile.channels.ExecBinChannelHandler
import dev.nanoai.mobile.channels.PtyChannelHandler
import dev.nanoai.mobile.channels.RuntimeChannelHandler
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

    /** Result pendiente de requestStoragePermission — resuelto por
     *  onRequestPermissionsResult cuando el usuario contesta el diálogo. */
    private var pendingStorageResult: MethodChannel.Result? = null

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
        // Si el diálogo de permisos quedó abierto al destruirse la Activity,
        // resolver el Result pendiente — un Future Dart colgado para siempre.
        pendingStorageResult?.error(
            "activity_destroyed", "Activity destruida antes de contestar permisos", null,
        )
        pendingStorageResult = null
        nativeSupervisor.shutdown()
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
                    nativeSupervisor = nativeSupervisor,
                    onRequestStoragePermission = { result -> requestStoragePermission(result) },
                ),
            )

        MethodChannel(messenger, ChannelNames.PTY)
            .setMethodCallHandler(PtyChannelHandler())

        MethodChannel(messenger, ChannelNames.RUNTIME)
            .setMethodCallHandler(RuntimeChannelHandler())

        MethodChannel(messenger, ChannelNames.AGENT)
            .setMethodCallHandler(AgentChannelHandler())
    }

    private companion object {
        private const val RUNTIME_WARMUP_DELAY_MS = 1_500L
        private const val REQ_STORAGE_PERMISSION = 4101
    }
}
