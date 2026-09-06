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

    /** Añade un ejemplo (body indexado por FTS4). Devuelve el rowId. */
    @Synchronized
    fun addExample(personaKey: String, body: String, toneJson: String, source: String): Long {
        if (personaKey.length > 80 || body.length > MAX_EXAMPLE_CHARS || toneJson.length > 4_000 || source.length > 80) return -1L
        val db = helper.writableDatabase
        val values = android.content.ContentValues().apply {
            put("persona_key", personaKey)
            put("body", body)
            put("tone_json", toneJson)
            put("source", source)
            put("created_at_ms", System.currentTimeMillis())
        }
        return db.insert("persona_examples", null, values)
    }

    /** Lista los ejemplos (más recientes primero). */
    @Synchronized
    fun listExamples(): List<Map<String, String>> {
        val out = mutableListOf<Map<String, String>>()
        helper.readableDatabase.query(
            "persona_examples",
            arrayOf("id", "persona_key", "body", "tone_json", "source"),
            null, null, null, null, "id DESC",
        ).use { c ->
            while (c.moveToNext()) {
                out += mapOf(
                    "id" to c.getLong(0).toString(),
                    "personaKey" to c.getString(1),
                    "body" to c.getString(2),
                    "toneJson" to c.getString(3),
                    "source" to c.getString(4),
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
     *  Orden: relevancia FTS (solo con order=FTS no disponible en fts4 sin
     *  rank; devolvemos por id DESC como proxy de recencia). */
    @Synchronized
    fun searchExamples(query: String, limit: Int): List<Map<String, String>> {
        val terms = query
            .split(Regex("[^\\p{L}\\p{N}]+"))
            .filter { it.isNotBlank() }
            .take(8)
        if (terms.isEmpty()) return emptyList()
        val match = terms.joinToString(" OR ") { "\"${it.replace("\"", "\"\"")}\"" }
        val cap = limit.coerceIn(1, 10)
        val out = mutableListOf<Map<String, String>>()
        helper.readableDatabase.rawQuery(
            "SELECT e.id, e.persona_key, e.body, e.tone_json, e.source " +
                "FROM persona_examples_fts f " +
                "JOIN persona_examples e ON e.id = f.docid " +
                "WHERE f.body MATCH ? ORDER BY e.id DESC LIMIT ?",
            arrayOf(match, cap.toString()),
        ).use { c ->
            while (c.moveToNext()) {
                out += mapOf(
                    "id" to c.getLong(0).toString(),
                    "personaKey" to c.getString(1),
                    "body" to c.getString(2),
                    "toneJson" to c.getString(3),
                    "source" to c.getString(4),
                )
            }
        }
        return out
    }

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
            // PERSONA-STORAGE-04 — instalación limpia: esquema completo v3.
            db.execSQL(PERSONA_DDL)
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            // v1 -> v2: bitácora de eventos del pipeline (append-only).
            if (oldVersion < 2) db.execSQL(EVENTS_DDL)
            // PERSONA-STORAGE-04 — v3: esquema del agente personal (perfiles,
            // ejemplos con FTS4 y episodios conversacionales). Los consumidores
            // Dart llegan en PERSONA-PROFILE-05..RETRIEVAL-07; la migración se
            // aplica UNA vez aquí para no encadenar versiones por tabla.
            if (oldVersion < 3) db.execSQL(PERSONA_DDL)
        }
    }

    companion object {
        private const val DB_NAME = "nano_automation_store.db"
        private const val DB_VERSION = 3
        private const val TABLE = "store_sections"
        private const val COL_KEY = "section_key"
        private const val COL_DATA = "data"
        private const val MAX_SECTION_CHARS = 2_000_000

        /** PERSONA-PROFILE-05 — límite de facts_json por perfil (fail-closed:
         *  jamás crecer sin control desde un canal). */
        private const val MAX_PERSONA_FACTS = 20_000

        /** PERSONA-DATASET-06 — límite del body de un ejemplo de estilo. */
        private const val MAX_EXAMPLE_CHARS = 2_000

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
        private const val PERSONA_DDL =
            "CREATE TABLE IF NOT EXISTS persona_profiles (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "persona_key TEXT NOT NULL UNIQUE, " +
                "display_name TEXT NOT NULL DEFAULT '', " +
                "facts_json TEXT NOT NULL DEFAULT '{}', " +
                "created_at_ms INTEGER NOT NULL);" +
            "CREATE TABLE IF NOT EXISTS relationship_profiles (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "relationship_key TEXT NOT NULL UNIQUE, " +
                "display_name TEXT NOT NULL DEFAULT '', " +
                "facts_json TEXT NOT NULL DEFAULT '{}', " +
                "updated_at_ms INTEGER NOT NULL);" +
            "CREATE TABLE IF NOT EXISTS persona_examples (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "persona_key TEXT NOT NULL, " +
                "body TEXT NOT NULL, " +
                "tone_json TEXT NOT NULL DEFAULT '{}', " +
                "source TEXT NOT NULL DEFAULT '', " +
                "created_at_ms INTEGER NOT NULL);" +
            "CREATE VIRTUAL TABLE IF NOT EXISTS persona_examples_fts " +
                "USING fts4(body, content='persona_examples');" +
            "CREATE TRIGGER IF NOT EXISTS persona_examples_ai " +
                "AFTER INSERT ON persona_examples BEGIN " +
                "INSERT INTO persona_examples_fts(docid, body) " +
                "VALUES (new.id, new.body); END;" +
            "CREATE TRIGGER IF NOT EXISTS persona_examples_ad " +
                "AFTER DELETE ON persona_examples BEGIN " +
                "INSERT INTO persona_examples_fts(persona_examples_fts, docid, body) " +
                "VALUES ('delete', old.id, old.body); END;" +
            "CREATE TRIGGER IF NOT EXISTS persona_examples_au " +
                "AFTER UPDATE ON persona_examples BEGIN " +
                "INSERT INTO persona_examples_fts(persona_examples_fts, docid, body) " +
                "VALUES ('delete', old.id, old.body); " +
                "INSERT INTO persona_examples_fts(docid, body) " +
                "VALUES (new.id, new.body); END;" +
            "CREATE TABLE IF NOT EXISTS conversation_episodes (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "conv_id TEXT NOT NULL, " +
                "sender TEXT NOT NULL DEFAULT '', " +
                "body TEXT NOT NULL, " +
                "at_ms INTEGER NOT NULL, " +
                "intent TEXT NOT NULL DEFAULT '', " +
                "summary TEXT NOT NULL DEFAULT '')"

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
