package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject

/** Procedencia observada, no parecido de texto: una recaptura corrige solo su ID real. */
internal object CanonicalWebVerification {
    const val SOURCE = "dom_verified_v1"
    const val PAGE_PREDICATE = " AND instr(raw_metadata, '\"source\":\"dom_verified_v1\"') > 0" +
        " AND (provider_message_id GLOB 'true_*' OR provider_message_id GLOB 'false_*')"
    private val providerId = Regex("^(true|false)_.+")

    fun refresh(db: SQLiteDatabase, values: ContentValues): Boolean {
        if (values.getAsString("provider") != "whatsapp_web") return false
        val id = values.getAsString("provider_message_id").orEmpty()
        if (!providerId.matches(id)) return false
        val source = try { JSONObject(values.getAsString("raw_metadata")).optString("source") }
            catch (_: Exception) { return false }
        if (source != SOURCE) return false
        val refreshed = ContentValues(values).apply { remove("canonical_id"); remove("fingerprint") }
        return db.update("canonical_messages", refreshed,
            "provider=? AND provider_message_id=? AND conversation_id=?",
            arrayOf("whatsapp_web", id, values.getAsString("conversation_id"))) > 0
    }
}
