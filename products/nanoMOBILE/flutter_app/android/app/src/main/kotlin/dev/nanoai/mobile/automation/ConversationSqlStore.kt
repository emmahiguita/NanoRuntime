package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase

/**
 * Repositorio SQL normalizado para conversaciones de los agentes.
 *
 * Mantiene cuatro responsabilidades de datos separadas: asignación activa,
 * scopes por agente, eventos/mensajes y estado de diálogo. Una transferencia
 * activa otro scope y registra solo un resumen mínimo; nunca fusiona memorias.
 */
internal class ConversationSqlStore(
    private val readable: () -> SQLiteDatabase,
    private val writable: () -> SQLiteDatabase,
) {
    fun listAssignments(): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        readable().query(
            ASSIGNMENTS,
            arrayOf(
                "address_key", "owner_id", "agent_id", "channel",
                "app_package", "channel_account_id", "conversation_id",
                "assigned_at_ms", "route_reason",
            ),
            null, null, null, null, "updated_at_ms DESC",
        ).use { cursor ->
            while (cursor.moveToNext()) {
                rows.add(
                    mapOf(
                        "addressKey" to cursor.getString(0),
                        "ownerId" to cursor.getString(1),
                        "agentId" to cursor.getString(2),
                        "channel" to cursor.getString(3),
                        "appPackage" to cursor.getString(4),
                        "channelAccountId" to cursor.getString(5),
                        "conversationId" to cursor.getString(6),
                        "assignedAtMs" to cursor.getLong(7),
                        "reason" to cursor.getString(8),
                    ),
                )
            }
        }
        return rows
    }

    fun assign(
        addressKey: String,
        scopeId: String,
        ownerId: String,
        agentId: String,
        previousAgentId: String?,
        channel: String,
        appPackage: String,
        channelAccountId: String,
        conversationId: String,
        assignedAtMs: Long,
        reason: String,
        minimalContext: String,
    ): Boolean {
        if (!validId(addressKey) || !validId(scopeId) || !validId(conversationId)) return false
        if (ownerId.isBlank() || channel.isBlank() || appPackage.isBlank() || channelAccountId.isBlank()) return false
        if (agentId !in AGENTS || previousAgentId != null && previousAgentId !in AGENTS) return false
        if (reason.isBlank() || reason.length > MAX_REASON || minimalContext.length > MAX_CONTEXT) return false
        val db = writable()
        db.beginTransaction()
        try {
            val now = if (assignedAtMs > 0) assignedAtMs else System.currentTimeMillis()
            val assignment = ContentValues().apply {
                put("address_key", addressKey)
                put("owner_id", ownerId.take(MAX_ID))
                put("agent_id", agentId)
                put("channel", channel.take(MAX_ID))
                put("app_package", appPackage.take(MAX_ID))
                put("channel_account_id", channelAccountId.take(MAX_ID))
                put("conversation_id", conversationId)
                put("assigned_at_ms", now)
                put("updated_at_ms", now)
                put("route_reason", reason)
            }
            db.insertWithOnConflict(ASSIGNMENTS, null, assignment, SQLiteDatabase.CONFLICT_REPLACE)
            val scope = ContentValues().apply {
                put("scope_id", scopeId)
                put("address_key", addressKey)
                put("agent_id", agentId)
                put("created_at_ms", now)
                put("updated_at_ms", now)
            }
            db.insertWithOnConflict(SCOPES, null, scope, SQLiteDatabase.CONFLICT_IGNORE)
            db.execSQL("UPDATE $SCOPES SET active = CASE WHEN scope_id = ? THEN 1 ELSE 0 END, updated_at_ms = ? WHERE address_key = ?", arrayOf(scopeId, now, addressKey))
            if (previousAgentId != null && previousAgentId != agentId) {
                val transfer = ContentValues().apply {
                    put("address_key", addressKey)
                    put("from_agent_id", previousAgentId)
                    put("to_agent_id", agentId)
                    put("reason", reason)
                    put("minimal_context", minimalContext)
                    put("at_ms", now)
                }
                db.insertOrThrow(TRANSFERS, null, transfer)
            }
            db.setTransactionSuccessful()
            return true
        } finally {
            db.endTransaction()
        }
    }

    fun appendMessage(
        scopeId: String,
        eventId: String,
        direction: String,
        deliveryState: String,
        sender: String,
        body: String,
        atMs: Long,
        ruleId: String,
    ): Boolean {
        if (!validId(scopeId) || !validId(eventId)) return false
        if (direction !in DIRECTIONS || deliveryState !in DELIVERY_STATES) return false
        if (body.isBlank() || body.length > MAX_BODY || sender.length > MAX_SENDER || ruleId.length > MAX_ID) return false
        val values = ContentValues().apply {
            put("scope_id", scopeId)
            put("event_id", eventId)
            put("direction", direction)
            put("delivery_state", deliveryState)
            put("sender", sender)
            put("body", body)
            put("at_ms", atMs)
            put("rule_id", ruleId)
        }
        return writable().insertWithOnConflict(
            MESSAGES, null, values, SQLiteDatabase.CONFLICT_REPLACE,
        ) != -1L
    }

    fun putDialogueState(scopeId: String, stateJson: String, updatedAtMs: Long): Boolean {
        if (!validId(scopeId) || stateJson.length > MAX_STATE) return false
        val values = ContentValues().apply {
            put("scope_id", scopeId)
            put("state_json", stateJson)
            put("updated_at_ms", updatedAtMs)
        }
        return writable().insertWithOnConflict(
            DIALOGUE_STATE, null, values, SQLiteDatabase.CONFLICT_REPLACE,
        ) != -1L
    }

    fun listMessages(scopeId: String, limit: Int): List<Map<String, Any>> {
        if (!validId(scopeId)) return emptyList()
        val rows = mutableListOf<Map<String, Any>>()
        readable().query(
            MESSAGES,
            arrayOf("event_id", "direction", "delivery_state", "sender", "body", "at_ms", "rule_id"),
            "scope_id = ?", arrayOf(scopeId), null, null, "at_ms ASC, id ASC",
            limit.coerceIn(1, 1000).toString(),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                rows.add(
                    mapOf(
                        "eventId" to cursor.getString(0),
                        "direction" to cursor.getString(1),
                        "deliveryState" to cursor.getString(2),
                        "sender" to cursor.getString(3),
                        "body" to cursor.getString(4),
                        "atMs" to cursor.getLong(5),
                        "ruleId" to cursor.getString(6),
                    ),
                )
            }
        }
        return rows
    }

    private fun validId(value: String): Boolean = value.isNotBlank() && value.length <= MAX_SCOPE_ID

    companion object {
        private const val ASSIGNMENTS = "conversation_assignments"
        private const val SCOPES = "conversation_scopes"
        private const val MESSAGES = "conversation_messages"
        private const val DIALOGUE_STATE = "conversation_dialogue_state"
        private const val TRANSFERS = "conversation_transfers"
        private const val MAX_ID = 240
        private const val MAX_SCOPE_ID = 3000
        private const val MAX_REASON = 240
        private const val MAX_CONTEXT = 1200
        private const val MAX_BODY = 4000
        private const val MAX_SENDER = 300
        private const val MAX_STATE = 20_000
        private val AGENTS = setOf("personal", "business")
        private val DIRECTIONS = setOf("inbound", "outbound")
        private val DELIVERY_STATES = setOf("observed", "verified", "dispatched", "unknown", "manual")

        fun ensureSchema(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE IF NOT EXISTS $ASSIGNMENTS (address_key TEXT PRIMARY KEY, owner_id TEXT NOT NULL, agent_id TEXT NOT NULL, channel TEXT NOT NULL, app_package TEXT NOT NULL, channel_account_id TEXT NOT NULL, conversation_id TEXT NOT NULL UNIQUE, assigned_at_ms INTEGER NOT NULL, updated_at_ms INTEGER NOT NULL, route_reason TEXT NOT NULL)")
            db.execSQL("CREATE TABLE IF NOT EXISTS $SCOPES (scope_id TEXT PRIMARY KEY, address_key TEXT NOT NULL, agent_id TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1, created_at_ms INTEGER NOT NULL, updated_at_ms INTEGER NOT NULL, FOREIGN KEY(address_key) REFERENCES $ASSIGNMENTS(address_key))")
            db.execSQL("CREATE INDEX IF NOT EXISTS conversation_scopes_address_agent ON $SCOPES(address_key, agent_id)")
            db.execSQL("CREATE TABLE IF NOT EXISTS $MESSAGES (id INTEGER PRIMARY KEY AUTOINCREMENT, scope_id TEXT NOT NULL, event_id TEXT NOT NULL, direction TEXT NOT NULL, delivery_state TEXT NOT NULL, sender TEXT NOT NULL DEFAULT '', body TEXT NOT NULL, at_ms INTEGER NOT NULL, rule_id TEXT NOT NULL DEFAULT '', UNIQUE(scope_id, event_id), FOREIGN KEY(scope_id) REFERENCES $SCOPES(scope_id))")
            db.execSQL("CREATE INDEX IF NOT EXISTS conversation_messages_scope_time ON $MESSAGES(scope_id, at_ms)")
            db.execSQL("CREATE TABLE IF NOT EXISTS $DIALOGUE_STATE (scope_id TEXT PRIMARY KEY, state_json TEXT NOT NULL, updated_at_ms INTEGER NOT NULL, FOREIGN KEY(scope_id) REFERENCES $SCOPES(scope_id))")
            db.execSQL("CREATE TABLE IF NOT EXISTS $TRANSFERS (id INTEGER PRIMARY KEY AUTOINCREMENT, address_key TEXT NOT NULL, from_agent_id TEXT NOT NULL, to_agent_id TEXT NOT NULL, reason TEXT NOT NULL, minimal_context TEXT NOT NULL DEFAULT '', at_ms INTEGER NOT NULL, FOREIGN KEY(address_key) REFERENCES $ASSIGNMENTS(address_key))")
            db.execSQL("CREATE INDEX IF NOT EXISTS conversation_transfers_address_time ON $TRANSFERS(address_key, at_ms)")
        }
    }
}
