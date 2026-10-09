package dev.nanoai.mobile.automation

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import dev.nanoai.mobile.MainActivity
import dev.nanoai.mobile.NanoApplication
import dev.nanoai.mobile.R
import dev.nanoai.mobile.RuntimeScope
import dev.nanoai.mobile.channels.AgentChannelHandler
import dev.nanoai.mobile.channels.AutomationStoreChannelHandler
import dev.nanoai.mobile.channels.EngineChannelHandler
import dev.nanoai.mobile.channels.NotificationAutomationChannelHandler
import dev.nanoai.mobile.channels.RuntimeChannelHandler
import dev.nanoai.mobile.services.NotificationAutomationBridge
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/** QUÉ: registra los mismos canales reales para el consumidor sin pantalla.
 * CÓMO: mantiene referencias solo a handlers que necesitan cerrar su lease.
 * POR QUÉ: evita una segunda ruta de inferencia y mantiene el servicio pequeño. */
internal class AutomationRuntimeChannels(
    private val service: Service,
    private val ioScope: CoroutineScope,
    private val mainHandler: Handler,
    private val sinkOwner: Any,
    private val control: MethodChannel.MethodCallHandler,
) {
    private var languageHandler: dev.nanoai.mobile.channels.LanguageAssistChannelHandler? = null
    private var mnnHandler: dev.nanoai.mobile.channels.MnnChannelHandler? = null
    private var liteRtHandler: dev.nanoai.mobile.channels.LiteRtChannelHandler? = null

    fun register(e: FlutterEngine) {
        val messenger = e.dartExecutor.binaryMessenger
        val notificationHandler = NotificationAutomationChannelHandler(service)
        MethodChannel(messenger, NotificationAutomationChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(notificationHandler)
        EventChannel(messenger, NotificationAutomationChannelHandler.CONFIRMATION_EVENTS_CHANNEL_NAME)
            .setStreamHandler(notificationHandler)
        EventChannel(messenger, AutomationRuntimeService.NOTIFICATION_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationAutomationBridge.setSink(sinkOwner, events)
                }

                override fun onCancel(arguments: Any?) {
                    NotificationAutomationBridge.clearSink(sinkOwner)
                }
            },
        )

        val app = NanoApplication.from(service)
        val engineHandler = EngineChannelHandler(app.runtimeScope.engineSupervisor, ioScope, mainHandler)
        MethodChannel(messenger, EngineChannelHandler.CHANNEL_NAME).also { channel ->
            engineHandler.attach(channel)
            channel.setMethodCallHandler(engineHandler)
        }
        MethodChannel(messenger, AgentChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(AgentChannelHandler())
        MethodChannel(messenger, RuntimeChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(RuntimeChannelHandler())
        MethodChannel(messenger, AutomationStoreChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(AutomationStoreChannelHandler(service.applicationContext))
        val language = dev.nanoai.mobile.channels.LanguageAssistChannelHandler(service)
        languageHandler = language
        MethodChannel(messenger, dev.nanoai.mobile.channels.LanguageAssistChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(language)
        MethodChannel(messenger, dev.nanoai.mobile.channels.ExecBinChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getFilesDir" -> {
                        val base = java.io.File(service.filesDir, "nano")
                        if (!base.exists()) base.mkdirs()
                        result.success(base.absolutePath)
                    }
                    else -> result.notImplemented()
                }
            }
        // FIX-3: device_metrics faltaba en el engine headless. El runtime
        // lo llama durante cold-start para telemetría RAM/CPU. Sin registro
        // lanzaba MissingPluginException y el modelo nunca reportaba métricas.
        MethodChannel(messenger, dev.nanoai.mobile.channels.DeviceMetricsChannelHandler.CHANNEL_NAME)
            .setMethodCallHandler(
                dev.nanoai.mobile.channels.DeviceMetricsChannelHandler(
                    dev.nanoai.mobile.DeviceMetricsProvider(service),
                ),
            )

        // WA-PROD-01 / LiteRT Headless: Registramos LiteRtChannelHandler en el engine headless
        // usando el mismo singleton NanoModelRuntimeSupervisor compartido con la UI.
        // Esto permite a Qwen3-0.6B generar respuestas automáticas sin duplicar el modelo en RAM.
        val liteRtSupervisor = app.modelRuntimeSupervisor
        val liteRtHandler = dev.nanoai.mobile.channels.LiteRtChannelHandler(
            service,
            ioScope,
            mainHandler,
            liteRtSupervisor
        )
        this.liteRtHandler = liteRtHandler
        MethodChannel(messenger, dev.nanoai.mobile.channels.LiteRtChannelHandler.METHOD_CHANNEL_NAME)
            .setMethodCallHandler(liteRtHandler)
        EventChannel(messenger, dev.nanoai.mobile.channels.LiteRtChannelHandler.STREAM_CHANNEL_NAME)
            .setStreamHandler(liteRtHandler)

        // MNN usa el mismo singleton y leases de la Activity, no un motor aparte.
        val mnn = dev.nanoai.mobile.channels.MnnChannelHandler(ioScope, mainHandler)
        mnnHandler = mnn
        MethodChannel(messenger, dev.nanoai.mobile.channels.MnnChannelHandler.METHOD_CHANNEL_NAME)
            .setMethodCallHandler(mnn)
        EventChannel(messenger, dev.nanoai.mobile.channels.MnnChannelHandler.STREAM_CHANNEL_NAME)
            .setStreamHandler(mnn)

        MethodChannel(messenger, AutomationRuntimeService.HEADLESS_CHANNEL).setMethodCallHandler(control)
    }

    fun close() {
        liteRtHandler?.close()
        liteRtHandler = null
        languageHandler?.close()
        languageHandler = null
        mnnHandler?.close()
        mnnHandler = null
    }
}
