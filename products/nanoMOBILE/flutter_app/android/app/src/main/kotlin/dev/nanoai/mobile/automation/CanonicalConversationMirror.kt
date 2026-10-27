package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject

/**
 * QUÉ: refleja la memoria de un scope en la fuente canónica de esa conversación.
 * CÓMO: resuelve la asignación técnica y conserva ID, dirección y estado real.
 * POR QUÉ: separa el almacenamiento de scopes de la adaptación canónica y evita
 * duplicar un entrante que el panel ya observó con otro identificador.
 */
internal object CanonicalConversationMirror {
    fun append(
        db: SQLiteDatabase, scopeId: String, eventId: String, direction: String,
        deliveryState: String, sender: String, body: String, atMs: Long, ruleId: String,
    ) {
        val conversationId = db.rawQuery(
            "SELECT a.conversation_id FROM conversation_scopes s " +
                "JOIN conversation_assignments a ON s.address_key = a.address_key " +
                "WHERE s.scope_id = ? LIMIT 1", arrayOf(scopeId),
        ).use { if (it.moveToFirst()) it.getString(0) else scopeId }
        if (CanonicalObservationIdentity.exists(
                db, conversationId, "android_notification", direction, sender.take(300), body, atMs,
            )) return
        val values = ContentValues().apply {
            put("canonical_id", "$scopeId:$eventId")
            put("conversation_id", conversationId)
            put("provider", "android_notification")
            put("provider_message_id", eventId)
            put("direction", direction)
            put("delivery_state", deliveryState)
            put("sender", sender.take(300))
            put("body", body)
            put("occurred_at_ms", atMs)
            put("observed_at_ms", System.currentTimeMillis())
            put("fingerprint", eventId)
            // JSON real: IDs con comillas no deben romper los metadatos.
            put("raw_metadata", JSONObject().put("ruleId", ruleId).toString())
        }
        db.insertWithOnConflict("canonical_messages", null, values, SQLiteDatabase.CONFLICT_IGNORE)
    }
}
