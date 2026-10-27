package dev.nanoai.mobile.automation

import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject

/** Distingue duplicado real de rechazo. Un fallo de aplicación aborta el lote
 * antes del cursor; no convierte datos omitidos en sincronización exitosa. */
internal object CanonicalBatchAdmission {
    fun apply(db: SQLiteDatabase, store: CanonicalMessageSqlStore, stream: String,
        row: Map<String, Any?>): Boolean {
        val id = row["id"] as? String ?: error("MCP row missing id")
        val conversation = row["conversationId"] as? String ?: error("MCP row missing conversation")
        val sourceId = row["providerMessageId"] as? String ?: error("MCP row missing provider id")
        require(id.isNotBlank() && id.length <= 500 && conversation.isNotBlank() && conversation.length <= 500)
        require(sourceId.length <= 500 && ((row["body"] as? String)?.length ?: 0) <= 16000)
        require(((row["rawMetadata"] as? String)?.length ?: 0) <= 4000)
        val metadata = JSONObject(row["rawMetadata"] as? String ?: "{}")
        require(row["provider"] == "whatsapp_mcp" && sourceId.isNotBlank())
        require(metadata.optString("accountId") == stream && metadata.optString("sourceChatId").isNotBlank())
        require(row["direction"] == "inbound" || row["direction"] == "outbound")
        require(((row["occurredAtMs"] as? Number)?.toLong() ?: 0L) > 0L)
        if (store.upsert(row)) return true
        val duplicate = db.rawQuery(
            "SELECT 1 FROM canonical_messages WHERE provider='whatsapp_mcp' AND conversation_id=? " +
                "AND (canonical_id=? OR provider_message_id=?) LIMIT 1",
            arrayOf(conversation, id, sourceId),
        ).use { it.moveToFirst() }
        check(duplicate) { "MCP row rejected; cursor unchanged" }
        return false
    }
}
