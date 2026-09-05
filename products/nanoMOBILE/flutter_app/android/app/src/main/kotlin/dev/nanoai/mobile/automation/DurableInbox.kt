package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.security.MessageDigest

/**
 * WA-PROD-01 — DurableInbox: cola transaccional de eventos de notificación.
 *
 * Dueño ÚNICO de escritura en el proceso (Kotlin, main process). El
 * NotificationListener persiste el evento (<10ms) y sale; si el proceso muere
 * antes de procesarlo, la fila sobrevive y el próximo wake (NLS o UI) la
 * reclama. Sin IPC: el service y el listener comparten proceso.
 *
 * PRIVACIDAD (contrato histórico del listener): nunca se persiste contenido —
 * texto, remitente o título. La fila guarda solo la identidad del evento
 * (package + notificationKey + tiempos); el contenido se rehidrata de las
 * notificaciones ACTIVAS de Android al momento de procesar. Fila cuya
 * notificación ya no está activa se descarta honesta (SKIP_GONE): sin
 * contenido no hay draft posible.
 *
 * Estados: RECEIVED → RESERVED (claim) → delete (complete). RESERVED con
 * updated_at viejo (> STALE_CLAIM_MS) se re-reclama tras un crash a mitad de
 * procesamiento; el dedupe persistente de Dart impide el doble envío.
 */
class DurableInbox(context: Context) {
    private val helper = InboxDb(context.applicationContext)

    /** Inserta el evento. false = ya existía (misma notificación re-publicada). */
    @Synchronized
    fun insert(packageName: String, notificationKey: String, postTimeMs: Long): Boolean {
        val db = helper.writableDatabase
        val row = ContentValues().apply {
            put(COL_EVENT_ID, eventId(packageName, notificationKey, postTimeMs))
            put(COL_PACKAGE, packageName)
            put(COL_KEY, notificationKey)
            put(COL_POST_TIME, postTimeMs)
            put(COL_STATE, STATE_RECEIVED)
            put(COL_RECEIVED_AT, System.currentTimeMillis())
            put(COL_UPDATED_AT, System.currentTimeMillis())
        }
        return db.insertWithOnConflict(TABLE, null, row, SQLiteDatabase.CONFLICT_IGNORE) != -1L
    }

    data class InboxEvent(
        val eventId: String,
        val packageName: String,
        val notificationKey: String,
        val postTimeMs: Long,
        val receivedAtMs: Long,
    )

    /** Reclama hasta [limit] filas: RECEIVED + RESERVED viejas (crash a mitad). */
    @Synchronized
    fun claim(limit: Int, staleClaimMs: Long = STALE_CLAIM_MS): List<InboxEvent> {
        val db = helper.writableDatabase
        val now = System.currentTimeMillis()
        val staleBefore = now - staleClaimMs
        db.beginTransaction()
        try {
            val claimable = db.query(
                TABLE,
                arrayOf(COL_EVENT_ID, COL_PACKAGE, COL_KEY, COL_POST_TIME, COL_RECEIVED_AT),
                "$COL_STATE = ? OR ($COL_STATE = ? AND $COL_UPDATED_AT < ?)",
                arrayOf(STATE_RECEIVED, STATE_RESERVED, staleBefore.toString()),
                null,
                null,
                "$COL_RECEIVED_AT ASC",
                limit.toString(),
            ).use { c ->
                buildList {
                    while (c.moveToNext()) {
                        add(
                            InboxEvent(
                                c.getString(0),
                                c.getString(1),
                                c.getString(2),
                                c.getLong(3),
                                c.getLong(4),
                            ),
                        )
                    }
                }
            }
            if (claimable.isNotEmpty()) {
                val cv = ContentValues().apply {
                    put(COL_STATE, STATE_RESERVED)
                    put(COL_UPDATED_AT, now)
                }
                for (e in claimable) {
                    db.update(
                        TABLE,
                        cv,
                        "$COL_EVENT_ID = ? AND $COL_STATE IN (?, ?)",
                        arrayOf(e.eventId, STATE_RECEIVED, STATE_RESERVED),
                    )
                }
            }
            db.setTransactionSuccessful()
            return claimable
        } finally {
            db.endTransaction()
        }
    }

    /** Estado terminal del evento: la fila se borra (sin payload no hay
     *  auditoría que conservar; el journal de Dart guarda el resultado). */
    @Synchronized
    fun complete(eventId: String) {
        helper.writableDatabase.delete(TABLE, "$COL_EVENT_ID = ?", arrayOf(eventId))
    }

    @Synchronized
    fun pendingCount(): Int = helper.readableDatabase.query(
        TABLE,
        arrayOf("COUNT(*)"),
        null,
        null,
        null,
        null,
        null,
    ).use { c -> if (c.moveToFirst()) c.getInt(0) else 0 }

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
                    $COL_RECEIVED_AT INTEGER NOT NULL,
                    $COL_UPDATED_AT INTEGER NOT NULL
                )
                """.trimIndent(),
            )
            db.execSQL("CREATE INDEX idx_inbox_state ON $TABLE ($COL_STATE, $COL_RECEIVED_AT)")
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            // v1: sin migraciones todavía.
        }
    }

    companion object {
        private const val DB_NAME = "nano_automation.db"
        private const val DB_VERSION = 1
        private const val TABLE = "inbox_events"
        private const val COL_EVENT_ID = "event_id"
        private const val COL_PACKAGE = "package_name"
        private const val COL_KEY = "notification_key"
        private const val COL_POST_TIME = "post_time"
        private const val COL_STATE = "state"
        private const val COL_RECEIVED_AT = "received_at"
        private const val COL_UPDATED_AT = "updated_at"
        private const val STATE_RECEIVED = "RECEIVED"
        private const val STATE_RESERVED = "RESERVED"
        private const val STALE_CLAIM_MS = 30_000L

        /** Identidad del evento; estable dentro de la sesión de la notificación
         *  (la re-publicación de la misma notificación reusa la fila). */
        fun eventId(packageName: String, notificationKey: String, postTimeMs: Long): String {
            val raw = "$packageName|$notificationKey|$postTimeMs"
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(raw.toByteArray(Charsets.UTF_8))
            return digest.take(12).joinToString("") { "%02x".format(it) }
        }
    }
}
