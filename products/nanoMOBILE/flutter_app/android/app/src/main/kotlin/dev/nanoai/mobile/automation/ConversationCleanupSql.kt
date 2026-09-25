package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase

/**
 * Borra la memoria local de un scope conversacional de forma atómica.
 *
 * El chat real de WhatsApp no se modifica. Esta operación elimina las filas
 * normalizadas de Nano y reemplaza su snapshot `memory` en la misma transacción.
 */
internal object ConversationCleanupSql {
    private const val MAX_SCOPE_ID = 3_000
    private const val MAX_MEMORY_JSON = 2_000_000

    fun clear(
        db: SQLiteDatabase,
        scopeId: String,
        memoryJson: String,
        sectionTable: String,
        sectionKeyColumn: String,
        sectionDataColumn: String,
    ): Boolean {
        if (scopeId.isBlank() || scopeId.length > MAX_SCOPE_ID) return false
        if (memoryJson.length > MAX_MEMORY_JSON) return false

        db.beginTransaction()
        return try {
            db.delete("conversation_messages", "scope_id = ?", arrayOf(scopeId))
            db.delete("conversation_dialogue_state", "scope_id = ?", arrayOf(scopeId))
            val section = ContentValues().apply {
                put(sectionKeyColumn, "memory")
                put(sectionDataColumn, memoryJson)
            }
            val rowId = db.insertWithOnConflict(
                sectionTable,
                null,
                section,
                SQLiteDatabase.CONFLICT_REPLACE,
            )
            if (rowId == -1L) return false
            db.setTransactionSuccessful()
            true
        } finally {
            db.endTransaction()
        }
    }
}
