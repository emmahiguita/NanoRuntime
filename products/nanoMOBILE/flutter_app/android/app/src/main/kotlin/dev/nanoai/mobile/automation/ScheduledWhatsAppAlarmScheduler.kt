package dev.nanoai.mobile.automation

import android.content.Context
import android.os.Build
import dev.nanoai.mobile.BuildConfig
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

object ScheduledWhatsAppAlarmScheduler {
    private const val PREFS = "nano_scheduled_whatsapp_v1"
    private const val KEY_PREFIX = "batch:"
    private const val MAX_ATTEMPTS = 2

    fun schedule(context: Context, input: ScheduledWhatsAppBatch): NativeScheduleResult {
        if (BuildConfig.PLAY_STORE_BUILD) {
            return NativeScheduleResult(false, false, 0L, "El envío automático requiere la variante sideload con Accesibilidad.")
        }
        val validation = ScheduledWhatsAppAlarmActions.validate(input)
        if (validation != null) return NativeScheduleResult(false, false, 0L, validation)
        val zone = ScheduledWhatsAppAlarmActions.resolveZone(input.timeZoneId)
            ?: return NativeScheduleResult(false, false, 0L, "Zona horaria inválida.")
        val base = ScheduledWhatsAppAlarmActions.nextOccurrence(input, zone, ZonedDateTime.now(zone)).toInstant().toEpochMilli()
        val batch = input.copy(
            timeZoneId = zone.id,
            scheduledAtMs = base,
            completedIndices = emptySet(),
            failedIndices = emptySet(),
            inFlightIndices = emptySet(),
            attemptCounts = emptyMap(),
            unknownIndices = emptySet(),
        )
        // Reprogramar la misma regla invalida alarmas, timeouts y reintentos
        // del lote anterior antes de publicar el nuevo estado.
        load(context, batch.ruleId)?.let { previous ->
            ScheduledWhatsAppAlarmActions.cancelPending(context, previous)
        }
        if (!save(context, batch)) {
            return NativeScheduleResult(false, false, 0L, "No se pudo guardar la programación de forma durable.")
        }
        val exact = ScheduledWhatsAppAlarmActions.schedulePending(context, batch)
        return NativeScheduleResult(true, exact, base)
    }

    fun cancel(context: Context, ruleId: String) {
        val batch = load(context, ruleId)
        if (batch != null) ScheduledWhatsAppAlarmActions.cancelPending(context, batch)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove("$KEY_PREFIX$ruleId").commit()
    }

    // Se marca en vuelo antes de abrir WhatsApp; al reiniciar se trata como resultado desconocido.
    fun markRecipientInFlight(
        context: Context,
        ruleId: String,
        index: Int,
        expectedScheduledAtMs: Long,
    ): Boolean {
        val latest = load(context, ruleId) ?: return false
        if (latest.scheduledAtMs != expectedScheduledAtMs) return false
        if (index !in latest.recipients.indices || index in latest.completedIndices ||
            index in latest.failedIndices || index in latest.inFlightIndices ||
            index in latest.unknownIndices
        ) return false
        save(context, latest.copy(inFlightIndices = latest.inFlightIndices + index))
        return true
    }

