package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Archivo local independiente: páginas indexadas, sin recorte por edad o cantidad. */
internal class WebHistorySqlStore(context: Context) :
    SQLiteOpenHelper(context.applicationContext, "nano_web_history.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE web_messages(account TEXT NOT NULL, chat TEXT NOT NULL, alias TEXT NOT NULL, event_id TEXT NOT NULL, body TEXT NOT NULL, sender TEXT NOT NULL, at_ms INTEGER NOT NULL, is_self INTEGER NOT NULL, PRIMARY KEY(account,chat,event_id))")
        db.execSQL("CREATE INDEX web_messages_page ON web_messages(account,alias,at_ms DESC,event_id DESC)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    /** Confirma el lote completo; nunca deduplica por contenido ni inventa timestamp. */
    fun append(account: String, chat: String, alias: String, rows: List<Map<String, Any?>>): Int {
        require(account.length in 1..100 && chat.length in 1..300 && alias.length in 1..300)
        require(rows.size <= 200)
        val db = writableDatabase
        // Un alias por nombre no autoriza mezclar hilos de distintos JID.
        db.rawQuery("SELECT chat FROM web_messages WHERE account=? AND alias=? LIMIT 1",
            arrayOf(account, alias)).use { cursor ->
            if (cursor.moveToFirst()) require(cursor.getString(0) == chat)
        }
        db.beginTransaction()
        try {
            // Migra aliases antiguos solo tras observar la misma cuenta/JID.
            // Conserva todas las páginas previas, no únicamente el lote visible.
            db.update("web_messages", ContentValues().apply { put("alias", alias) },
                "account=? AND chat=? AND alias<>?", arrayOf(account, chat, alias))
            var written = 0
            rows.forEach { row ->
                val id = row["eventId"] as? String ?: return@forEach
                val body = row["body"] as? String ?: return@forEach
                val time = (row["atMs"] as? Number)?.toLong() ?: return@forEach
                require(id.length in 1..400 && body.length in 1..100_000 && time > 0)
                val values = ContentValues().apply {
                    put("account", account); put("chat", chat); put("alias", alias)
                    put("event_id", id); put("body", body)
                    put("sender", (row["sender"] as? String).orEmpty().take(500))
                    put("at_ms", time); put("is_self", if (row["isSelf"] == true) 1 else 0)
                }
                db.insertWithOnConflict("web_messages", null, values, SQLiteDatabase.CONFLICT_REPLACE)
                written++
            }
            db.setTransactionSuccessful()
            return written
        } finally {
            db.endTransaction()
        }
    }

    /** Cursor compuesto: mensajes con la misma hora no se saltan entre páginas. */
    fun page(account: String, alias: String, beforeMs: Long?, beforeId: String?): Map<String, Any> {
        val args = mutableListOf(account, alias)
        var where = "account=? AND alias=?"
        if (beforeMs != null && beforeId != null) {
            where += " AND (at_ms < ? OR (at_ms = ? AND event_id < ?))"
            args.addAll(listOf("$beforeMs", "$beforeMs", beforeId))
        }
        val rows = readableDatabase.query(
            "web_messages", arrayOf("event_id", "body", "sender", "at_ms", "is_self"),
            where, args.toTypedArray(), null, null, "at_ms DESC,event_id DESC", "201",
        ).use { cursor -> buildList {
            while (cursor.moveToNext()) add(mapOf(
                "eventId" to cursor.getString(0), "body" to cursor.getString(1),
                "sender" to cursor.getString(2), "atMs" to cursor.getLong(3),
                "isSelf" to (cursor.getInt(4) != 0),
            ))
        } }
        return mapOf("rows" to rows.take(200), "hasMore" to (rows.size > 200))
    }
}
