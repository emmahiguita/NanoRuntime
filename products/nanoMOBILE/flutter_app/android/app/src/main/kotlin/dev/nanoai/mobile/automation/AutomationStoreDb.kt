package dev.nanoai.mobile.automation

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * WA-PROD-02 — AutomationStoreDb: estado durable de la automatización.
 *
 * Sustituye shared_preferences para el estado CRÍTICO del pipeline (dedupe,
 * rate limiter y memoria conversacional). Una sola base por proceso con
 * escritor único Kotlin (synchronized) y reemplazo atómico por sección —
 * WAL + transacción. Ventajas sobre el plugin de prefs (versión pinned por
 * problema de R8 en el APK + caché en memoria por isolate):
 *
 * - escrituras serializadas en un solo dueño (nunca dos isolates pisándose);
 * - reemplazo atómico por sección (sin archivo JSON parcial/roto a mitad);
 * - la carga queda bajo barrera explícita (WA-PROD-02 hydration);
 * - migración única desde las claves legacy de prefs (Dart la orquesta).
 *
 * Contenido: sigue la política del módulo — secciones de ESTADO del pipeline,
 * nunca contenido de conversación ajeno (la memoria conversacional retiene
 * texto de mensajes por diseño del agente local, igual que hacía en prefs).
 */
class AutomationStoreDb(context: Context) {
    private val helper = StoreDb(context.applicationContext)

    /** Snapshot completo: section → json. */
    @Synchronized
    fun loadAll(): Map<String, String> {
        val out = mutableMapOf<String, String>()
        helper.readableDatabase.query(
            TABLE,
            arrayOf(COL_KEY, COL_DATA),
            null,
            null,
            null,
            null,
            null,
        ).use { c ->
            while (c.moveToNext()) {
                out[c.getString(0)] = c.getString(1)
            }
        }
        return out
    }

    @Synchronized
    fun section(key: String): String? {
        if (key !in VALID_SECTIONS) return null
        return helper.readableDatabase.query(
            TABLE,
            arrayOf(COL_DATA),
            "$COL_KEY = ?",
            arrayOf(key),
            null,
            null,
            null,
        ).use { c -> if (c.moveToFirst()) c.getString(0) else null }
    }

