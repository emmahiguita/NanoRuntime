package dev.nanoai.mobile.media

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Índice de metadatos; jamás copia originales ni establece relaciones con chats. */
internal class WhatsAppMediaCatalogDb(context: Context) :
    SQLiteOpenHelper(context.applicationContext, "nano_whatsapp_media_index.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE media(uri TEXT PRIMARY KEY,kind TEXT NOT NULL,name TEXT NOT NULL,mime TEXT NOT NULL,size INTEGER NOT NULL,modified INTEGER NOT NULL,source TEXT NOT NULL,generation INTEGER NOT NULL)")
        db.execSQL("CREATE INDEX media_page ON media(modified DESC,uri DESC)")
        db.execSQL("CREATE TABLE checkpoint(kind TEXT PRIMARY KEY,version TEXT NOT NULL,generation INTEGER NOT NULL,item_id INTEGER NOT NULL)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    /** Cambio de versión del proveedor invalida solo nuestro índice, nunca WhatsApp. */
    fun checkpoint(kind: String, version: String): Pair<Long, Long> {
        readableDatabase.rawQuery("SELECT version,generation,item_id FROM checkpoint WHERE kind=?", arrayOf(kind)).use {
            if (it.moveToFirst() && it.getString(0) == version) return it.getLong(1) to it.getLong(2)
        }
        writableDatabase.delete("media", "kind=?", arrayOf(kind))
        writableDatabase.delete("checkpoint", "kind=?", arrayOf(kind))
        return 0L to 0L
    }

    /** Filas y cursor se confirman juntos: un cierre no salta un lote pendiente. */
    fun save(kind: String, version: String, rows: List<ContentValues>, generation: Long, id: Long) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            rows.forEach { db.insertWithOnConflict("media", null, it, SQLiteDatabase.CONFLICT_REPLACE) }
            db.insertWithOnConflict("checkpoint", null, ContentValues().apply {
                put("kind", kind); put("version", version); put("generation", generation); put("item_id", id)
            }, SQLiteDatabase.CONFLICT_REPLACE)
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }

    /** Página local independiente de MediaStore: abrir una biblioteca no recorre carpetas. */
    fun page(kinds: Set<String>, beforeMs: Long?, beforeUri: String?): Map<String, Any> {
        if (kinds.isEmpty()) return mapOf("rows" to emptyList<Any>(), "hasMore" to false)
        var where = "kind IN (${kinds.joinToString(",") { "?" }})"
        val args = kinds.toMutableList()
        if (beforeMs != null && beforeUri != null) {
            where += " AND (modified < ? OR (modified = ? AND uri < ?))"
            args.addAll(listOf("$beforeMs", "$beforeMs", beforeUri))
        }
        val rows = readableDatabase.query("media", null, where, args.toTypedArray(), null, null,
            "modified DESC,uri DESC", "61").use { c -> buildList {
            while (c.moveToNext()) add(c.columnNames.associateWith { column ->
                c.getString(c.getColumnIndexOrThrow(column)).orEmpty()
            })
        } }
        return mapOf("rows" to rows.take(60), "hasMore" to (rows.size > 60))
    }

    /** Un método de apertura solo acepta URIs ya incluidas en este índice. */
    fun find(uri: String): Map<String, String>? = readableDatabase.query("media", null,
        "uri=?", arrayOf(uri), null, null, null, "1").use { c ->
        if (!c.moveToFirst()) null else c.columnNames.associateWith { c.getString(c.getColumnIndexOrThrow(it)).orEmpty() }
    }
}
