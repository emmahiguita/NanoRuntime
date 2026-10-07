package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.security.MessageDigest

/**
 * WA-PROD-01/02 — DurableInbox: Cola transaccional persistente y recuperable de eventos.
 *
 * QUÉ HACE:
 * Gestiona el ciclo de vida de los eventos de notificación en SQLite con:
 *   1. Estados explícitos: RECEIVED → QUEUED → PROCESSING → GENERATED → SENDING → SENT.
 *   2. Reclamo atómico (claimNext / claimBatch) con lease temporal (30s) y workerId.
 *   3. Recuperación automática de leases vencidos (crash recovery / process death).
 *   4. Idempotencia estricta para evitar dobles envíos.
 *   5. Límite de intentos (maxAttempts = 3) y registro de errores por categoría.
 *
 * SOLID: SRP (Única responsabilidad: persistencia y orden transaccional del buzón de entrada).
 */
class DurableInbox(context: Context) {
    private val helper = InboxDb(context.applicationContext)

    /** Inserta el evento en estado QUEUED. Retorna true si es nuevo; false si ya existía. */
    @Synchronized
    fun insert(packageName: String, notificationKey: String, postTimeMs: Long): Boolean {
        val db = helper.writableDatabase
        val id = eventId(packageName, notificationKey, postTimeMs)
        val now = System.currentTimeMillis()
        val row = ContentValues().apply {
            put(COL_EVENT_ID, id)
            put(COL_PACKAGE, packageName)
            put(COL_KEY, notificationKey)
            put(COL_POST_TIME, postTimeMs)
            put(COL_STATE, STATE_QUEUED)
            put(COL_ATTEMPTS, 0)
            put(COL_RECEIVED_AT, now)
            put(COL_UPDATED_AT, now)
            put(COL_LEASE_UNTIL, 0L)
        }
        return db.insertWithOnConflict(TABLE, null, row, SQLiteDatabase.CONFLICT_IGNORE) != -1L
    }

    data class InboxEvent(
        val eventId: String,
        val packageName: String,
        val notificationKey: String,
        val postTimeMs: Long,
        val receivedAtMs: Long,
        val attempts: Int = 0,
        val state: String = STATE_QUEUED,
        val generatedText: String? = null,
    )

    /** Overload para llamadas con duración de lease/stale explícita en Long. */
    @Synchronized
    fun claim(limit: Int, staleClaimMs: Long): List<InboxEvent> =
        claim(limit, "worker-${System.currentTimeMillis()}", staleClaimMs)

    /** Reclama transaccionalmente hasta [limit] eventos asignando lease y workerId. */
    @Synchronized
    fun claim(
        limit: Int,
        workerId: String = "worker-${System.currentTimeMillis()}",
        leaseDurationMs: Long = LEASE_DURATION_MS,
    ): List<InboxEvent> {
        val db = helper.writableDatabase
        val now = System.currentTimeMillis()
        val leaseUntil = now + leaseDurationMs

        db.beginTransaction()
        try {
            // Reclama eventos QUEUED o eventos PROCESSING cuyo lease haya expirado con intentos < MAX_ATTEMPTS
            val claimable = db.query(
                TABLE,
                arrayOf(COL_EVENT_ID, COL_PACKAGE, COL_KEY, COL_POST_TIME, COL_RECEIVED_AT, COL_ATTEMPTS, COL_STATE, COL_DRAFT_TEXT),
                "($COL_STATE = ? OR ($COL_STATE = ? AND $COL_LEASE_UNTIL < ?)) AND $COL_ATTEMPTS < ?",
                arrayOf(STATE_QUEUED, STATE_PROCESSING, now.toString(), MAX_ATTEMPTS.toString()),
                null,
                null,
                "$COL_RECEIVED_AT ASC",
                limit.toString(),
            ).use { c ->
                buildList {
                    while (c.moveToNext()) {
                        add(
                            InboxEvent(
                                eventId = c.getString(0),
                                packageName = c.getString(1),
                                notificationKey = c.getString(2),
                                postTimeMs = c.getLong(3),
                                receivedAtMs = c.getLong(4),
                                attempts = c.getInt(5),
                                state = c.getString(6),
                                generatedText = c.getString(7),
                            ),
                        )
                    }
                }
            }

            if (claimable.isNotEmpty()) {
                for (e in claimable) {
                    val nextAttempts = e.attempts + 1
                    val cv = ContentValues().apply {
                        put(COL_STATE, STATE_PROCESSING)
                        put(COL_WORKER_ID, workerId)
                        put(COL_ATTEMPTS, nextAttempts)
                        put(COL_UPDATED_AT, now)
                        put(COL_LEASE_UNTIL, leaseUntil)
                    }
                    db.update(TABLE, cv, "$COL_EVENT_ID = ?", arrayOf(e.eventId))
                }
            }
            db.setTransactionSuccessful()
            return claimable
        } finally {
            db.endTransaction()
        }
    }

