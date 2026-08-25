package dev.nanoai.mobile.channels

import android.content.Context
import android.os.Handler
import android.os.Looper
import dev.nanoai.mobile.services.AndroidSystemIntentExecutor
import dev.nanoai.mobile.services.SystemInventoryService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Handler del canal `com.nanoai/system`: inventario factual del dispositivo y
 * navegación de sistema allowlisted.
 *
 * Responsabilidades SOLO: MethodChannel arguments → service → DTO → errores
 * tipados. NO contiene lógica de catálogo ni de matching (eso es
 * InstalledAppCatalog en Dart) ni lógica de negocio de navegación (eso es
 * [AndroidSystemIntentExecutor]).
 *
 * Reads (getDeviceProfile/listLaunchableApps/getDefaultLauncher) se despachan a
 * un executor single-thread (queryIntentActivities + getPackageInfo puede tardar
 * decenas de ms). `openSystemDestination` se ejecuta en el main thread porque
 * `startActivity` lo exige.
 */
class SystemInventoryChannelHandler(context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/system"
    }

    private val service = SystemInventoryService(context.applicationContext)
    private val intentExecutor = AndroidSystemIntentExecutor(context.applicationContext)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "openSystemDestination") {
            mainHandler.post { handleOpenDestination(call, result) }
            return
        }
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

    private fun handleOpenDestination(call: MethodCall, result: MethodChannel.Result) {
        try {
            val destination = call.argument<String>("destination")
            if (destination.isNullOrBlank()) {
                result.error("SYSTEM_ERR", "destination requerido", null)
                return
            }
            val res = intentExecutor.open(destination)
            result.success(mapOf("opened" to res.opened, "error" to res.error))
        } catch (e: Exception) {
            result.error("SYSTEM_ERR", e.message ?: "error de navegación", null)
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
