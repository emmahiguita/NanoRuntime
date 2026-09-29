package dev.nanoai.mobile.automation

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import dev.nanoai.mobile.BuildConfig
import dev.nanoai.mobile.services.AgentAccessibilityBridge
import dev.nanoai.mobile.services.whatsapp.WhatsAppTextSendBackend
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

data class ScheduledWhatsAppRecipient(val name: String, val number: String) {
    fun toJson(): JSONObject = JSONObject().put("name", name).put("number", number)

    companion object {
        fun fromJson(json: JSONObject) = ScheduledWhatsAppRecipient(
            name = json.optString("name"),
            number = json.optString("number"),
        )
    }
}

data class ScheduledWhatsAppBatch(
    val ruleId: String,
    val hour: Int,
    val minute: Int,
    val weekdays: Set<Int>,
    val timeZoneId: String,
    val recurring: Boolean,
    val message: String,
    val packageName: String,
    val recipients: List<ScheduledWhatsAppRecipient>,
    val scheduledAtMs: Long = 0L,
    val completedIndices: Set<Int> = emptySet(),
) {
    fun toJson(): JSONObject = JSONObject()
        .put("ruleId", ruleId)
        .put("hour", hour)
        .put("minute", minute)
        .put("weekdays", JSONArray(weekdays.sorted()))
        .put("timeZoneId", timeZoneId)
        .put("recurring", recurring)
        .put("message", message)
        .put("packageName", packageName)
        .put("recipients", JSONArray(recipients.map { it.toJson() }))
        .put("scheduledAtMs", scheduledAtMs)
        .put("completedIndices", JSONArray(completedIndices.sorted()))

    companion object {
        fun fromJson(json: JSONObject): ScheduledWhatsAppBatch {
            val weekdays = json.optJSONArray("weekdays") ?: JSONArray()
            val recipients = json.optJSONArray("recipients") ?: JSONArray()
            val completed = json.optJSONArray("completedIndices") ?: JSONArray()
            return ScheduledWhatsAppBatch(
                ruleId = json.getString("ruleId"),
                hour = json.getInt("hour"),
                minute = json.getInt("minute"),
                weekdays = (0 until weekdays.length()).map { weekdays.getInt(it) }.toSet(),
                timeZoneId = json.optString("timeZoneId"),
                recurring = json.optBoolean("recurring", false),
                message = json.getString("message"),
                packageName = json.optString("packageName", "com.whatsapp"),
                recipients = (0 until recipients.length()).map {
                    ScheduledWhatsAppRecipient.fromJson(recipients.getJSONObject(it))
                },
                scheduledAtMs = json.optLong("scheduledAtMs", 0L),
                completedIndices = (0 until completed.length()).map {
                    completed.getInt(it)
                }.toSet(),
            )
        }
    }
}

data class NativeScheduleResult(
    val ok: Boolean,
    val exact: Boolean,
    val scheduledAtMs: Long,
    val reason: String = "",
)

/** AlarmManager durable + store privado, independiente del ciclo de Flutter. */
object ScheduledWhatsAppAlarmScheduler {
    private const val PREFS = "nano_scheduled_whatsapp_v1"
    private const val KEY_PREFIX = "batch:"
    private const val RECIPIENT_GAP_MS = 8_000L

    fun schedule(context: Context, input: ScheduledWhatsAppBatch): NativeScheduleResult {
        val validation = validate(input)
        if (validation != null) return NativeScheduleResult(false, false, 0L, validation)
        val zone = resolveZone(input.timeZoneId)
            ?: return NativeScheduleResult(false, false, 0L, "Zona horaria inválida.")
        val base = nextOccurrence(input, zone, ZonedDateTime.now(zone)).toInstant().toEpochMilli()
        val batch = input.copy(
            timeZoneId = zone.id,
            scheduledAtMs = base,
            completedIndices = emptySet(),
        )
        save(context, batch)
        val exact = schedulePending(context, batch)
        return NativeScheduleResult(true, exact, base)
    }

    fun cancel(context: Context, ruleId: String) {
        val batch = load(context, ruleId)
        if (batch != null) cancelPending(context, batch)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove("$KEY_PREFIX$ruleId").apply()
    }

    fun onRecipientFinished(context: Context, batch: ScheduledWhatsAppBatch, index: Int) {
        val latest = load(context, batch.ruleId) ?: return
        if (latest.completedIndices.size >= latest.recipients.size) {
            finishBatch(context, latest)
            return
        }
        if (index in latest.completedIndices) return
        val completed = latest.completedIndices + index
        if (completed.size < latest.recipients.size) {
            save(context, latest.copy(completedIndices = completed))
            return
        }
        finishBatch(context, latest.copy(completedIndices = completed))
    }

