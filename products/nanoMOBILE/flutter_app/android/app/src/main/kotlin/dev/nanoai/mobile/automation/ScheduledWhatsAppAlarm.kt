package dev.nanoai.mobile.automation

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import dev.nanoai.mobile.BuildConfig
import dev.nanoai.mobile.services.AgentAccessibilityBridge
import dev.nanoai.mobile.services.whatsapp.WhatsAppTextSendBackend

class ScheduledWhatsAppAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val ruleId = intent.getStringExtra("ruleId") ?: return
        val index = intent.getIntExtra("recipientIndex", -1)
        val batch = ScheduledWhatsAppAlarmScheduler.load(context, ruleId) ?: return
        val expectedScheduledAtMs = intent.getLongExtra("batchScheduledAtMs", Long.MIN_VALUE)
        if (expectedScheduledAtMs != batch.scheduledAtMs) return
        if (index !in batch.recipients.indices) return
        if (intent.getBooleanExtra("resultTimeout", false)) {
            if (index in batch.inFlightIndices) {
                ScheduledWhatsAppAlarmScheduler.onRecipientResult(
                    context, ruleId, index, clickedSend = false, retryable = false,
                    unknownOutcome = true,
                    expectedScheduledAtMs = expectedScheduledAtMs,
                )
                notifyFailure(context, batch.recipients[index].name,
                    "No llegó confirmación de Nano. Revisa WhatsApp antes de intentar enviarlo otra vez.")
            }
            return
        }
        if (index in batch.completedIndices || index in batch.failedIndices) return
        val recipient = batch.recipients[index]
        if (!ScheduledWhatsAppAlarmScheduler.markRecipientInFlight(
                context,
                ruleId,
                index,
                expectedScheduledAtMs,
            )
        ) return
        val failure = when {
            BuildConfig.PLAY_STORE_BUILD ->
                "El autoenvío no está disponible en la edición de Google Play."
            AgentAccessibilityBridge.service == null ->
                "Activa Accesibilidad de Nano para enviar a ${recipient.name}."
            else -> {
                val opened = WhatsAppTextSendBackend(context.applicationContext).openChat(
                    contact = recipient.number,
                    text = batch.message,
                    requestedPackage = batch.packageName,
                    autoSend = true,
                    expectedAliasOverride = recipient.name,
                    onAutoSendResult = { clicked, detail ->
                        ScheduledWhatsAppAlarmScheduler.onRecipientResult(
                            context, ruleId, index, clickedSend = clicked, retryable = !clicked,
                            expectedScheduledAtMs = expectedScheduledAtMs,
                        )
                        if (!clicked) notifyFailure(context, recipient.name, detail)
                    },
                )
                if (opened.ok) null else opened.message
            }
        }
        if (failure != null) {
            ScheduledWhatsAppAlarmScheduler.onRecipientResult(
                context, ruleId, index, clickedSend = false, retryable = false,
                expectedScheduledAtMs = expectedScheduledAtMs,
            )
            notifyFailure(context, recipient.name, failure)
        } else {
            ScheduledWhatsAppAlarmScheduler.scheduleResultTimeout(
                context,
                ruleId,
                index,
                expectedScheduledAtMs,
            )
        }
    }

    private fun notifyFailure(context: Context, recipient: String, reason: String) {
        ScheduledWhatsAppNotifier.failure(context, recipient, reason)
    }
}

class ScheduledWhatsAppBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED
        ) {
            ScheduledWhatsAppAlarmScheduler.restoreAll(context.applicationContext)
        }
    }
}
