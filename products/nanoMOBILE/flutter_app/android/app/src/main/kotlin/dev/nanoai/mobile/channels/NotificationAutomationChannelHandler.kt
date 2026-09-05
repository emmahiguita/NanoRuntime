package dev.nanoai.mobile.channels

import android.app.Activity
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import dev.nanoai.mobile.MainActivity
import dev.nanoai.mobile.R
import dev.nanoai.mobile.services.NotificationAutomationBridge
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Puente Flutter ↔ NotificationListenerService. Todas las acciones son locales.
 *
 *  WA-PROD-01: ctor por [Context] (antes Activity) — el MISMO handler sirve
 *  al engine de la UI (MainActivity) y al engine headless del
 *  AutomationRuntimeService. Las pantallas de sistema se abren con NEW_TASK
 *  cuando el contexto no es una Activity. */
class NotificationAutomationChannelHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/notifications"
        private const val CONFIRMATION_CHANNEL_ID = "nano_automation_confirmation"
        private const val CONFIRMATION_NOTIFICATION_ID = 0x4E41

        /** NOTIFY-01: avisos locales de reglas (RuleAction.notify). */
        private const val NOTICE_CHANNEL_ID = "nano_rule_notices"
        private const val NOTICE_NOTIFICATION_ID = 0x4E42
        const val CONFIRMATION_EVENTS_CHANNEL_NAME =
            "com.nanoai/automation_confirmation_events"
        const val ACTION_CONFIRM_AUTOMATION =
            "dev.nanoai.mobile.action.CONFIRM_AUTOMATION"
        @Volatile
        private var confirmationEventsSink: EventChannel.EventSink? = null

        fun emitConfirmationAction(action: String): Boolean {
            val sink = confirmationEventsSink ?: return false
            sink.success(action)
            return true
        }

        fun dismissConfirmation(context: Context) {
            NotificationManagerCompat.from(context)
                .cancel(CONFIRMATION_NOTIFICATION_ID)
        }

        val CAPABILITIES = listOf(
            "notification-read",
            "notification-reply",
            "automation-confirmation-alert",
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(
                mapOf(
                    "accessGranted" to NotificationManagerCompat
                        .getEnabledListenerPackages(context)
                        .contains(context.packageName),
                    "connected" to (NotificationAutomationBridge.service != null),
                ),
            )

            "requestAccess" -> {
                val opened = openSystemSettings(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    || openSystemSettings(Settings.ACTION_SETTINGS)
                result.success(opened)
            }

            "list" -> {
                val limit = call.argument<Number>("limit")?.toInt() ?: 30
                result.success(NotificationAutomationBridge.service?.snapshot(limit) ?: emptyList<Any>())
            }

            "showAutomationConfirmation" ->
                result.success(showAutomationConfirmation())

            "dismissAutomationConfirmation" -> {
                NotificationManagerCompat.from(context)
                    .cancel(CONFIRMATION_NOTIFICATION_ID)
                result.success(true)
            }

            "notifyRuleEvent" -> {
                val title = call.argument<String>("title").orEmpty()
                val body = call.argument<String>("body").orEmpty()
                result.success(notifyRuleEvent(title, body))
            }

            "reply" -> {
                val key = call.argument<String>("key")
                val text = call.argument<String>("text")
                val confirmed = call.argument<Boolean>("confirmed") == true
                if (!confirmed) {
                    result.error("CONFIRMATION_REQUIRED", "la respuesta requiere confirmación", null)
                    return
                }
                if (key.isNullOrBlank() || text.isNullOrBlank()) {
                    result.error("BAD_ARG", "key y text requeridos", null)
                    return
                }
                val service = NotificationAutomationBridge.service
                if (service == null) {
                    result.error("LISTENER_UNAVAILABLE", "listener no conectado", null)
                    return
                }
                // WA-RI-05: campos de la capacidad OBSERVADA (opcionales).
                // El servicio los recomputa contra la notificación activa y
                // exige igualdad antes de enviar (CONTEXT_CHANGED si no).
                val actionIndex = call.argument<Number>("actionIndex")?.toInt() ?: -1
                val remoteInputKey = call.argument<String>("remoteInputKey").orEmpty()
                val contextFingerprint = call.argument<String>("contextFingerprint").orEmpty()
                val reply = service.reply(
                    key,
                    text,
                    expectedActionIndex = actionIndex,
                    expectedRemoteInputKey = remoteInputKey,
                    expectedContextFingerprint = contextFingerprint,
                )
                result.success(mapOf("ok" to reply.ok, "code" to reply.code))
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        confirmationEventsSink = events
    }

    override fun onCancel(arguments: Any?) {
        confirmationEventsSink = null
    }

    /** Pantalla de sistema; NEW_TASK solo cuando el contexto no es Activity. */
    private fun openSystemSettings(action: String): Boolean {
        return try {
            val intent = Intent(action)
            if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (_: android.content.ActivityNotFoundException) {
            false
        }
    }

    /**
     * NOTIFY-01 — aviso local de una regla: "cuando X me escriba, avísame".
     * Notificación propia de Nano; el tap solo abre Nano. Un aviso nuevo
     * reemplaza al anterior (ID fijo): es señal, no historial.
     */
    private fun notifyRuleEvent(title: String, body: String): Boolean {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return false
        if (title.isBlank() && body.isBlank()) return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTICE_CHANNEL_ID,
                "Avisos de reglas",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Mensajes nuevos que activaron una regla de aviso"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        val openIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            NOTICE_NOTIFICATION_ID,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, NOTICE_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_nano_confirmation)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(openPendingIntent)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .build()

        return try {
            manager.notify(NOTICE_NOTIFICATION_ID, notification)
            true
        } catch (_: SecurityException) {
            false
        }
    }

    /**
     * Hace visible una pausa de gobernanza mientras la app controlada está al
     * frente. La notificación NO confirma ni ejecuta nada: solo devuelve al
     * usuario a la confirmación firmada que conserva Flutter/Journal.
     */
    private fun showAutomationConfirmation(): Boolean {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CONFIRMATION_CHANNEL_ID,
                "Confirmaciones de automatización",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Solicitudes de revisión antes de acciones sensibles"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        val reviewIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val reviewPendingIntent = PendingIntent.getActivity(
            context,
            CONFIRMATION_NOTIFICATION_ID,
            reviewIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val confirmIntent = Intent(
            context,
            AutomationConfirmationActionReceiver::class.java,
        ).setAction(ACTION_CONFIRM_AUTOMATION)
        val confirmPendingIntent = PendingIntent.getBroadcast(
            context,
            CONFIRMATION_NOTIFICATION_ID + 1,
            confirmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CONFIRMATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_nano_confirmation)
            .setContentTitle("Nano necesita confirmación")
            .setContentText("Toca para revisar y autorizar la acción pendiente.")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("La automatización está pausada. Toca para revisar y autorizar la acción pendiente en Nano."),
            )
            .setContentIntent(reviewPendingIntent)
            .addAction(
                R.drawable.ic_nano_confirmation,
                "Confirmar acción",
                confirmPendingIntent,
            )
            .addAction(0, "Revisar en Nano", reviewPendingIntent)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .build()

        return try {
            manager.notify(CONFIRMATION_NOTIFICATION_ID, notification)
            true
        } catch (_: SecurityException) {
            false
        }
    }
}

/**
 * Entrada explícita y no exportada para confirmar desde la notificación sin
 * sacar del primer plano a la app controlada. No contiene token ni payload:
 * Flutter reanuda exclusivamente la confirmación firmada que mantiene activa.
 */
class AutomationConfirmationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != NotificationAutomationChannelHandler.ACTION_CONFIRM_AUTOMATION) {
            return
        }
        val keyguard = context.getSystemService(KeyguardManager::class.java)
        if (keyguard?.isDeviceLocked == true) return

        if (NotificationAutomationChannelHandler.emitConfirmationAction("confirm")) {
            NotificationAutomationChannelHandler.dismissConfirmation(context)
        }
    }
}