    /** Registra la respuesta generada por el LLM antes de enviarla (fase GENERATED). */
    @Synchronized
    fun markGenerated(eventId: String, draftText: String) {
        val cv = ContentValues().apply {
            put(COL_STATE, STATE_GENERATED)
            put(COL_DRAFT_TEXT, draftText)
            put(COL_UPDATED_AT, System.currentTimeMillis())
        }
        helper.writableDatabase.update(TABLE, cv, "$COL_EVENT_ID = ?", arrayOf(eventId))
    }

    /** Marca el evento como en tránsito hacia el canal RemoteInput (SENDING). */
    @Synchronized
    fun markSending(eventId: String) {
        val cv = ContentValues().apply {
            put(COL_STATE, STATE_SENDING)
            put(COL_UPDATED_AT, System.currentTimeMillis())
        }
        helper.writableDatabase.update(TABLE, cv, "$COL_EVENT_ID = ?", arrayOf(eventId))
    }

    /** Marca el evento como exitoso y entregado (SENT). */
    @Synchronized
    fun markSent(eventId: String) {
        val cv = ContentValues().apply {
            put(COL_STATE, STATE_SENT)
            put(COL_UPDATED_AT, System.currentTimeMillis())
        }
        helper.writableDatabase.update(TABLE, cv, "$COL_EVENT_ID = ?", arrayOf(eventId))
    }