    private fun finishBatch(context: Context, latest: ScheduledWhatsAppBatch) {
        if (!latest.recurring) {
            cancel(context, latest.ruleId)
            return
        }
        val zone = resolveZone(latest.timeZoneId) ?: ZoneId.systemDefault()
        val after = Instant.ofEpochMilli(latest.scheduledAtMs)
            .atZone(zone)
            .plusMinutes(1)
        val next = nextOccurrence(latest, zone, after).toInstant().toEpochMilli()
        val renewed = latest.copy(scheduledAtMs = next, completedIndices = emptySet())
        save(context, renewed)
        schedulePending(context, renewed)
    }

    fun restoreAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val batches = prefs.all
            .filterKeys { it.startsWith(KEY_PREFIX) }
            .values
            .mapNotNull { raw ->
                runCatching { ScheduledWhatsAppBatch.fromJson(JSONObject(raw as String)) }.getOrNull()
            }
        val now = System.currentTimeMillis()
        for (batch in batches) {
            val remaining = batch.recipients.indices.filterNot(batch.completedIndices::contains)
            if (remaining.isEmpty()) {
                onRecipientFinished(context, batch, batch.recipients.lastIndex)
                continue
            }
            val restored = if (batch.scheduledAtMs <= now) {
                batch.copy(scheduledAtMs = now + 2_000L)
            } else {
                batch
            }
            save(context, restored)
            schedulePending(context, restored, remaining.toSet())
        }
    }

    fun load(context: Context, ruleId: String): ScheduledWhatsAppBatch? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("$KEY_PREFIX$ruleId", null) ?: return null
        return runCatching { ScheduledWhatsAppBatch.fromJson(JSONObject(raw)) }.getOrNull()
    }

    private fun save(context: Context, batch: ScheduledWhatsAppBatch) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString("$KEY_PREFIX${batch.ruleId}", batch.toJson().toString()).apply()
    }

    private fun schedulePending(
        context: Context,
        batch: ScheduledWhatsAppBatch,
        onlyIndices: Set<Int>? = null,
    ): Boolean {
        val manager = context.getSystemService(AlarmManager::class.java)
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
        batch.recipients.indices
            .filter { onlyIndices == null || it in onlyIndices }
            .forEach { index ->
                val at = batch.scheduledAtMs + index * RECIPIENT_GAP_MS
                val operation = pendingIntent(context, batch.ruleId, index)
                if (exact) {
                    manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
                } else {
                    manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
                }
            }
        return exact
    }

    private fun cancelPending(context: Context, batch: ScheduledWhatsAppBatch) {
        val manager = context.getSystemService(AlarmManager::class.java)
        batch.recipients.indices.forEach { index ->
            manager.cancel(pendingIntent(context, batch.ruleId, index))
        }
    }

    private fun pendingIntent(context: Context, ruleId: String, index: Int): PendingIntent {
        val intent = Intent(context, ScheduledWhatsAppAlarmReceiver::class.java)
            .putExtra("ruleId", ruleId)
            .putExtra("recipientIndex", index)
        return PendingIntent.getBroadcast(
            context,
            "$ruleId:$index".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun nextOccurrence(
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

    private fun resolveZone(id: String): ZoneId? = runCatching {
        if (id.isBlank()) ZoneId.systemDefault() else ZoneId.of(id)
    }.getOrNull()

    private fun validate(batch: ScheduledWhatsAppBatch): String? = when {
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

class ScheduledWhatsAppAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val ruleId = intent.getStringExtra("ruleId") ?: return
        val index = intent.getIntExtra("recipientIndex", -1)
        val batch = ScheduledWhatsAppAlarmScheduler.load(context, ruleId) ?: return
        if (index !in batch.recipients.indices || index in batch.completedIndices) return
        val recipient = batch.recipients[index]
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
                )
                if (opened.ok) null else opened.message
            }
        }
        if (failure != null) notifyFailure(context, recipient.name, failure)
        ScheduledWhatsAppAlarmScheduler.onRecipientFinished(context, batch, index)
    }

    private fun notifyFailure(context: Context, recipient: String, reason: String) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val channelId = "nano_scheduled_messages"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "Mensajes programados",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("No se pudo enviar a $recipient")
            .setContentText(reason)
            .setStyle(NotificationCompat.BigTextStyle().bigText(reason))
            .setAutoCancel(true)
            .build()
        manager.notify((recipient + System.currentTimeMillis()).hashCode(), notification)
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
