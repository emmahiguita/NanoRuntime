package dev.nanoai.mobile.automation

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

// Encapsula AlarmManager, PendingIntent y cálculo horario sin cargar el ciclo de estado.
internal object ScheduledWhatsAppAlarmActions {
    private const val RECIPIENT_GAP_MS = 8_000L
    private const val RETRY_DELAY_MS = 15_000L
    private const val RESULT_TIMEOUT_MS = 20_000L

    // Un timeout cierra en estado incierto si Android mata Nano antes del callback accesible.
    fun scheduleResultTimeout(
        context: Context,
        ruleId: String,
        index: Int,
        expectedScheduledAtMs: Long,
    ) {
        val manager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, ScheduledWhatsAppAlarmReceiver::class.java)
            .putExtra("ruleId", ruleId)
            .putExtra("recipientIndex", index)
            .putExtra("resultTimeout", true)
            .putExtra("batchScheduledAtMs", expectedScheduledAtMs)
        val operation = PendingIntent.getBroadcast(
            context,
            "${ruleId}:${index}:result-timeout".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val at = System.currentTimeMillis() + RESULT_TIMEOUT_MS
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()) {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
        } else {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
        }
    }

    // Al terminar antes del plazo, elimina el callback de timeout que ya no aporta.
    fun cancelResultTimeout(context: Context, ruleId: String, index: Int) {
        val intent = Intent(context, ScheduledWhatsAppAlarmReceiver::class.java)
        val operation = PendingIntent.getBroadcast(
            context,
            "${ruleId}:${index}:result-timeout".hashCode(),
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(operation)
        operation.cancel()
    }

    fun schedulePending(
        context: Context,
        batch: ScheduledWhatsAppBatch,
        onlyIndices: Set<Int>? = null,
    ): Boolean {
        val manager = context.getSystemService(AlarmManager::class.java)
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
        // Solo se agenda el siguiente contacto; así dos alarmas retrasadas no pisan la misma UI.
        val index = batch.recipients.indices.firstOrNull { candidate ->
            candidate !in batch.completedIndices && candidate !in batch.failedIndices &&
                candidate !in batch.inFlightIndices && candidate !in batch.unknownIndices &&
                (onlyIndices == null || candidate in onlyIndices)
        }
        if (index != null) {
            val at = batch.scheduledAtMs
            val operation = pendingIntent(context, batch.ruleId, index, batch.scheduledAtMs)
            if (exact) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
            else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
        }
        return exact
    }

    // Un fallo verificado antes del click permite un reintento separado y acotado.
    fun scheduleRetry(context: Context, batch: ScheduledWhatsAppBatch, index: Int) {
        val manager = context.getSystemService(AlarmManager::class.java)
        val at = System.currentTimeMillis() + RETRY_DELAY_MS
        val operation = pendingIntent(context, batch.ruleId, index, batch.scheduledAtMs)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()) {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
        } else {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
        }
    }

    // Agenda el siguiente destinatario solo cuando el anterior ya tuvo resultado terminal.
    fun scheduleNextRecipient(context: Context, batch: ScheduledWhatsAppBatch) {
        val next = batch.recipients.indices.firstOrNull { index ->
            index !in batch.completedIndices && index !in batch.failedIndices &&
                index !in batch.inFlightIndices && index !in batch.unknownIndices
        } ?: return
        val manager = context.getSystemService(AlarmManager::class.java)
        val operation = pendingIntent(context, batch.ruleId, next, batch.scheduledAtMs)
        val at = System.currentTimeMillis() + RECIPIENT_GAP_MS
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()) {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
        } else {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
        }
    }

    fun cancelPending(context: Context, batch: ScheduledWhatsAppBatch) {
        val manager = context.getSystemService(AlarmManager::class.java)
        batch.recipients.indices.forEach { index ->
            manager.cancel(pendingIntent(context, batch.ruleId, index, batch.scheduledAtMs))
            cancelResultTimeout(context, batch.ruleId, index)
        }
    }

    private fun pendingIntent(
        context: Context,
        ruleId: String,
        index: Int,
        expectedScheduledAtMs: Long,
    ): PendingIntent {
        val intent = Intent(context, ScheduledWhatsAppAlarmReceiver::class.java)
            .putExtra("ruleId", ruleId)
            .putExtra("recipientIndex", index)
            .putExtra("batchScheduledAtMs", expectedScheduledAtMs)
        return PendingIntent.getBroadcast(
            context,
            "$ruleId:$index".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun nextOccurrence(
        batch: ScheduledWhatsAppBatch,
        zone: ZoneId,
        now: ZonedDateTime,
    ): ZonedDateTime {
        var candidate = now.withHour(batch.hour).withMinute(batch.minute)
            .withSecond(0).withNano(0)
        if (!candidate.isAfter(now.plusSeconds(1))) candidate = candidate.plusDays(1)
        if (batch.weekdays.isNotEmpty()) {
            while (candidate.dayOfWeek.value !in batch.weekdays) candidate = candidate.plusDays(1)
        }
        return candidate.withZoneSameLocal(zone)
    }

    fun resolveZone(id: String): ZoneId? = runCatching {
        if (id.isBlank()) ZoneId.systemDefault() else ZoneId.of(id)
    }.getOrNull()

    fun validate(batch: ScheduledWhatsAppBatch): String? = when {
        batch.ruleId.isBlank() -> "Falta el identificador de la regla."
        batch.hour !in 0..23 || batch.minute !in 0..59 -> "Hora inválida."
        batch.message.isBlank() -> "El mensaje está vacío."
        batch.recipients.isEmpty() -> "No hay destinatarios."
        batch.recipients.size > 50 -> "Máximo 50 destinatarios por regla."
        batch.recipients.any { it.number.filter(Char::isDigit).length < 7 } ->
            "Hay un destinatario sin número válido."
        else -> null
    }
}
