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
                "persona_key TEXT NOT NULL, " +
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
