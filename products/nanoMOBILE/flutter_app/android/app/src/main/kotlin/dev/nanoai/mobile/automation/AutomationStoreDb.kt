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
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            // v1: sin migraciones todavía.
        }
    }

    companion object {
        private const val DB_NAME = "nano_automation_store.db"
        private const val DB_VERSION = 1
        private const val TABLE = "store_sections"
        private const val COL_KEY = "section_key"
        private const val COL_DATA = "data"
        private const val MAX_SECTION_CHARS = 2_000_000

        /** Secciones válidas — espejo de las secciones Dart (jamás crecer
         *  desde un canal sin revisión: whitelist explícita). */
        private val VALID_SECTIONS = setOf("dedupe", "rate", "memory")
    }
}
