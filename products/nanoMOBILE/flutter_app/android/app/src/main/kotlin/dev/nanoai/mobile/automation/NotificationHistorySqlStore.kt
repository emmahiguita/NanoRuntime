package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import java.security.MessageDigest

/**
 * Guarda eventos de conversación entregados por Android en SQLite local.
 * Conserva el historial recibido sin purgas automáticas por edad o cantidad;
 * cerrar una notificación no borra los mensajes guardados.
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
                val verification = SocialHistoryAdmission.verification(event.packageName, event.verifiedMessage)
                val row = ContentValues().apply {
                    put("history_id", historyId)
                    put("event_id", eventId)
                    put("package_name", event.packageName.take(MAX_FIELD))
                    put("conversation_id", event.conversationId.take(MAX_FIELD))
                    put("display_name", event.displayName.take(MAX_FIELD))
                    put("notification_key", event.notificationKey.take(MAX_FIELD))
                    put("sender", event.sender.take(MAX_FIELD))
                    put("body", event.body)
                    put("at_ms", event.atMs)
                    put("is_group", if (event.isGroup) 1 else 0)
                    put("is_self", if (event.isSelf) 1 else 0)
                    put("message_verified", verification)
                    put("identity_json", event.identityJson)
                }
                db.insertWithOnConflict(TABLE, null, row, SQLiteDatabase.CONFLICT_IGNORE)
                // Una recaptura real verifica el registro anterior sin duplicar ni cambiar su cuerpo.
                if (event.verifiedMessage) db.update(
                    TABLE, ContentValues().apply {
                        put("message_verified", verification)
                        if (event.identityJson.isNotBlank()) put("identity_json", event.identityJson)
                    }, "event_id = ?", arrayOf(eventId),
                )
            }
            // La retención es historial, no una ventana del modelo. No se purga
            // por límite de lectura ni porque los mensajes hayan envejecido.
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun listConversations(limit: Int): List<Map<String, Any?>> = readable().rawQuery(
        """SELECT h.history_id, h.package_name, h.conversation_id,
            COALESCE((SELECT d.display_name FROM $TABLE d WHERE d.history_id = h.history_id AND ${SocialHistoryAdmission.predicate("d")} AND d.display_name NOT IN ('Tú', 'Tu', '0', '') ORDER BY d.at_ms DESC LIMIT 1), h.display_name),
            h.notification_key, h.sender, h.body, h.at_ms, h.is_group,
            (SELECT COUNT(*) FROM $TABLE c WHERE c.history_id = h.history_id AND ${SocialHistoryAdmission.predicate("c")}),
            h.identity_json, h.message_verified
            FROM $TABLE h WHERE ${SocialHistoryAdmission.predicate("h")} AND h.id = (SELECT x.id FROM $TABLE x
            WHERE x.history_id = h.history_id AND ${SocialHistoryAdmission.predicate("x")} ORDER BY x.at_ms DESC, x.id DESC LIMIT 1)
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
                "identityJson" to cursor.getString(10), "messageVerified" to (cursor.getInt(11) > 0),
            ))
        }
    }

    fun listMessages(historyId: String, limit: Int): List<Map<String, Any?>> {
        if (historyId.isBlank() || historyId.length > 64) return emptyList()
        val rows = readable().query(
            TABLE, arrayOf("event_id", "sender", "body", "at_ms", "is_self"),
            "history_id = ? AND ${SocialHistoryAdmission.predicate()}", arrayOf(historyId), null, null, "at_ms DESC, id DESC",
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

    /** Cursor estable por fecha + ID: permite recorrer TODO lo guardado sin OFFSET ni purgas. */
    fun pageMessages(historyId: String, limit: Int, beforeMs: Long?, beforeId: String?): Map<String, Any> {
        require(Regex("^[a-f0-9]{64}$").matches(historyId)) { "historyId inválido" }
        require((beforeMs == null) == (beforeId == null)) { "Cursor incompleto" }
        if (beforeId != null) require(Regex("^[a-f0-9]{64}$").matches(beforeId)) { "Cursor inválido" }
        val count = limit.coerceIn(1, 200)
        val older = if (beforeMs == null) "" else " AND (at_ms < ? OR (at_ms = ? AND event_id < ?))"
        val args = if (beforeMs == null) arrayOf(historyId) else
            arrayOf(historyId, beforeMs.toString(), beforeMs.toString(), beforeId.orEmpty())
        val rows = readable().query(TABLE,
            arrayOf("event_id", "sender", "body", "at_ms", "is_self"),
            "history_id = ? AND ${SocialHistoryAdmission.predicate()}$older", args,
            null, null, "at_ms DESC, event_id DESC", (count + 1).toString(),
        ).use { cursor -> buildList {
            while (cursor.moveToNext()) add(mapOf(
                "eventId" to cursor.getString(0), "sender" to cursor.getString(1),
                "body" to cursor.getString(2), "atMs" to cursor.getLong(3),
                "isSelf" to (cursor.getInt(4) != 0),
            ))
        } }
        return mapOf("rows" to rows.take(count), "hasMore" to (rows.size > count))
    }

    companion object {
        private const val TABLE = "notification_conversation_history"
        private const val MAX_BATCH = 30
        private const val MAX_FIELD = 500

        /** DDL idempotente para instalaciones existentes sin recrear la base. */
        fun ensureSchema(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE IF NOT EXISTS $TABLE (id INTEGER PRIMARY KEY AUTOINCREMENT, history_id TEXT NOT NULL, event_id TEXT NOT NULL UNIQUE, package_name TEXT NOT NULL, conversation_id TEXT NOT NULL, display_name TEXT NOT NULL, notification_key TEXT NOT NULL, sender TEXT NOT NULL, body TEXT NOT NULL, at_ms INTEGER NOT NULL, is_group INTEGER NOT NULL, is_self INTEGER NOT NULL)")
            db.execSQL("CREATE INDEX IF NOT EXISTS notification_history_by_time ON $TABLE(history_id, at_ms DESC)")
            db.execSQL("CREATE INDEX IF NOT EXISTS notification_history_by_cursor ON $TABLE(history_id, at_ms DESC, event_id DESC)")
            SocialHistoryAdmission.ensureSchema(db, TABLE)
            // Migración aditiva: no borra ni inventa identidad para filas antiguas.
            val hasIdentity = db.rawQuery("PRAGMA table_info($TABLE)", null).use { cursor ->
                val name = cursor.getColumnIndexOrThrow("name")
                var found = false
                while (cursor.moveToNext()) if (cursor.getString(name) == "identity_json") found = true
                found
            }
            if (!hasIdentity) db.execSQL("ALTER TABLE $TABLE ADD COLUMN identity_json TEXT NOT NULL DEFAULT ''")
            // Los avisos se filtran al leer; no borres texto humano que contenga
            // una frase parecida a un aviso durante una apertura de la base.
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
    // Solo el extractor que ha pasado la admisión nativa puede verificar un evento nuevo.
    val verifiedMessage: Boolean = false,
    val identityJson: String = "",
)
