package dev.nanoai.mobile.automation

import org.json.JSONArray
import org.json.JSONObject

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
    // Conserva fallos y solicitudes activas separados del resultado de envío.
    val failedIndices: Set<Int> = emptySet(),
    val inFlightIndices: Set<Int> = emptySet(),
    val attemptCounts: Map<Int, Int> = emptyMap(),
    val unknownIndices: Set<Int> = emptySet(),
) {
    fun toJson(): JSONObject = JSONObject()
        .put("schemaVersion", 2)
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
        .put("failedIndices", JSONArray(failedIndices.sorted()))
        .put("inFlightIndices", JSONArray(inFlightIndices.sorted()))
        .put("unknownIndices", JSONArray(unknownIndices.sorted()))
        .put("attemptCounts", JSONObject().apply {
            attemptCounts.forEach { (index, count) -> put(index.toString(), count) }
        })

    companion object {
        fun fromJson(json: JSONObject): ScheduledWhatsAppBatch {
            val weekdays = json.optJSONArray("weekdays") ?: JSONArray()
            val recipients = json.optJSONArray("recipients") ?: JSONArray()
            val completed = json.optJSONArray("completedIndices") ?: JSONArray()
            val failed = json.optJSONArray("failedIndices") ?: JSONArray()
            val inFlight = json.optJSONArray("inFlightIndices") ?: JSONArray()
            val unknown = json.optJSONArray("unknownIndices") ?: JSONArray()
            val attempts = json.optJSONObject("attemptCounts") ?: JSONObject()
            val storedCompleted = (0 until completed.length()).map { completed.getInt(it) }.toSet()
            val isLegacy = json.optInt("schemaVersion", 0) < 2
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
                // Version anterior marcaba como completado solo abrir WhatsApp; migramos a incierto.
                completedIndices = if (isLegacy) emptySet() else storedCompleted,
                failedIndices = (0 until failed.length()).map { failed.getInt(it) }.toSet(),
                inFlightIndices = (0 until inFlight.length()).map { inFlight.getInt(it) }.toSet(),
                unknownIndices = (0 until unknown.length()).map { unknown.getInt(it) }
                    .toSet() + if (isLegacy) storedCompleted else emptySet(),
                attemptCounts = attempts.keys().asSequence().mapNotNull { key ->
                    val index = key.toIntOrNull() ?: return@mapNotNull null
                    index to attempts.optInt(key)
                }.toMap(),
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
