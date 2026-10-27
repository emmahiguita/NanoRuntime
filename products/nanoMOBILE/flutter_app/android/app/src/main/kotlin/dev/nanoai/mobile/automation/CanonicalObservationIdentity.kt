package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase

/** Correlación estricta: conserva cada fuente y cada repetición legítima.
 * Un texto parecido dentro de una ventana no prueba identidad del mensaje. */
internal object CanonicalObservationIdentity {
    fun exists(
        db: SQLiteDatabase, conversationId: String, provider: String,
        direction: String, sender: String, body: String, atMs: Long,
    ): Boolean {
        // Los proveedores con IDs reales se reconcilian por ese ID, nunca aquí.
        if (provider != "android_notification" || direction != "inbound" ||
            atMs <= 0L || body.isBlank()) return false
        return db.rawQuery(
            "SELECT 1 FROM canonical_messages WHERE conversation_id=? AND provider=? " +
                "AND direction=? AND sender=? AND body=? AND occurred_at_ms=? LIMIT 1",
            arrayOf(conversationId, provider, direction, sender, body, atMs.toString()),
        ).use { it.moveToFirst() }
    }

    // Nombre conservado para los lectores existentes. Ya no promueve ni borra
    // evidencia de notificación: actualiza exclusivamente el ID real de su fuente.
    fun promoteNotificationIfPresent(db: SQLiteDatabase, values: ContentValues): Boolean {
        val provider = values.getAsString("provider").orEmpty()
        if (provider != "whatsapp_mcp" && provider != "meta_cloud") return false
        val providerId = values.getAsString("provider_message_id").orEmpty()
        val conversation = values.getAsString("conversation_id").orEmpty()
        if (providerId.isBlank() || conversation.isBlank()) return false
        val update = ContentValues(values).apply { remove("canonical_id") }
        return db.update("canonical_messages", update,
            "provider=? AND conversation_id=? AND provider_message_id=?",
            arrayOf(provider, conversation, providerId)) > 0
    }
}