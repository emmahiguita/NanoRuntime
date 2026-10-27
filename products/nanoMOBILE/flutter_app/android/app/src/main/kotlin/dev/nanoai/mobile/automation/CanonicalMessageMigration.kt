package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase

/**
 * QUÉ HACE:
 * Gestiona la migración de datos históricos de mensajería desde fuentes previas
 * ('conversation_messages' y base 'nano_web_history.db') hacia la tabla unificada 'canonical_messages'.
 *
 * CÓMO FUNCIONA:
 * - Realiza inserciones con cláusula CONFLICT_IGNORE para asegurar idempotencia.
 * - Mapea eventos antiguos a la estructura canónica con huella digital, proveedor y marca de tiempo.
 * - Se ejecuta en segundo plano o durante la creación/actualización del esquema.
 *
 * POR QUÉ:
 * Aplica el principio de Responsabilidad Única (SRP) de Clean Architecture y SOLID,
 * aislando la lógica de transición de datos heredados fuera del almacén canónico en caliente
 * y asegurando archivos modulares con menos de 200 líneas de código.
 */
internal object CanonicalMessageMigration {

    fun migrateFromConversationMessages(db: SQLiteDatabase) {
        try {
            db.execSQL("""
                INSERT OR IGNORE INTO canonical_messages (
                    canonical_id, conversation_id, provider, provider_message_id,
                    direction, sender, body, occurred_at_ms, observed_at_ms,
                    delivery_state, fingerprint, raw_metadata
                )
                SELECT
                    m.scope_id || ':' || m.event_id AS canonical_id,
                    COALESCE(
                        (SELECT a.conversation_id FROM conversation_scopes s JOIN conversation_assignments a ON s.address_key = a.address_key WHERE s.scope_id = m.scope_id LIMIT 1),
                        m.scope_id
                    ) AS conversation_id,
                    'android_notification' AS provider,
                    m.event_id AS provider_message_id,
                    m.direction,
                    m.sender,
                    m.body,
                    m.at_ms AS occurred_at_ms,
                    m.at_ms AS observed_at_ms,
                    m.delivery_state,
                    m.event_id AS fingerprint,
                    '{"ruleId":"' || m.rule_id || '","source":"migrated_conversation_messages"}' AS raw_metadata
                FROM conversation_messages m
            """.trimIndent())
        } catch (_: Exception) {}
    }

    fun migrateFromWebHistoryDb(context: Context, writableDb: SQLiteDatabase) {
        val dbFile = context.getDatabasePath("nano_web_history.db")
        if (!dbFile.exists()) return
        try {
            val webDb = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
            webDb.use { wDb ->
                wDb.query(
                    "web_messages",
                    arrayOf("account", "chat", "alias", "event_id", "body", "sender", "at_ms", "is_self"),
                    null, null, null, null, null
                ).use { cursor ->
                    writableDb.beginTransaction()
                    try {
                        while (cursor.moveToNext()) {
                            val account = cursor.getString(0) ?: ""
                            val chat = cursor.getString(1) ?: ""
                            val alias = cursor.getString(2) ?: ""
                            val eventId = cursor.getString(3) ?: ""
                            val body = cursor.getString(4) ?: ""
                            val sender = cursor.getString(5) ?: ""
                            val atMs = cursor.getLong(6)
                            val isSelf = (cursor.getInt(7) == 1)
                            val canonicalId = "waweb:$account/$chat:$eventId"
                            val values = ContentValues().apply {
                                put("canonical_id", canonicalId)
                                put("conversation_id", alias.ifBlank { chat })
                                put("provider", "whatsapp_web")
                                put("provider_message_id", eventId)
                                put("direction", if (isSelf) "outbound" else "inbound")
                                put("sender", sender)
                                put("body", body)
                                put("occurred_at_ms", atMs)
                                put("observed_at_ms", System.currentTimeMillis())
                                put("delivery_state", "observed")
                                put("fingerprint", eventId)
                                put("raw_metadata", "{\"account\":\"$account\",\"chat\":\"$chat\",\"alias\":\"$alias\",\"source\":\"migrated_web_history\"}")
                            }
                            writableDb.insertWithOnConflict("canonical_messages", null, values, SQLiteDatabase.CONFLICT_IGNORE)
                        }
                        writableDb.setTransactionSuccessful()
                    } finally {
                        writableDb.endTransaction()
                    }
                }
            }
        } catch (_: Exception) {}
    }
}
