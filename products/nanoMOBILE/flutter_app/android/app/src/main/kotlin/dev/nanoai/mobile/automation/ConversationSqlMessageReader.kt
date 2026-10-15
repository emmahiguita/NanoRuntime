package dev.nanoai.mobile.automation

import android.database.sqlite.SQLiteDatabase

// QUÉ: lee mensajes recientes del scope solicitado usando canonical_messages como fuente única.
// CÓMO: Resuelve conversation_id y consulta canonical_messages; fallback a conversation_messages.
// POR QUÉ: Unifica Web, Notificaciones y Meta en la memoria duradera del agente.
internal object ConversationSqlMessageReader {
    fun read(db: SQLiteDatabase, scopeId: String, limit: Int): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()

        // 1. Resolver conversation_id desde conversation_scopes y conversation_assignments
        val convId = try {
            db.rawQuery(
                "SELECT a.conversation_id FROM conversation_scopes s JOIN conversation_assignments a ON s.address_key = a.address_key WHERE s.scope_id = ? LIMIT 1",
                arrayOf(scopeId),
            ).use { if (it.moveToFirst()) it.getString(0) else scopeId }
        } catch (_: Exception) {
            scopeId
        }

        // 2. Lectura unificada desde canonical_messages
        try {
            db.query(
                "canonical_messages",
                arrayOf("canonical_id", "provider_message_id", "direction", "delivery_state", "sender", "body", "occurred_at_ms", "raw_metadata"),
                "conversation_id = ? OR conversation_id = ?",
                arrayOf(convId, scopeId),
                null, null,
                "occurred_at_ms DESC, id DESC",
                limit.coerceIn(1, 1000).toString(),
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    val canonicalId = cursor.getString(0) ?: ""
                    val providerMsgId = cursor.getString(1) ?: ""
                    val eventId = if (providerMsgId.isNotBlank()) providerMsgId else canonicalId
                    val direction = cursor.getString(2) ?: "inbound"
                    val deliveryState = cursor.getString(3) ?: "observed"
                    val sender = cursor.getString(4) ?: ""
                    val body = cursor.getString(5) ?: ""
                    val atMs = cursor.getLong(6)
                    val rawMeta = cursor.getString(7) ?: ""
                    val ruleId = extractRuleId(rawMeta)
                    rows.add(mapOf(
                        "eventId" to eventId,
                        "direction" to direction,
                        "deliveryState" to deliveryState,
                        "sender" to sender,
                        "body" to body,
                        "atMs" to atMs,
                        "ruleId" to ruleId,
                    ))
                }
            }
        } catch (_: Exception) {}

        // 3. Fallback a conversation_messages si canonical_messages aún no tiene entradas
        if (rows.isEmpty()) {
            try {
                db.query(
                    "conversation_messages",
                    arrayOf("event_id", "direction", "delivery_state", "sender", "body", "at_ms", "rule_id"),
                    "scope_id = ?", arrayOf(scopeId), null, null, "at_ms DESC, id DESC",
                    limit.coerceIn(1, 1000).toString(),
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        rows.add(mapOf(
                            "eventId" to cursor.getString(0),
                            "direction" to cursor.getString(1),
                            "deliveryState" to cursor.getString(2),
                            "sender" to cursor.getString(3),
                            "body" to cursor.getString(4),
                            "atMs" to cursor.getLong(5),
                            "ruleId" to cursor.getString(6),
                        ))
                    }
                }
            } catch (_: Exception) {}
        }

        return rows.asReversed()
    }

    private fun extractRuleId(rawMetadata: String): String {
        if (rawMetadata.isBlank()) return ""
        val match = Regex("\"ruleId\"\\s*:\\s*\"([^\"]+)\"").find(rawMetadata)
        return match?.groupValues?.get(1) ?: ""
    }
}

