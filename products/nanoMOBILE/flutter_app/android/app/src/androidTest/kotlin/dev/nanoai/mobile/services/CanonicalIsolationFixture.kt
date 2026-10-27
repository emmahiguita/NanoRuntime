package dev.nanoai.mobile.services

import android.database.sqlite.SQLiteDatabase
import dev.nanoai.mobile.automation.CanonicalMessageSqlStore
import dev.nanoai.mobile.automation.CanonicalMcpDeltaSync

/** SQLite real en memoria. No consulta ni modifica la base de datos del teléfono. */
internal object CanonicalIsolationFixture {
    fun run(): String = SQLiteDatabase.create(null).use { db ->
        db.execSQL("CREATE TABLE canonical_messages (id INTEGER PRIMARY KEY AUTOINCREMENT, " +
            "canonical_id TEXT NOT NULL UNIQUE, conversation_id TEXT NOT NULL, provider TEXT NOT NULL, " +
            "provider_message_id TEXT, direction TEXT NOT NULL, sender TEXT NOT NULL DEFAULT '', " +
            "body TEXT NOT NULL DEFAULT '', media_type TEXT NOT NULL DEFAULT '', media_uri TEXT NOT NULL DEFAULT '', " +
            "occurred_at_ms INTEGER NOT NULL, observed_at_ms INTEGER NOT NULL, delivery_state TEXT NOT NULL, " +
            "fingerprint TEXT NOT NULL, raw_metadata TEXT NOT NULL DEFAULT '', " +
            "UNIQUE(provider, provider_message_id), UNIQUE(conversation_id, fingerprint))")
        db.execSQL("INSERT INTO canonical_messages(canonical_id,conversation_id,provider,direction,body,occurred_at_ms,observed_at_ms,delivery_state,fingerprint) " +
            "VALUES('legacy','legacy-chat','android_notification','inbound','Original',100,200,'observed','legacy-fp')")
        CanonicalMessageSqlStore.ensureSchema(db)
        CanonicalMessageSqlStore.ensureSchema(db)
        check(db.rawQuery("SELECT id,body FROM canonical_messages WHERE canonical_id='legacy'", null).use {
            it.moveToFirst() && it.getLong(0) == 1L && it.getString(1) == "Original"
        }) { "legacy migration changed data" }
        val store = CanonicalMessageSqlStore({ db }, { db })
        fun row(provider: String, conversation: String, id: String, at: Long = 1000) = mapOf<String, Any?>(
            "id" to "$provider:$conversation:$id", "conversationId" to conversation,
            "provider" to provider, "providerMessageId" to id, "direction" to "inbound",
            "sender" to "Juan", "body" to "sí", "occurredAtMs" to at, "observedAtMs" to at,
            "deliveryState" to "observed", "fingerprint" to "same-body:$at",
            "rawMetadata" to "{\"accountId\":\"account-a\",\"sourceChatId\":\"juan\"}",
        )
        check(store.upsert(row("whatsapp_mcp", "personal/account-a/juan", "id-1")))
        check(store.upsert(row("whatsapp_mcp", "personal/account-b/juan", "id-1")))
        check(store.upsert(row("meta_cloud", "business/account-c/juan", "id-1")))
        check(store.upsert(row("whatsapp_mcp", "personal/account-a/juan", "id-2")))
        check(store.list("personal/account-a/juan", 10).size == 2)
        check(store.upsert(row("android_notification", "shared-chat", "notification")))
        check(store.upsert(row("whatsapp_mcp", "shared-chat", "source-message")))
        check(store.list("shared-chat", 10).size == 2) { "cross-source evidence overwritten" }
        check(store.upsert(row("android_notification", "shared-chat", "repeat", 2000)))
        check(store.list("shared-chat", 10).size == 3) { "legitimate repeat dropped" }
        val valid = row("whatsapp_mcp", "personal/account-a/test", "delta-1")
        check(runCatching { CanonicalMcpDeltaSync.applyBatch(db, store, "account-a", 7, 7,
            listOf(valid, valid - "id")) }.isFailure)
        check(store.list("personal/account-a/test", 10).isEmpty()) { "partial batch escaped rollback" }
        check(CanonicalMcpDeltaSync.getCursor(db, "account-a")["cursorSeq"] == 0L)
        CanonicalMcpDeltaSync.applyBatch(db, store, "account-a", 7, 7, listOf(valid))
        CanonicalMcpDeltaSync.applyBatch(db, store, "account-a", 7, 7, listOf(valid))
        check(store.list("personal/account-a/test", 10).size == 1)
        check(runCatching { CanonicalMcpDeltaSync.applyBatch(db, store, "account-a", 6, 7, emptyList()) }.isFailure)
        "Canonical isolation: PASS legacy-preserved, accounts-separated, repeats-preserved, batch-rollback, idempotency\n"
    }
}
