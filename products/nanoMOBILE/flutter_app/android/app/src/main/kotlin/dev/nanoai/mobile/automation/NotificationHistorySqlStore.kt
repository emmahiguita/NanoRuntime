package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import java.security.MessageDigest

/**
 * Guarda eventos de conversación entregados por Android en SQLite local.
 * Retiene hasta 5.000 mensajes o 90 días para que cerrar una notificación no
 * borre el historial visible; nunca envía el texto a un servidor.
 */
internal class NotificationHistorySqlStore(
    private val readable: () -> SQLiteDatabase,
    private val writable: () -> SQLiteDatabase,
) {
    fun append(events: List<NotificationHistoryEvent>) {
        if (events.isEmpty()) return
        val db = writable()
        db.beginTransaction()
        try {
            events.takeLast(MAX_BATCH).forEach { event ->
                if (event.body.isBlank() || event.conversationId.isBlank()) return@forEach
                val historyId = digest("${event.packageName}\u0000${event.conversationId}")
                val eventId = digest("$historyId\u0000${event.atMs}\u0000${event.sender}\u0000${event.body}")
                val row = ContentValues().apply {
                    put("history_id", historyId)
                    put("event_id", eventId)
                    put("package_name", event.packageName.take(MAX_FIELD))
                    put("conversation_id", event.conversationId.take(MAX_FIELD))
                    put("display_name", event.displayName.take(MAX_FIELD))
                    put("notification_key", event.notificationKey.take(MAX_FIELD))
                    put("sender", event.sender.take(MAX_FIELD))
                    put("body", event.body.take(MAX_BODY))
                    put("at_ms", event.atMs)
                    put("is_group", if (event.isGroup) 1 else 0)
                    put("is_self", if (event.isSelf) 1 else 0)
                }
                db.insertWithOnConflict(TABLE, null, row, SQLiteDatabase.CONFLICT_IGNORE)
            }
            db.delete(TABLE, "at_ms < ?", arrayOf((System.currentTimeMillis() - RETENTION_MS).toString()))
            db.execSQL("DELETE FROM $TABLE WHERE id NOT IN (SELECT id FROM $TABLE ORDER BY at_ms DESC, id DESC LIMIT $MAX_ROWS)")
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun listConversations(limit: Int): List<Map<String, Any?>> = readable().rawQuery(
        """SELECT h.history_id, h.package_name, h.conversation_id,
            COALESCE((SELECT d.display_name FROM $TABLE d WHERE d.history_id = h.history_id AND d.display_name NOT IN ('Tú', 'Tu', '0', '') ORDER BY d.at_ms DESC LIMIT 1), h.display_name),
            h.notification_key, h.sender, h.body, h.at_ms, h.is_group,
            (SELECT COUNT(*) FROM $TABLE c WHERE c.history_id = h.history_id)
            FROM $TABLE h WHERE h.id = (SELECT x.id FROM $TABLE x
            WHERE x.history_id = h.history_id ORDER BY x.at_ms DESC, x.id DESC LIMIT 1)
            ORDER BY h.at_ms DESC LIMIT ?""",
        arrayOf(limit.coerceIn(1, 200).toString()),
    ).use { cursor ->
        buildList {
            while (cursor.moveToNext()) add(mapOf(
                "historyId" to cursor.getString(0), "packageName" to cursor.getString(1),
                "conversationId" to cursor.getString(2), "displayName" to cursor.getString(3),
                "notificationKey" to cursor.getString(4), "lastSender" to cursor.getString(5),
                "lastMessage" to cursor.getString(6), "lastAtMs" to cursor.getLong(7),
                "isGroup" to (cursor.getInt(8) != 0), "entryCount" to cursor.getInt(9),
            ))
        }
    }

    fun listMessages(historyId: String, limit: Int): List<Map<String, Any?>> {
        if (historyId.isBlank() || historyId.length > 64) return emptyList()
        val rows = readable().query(
            TABLE, arrayOf("event_id", "sender", "body", "at_ms", "is_self"),
            "history_id = ?", arrayOf(historyId), null, null, "at_ms DESC, id DESC",
            limit.coerceIn(1, 1000).toString(),
        ).use { cursor -> buildList {
            while (cursor.moveToNext()) add(mapOf(
                "eventId" to cursor.getString(0), "sender" to cursor.getString(1),
                "body" to cursor.getString(2), "atMs" to cursor.getLong(3),
                "isSelf" to (cursor.getInt(4) != 0),
            ))
        } }
        return rows.reversed()
    }

    private fun digest(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray()).joinToString("") { "%02x".format(it) }

    companion object {
        private const val TABLE = "notification_conversation_history"
        private const val MAX_ROWS = 5_000
        private const val MAX_BATCH = 30
        private const val MAX_FIELD = 500
        private const val MAX_BODY = 4_000
        private const val RETENTION_MS = 90L * 24 * 60 * 60 * 1_000

        /** DDL idempotente para instalaciones existentes sin recrear la base. */
        fun ensureSchema(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE IF NOT EXISTS $TABLE (id INTEGER PRIMARY KEY AUTOINCREMENT, history_id TEXT NOT NULL, event_id TEXT NOT NULL UNIQUE, package_name TEXT NOT NULL, conversation_id TEXT NOT NULL, display_name TEXT NOT NULL, notification_key TEXT NOT NULL, sender TEXT NOT NULL, body TEXT NOT NULL, at_ms INTEGER NOT NULL, is_group INTEGER NOT NULL, is_self INTEGER NOT NULL)")
            db.execSQL("CREATE INDEX IF NOT EXISTS notification_history_by_time ON $TABLE(history_id, at_ms DESC)")
            // Purga entradas espurias de estado, comprobaciones del sistema o fallback "0"
            db.execSQL("DELETE FROM $TABLE WHERE conversation_id = '0' OR display_name = '0' OR conversation_id LIKE '%status@broadcast%' OR conversation_id LIKE '%@newsletter%' OR body LIKE '%le gustó tu estado%' OR body LIKE '%comprobando si hay%' OR body LIKE '%buscando mensajes nuevos%'")
            db.execSQL("UPDATE $TABLE SET display_name = (SELECT d.display_name FROM $TABLE d WHERE d.history_id = $TABLE.history_id AND d.display_name NOT IN ('Tú', 'Tu', '0', '') ORDER BY d.at_ms DESC LIMIT 1) WHERE display_name IN ('Tú', 'Tu') AND EXISTS (SELECT 1 FROM $TABLE d WHERE d.history_id = $TABLE.history_id AND d.display_name NOT IN ('Tú', 'Tu', '0', ''))")
        }
    }
}

/** Mensaje capturado de una notificación real de una app de mensajería. */
internal data class NotificationHistoryEvent(
    val packageName: String,
    val conversationId: String,
    val displayName: String,
    val notificationKey: String,
    val sender: String,
    val body: String,
    val atMs: Long,
    val isGroup: Boolean,
    val isSelf: Boolean,
)
