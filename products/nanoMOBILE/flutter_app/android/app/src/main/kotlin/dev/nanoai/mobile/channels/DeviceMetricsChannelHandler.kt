package dev.nanoai.mobile.channels

import dev.nanoai.mobile.DeviceMetricsProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handler dedicado para el canal de métricas del dispositivo.
 * StatFs + lecturas de /proc y /sys corren en hilo de fondo: el dashboard
 * llama getMetrics cada 3s y no debe causar jank en el main thread.
 */
class DeviceMetricsChannelHandler(
    private val deviceMetricsProvider: DeviceMetricsProvider,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/device_metrics"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getMetrics" -> Thread({
                result.success(deviceMetricsProvider.getDeviceMetrics())
            }, "metrics-fetch").start()
            "getDeviceIdentity" -> Thread({
                result.success(deviceMetricsProvider.getDeviceIdentity())
            }, "metrics-identity").start()
            else -> result.notImplemented()
        }
    }
}