    /** Reemplazo atómico de la sección. false = key no válida o payload
     *  fuera de límite (fail-closed: jamás crecer sin control). */
    @Synchronized
    fun putSection(key: String, json: String): Boolean {
        if (key !in VALID_SECTIONS) return false
        if (json.length > MAX_SECTION_CHARS) return false
        val db = helper.writableDatabase
        db.beginTransaction()
        try {
            db.delete(TABLE, "$COL_KEY = ?", arrayOf(key))
            db.execSQL(
                "INSERT INTO $TABLE ($COL_KEY, $COL_DATA) VALUES (?, ?)",
                arrayOf(key, json),
            )
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return true
    }

    @Synchronized
    fun deleteSection(key: String) {
        if (key !in VALID_SECTIONS) return
        helper.writableDatabase.delete(TABLE, "$COL_KEY = ?", arrayOf(key))
    }

    /** WA-EVLOG-01 — registra un evento de pipeline (append-only, local).
     *  false = tipo no whitelisted o detalle fuera de límite. */
    @Synchronized
    fun appendEvent(convId: String, kind: String, detail: String): Boolean {
        if (kind !in VALID_EVENT_KINDS) return false
        if (detail.length > MAX_EVENT_DETAIL) return false
        val db = helper.writableDatabase
        db.execSQL(
            "INSERT INTO pipeline_events (at_ms, conv_id, kind, detail) VALUES (?, ?, ?, ?)",
            arrayOf(
                System.currentTimeMillis(),
                convId.take(120),
                kind,
                detail,
            ),
        )
        return true
    }

    // ── PERSONA-PROFILE-05 — perfiles del agente personal ──────────────
    // El SQL SIEMPRE se compone aquí en Kotlin: Dart manda datos tipados
    // (key/name/facts) y jamás texto SQL. Límites iguales a las secciones.

    /** Upsert del perfil de la persona (key única). Devuelve el rowId. */
    @Synchronized
    fun upsertPersona(personaKey: String, displayName: String, factsJson: String): Long {
        if (personaKey.length > 80 || displayName.length > 200 || factsJson.length > MAX_PERSONA_FACTS) return -1L
        val db = helper.writableDatabase
        val values = android.content.ContentValues().apply {
            put("persona_key", personaKey)
            put("display_name", displayName)
            put("facts_json", factsJson)
            put("created_at_ms", System.currentTimeMillis())
        }
        return db.insertWithOnConflict(
            "persona_profiles", null, values,
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    /** Lista los perfiles de persona: key → (name, facts_json). */
    @Synchronized
    fun listPersonas(): List<Map<String, String>> {
        val out = mutableListOf<Map<String, String>>()
        helper.readableDatabase.query(
            "persona_profiles",
            arrayOf("persona_key", "display_name", "facts_json"),
            null, null, null, null, null,
        ).use { c ->
            while (c.moveToNext()) {
                out += mapOf(
                    "personaKey" to c.getString(0),
                    "displayName" to c.getString(1),
                    "factsJson" to c.getString(2),
                )
            }
        }
        return out
    }

    /** Upsert de un perfil de relación (contacto). Devuelve el rowId. */
    @Synchronized
    fun upsertRelationship(relationshipKey: String, displayName: String, factsJson: String): Long {
        if (relationshipKey.length > 200 || displayName.length > 200 || factsJson.length > MAX_PERSONA_FACTS) return -1L
        val db = helper.writableDatabase
        val values = android.content.ContentValues().apply {
            put("relationship_key", relationshipKey)
            put("display_name", displayName)
            put("facts_json", factsJson)
            put("updated_at_ms", System.currentTimeMillis())
        }
        return db.insertWithOnConflict(
            "relationship_profiles", null, values,
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    /** Lista los perfiles de relación: key → (name, facts_json). */
    @Synchronized
    fun listRelationships(): List<Map<String, String>> {
        val out = mutableListOf<Map<String, String>>()
        helper.readableDatabase.query(
            "relationship_profiles",
            arrayOf("relationship_key", "display_name", "facts_json"),
            null, null, null, null, null,
        ).use { c ->
            while (c.moveToNext()) {
                out += mapOf(
                    "relationshipKey" to c.getString(0),
                    "displayName" to c.getString(1),
                    "factsJson" to c.getString(2),
                )
            }
        }
        return out
    }

    /** Borra un perfil de relación. false = key inválida (fail-closed). */
    @Synchronized
    fun deleteRelationship(relationshipKey: String): Boolean {
        if (relationshipKey.length > 200) return false
        val deleted = helper.writableDatabase.delete(
            "relationship_profiles",
            "relationship_key = ?",
            arrayOf(relationshipKey),
        )
        return deleted > 0
    }

    // ── PERSONA-DATASET-06 — ejemplos del estilo del dueño ─────────────
    // Cada ejemplo = un mensaje tal como lo escribiría el dueño. El índice
    // FTS4 (persona_examples_fts) se sincroniza solo por triggers; el
    // retriever (PERSONA-RETRIEVAL-07) consulta con MATCH compuesto aquí.

    /** Añade un ejemplo (body indexado por FTS4). [incomingText] no vacío
     *  = PAR condicionado (R5-03): entrada de cliente a la que responde
     *  [body]; vacío = estilo legacy sin condicionar. Devuelve el rowId. */
    @Synchronized
    fun addExample(
        personaKey: String,
        body: String,
        toneJson: String,
        source: String,
        incomingText: String = "",
    ): Long {
        if (personaKey.isBlank() || personaKey.length > 80 || body.isBlank() || body.length > MAX_EXAMPLE_CHARS ||
            toneJson.length > 4_000 || source.length > 80 ||
            incomingText.length > MAX_EXAMPLE_CHARS
        ) return -1L
        val metadata = org.json.JSONObject(toneJson.ifBlank { "{}" }).toString()
        val db = helper.writableDatabase
        val values = android.content.ContentValues().apply {
            put("persona_key", personaKey)
            put("body", body)
            put("tone_json", metadata)
            put("source", source)
            put("incoming_text", incomingText)
            put("created_at_ms", System.currentTimeMillis())
        }
        return db.insert("persona_examples", null, values)
    }

    /** Lista los ejemplos (más recientes primero). */
    @Synchronized
    fun listExamples(limit: Int = 200, offset: Int = 0, scopeKey: String? = null): List<Map<String, String>> {
        val out = mutableListOf<Map<String, String>>()
        helper.readableDatabase.query(
            "persona_examples",
            arrayOf("id", "persona_key", "incoming_text", "body", "tone_json", "source"),
            if (scopeKey.isNullOrEmpty()) null else "persona_key = ?",
            if (scopeKey.isNullOrEmpty()) null else arrayOf(scopeKey),
            null, null, "id DESC", "${offset.coerceAtLeast(0)},${limit.coerceIn(1, 200)}",
        ).use { c ->
            while (c.moveToNext()) {
                out += mapOf(
                    "id" to c.getLong(0).toString(),
                    "personaKey" to c.getString(1),
                    "incomingText" to c.getString(2),
                    "body" to c.getString(3),
                    "toneJson" to c.getString(4),
                    "source" to c.getString(5),
                )
            }
        }
        return out
    }

    /** Borra un ejemplo. false = id inválido o inexistente. */
    @Synchronized
    fun deleteExample(id: Long): Boolean {
        if (id <= 0) return false
        val deleted = helper.writableDatabase.delete(
            "persona_examples",
            "id = ?",
            arrayOf(id.toString()),
        )
        return deleted > 0
    }

    /** PERSONA-RETRIEVAL-07 — busca ejemplos por similitud textual con FTS4.
     *  El MATCH se compone aquí (términos entrecomillados unidos por OR):
     *  Dart jamás manda SQL y los términos raros no rompen la sintaxis FTS.
     *
     *  R5-03 — dos pasadas en orden de prioridad:
     *  1) PARES condicionados: el texto entrante matchea incoming_text
     *     guardado (CURRENT INPUT ≈ PAST INPUT; invariante del brief). Un
     *     par trae su respuesta del dueño (body) como referencia de forma
     *     Y de contenido.
     *  2) LEGACY sin par (incoming_text = ''): solo estilo, sin condicionar
     *     el turno. Solo si quedan cupos. Su body ya NO matchea el input —
     *     indexar la respuesta del dueño contra el mensaje entrante era la
     *     dirección invertida que contaminó drafts (evidencia R5-01).
     *  Orden dentro de cada pasada: id DESC como proxy de recencia. */
    @Synchronized
    fun searchExamples(query: String, limit: Int, scopeKey: String = "owner", roleKey: String = "role:personal"): List<Map<String, String>> {
        val terms = query
            .split(Regex("[^\\p{L}\\p{N}]+"))
            .filter { it.isNotBlank() }
            .take(8)
        if (terms.isEmpty()) return emptyList()
        val match = terms.joinToString(" OR ") { "\"${it.replace("\"", "\"\"")}\"" }
        val cap = limit.coerceIn(1, 40)
        val out = mutableListOf<Map<String, String>>()
        helper.readableDatabase.rawQuery(
            "SELECT e.id, e.persona_key, e.incoming_text, e.body, e.tone_json, e.source " +
                "FROM persona_examples_fts f " +
                "JOIN persona_examples e ON e.id = f.docid " +
                "WHERE f.incoming_text MATCH ? AND e.incoming_text != '' AND e.persona_key IN (?, ?, 'owner') " +
                "AND $RETRIEVABLE_EXAMPLE_SQL " +
                "ORDER BY CASE WHEN e.persona_key = ? THEN 0 WHEN e.persona_key = ? THEN 1 ELSE 2 END, e.id DESC LIMIT ?",
            arrayOf(match, scopeKey, roleKey, scopeKey, roleKey, cap.toString()),
        ).use { c ->
            while (c.moveToNext()) {
                out += mapOf(
                    "id" to c.getLong(0).toString(),
                    "personaKey" to c.getString(1),
                    "incomingText" to c.getString(2),
                    "body" to c.getString(3),
                    "toneJson" to c.getString(4),
                    "source" to c.getString(5),
                )
            }
        }
        if (out.size < cap) {
            helper.readableDatabase.rawQuery(
                "SELECT e.id, e.persona_key, e.incoming_text, e.body, e.tone_json, e.source " +
                    "FROM persona_examples e " +
                    "WHERE e.incoming_text = '' AND e.persona_key IN (?, ?, 'owner') AND $RETRIEVABLE_EXAMPLE_SQL " +
                    "ORDER BY CASE WHEN e.persona_key = ? THEN 0 WHEN e.persona_key = ? THEN 1 ELSE 2 END, e.id DESC LIMIT ?",
                arrayOf(scopeKey, roleKey, scopeKey, roleKey, (cap - out.size).toString()),
            ).use { c ->
                while (c.moveToNext()) {
                    out += mapOf(
                        "id" to c.getLong(0).toString(),
                        "personaKey" to c.getString(1),
                        "incomingText" to c.getString(2),
                        "body" to c.getString(3),
                        "toneJson" to c.getString(4),
                        "source" to c.getString(5),
                    )
                }
            }
        }
        return out
    }

    // Personalization Studio activates the existing conversation_episodes table.
    // Its intent identifies memory type; summary stores provenance/expiry metadata.
    // No second database, model training, or destructive schema migration.
    @Synchronized
    fun savePersonalMemory(row: org.json.JSONObject): Long {
        val kind = row.optString("kind")
        require(kind in MEMORY_KINDS) { "Invalid memory kind" }
        val scope = row.optString("scopeKey", "owner")
        val key = row.optString("key")
        val body = row.optString("value")
        require(scope.length in 1..200 && key.length in 1..120 && body.length in 1..2000)
        val meta = row.optJSONObject("metadata") ?: org.json.JSONObject()
        require(meta.toString().length <= 4000)
        val at = row.optLong("observedAt", System.currentTimeMillis())
        require(at > 0)
        if (kind == "temporaryFact") require(meta.optLong("expiresAt") > at) { "Temporary memory needs expiry" }
        val cv = android.content.ContentValues().apply {
            put("conv_id", scope); put("sender", key); put("body", body)
            put("at_ms", at); put("intent", kind); put("summary", meta.toString())
        }
        val id = row.optLong("id", -1)
        val db = helper.writableDatabase
        return if (id > 0) {
            require(db.update("conversation_episodes", cv, "id = ? AND intent IN ($MEMORY_KIND_SQL)", arrayOf(id.toString())) == 1)
            id
        } else db.insertOrThrow("conversation_episodes", null, cv)
    }

    @Synchronized
    fun listPersonalMemories(scopeKey: String?, limit: Int, offset: Int): List<Map<String, Any?>> {
        return helper.readableDatabase.query("conversation_episodes",
            arrayOf("id", "conv_id", "sender", "body", "at_ms", "intent", "summary"),
            "intent IN ($MEMORY_KIND_SQL)" + if (scopeKey.isNullOrEmpty()) "" else " AND conv_id IN (?, 'owner')",
            if (scopeKey.isNullOrEmpty()) null else arrayOf(scopeKey),
            null, null, "at_ms DESC, id DESC", "${offset.coerceAtLeast(0)},${limit.coerceIn(1, 200)}").use { c ->
            buildList { while (c.moveToNext()) add(mapOf(
                "id" to c.getLong(0), "scopeKey" to c.getString(1), "key" to c.getString(2),
                "value" to c.getString(3), "observedAt" to c.getLong(4), "kind" to c.getString(5), "metadata" to c.getString(6))) }
        }
    }

    @Synchronized
    fun deletePersonalMemory(id: Long): Boolean = helper.writableDatabase.delete(
        "conversation_episodes", "id = ? AND intent IN ($MEMORY_KIND_SQL)", arrayOf(id.toString())) > 0

    @Synchronized
    fun updateExample(id: Long, body: String, incoming: String, toneJson: String, scopeKey: String? = null): Boolean {
        require(body.isNotBlank() && body.length <= MAX_EXAMPLE_CHARS && incoming.length <= MAX_EXAMPLE_CHARS && toneJson.length <= 4000)
        val metadata = org.json.JSONObject(toneJson).toString()
        val cv = android.content.ContentValues().apply {
            put("body", body); put("incoming_text", incoming); put("tone_json", metadata)
            if (scopeKey != null) { require(scopeKey.length in 1..80); put("persona_key", scopeKey) }
        }
        return helper.writableDatabase.update("persona_examples", cv, "id = ?", arrayOf(id.toString())) == 1
    }

    @Synchronized
    fun bindRelationshipScope(oldKey: String, newKey: String, conversationId: String): Boolean {
        require(oldKey.isNotBlank() && oldKey != "owner" && !oldKey.startsWith("role:") && !oldKey.startsWith("contact:") && oldKey.length <= 200 && newKey.matches(Regex("contact:[a-f0-9]{64}")) && conversationId.isNotBlank() && conversationId.length <= 2000)
        val db = helper.writableDatabase
        db.beginTransaction()
        try {
            require(!db.rawQuery("SELECT id FROM relationship_profiles WHERE relationship_key = ?", arrayOf(newKey)).use { it.moveToFirst() }) { "Target already has a profile" }
            val profile = db.rawQuery("SELECT display_name, facts_json FROM relationship_profiles WHERE relationship_key = ?", arrayOf(oldKey)).use { c ->
                require(c.moveToFirst()) { "Source profile missing" }; Pair(c.getString(0), c.getString(1))
            }
            val facts = org.json.JSONObject(profile.second).put("conversationId", conversationId)
            require(upsertRelationship(newKey, profile.first, facts.toString()) > 0)
            val example = android.content.ContentValues().apply { put("persona_key", newKey) }
            val memory = android.content.ContentValues().apply { put("conv_id", newKey) }
            db.update("persona_examples", example, "persona_key = ?", arrayOf(oldKey))
            db.update("conversation_episodes", memory, "conv_id = ? AND (intent IN ($MEMORY_KIND_SQL) OR intent = 'importHistory')", arrayOf(oldKey))
            db.delete("relationship_profiles", "relationship_key = ?", arrayOf(oldKey))
            db.setTransactionSuccessful()
            return true
        } finally { db.endTransaction() }
    }

    @Synchronized
    fun importPersonalization(payload: String): Map<String, Any> {
        require(payload.length <= 4_000_000)
        val data = org.json.JSONObject(payload)
        val batch = data.getString("batchId")
        require(batch.matches(Regex("[a-f0-9]{64}")))
        val batchScope = data.optString("scopeKey", "owner")
        require(batchScope.length in 1..80 && batchScope.isNotBlank())
        val examples = data.optJSONArray("examples") ?: org.json.JSONArray()
        val memories = data.optJSONArray("memories") ?: org.json.JSONArray()
        require(examples.length() + memories.length() in 1..1000)
        val history = data.optString("history")
        require(history.toByteArray(Charsets.UTF_8).size <= 2_000_000)
        val db = helper.writableDatabase
        var added = 0
        var duplicates = 0
        db.beginTransaction()
        try {
            for (i in 0 until examples.length()) {
                val e = examples.getJSONObject(i)
                val scope = e.optString("personaKey", "owner")
                require(scope == batchScope) { "Import cannot mix contact scopes" }
                val body = e.getString("body")
                val incoming = e.optString("incomingText")
                val metadata = e.optJSONObject("tone") ?: org.json.JSONObject()
                val kind = metadata.optString("kind", "paired")
                require(kind in setOf("paired", "style", "template"))
                require(e.optString("source") in setOf("manual", "owner_import", "template")) { "Generated output is not owner evidence" }
                if (kind != "template") require(metadata.optString("ownerVerified") == "true") { "Owner evidence must be confirmed" }
                metadata.put("importBatch", batch)
                metadata.put("enabled", "true")
                val fingerprint = metadata.getString("fingerprint")
                require(fingerprint.matches(Regex("[a-f0-9]{64}")))
                val exists = db.rawQuery("SELECT id FROM persona_examples WHERE persona_key = ? AND tone_json LIKE ? LIMIT 1",
                    arrayOf(scope, "%\"fingerprint\":\"$fingerprint\"%")).use { it.moveToFirst() }
                if (exists) { duplicates++; continue }
                require(addExample(scope, body, metadata.toString(), e.getString("source"), incoming) > 0) { "Example exceeds storage limits" }
                added++
            }
            for (i in 0 until memories.length()) {
                val memory = memories.getJSONObject(i)
                require(memory.optString("scopeKey", "owner") == batchScope) { "Import cannot mix contact scopes" }
                // An imported payload must never overwrite a pre-existing manual row.
                memory.remove("id")
                val metadata = memory.optJSONObject("metadata") ?: org.json.JSONObject()
                val fingerprint = metadata.getString("fingerprint")
                require(fingerprint.matches(Regex("[a-f0-9]{64}")))
                metadata.put("importBatch", batch)
                metadata.put("enabled", "true")
                memory.put("metadata", metadata)
                val exists = db.rawQuery("SELECT id FROM conversation_episodes WHERE conv_id = ? AND summary LIKE ? LIMIT 1",
                    arrayOf(memory.optString("scopeKey", "owner"), "%\"fingerprint\":\"$fingerprint\"%")).use { it.moveToFirst() }
                if (exists) { duplicates++; continue }
                savePersonalMemory(memory); added++
            }
            val existingHistory = db.rawQuery("SELECT id, summary FROM conversation_episodes WHERE intent = 'importHistory' AND sender = ? LIMIT 1",
                arrayOf(batch)).use { if (it.moveToFirst()) Pair(it.getLong(0), it.getString(1)) else null }
            if (added > 0 && existingHistory == null) {
                val values = android.content.ContentValues().apply {
                    put("conv_id", batchScope); put("sender", batch)
                    put("body", history); put("at_ms", System.currentTimeMillis()); put("intent", "importHistory")
                    put("summary", org.json.JSONObject().put("fileName", data.optString("fileName").take(200))
                        .put("importBatch", batch).put("accepted", added).toString())
                }
                db.insertOrThrow("conversation_episodes", null, values)
            } else if (added > 0 && existingHistory != null) {
                // Review may accept more candidates from the same file on a later visit.
                val metadata = org.json.JSONObject(existingHistory.second)
                metadata.put("accepted", metadata.optInt("accepted") + added)
                val values = android.content.ContentValues().apply { put("summary", metadata.toString()) }
                db.update("conversation_episodes", values, "id = ?", arrayOf(existingHistory.first.toString()))
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
        return mapOf("added" to added, "duplicates" to duplicates, "batchId" to batch)
    }

    @Synchronized
    fun deleteImportBatch(batch: String): Int {
        require(batch.matches(Regex("[a-f0-9]{64}")))
        val db = helper.writableDatabase
        val marker = "%\"importBatch\":\"$batch\"%"
        db.beginTransaction()
        try {
            val removed = db.delete("persona_examples", "tone_json LIKE ?", arrayOf(marker)) +
                db.delete("conversation_episodes", "summary LIKE ? AND (intent IN ($MEMORY_KIND_SQL) OR intent = 'importHistory')", arrayOf(marker))
            db.setTransactionSuccessful()
            return removed
        } finally { db.endTransaction() }
    }

    @Synchronized
    fun personalizationSummary(): Map<String, Any> {
        val db = helper.readableDatabase
        fun count(table: String, where: String = "1=1") = db.rawQuery("SELECT COUNT(*) FROM $table WHERE $where", null).use { it.moveToFirst(); it.getInt(0) }
        val batches = db.query("conversation_episodes", arrayOf("id", "sender", "at_ms", "summary"), "intent = ?", arrayOf("importHistory"),
            null, null, "at_ms DESC", "100").use { c -> buildList {
            while (c.moveToNext()) add(mapOf("id" to c.getLong(0), "batchId" to c.getString(1), "atMs" to c.getLong(2), "metadata" to c.getString(3)))
        } }
        val scopes = db.rawQuery("SELECT persona_key AS scope_key FROM persona_examples UNION " +
            "SELECT conv_id AS scope_key FROM conversation_episodes WHERE intent IN ($MEMORY_KIND_SQL) OR intent = 'importHistory' ORDER BY scope_key", null).use { c ->
            buildList { while (c.moveToNext()) if (!c.getString(0).isNullOrBlank()) add(c.getString(0)) }
        }
        return mapOf("examples" to count("persona_examples", "tone_json NOT LIKE '%\"kind\":\"template\"%'"),
            "templates" to count("persona_examples", "tone_json LIKE '%\"kind\":\"template\"%'"),
            "contacts" to count("relationship_profiles", "relationship_key NOT LIKE 'role:%'"),
            "memories" to count("conversation_episodes", "intent IN ($MEMORY_KIND_SQL)"), "batches" to batches, "scopeKeys" to scopes)
    }

    @Synchronized
    fun importHistory(id: Long): String? = helper.readableDatabase.rawQuery(
        "SELECT body FROM conversation_episodes WHERE id = ? AND intent = 'importHistory'", arrayOf(id.toString())).use { if (it.moveToFirst()) it.getString(0) else null }

    private class StoreDb(context: Context) :
        SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE $TABLE (
                    $COL_KEY TEXT PRIMARY KEY,
                    $COL_DATA TEXT NOT NULL
                )
                """.trimIndent(),
            )
            db.execSQL(EVENTS_DDL)
            for (ddl in PERSONA_DDL_STATEMENTS) db.execSQL(ddl)
            ensureFts(db)
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            // v1 -> v2: bitácora de eventos del pipeline (append-only).
            if (oldVersion < 2) db.execSQL(EVENTS_DDL)
            // Create missing base tables before ALTER: historical v3/v4 installs
            // could contain only a subset. SQLiteOpenHelper rolls back a failed
            // migration instead of marking an incomplete schema as upgraded.
            for (ddl in PERSONA_DDL_STATEMENTS) db.execSQL(ddl)
            val hasIncoming = db.rawQuery("PRAGMA table_info(persona_examples)", null).use { c ->
                var found = false
                while (c.moveToNext()) if (c.getString(1) == "incoming_text") found = true
                found
            }
            if (!hasIncoming) db.execSQL("ALTER TABLE persona_examples ADD COLUMN incoming_text TEXT NOT NULL DEFAULT ''")
            if (oldVersion < 6) {
                dropFtsTriggers(db)
                db.execSQL("DROP TABLE IF EXISTS persona_examples_fts")
            }
            // v7 repairs invalid FTS5-style delete commands in FTS4 triggers.
            // Only the derived index is rebuilt; examples and profiles remain.
            ensureFts(db)
        }

        private fun dropFtsTriggers(db: SQLiteDatabase) {
            for (name in listOf("persona_examples_ai", "persona_examples_ad", "persona_examples_au", "persona_examples_bd", "persona_examples_bu")) {
                db.execSQL("DROP TRIGGER IF EXISTS $name")
            }
        }

        /** FTS4 external-content removal must run before the source row changes.
         *  https://www.sqlite.org/fts3.html#external_content_fts4_tables */
        private fun ensureFts(db: SQLiteDatabase) {
            db.execSQL(FTS_DDL)
            dropFtsTriggers(db)
            db.execSQL(FTS_TRIGGER_BD)
            db.execSQL(FTS_TRIGGER_BU)
            db.execSQL(FTS_TRIGGER_AI)
            db.execSQL(FTS_TRIGGER_AU)
            db.execSQL("INSERT INTO persona_examples_fts(persona_examples_fts) VALUES('rebuild')")
        }
    }

    companion object {
        private const val DB_NAME = "nano_automation_store.db"
        // PERSONA-BUGFIX-02 — v5: DDL base idempotente en CADA upgrade (la
        // v3 multi-sentencia dejó tablas base sin crear en devices ya en v4).
        // R5-03 — v6: pares condicionados (columna incoming_text + FTS
        // recreada sobre incoming_text Y body).
        // v7: FTS4-safe edit/delete triggers, rebuilt index, no user-row deletion.
        private const val DB_VERSION = 7
        private const val TABLE = "store_sections"
        private const val COL_KEY = "section_key"
        private const val COL_DATA = "data"
        private const val MAX_SECTION_CHARS = 2_000_000

        /** PERSONA-PROFILE-05 — límite de facts_json por perfil (fail-closed:
         *  jamás crecer sin control desde un canal). */
        private const val MAX_PERSONA_FACTS = 20_000

        /** PERSONA-DATASET-06 — límite del body de un ejemplo de estilo. */
        private const val MAX_EXAMPLE_CHARS = 2_000
        private val MEMORY_KINDS = setOf("stablePreference", "stableRelationshipFact", "businessFact", "episodicMemory", "temporaryFact", "stylePreference")
        private val MEMORY_KIND_SQL = MEMORY_KINDS.joinToString(",") { "'$it'" }
        // Filter before LIMIT so disabled/unverified records do not hide usable
        // examples. JSON is canonicalized on write; REPLACE also handles legacy
        // pretty-printed metadata without requiring Android's optional JSON1.
        private const val COMPACT_TONE_SQL = "REPLACE(REPLACE(REPLACE(REPLACE(e.tone_json, ' ', ''), char(9), ''), char(10), ''), char(13), '')"
        private const val RETRIEVABLE_EXAMPLE_SQL =
            "$COMPACT_TONE_SQL NOT LIKE '%\"enabled\":\"false\"%' AND " +
            "$COMPACT_TONE_SQL NOT LIKE '%\"enabled\":false%' AND " +
            "lower(e.source) NOT LIKE '%nano%' AND lower(e.source) NOT LIKE '%assistant%' AND lower(e.source) != 'generated' AND " +
            "(e.source = 'manual' OR $COMPACT_TONE_SQL LIKE '%\"ownerVerified\":\"true\"%' OR " +
            "$COMPACT_TONE_SQL LIKE '%\"kind\":\"template\"%')"

        /** WA-EVLOG-01 — bitácora append-only de eventos del pipeline.
         *  Auditoría diagnóstica local (nunca contenido de conversación):
         *  cada fila es {momento, conversación, tipo, detalle corto}. */
        private const val EVENTS_TABLE = "pipeline_events"
        private const val EVENTS_DDL =
            "CREATE TABLE IF NOT EXISTS $EVENTS_TABLE (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "at_ms INTEGER NOT NULL, " +
                "conv_id TEXT NOT NULL DEFAULT '', " +
                "kind TEXT NOT NULL, " +
                "detail TEXT NOT NULL DEFAULT '')"

        /** PERSONA-STORAGE-04 — esquema v3 del agente personal. Los perfiles
         *  (persona/relación), los ejemplos de estilo con índice FTS4 y los
         *  episodios conversacionales necesitan SQL real (búsqueda textual y
         *  consultas por ventana de tiempo) — por eso son tablas y no
         *  secciones JSON. El ownership en cambio SÍ viaja por sección
         *  ("ownership") para usar el mismo patrón de reemplazo atómico que
         *  dedupe/rate/memory. Los consumidores Dart llegan en
         *  PERSONA-PROFILE-05..RETRIEVAL-07. */
        private val PERSONA_DDL_STATEMENTS = listOf(
            "CREATE TABLE IF NOT EXISTS persona_profiles (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "persona_key TEXT NOT NULL UNIQUE, " +
                "display_name TEXT NOT NULL DEFAULT '', " +
                "facts_json TEXT NOT NULL DEFAULT '{}', " +
                "created_at_ms INTEGER NOT NULL)",
            "CREATE TABLE IF NOT EXISTS relationship_profiles (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "relationship_key TEXT NOT NULL UNIQUE, " +
                "display_name TEXT NOT NULL DEFAULT '', " +
                "facts_json TEXT NOT NULL DEFAULT '{}', " +
                "updated_at_ms INTEGER NOT NULL)",
            "CREATE TABLE IF NOT EXISTS persona_examples (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "persona_key TEXT NOT NULL, " +
                "body TEXT NOT NULL, " +
                "incoming_text TEXT NOT NULL DEFAULT '', " +
                "tone_json TEXT NOT NULL DEFAULT '{}', " +
                "source TEXT NOT NULL DEFAULT '', " +
                "created_at_ms INTEGER NOT NULL)",
            "CREATE TABLE IF NOT EXISTS conversation_episodes (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "conv_id TEXT NOT NULL, " +
                "sender TEXT NOT NULL DEFAULT '', " +
                "body TEXT NOT NULL, " +
                "at_ms INTEGER NOT NULL, " +
                "intent TEXT NOT NULL DEFAULT '', " +
                "summary TEXT NOT NULL DEFAULT '')",
            "CREATE INDEX IF NOT EXISTS persona_examples_scope_id ON persona_examples(persona_key, id)",
            "CREATE INDEX IF NOT EXISTS conversation_episodes_scope_type_time ON conversation_episodes(conv_id, intent, at_ms)",
            "CREATE INDEX IF NOT EXISTS conversation_episodes_type_sender ON conversation_episodes(intent, sender)",
        )

        /** FTS4 index and its synchronization triggers. */
        private const val FTS_DDL =
            "CREATE VIRTUAL TABLE IF NOT EXISTS persona_examples_fts " +
                "USING fts4(incoming_text, body, content='persona_examples')"
        private const val FTS_TRIGGER_AI =
            "CREATE TRIGGER IF NOT EXISTS persona_examples_ai " +
                "AFTER INSERT ON persona_examples BEGIN " +
                "INSERT INTO persona_examples_fts(docid, incoming_text, body) " +
                "VALUES (new.id, new.incoming_text, new.body); END"
        private const val FTS_TRIGGER_BD =
            "CREATE TRIGGER IF NOT EXISTS persona_examples_bd " +
                "BEFORE DELETE ON persona_examples BEGIN " +
                "DELETE FROM persona_examples_fts WHERE docid = old.id; END"
        private const val FTS_TRIGGER_BU =
            "CREATE TRIGGER IF NOT EXISTS persona_examples_bu " +
                "BEFORE UPDATE ON persona_examples BEGIN " +
                "DELETE FROM persona_examples_fts WHERE docid = old.id; END"
        private const val FTS_TRIGGER_AU =
            "CREATE TRIGGER IF NOT EXISTS persona_examples_au " +
                "AFTER UPDATE ON persona_examples BEGIN " +
                "INSERT INTO persona_examples_fts(docid, incoming_text, body) " +
                "VALUES (new.id, new.incoming_text, new.body); END"

        /** Secciones válidas — espejo de las secciones Dart (jamás crecer
         *  desde un canal sin revisión: whitelist explícita). */
        private val VALID_SECTIONS = setOf(
            "dedupe", "rate", "memory", "business", "tone", "convstate",
            // PERSONA-HANDOFF-03 — ownership por conversación (bot/humano).
            "ownership",
        )

        /** Kinds de bitácora aceptados (espejo Dart, whitelist explícita). */
        private val VALID_EVENT_KINDS = setOf("received", "terminal", "echo")
        private const val MAX_EVENT_DETAIL = 400
    }
}
