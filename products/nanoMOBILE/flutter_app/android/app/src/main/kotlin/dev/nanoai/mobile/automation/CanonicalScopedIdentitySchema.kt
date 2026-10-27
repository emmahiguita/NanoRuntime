package dev.nanoai.mobile.automation

import android.database.sqlite.SQLiteDatabase

/** Cambia solo la unicidad externa. La conversación conserva fuente/cuenta;
 * se copian todas las columnas e IDs dentro de una transacción verificada. */
internal object CanonicalScopedIdentitySchema {
    fun ensure(db: SQLiteDatabase) {
        val sql = db.rawQuery("SELECT sql FROM sqlite_master WHERE type='table' AND name='canonical_messages'", null)
            .use { if (it.moveToFirst()) it.getString(0) else null } ?: return
        val oldKey = Regex("UNIQUE\\s*\\(\\s*provider\\s*,\\s*provider_message_id\\s*\\)", RegexOption.IGNORE_CASE)
        val oldFingerprint = Regex(",\\s*UNIQUE\\s*\\(\\s*conversation_id\\s*,\\s*fingerprint\\s*\\)", RegexOption.IGNORE_CASE)
        if (!oldKey.containsMatchIn(sql) && !oldFingerprint.containsMatchIn(sql)) return
        val ownsTransaction = !db.inTransaction()
        if (ownsTransaction) db.beginTransaction()
        try {
            val newSql = sql.replace(oldKey, "UNIQUE(provider, conversation_id, provider_message_id)")
                .replace(oldFingerprint, "")
                .replaceFirst(Regex("(?i)CREATE TABLE(?: IF NOT EXISTS)?\\s+[\"`]?canonical_messages[\"`]?") ,
                    "CREATE TABLE canonical_messages_scoped")
            check(newSql.contains("CREATE TABLE canonical_messages_scoped"))
            db.execSQL(newSql)
            db.execSQL("INSERT INTO canonical_messages_scoped SELECT * FROM canonical_messages")
            fun count(table: String) = db.rawQuery("SELECT COUNT(*) FROM $table", null)
                .use { it.moveToFirst(); it.getLong(0) }
            check(count("canonical_messages") == count("canonical_messages_scoped")) { "Canonical migration lost rows" }
            db.execSQL("DROP TABLE canonical_messages")
            db.execSQL("ALTER TABLE canonical_messages_scoped RENAME TO canonical_messages")
            if (ownsTransaction) db.setTransactionSuccessful()
        } finally {
            if (ownsTransaction) db.endTransaction()
        }
    }
}
