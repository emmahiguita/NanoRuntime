package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase

/**
 * QUÉ HACE:
 * Repositorio SQLite para 'canonical_messages' y 'conversation_coverage'.
 * Es la fuente única de verdad para el almacenamiento de mensajes unificados en el dispositivo.
 *
 * CÓMO FUNCIONA:
 * - Upsert idempotente con validación de identificadores y límites de tamaño.
 * - Deduplica automáticamente por (provider, provider_message_id) y (conversation_id, fingerprint).
 * - Provee métodos de listado reciente y paginación determinista (beforeMs, beforeId).
 * - Mantiene el registro de cobertura temporal (cobertura histórica y detección de huecos).
 *
 * POR QUÉ:
 * Implementa Clean Architecture asegurando que ningún canal (Web, Android Notifications, Meta Cloud)
 * dependa de tablas ad-hoc aisladas, unificando la memoria del asistente bajo un contrato robusto y SOLID.
 */
internal class CanonicalMessageSqlStore(
    private val readable: () -> SQLiteDatabase,
    private val writable: () -> SQLiteDatabase,
) {
    fun upsert(row: Map<String, Any?>): Boolean {
        val id = row["id"] as? String ?: return false
        val conversationId = row["conversationId"] as? String ?: return false
        val provider = row["provider"] as? String ?: return false
        val body = row["body"] as? String ?: ""
        if (!validId(id) || !validId(conversationId) || provider !in PROVIDERS || body.length > MAX_BODY) return false
        val values = ContentValues().apply {
            put("canonical_id", id); put("conversation_id", conversationId); put("provider", provider)
            val providerId = (row["providerMessageId"] as? String).orEmpty().take(MAX_ID)
            if (providerId.isEmpty()) putNull("provider_message_id") else put("provider_message_id", providerId)
            put("direction", (row["direction"] as? String).orEmpty())
            put("sender", (row["sender"] as? String).orEmpty().take(MAX_SENDER))
            put("body", body)
            put("media_type", (row["mediaType"] as? String).orEmpty().take(40))
            put("media_uri", (row["mediaUri"] as? String).orEmpty().take(MAX_URI))
            put("occurred_at_ms", (row["occurredAtMs"] as? Number)?.toLong() ?: 0L)
            put("observed_at_ms", (row["observedAtMs"] as? Number)?.toLong() ?: System.currentTimeMillis())
            put("delivery_state", (row["deliveryState"] as? String).orEmpty().take(40))
            put("fingerprint", (row["fingerprint"] as? String).orEmpty().take(64))
            put("raw_metadata", (row["rawMetadata"] as? String).orEmpty().take(MAX_METADATA))
        }
        val db = writable()
        // Solo actualiza el mismo evento de la misma fuente y conversación.
        // Una notificación parecida no se transforma en un mensaje MCP/Cloud.
        if (CanonicalObservationIdentity.promoteNotificationIfPresent(db, values)) return true
        // 2. Una recaptura del mismo ID real en Web corrige datos heredados sin fusionar por texto/hora.
        if (CanonicalWebVerification.refresh(db, values)) return true
        // 3. Impide que una notificación posterior duplique un mensaje ya observado.
        if (values.getAsString("provider_message_id").isNullOrBlank() && CanonicalObservationIdentity.exists(
                db, conversationId, provider, values.getAsString("direction"),
                values.getAsString("sender"), body, values.getAsLong("occurred_at_ms"),
            )) return false
        return db.insertWithOnConflict(MESSAGES, null, values, SQLiteDatabase.CONFLICT_IGNORE) != -1L
    }

    fun list(conversationId: String, limit: Int): List<Map<String, Any>> = list(listOf(conversationId), limit)

    fun list(conversationIds: List<String>, limit: Int): List<Map<String, Any>> {
        val validIds = conversationIds.filter { validId(it) }
        if (validIds.isEmpty()) return emptyList()
        val placeholders = validIds.joinToString(",") { "?" }
        val rows = mutableListOf<Map<String, Any>>()
        readable().query(
            MESSAGES, COLUMNS, "conversation_id IN ($placeholders)", validIds.toTypedArray(), null, null,
            "occurred_at_ms DESC, id DESC", limit.coerceIn(1, 1000).toString(),
        ).use { c ->
            while (c.moveToNext()) rows += COLUMNS.indices.associate { COLUMNS[it] to if (c.isNull(it)) "" else c.getString(it) }
        }
        return rows.asReversed()
    }

    fun page(
        conversationIds: List<String>,
        provider: String?,
        beforeMs: Long?,
        beforeId: String?,
        limit: Int = 200,
    ): Map<String, Any> {
        val validIds = conversationIds.filter { validId(it) }
        if (validIds.isEmpty()) return mapOf("rows" to emptyList<Map<String, Any>>(), "hasMore" to false)
        val args = mutableListOf<String>().apply { addAll(validIds) }
        var where = "conversation_id IN (${validIds.joinToString(",") { "?" }})"
        // La página visual excluye previews sin dirección/fecha comprobada.
        where += " AND direction IN ('inbound','outbound') AND occurred_at_ms > 0"
        if (provider != null && provider in PROVIDERS) {
            where += " AND provider = ?"
            args.add(provider)
        }
        // Datos Web anteriores permanecen guardados, pero no se muestran como hechos
        // hasta recapturar su identidad, fecha y dirección contra el DOM actual.
        if (provider == "whatsapp_web") {
            where += CanonicalWebVerification.PAGE_PREDICATE
        }
        if (beforeMs != null && beforeMs > 0 && beforeId != null && beforeId.isNotBlank()) {
            // El cursor usa el mismo ID efectivo y orden que devuelve la página.
            where += " AND (occurred_at_ms < ? OR (occurred_at_ms = ? AND $EVENT_ID < ?))"
            args.add(beforeMs.toString()); args.add(beforeMs.toString()); args.add(beforeId)
        }
        val fetchLimit = (limit.coerceIn(1, 500) + 1).toString()
        val rows = mutableListOf<Map<String, Any>>()
        readable().query(
            MESSAGES, arrayOf("provider_message_id", "canonical_id", "body", "sender", "occurred_at_ms", "direction"),
            where, args.toTypedArray(), null, null, "occurred_at_ms DESC, $EVENT_ID DESC", fetchLimit,
        ).use { c ->
            while (c.moveToNext()) {
                val pId = c.getString(0) ?: ""
                val cId = c.getString(1) ?: ""
                rows.add(mapOf(
                    "eventId" to if (pId.isNotBlank()) pId else cId, "body" to (c.getString(2) ?: ""),
                    "sender" to (c.getString(3) ?: ""), "atMs" to c.getLong(4), "isSelf" to (c.getString(5) == "outbound"),
                ))
            }
        }
        return mapOf("rows" to rows.take(limit), "hasMore" to (rows.size > limit))
    }

    fun recordCoverage(conversationId: String, provider: String, fromMs: Long, toMs: Long, gapBefore: Boolean): Boolean {
        if (!validId(conversationId) || provider !in PROVIDERS || fromMs < 0 || toMs < fromMs) return false
        val values = ContentValues().apply {
            put("conversation_id", conversationId); put("provider", provider)
            put("from_ms", fromMs); put("to_ms", toMs); put("gap_before", if (gapBefore) 1 else 0)
            put("updated_at_ms", System.currentTimeMillis())
        }
        return writable().insertWithOnConflict(COVERAGE, null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L
    }

    fun coverage(conversationId: String): List<Map<String, Any>> {
        if (!validId(conversationId)) return emptyList()
        val rows = mutableListOf<Map<String, Any>>()
        readable().query(
            COVERAGE, arrayOf("provider", "from_ms", "to_ms", "gap_before", "updated_at_ms"),
            "conversation_id = ?", arrayOf(conversationId), null, null, "from_ms ASC"
        ).use { c ->
            while (c.moveToNext()) rows += mapOf(
                "provider" to c.getString(0), "fromMs" to c.getLong(1),
                "toMs" to c.getLong(2), "gapBefore" to (c.getInt(3) == 1), "updatedAtMs" to c.getLong(4)
            )
        }
        return rows
    }

    fun migrateFromWebHistoryDb(context: Context, writableDb: SQLiteDatabase) {
        CanonicalMessageMigration.migrateFromWebHistoryDb(context, writableDb)
    }

    private fun validId(value: String) = value.isNotBlank() && value.length <= MAX_ID

    companion object {
        private const val MESSAGES = "canonical_messages"
        private const val COVERAGE = "conversation_coverage"
        private const val EVENT_ID = "COALESCE(NULLIF(provider_message_id, ''), canonical_id)"
        private const val MAX_ID = 500
        private const val MAX_BODY = 16_000
        private const val MAX_SENDER = 300
        private const val MAX_URI = 2_000
        private const val MAX_METADATA = 4_000
        private val PROVIDERS = setOf("whatsapp_web", "android_notification", "meta_cloud", "whatsapp_mcp")
        private val COLUMNS = arrayOf(
            "canonical_id", "conversation_id", "provider", "provider_message_id", "direction",
            "sender", "body", "media_type", "media_uri", "occurred_at_ms", "observed_at_ms",
            "delivery_state", "fingerprint", "raw_metadata"
        )

        fun ensureSchema(db: SQLiteDatabase) {
            db.execSQL(
                "CREATE TABLE IF NOT EXISTS $MESSAGES (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, canonical_id TEXT NOT NULL UNIQUE, " +
                "conversation_id TEXT NOT NULL, provider TEXT NOT NULL, provider_message_id TEXT, " +
                "direction TEXT NOT NULL, sender TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '', " +
                "media_type TEXT NOT NULL DEFAULT '', media_uri TEXT NOT NULL DEFAULT '', " +
                "occurred_at_ms INTEGER NOT NULL, observed_at_ms INTEGER NOT NULL, " +
                "delivery_state TEXT NOT NULL, fingerprint TEXT NOT NULL, " +
                "raw_metadata TEXT NOT NULL DEFAULT '', " +
                "UNIQUE(provider, conversation_id, provider_message_id))"
            )
            CanonicalScopedIdentitySchema.ensure(db)
            // Un ID real distinto prevalece incluso con texto/fecha idénticos.
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS canonical_messages_fallback_identity ON " +
                "$MESSAGES(provider, conversation_id, fingerprint) WHERE provider_message_id IS NULL")
            db.execSQL("CREATE INDEX IF NOT EXISTS canonical_messages_conversation_time ON $MESSAGES(conversation_id, occurred_at_ms)")
            db.execSQL(
                "CREATE TABLE IF NOT EXISTS $COVERAGE (" +
                "conversation_id TEXT NOT NULL, provider TEXT NOT NULL, " +
                "from_ms INTEGER NOT NULL, to_ms INTEGER NOT NULL, " +
                "gap_before INTEGER NOT NULL DEFAULT 1, updated_at_ms INTEGER NOT NULL, " +
                "PRIMARY KEY(conversation_id, provider, from_ms))"
            )
            CanonicalMcpDeltaSync.ensureSchema(db)
            CanonicalMessageMigration.migrateFromConversationMessages(db)
        }
    }
}