    // Solo un click confirmado por Accesibilidad cuenta como acción despachada; nunca como entrega.
    fun onRecipientResult(
        context: Context,
        ruleId: String,
        index: Int,
        clickedSend: Boolean,
        retryable: Boolean,
        unknownOutcome: Boolean = false,
        expectedScheduledAtMs: Long,
    ) {
        val latest = load(context, ruleId) ?: return
        if (latest.scheduledAtMs != expectedScheduledAtMs) return
        if (index !in latest.recipients.indices || index !in latest.inFlightIndices ||
            index in latest.completedIndices || index in latest.failedIndices ||
            index in latest.unknownIndices
        ) return
        val inFlight = latest.inFlightIndices - index
        val attempts = latest.attemptCounts[index] ?: 0
        val confirmedClick = clickedSend && !unknownOutcome
        val nextAttempts = if (confirmedClick) attempts else attempts + 1
        val shouldRetry = !confirmedClick && !unknownOutcome && retryable && nextAttempts < MAX_ATTEMPTS
        val updated = latest.copy(
            completedIndices = if (confirmedClick) latest.completedIndices + index else latest.completedIndices,
            failedIndices = if (!confirmedClick && !shouldRetry && !unknownOutcome) latest.failedIndices + index else latest.failedIndices,
            inFlightIndices = inFlight,
            attemptCounts = latest.attemptCounts + (index to nextAttempts),
            unknownIndices = if (unknownOutcome) latest.unknownIndices + index else latest.unknownIndices,
        )
        save(context, updated)
        ScheduledWhatsAppAlarmActions.cancelResultTimeout(context, ruleId, index)
        if (shouldRetry) {
            ScheduledWhatsAppAlarmActions.scheduleRetry(context, updated, index)
        } else if (updated.completedIndices.size + updated.failedIndices.size + updated.unknownIndices.size >= updated.recipients.size) {
            finishBatch(context, updated)
        } else {
            ScheduledWhatsAppAlarmActions.scheduleNextRecipient(context, updated)
        }
    }

    private fun finishBatch(context: Context, latest: ScheduledWhatsAppBatch) {
        if (!latest.recurring) {
            cancel(context, latest.ruleId)
            return
        }
        val zone = ScheduledWhatsAppAlarmActions.resolveZone(latest.timeZoneId) ?: ZoneId.systemDefault()
        val after = Instant.ofEpochMilli(latest.scheduledAtMs)
            .atZone(zone)
            .plusMinutes(1)
        val next = ScheduledWhatsAppAlarmActions.nextOccurrence(latest, zone, after).toInstant().toEpochMilli()
        val renewed = latest.copy(
            scheduledAtMs = next,
            completedIndices = emptySet(),
            failedIndices = emptySet(),
            inFlightIndices = emptySet(),
            attemptCounts = emptyMap(),
            unknownIndices = emptySet(),
        )
        save(context, renewed)
        ScheduledWhatsAppAlarmActions.schedulePending(context, renewed)
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
            // Una ejecución cortada no se repite: el click pudo ocurrir justo antes del cierre.
            val interrupted = batch.inFlightIndices + batch.unknownIndices
            val recovered = if (interrupted.isNotEmpty()) {
                batch.copy(
                    inFlightIndices = emptySet(),
                    failedIndices = batch.failedIndices + interrupted,
                    unknownIndices = emptySet(),
                ).also { updated ->
                    save(context, updated)
                    interrupted.forEach { index ->
                        updated.recipients.getOrNull(index)?.let { recipient ->
                            ScheduledWhatsAppNotifier.failure(
                                context, recipient.name,
                                "Nano se reinició antes de confirmar el envío. Revisa WhatsApp antes de repetirlo.",
                            )
                        }
                    }
                }
            } else batch
            val remaining = recovered.recipients.indices.filterNot {
                it in recovered.completedIndices || it in recovered.failedIndices
            }
            if (remaining.isEmpty()) {
                finishBatch(context, recovered)
                continue
            }
            val restored = if (recovered.scheduledAtMs <= now) {
                recovered.copy(scheduledAtMs = now + 2_000L)
            } else {
                recovered
            }
            save(context, restored)
            ScheduledWhatsAppAlarmActions.schedulePending(context, restored, remaining.toSet())
        }
    }


    // Mantiene el contrato usado por el receptor y delega la alarma de timeout.
    fun scheduleResultTimeout(
        context: Context,
        ruleId: String,
        index: Int,
        expectedScheduledAtMs: Long,
    ) = ScheduledWhatsAppAlarmActions.scheduleResultTimeout(
        context,
        ruleId,
        index,
        expectedScheduledAtMs,
    )

    fun load(context: Context, ruleId: String): ScheduledWhatsAppBatch? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("$KEY_PREFIX$ruleId", null) ?: return null
        return runCatching { ScheduledWhatsAppBatch.fromJson(JSONObject(raw)) }.getOrNull()
    }

    private fun save(context: Context, batch: ScheduledWhatsAppBatch): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString("$KEY_PREFIX${batch.ruleId}", batch.toJson().toString()).commit()


}