    /** Registra error de ejecución categorizado e incrementa lógica de reintento. */
    @Synchronized
    fun recordFailure(eventId: String, category: String, message: String?) {
        val db = helper.writableDatabase
        db.beginTransaction()
        try {
            var currentAttempts = 1
            db.query(TABLE, arrayOf(COL_ATTEMPTS), "$COL_EVENT_ID = ?", arrayOf(eventId), null, null, null).use { c ->
                if (c.moveToFirst()) currentAttempts = c.getInt(0)
            }
            val finalState = if (currentAttempts >= MAX_ATTEMPTS) STATE_FAILED_FINAL else STATE_QUEUED
            val cv = ContentValues().apply {
                put(COL_STATE, finalState)
                put(COL_LAST_ERROR, "$category: ${message ?: "Unknown"}")
                put(COL_LEASE_UNTIL, 0L)
                put(COL_UPDATED_AT, System.currentTimeMillis())
            }
            db.update(TABLE, cv, "$COL_EVENT_ID = ?", arrayOf(eventId))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    /** Estado terminal tradicional completado (equivalente a SENT o SKIP_GONE). */
    @Synchronized
    fun complete(eventId: String) {
        markSent(eventId)
    }

    /** Recupera leases expirados:
     *  - Registros en PROCESSING o GENERATED vuelven a QUEUED para reintento.
     *  - Registros en SENDING pasan a SEND_UNCERTAIN para evitar doble envío ciego. */
    @Synchronized
    fun recoverExpiredLeases(now: Long = System.currentTimeMillis()): Int {
        val db = helper.writableDatabase
        var recovered = 0
        db.beginTransaction()
        try {
            // 1. PROCESSING / GENERATED expirados vuelven a QUEUED
            val cvQueued = ContentValues().apply {
                put(COL_STATE, STATE_QUEUED)
                put(COL_LEASE_UNTIL, 0L)
                put(COL_UPDATED_AT, now)
            }
            recovered += db.update(
                TABLE,
                cvQueued,
                "($COL_STATE = ? OR $COL_STATE = ?) AND $COL_LEASE_UNTIL < ? AND $COL_ATTEMPTS < ?",
                arrayOf(STATE_PROCESSING, STATE_GENERATED, now.toString(), MAX_ATTEMPTS.toString()),
            )

            // 2. SENDING expirado pasa a SEND_UNCERTAIN (espera confirmación de outbound antes de reenviar)
            val cvUncertain = ContentValues().apply {
                put(COL_STATE, STATE_SEND_UNCERTAIN)
                put(COL_LEASE_UNTIL, 0L)
                put(COL_LAST_ERROR, "CRASH_DURING_SEND: Lease expirado en tránsito de RemoteInput")
                put(COL_UPDATED_AT, now)
            }
            recovered += db.update(
                TABLE,
                cvUncertain,
                "$COL_STATE = ? AND $COL_LEASE_UNTIL < ?",
                arrayOf(STATE_SENDING, now.toString()),
            )
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return recovered
    }

    /** Comprueba si un evento ya fue procesado y enviado (Idempotencia). */
    @Synchronized
    fun isAlreadySent(eventId: String): Boolean {
        return helper.readableDatabase.query(
            TABLE,
            arrayOf(COL_STATE),
            "$COL_EVENT_ID = ? AND $COL_STATE = ?",
            arrayOf(eventId, STATE_SENT),
            null,
            null,
            null,
        ).use { it.moveToFirst() }
    }

    @Synchronized
    fun pendingCount(): Int = helper.readableDatabase.query(
        TABLE,
        arrayOf("COUNT(*)"),
        "$COL_STATE IN (?, ?)",
        arrayOf(STATE_QUEUED, STATE_PROCESSING),
        null,
        null,
        null,
    ).use { c -> if (c.moveToFirst()) c.getInt(0) else 0 }

    /** Limpia registros completados o caducados que superen [maxAgeMs]. */
    @Synchronized
    fun cleanup(maxAgeMs: Long = 86_400_000L): Int {
        val cutoff = System.currentTimeMillis() - maxAgeMs
        return helper.writableDatabase.delete(
            TABLE,
            "$COL_STATE IN (?, ?) OR $COL_RECEIVED_AT < ?",
            arrayOf(STATE_SENT, STATE_FAILED_FINAL, cutoff.toString()),
        )
    }

    private class InboxDb(context: Context) : SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE $TABLE (
                    $COL_EVENT_ID TEXT PRIMARY KEY,
                    $COL_PACKAGE TEXT NOT NULL,
                    $COL_KEY TEXT NOT NULL,
                    $COL_POST_TIME INTEGER NOT NULL,
                    $COL_STATE TEXT NOT NULL,
                    $COL_ATTEMPTS INTEGER NOT NULL DEFAULT 0,
                    $COL_WORKER_ID TEXT,
                    $COL_LEASE_UNTIL INTEGER NOT NULL DEFAULT 0,
                    $COL_DRAFT_TEXT TEXT,
                    $COL_LAST_ERROR TEXT,
                    $COL_RECEIVED_AT INTEGER NOT NULL,
                    $COL_UPDATED_AT INTEGER NOT NULL
                )
                """.trimIndent(),
            )
            db.execSQL("CREATE INDEX idx_inbox_state ON $TABLE ($COL_STATE, $COL_RECEIVED_AT)")
            db.execSQL("CREATE INDEX idx_inbox_lease ON $TABLE ($COL_LEASE_UNTIL, $COL_ATTEMPTS)")
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            if (oldVersion < 2) {
                db.execSQL("ALTER TABLE $TABLE ADD COLUMN $COL_ATTEMPTS INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE $TABLE ADD COLUMN $COL_WORKER_ID TEXT")
                db.execSQL("ALTER TABLE $TABLE ADD COLUMN $COL_LEASE_UNTIL INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE $TABLE ADD COLUMN $COL_DRAFT_TEXT TEXT")
                db.execSQL("ALTER TABLE $TABLE ADD COLUMN $COL_LAST_ERROR TEXT")
                db.execSQL("CREATE INDEX IF NOT EXISTS idx_inbox_lease ON $TABLE ($COL_LEASE_UNTIL, $COL_ATTEMPTS)")
            }
        }
    }

    companion object {
        private const val DB_NAME = "nano_automation.db"
        private const val DB_VERSION = 2
        private const val TABLE = "inbox_events"

        private const val COL_EVENT_ID = "event_id"
        private const val COL_PACKAGE = "package_name"
        private const val COL_KEY = "notification_key"
        private const val COL_POST_TIME = "post_time"
        private const val COL_STATE = "state"
        private const val COL_ATTEMPTS = "attempts"
        private const val COL_WORKER_ID = "worker_id"
        private const val COL_LEASE_UNTIL = "lease_until"
        private const val COL_DRAFT_TEXT = "draft_text"
        private const val COL_LAST_ERROR = "last_error"
        private const val COL_RECEIVED_AT = "received_at"
        private const val COL_UPDATED_AT = "updated_at"

        const val STATE_QUEUED = "QUEUED"
        const val STATE_PROCESSING = "PROCESSING"
        const val STATE_GENERATED = "GENERATED"
        const val STATE_SENDING = "SENDING"
        const val STATE_SEND_UNCERTAIN = "SEND_UNCERTAIN"
        const val STATE_SENT = "SENT"
        const val STATE_FAILED_FINAL = "FAILED_FINAL"

        const val LEASE_DURATION_MS = 30_000L
        const val MAX_ATTEMPTS = 3

        fun eventId(packageName: String, notificationKey: String, postTimeMs: Long): String {
            val raw = "$packageName|$notificationKey|$postTimeMs"
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(raw.toByteArray(Charsets.UTF_8))
            return digest.take(12).joinToString("") { "%02x".format(it) }
        }
    }
}
