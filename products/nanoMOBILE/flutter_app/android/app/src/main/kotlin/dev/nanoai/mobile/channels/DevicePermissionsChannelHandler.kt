package dev.nanoai.mobile.channels

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.content.ServiceConnection
import android.content.Context
import android.media.AudioManager
import android.bluetooth.BluetoothAdapter
import android.net.wifi.WifiManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import dev.nanoai.mobile.services.AgentAccessibilityService
import dev.nanoai.mobile.shizuku.IPackageAction
import dev.nanoai.mobile.shizuku.PackageActionService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku

/** Estado y navegación para los permisos que NanoAI usa realmente. */
class DevicePermissionsChannelHandler(
    private val activity: Activity,
    private val requestRuntimePermissions: (MethodChannel.Result) -> Unit,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/device_permissions"

        /** Código de solicitud único para el diálogo de concesión Shizuku. */
        private const val REQ_SHIZUKU_PERMISSION = 1001
    }

    /** Result pendiente del diálogo Shizuku; el listener lo resuelve al volver. */
    private var pendingShizukuPermission: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Listener del resultado del diálogo Shizuku (una sola instancia). */
    private val shizukuPermissionListener =
        Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
            if (requestCode == REQ_SHIZUKU_PERMISSION) {
                mainHandler.post {
                    pendingShizukuPermission?.success(
                        grantResult == PackageManager.PERMISSION_GRANTED,
                    )
                    pendingShizukuPermission = null
                }
            }
        }

    init {
        // A14.4: escucha el resultado del diálogo de concesión Shizuku y lo
        // resuelve en el hilo principal. Se registra una sola vez (defensa:
        // un listener duplicado entre recreaciones de la Activity no deja
        // resultados huérfanos — el nuevo sobrescribe al anterior).
        Shizuku.removeRequestPermissionResultListener(shizukuPermissionListener)
        Shizuku.addRequestPermissionResultListener(shizukuPermissionListener)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "queryShizukuStatus" -> result.success(queryShizukuStatus())
            "shizukuQueryPackage" -> result.success(
                shizukuQueryPackage(call.argument<String>("packageName")),
            )
            "shizukuRequestPermission" -> shizukuRequestPermission(result)
            "shizukuForceStop" -> shizukuForceStop(
                call.argument<String>("packageName"),
                result,
            )
            "systemState" -> result.success(systemState())
            "requestRuntime" -> requestRuntimePermissions(result)
            "openAccessibility" -> result.success(
                open(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)),
            )
            "openNotificationAccess" -> result.success(
                open(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)),
            )
            "openAllFilesAccess" -> result.success(openAllFilesAccess())
            "openAppDetails" -> result.success(
                open(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:${activity.packageName}"),
                    ),
                ),
            )
            else -> result.notImplemented()
        }
    }

    private fun status(): Map<String, Boolean> = mapOf(
        "microphone" to granted(Manifest.permission.RECORD_AUDIO),
        "media" to mediaGranted(),
        "accessibility" to accessibilityGranted(),
        "notificationAccess" to NotificationManagerCompat
            .getEnabledListenerPackages(activity)
            .contains(activity.packageName),
        "allFiles" to (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
                Environment.isExternalStorageManager()
            ),
    )

    /**
     * A14.3 — estado FACTUAL de Shizuku, PASIVO. Solo consulta:
     * instalación (PackageManager), binder vivo (Shizuku.pingBinder) y
     * autorización (Shizuku.checkSelfPermission). NINGUNA de estas llama abre
     * diálogo, ejecuta shell ni toca acciones privilegiadas. `permissionGranted`
     * es la verdad del servicio Shizuku, no una inferencia de la app.
     */
    private fun queryShizukuStatus(): Map<String, Any?> {
        val installed = isShizukuAppInstalled()
        val binderAlive = try {
            Shizuku.pingBinder()
        } catch (_: Throwable) {
            false
        }
        val permissionGranted = if (binderAlive) {
            try {
                // API 13.x: checkSelfPermission() devuelve int (0 = concedido).
                Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
            } catch (_: Throwable) {
                false
            }
        } else {
            false
        }
        return mapOf(
            "installed" to installed,
            "binderAlive" to binderAlive,
            "permissionGranted" to permissionGranted,
        )
    }

    /**
     * A14.4 — automatiza la SOLICITUD de conexión con Shizuku. Si Nano ya está
     * autorizada responde de inmediato (true); si no, lanza `requestPermission`
     * que muestra el diálogo Shizuku para que el usuario toque "Permitir". El
     * resultado llega por el listener y se resuelve en el main thread. NO
     * concede por sí solo: el consentimiento humano es innegociable.
     */
    private fun shizukuRequestPermission(result: MethodChannel.Result) {
        val granted = try {
            // API 13.x: checkSelfPermission() devuelve int (0 = concedido).
            Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (_: Throwable) {
            false
        }
        if (granted) {
            result.success(true)
            return
        }
        if (pendingShizukuPermission != null) {
            result.error("permission_pending", "solicitud Shizuku ya abierta", null)
            return
        }
        pendingShizukuPermission = result
        try {
            Shizuku.requestPermission(REQ_SHIZUKU_PERMISSION)
        } catch (e: Throwable) {
            pendingShizukuPermission = null
            result.error("shizuku_unsupported", e.message ?: "no soportado", null)
        }
    }

    private fun isShizukuAppInstalled(): Boolean {
        val pm = activity.packageManager
        return listOf("moe.shizuku.privileged.api", "moe.shizuku.manager")
            .any { pkg ->
                try {
                    pm.getPackageInfo(pkg, 0)
                    true
                } catch (_: Exception) {
                    false
                }
            }
    }

    /**
     * A14.5.4 — estado semántico factual del sistema (media reproduciéndose,
     * Bluetooth on/off, WiFi on/off). Lectura pasiva: no cambia nada. Los
     * APIs isMusicActive/isWifiEnabled están deprecated en API moderna pero
     * siguen funcionales; Bluetooth requiere permiso en API 31+ → try/catch
     * devuelve false (honesto) si no es observable.
     */
    private fun systemState(): Map<String, Any?> {
        val context = activity.applicationContext
        val mediaPlaying = try {
            (context.getSystemService(Context.AUDIO_SERVICE) as AudioManager)
                .isMusicActive
        } catch (_: Throwable) {
            false
        }
        val bluetoothEnabled = try {
            BluetoothAdapter.getDefaultAdapter()?.isEnabled ?: false
        } catch (_: Throwable) {
            false
        }
        val wifiEnabled = try {
            (context.getSystemService(Context.WIFI_SERVICE) as WifiManager)
                .isWifiEnabled
        } catch (_: Throwable) {
            false
        }
        return mapOf(
            "mediaPlaying" to mediaPlaying,
            "bluetoothEnabled" to bluetoothEnabled,
            "wifiEnabled" to wifiEnabled,
        )
    }

    /**
     * A14.4 — acción Shizuku TIPADA con efecto: detener una app (reversible
     * reabriéndola). Usa el UserService [PackageActionService], cuyo código corre
     * en el proceso Shizuku (privilegios). Solo packageName validado; el estado
     * de autorización se valida (a nivel de broker) ANTES de llegar aquí.
     */
    private fun shizukuForceStop(packageName: String?, result: MethodChannel.Result) {
        val pkg = packageName?.trim().orEmpty()
        if (pkg.isEmpty() || pkg.length > 255 ||
            !pkg.matches(Regex("[a-zA-Z][a-zA-Z0-9._]*"))
        ) {
            result.success(false)
            return
        }
        val args = Shizuku.UserServiceArgs(
            ComponentName(activity, PackageActionService::class.java),
        )
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, service: IBinder) {
                val stub = IPackageAction.Stub.asInterface(service)
                val ok = try {
                    stub.forceStop(pkg)
                } catch (_: Throwable) {
                    false
                }
                mainHandler.post { result.success(ok) }
                try {
                    Shizuku.unbindUserService(args, this, true)
                } catch (_: Throwable) {
                    // se desvincula tras resolver; sin consecuencias.
                }
            }

            override fun onServiceDisconnected(name: ComponentName) {
                mainHandler.post { result.success(false) }
            }
        }
        try {
            Shizuku.bindUserService(args, connection)
        } catch (e: Throwable) {
            result.success(false)
        }
    }

    /**
     * A14.4 — primera acción Shizuku TIPADA y de bajo riesgo: consultar metadatos
     * de un paquete con privilegios. `Shizuku.getUid()` confirma el contexto
     * Shizuku real (binder vivo + uid shell/root); la lectura de metadata usa el
     * PackageManager (misma info). NUNCA se acepta comando/shell libre: el único
     * parámetro es el packageName, validado como nombre de paquete Android.
     * La verificación de autorización la hace el llamador Dart ANTES de llegar.
     */
    private fun shizukuQueryPackage(packageName: String?): Map<String, Any?> {
        val pkg = packageName?.trim().orEmpty()
        if (pkg.isEmpty() || pkg.length > 255 ||
            !pkg.matches(Regex("[a-zA-Z][a-zA-Z0-9._]*"))
        ) {
            return mapOf("ok" to false, "code" to "INVALID_PACKAGE")
        }
        // Confirma contexto Shizuku real (binder + uid). -1 si no autorizado.
        val shizukuUid = try {
            Shizuku.getUid()
        } catch (_: Throwable) {
            -1
        }
        return try {
            val info = activity.packageManager.getPackageInfo(pkg, 0)
            val app = info.applicationInfo
            mapOf(
                "ok" to true,
                "code" to "SHIZUKU_OK",
                "shizukuUid" to shizukuUid,
                "output" to buildString {
                    append("package: ").append(info.packageName).append('\n')
                    append("versionCode: ").append(info.versionCode).append('\n')
                    append("versionName: ").append(info.versionName ?: "unknown").append('\n')
                    append("uid: ").append(app?.uid ?: "unknown").append('\n')
                    append("flags: ").append(app?.flags ?: 0)
                },
            )
        } catch (_: Exception) {
            mapOf("ok" to false, "code" to "PACKAGE_NOT_FOUND")
        }
    }

    private fun mediaGranted(): Boolean {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
                Manifest.permission.READ_MEDIA_AUDIO,
            )
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        return permissions.all(::granted)
    }

    private fun granted(permission: String): Boolean =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun accessibilityGranted(): Boolean {
        val expected = ComponentName(activity, AgentAccessibilityService::class.java)
        val enabled = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any { flattened ->
            ComponentName.unflattenFromString(flattened) == expected
        }
    }

    private fun openAllFilesAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return true
        return open(
            Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:${activity.packageName}"),
            ),
        )
    }

    private fun open(intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }
}
