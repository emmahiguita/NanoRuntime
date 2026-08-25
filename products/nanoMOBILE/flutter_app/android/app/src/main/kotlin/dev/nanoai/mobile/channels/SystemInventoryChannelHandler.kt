package dev.nanoai.mobile.channels

import android.content.Context
import dev.nanoai.mobile.services.SystemInventoryService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Handler del canal `com.nanoai/system`: inventario factual del dispositivo y
 * de sus aplicaciones launchable.
 *
 * Responsabilidades SOLO: MethodChannel arguments → [SystemInventoryService]
 * → DTO (map primitivo) → errores tipados. NO contiene lógica de catálogo ni
 * de matching (eso es InstalledAppCatalog en Dart). Las llamadas se despachan
 * a un executor single-thread para no bloquear el main (queryIntentActivities
 * + getPackageInfo por app puede tardar decenas de ms).
 */
class SystemInventoryChannelHandler(context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/system"
    }

    private val service = SystemInventoryService(context.applicationContext)
    private val executor = Executors.newSingleThreadExecutor()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            try {
                when (call.method) {
                    "getDeviceProfile" ->
                        result.success(deviceProfileToMap(service.getDeviceProfile()))

                    "listLaunchableApps" ->
                        result.success(service.listLaunchableApps().map { appToMap(it) })

                    "getDefaultLauncher" ->
                        result.success(service.getDefaultLauncher())

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("SYSTEM_ERR", e.message ?: "error de inventario", null)
            }
        }
    }

    private fun deviceProfileToMap(
        p: SystemInventoryService.NativeDeviceProfile,
    ): Map<String, Any?> = mapOf(
        "manufacturer" to p.manufacturer,
        "model" to p.model,
        "sdkInt" to p.sdkInt,
        "release" to p.release,
        "defaultLauncherPackage" to p.defaultLauncherPackage,
    )

    private fun appToMap(a: SystemInventoryService.NativeInstalledApp): Map<String, Any?> =
        mapOf(
            "packageName" to a.packageName,
            "label" to a.label,
            "versionName" to a.versionName,
            "versionCode" to a.versionCode,
            "enabled" to a.enabled,
            "systemApp" to a.systemApp,
            "launchable" to a.launchable,
        )
}
