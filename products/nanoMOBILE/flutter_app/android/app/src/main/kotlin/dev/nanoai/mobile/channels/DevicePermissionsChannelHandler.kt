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
