package dev.nanoai.mobile.channels

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import dev.nanoai.mobile.services.AgentAccessibilityService
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
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "queryShizukuStatus" -> result.success(queryShizukuStatus())
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
                Shizuku.checkSelfPermission()
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
