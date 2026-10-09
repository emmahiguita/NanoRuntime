package dev.nanoai.mobile.automation

import android.database.sqlite.SQLiteDatabase

// QUÉ: lee mensajes recientes del scope solicitado sin modificar la base.
// CÓMO: DESC aplica LIMIT a los últimos; reverse devuelve orden cronológico.
// POR QUÉ: ASC + LIMIT devolvía los más antiguos y perdía la conversación actual.
internal object ConversationSqlMessageReader {
    fun read(db: SQLiteDatabase, scopeId: String, limit: Int): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
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
        return rows.asReversed()
    }
}
