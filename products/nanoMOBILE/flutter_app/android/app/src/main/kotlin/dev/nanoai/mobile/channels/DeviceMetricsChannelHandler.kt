package dev.nanoai.mobile.channels

import dev.nanoai.mobile.DeviceMetricsProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handler dedicado para el canal de métricas del dispositivo.
 * Operaciones rápidas y no bloqueantes.
 */
class DeviceMetricsChannelHandler(
    private val deviceMetricsProvider: DeviceMetricsProvider,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/device_metrics"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getMetrics" -> result.success(deviceMetricsProvider.getDeviceMetrics())
            "getDeviceIdentity" -> result.success(deviceMetricsProvider.getDeviceIdentity())
            else -> result.notImplemented()
        }
    }
}
