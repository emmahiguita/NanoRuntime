package dev.nanoai.mobile.automation

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase

/**
 * QUÉ HACE:
 * Identificador tipado sin sobrecoste en memoria (`@JvmInline value class`) para un flujo de sincronización.
 * CÓMO FUNCIONA:
 * Valida en tiempo de construcción que el nombre del flujo no esté vacío ni supere 120 caracteres.
 * POR QUÉ:
 * Evita pasar cadenas arbitrarias o vacías a las consultas SQL de cursores (Kotlin Expresivo / SOLID).
 */
@JvmInline
internal value class SyncStreamKey(val id: String) {
    init {
        require(id.isNotBlank() && id.length <= 120) { "Stream inválido" }
    }
}

/**
 * QUÉ HACE:
 * Gestiona la sincronización incremental (Delta Sync) de WhatsApp MCP y la detección de
 * conversaciones pendientes de respuesta directamente sobre `canonical_messages`.
 *
 * CÓMO FUNCIONA:
 * 1. `ensureSchema`: crea la tabla ligera `sync_cursors` en `nano_automation_store.db`.
 * 2. `applyBatch`: inserta/promueve mensajes y avanza el cursor dentro de UNA SOLA transacción SQLite.
 * 3. `listPendingConversations`: consulta las conversaciones cuyo último mensaje entrante
 *    no tiene ningún mensaje saliente posterior.
 *
 * POR QUÉ:
 * Reutiliza la base canónica existente sin crear bases duplicadas (`nano_whatsapp_context.db`),
 * garantizando atomicidad (si falla un lote, el cursor no avanza).
 */
internal object CanonicalMcpDeltaSync {
    private const val CURSORS_TABLE = "sync_cursors"

    /**
     * QUÉ HACE: Crea la tabla `sync_cursors` si no existe.
     * CÓMO FUNCIONA: Ejecuta DDL idempotente al abrir o actualizar `AutomationStoreDb`.
     * POR QUÉ: Guarda el último `sequence` confirmado del servidor MCP por cada cuenta/flujo.
     */
    fun ensureSchema(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE IF NOT EXISTS $CURSORS_TABLE (" +
                "stream TEXT PRIMARY KEY, " +
                "cursor_seq INTEGER NOT NULL DEFAULT 0, " +
                "snapshot_seq INTEGER NOT NULL DEFAULT 0, " +
                "updated_at_ms INTEGER NOT NULL)",
        )
    }

    /**
     * QUÉ HACE: Obtiene el cursor actual de sincronización para un flujo dado.
     * CÓMO FUNCIONA: Lee `cursor_seq` y `snapshot_seq` desde `sync_cursors`.
     * POR QUÉ: Permite reanudar `whatsapp_get_changes(after=cursor)` tras reiniciar la app.
     */
    fun getCursor(db: SQLiteDatabase, stream: String): Map<String, Any> {
        if (stream.isBlank() || stream.length > 120) {
            return mapOf("cursorSeq" to 0L, "snapshotSeq" to 0L, "updatedAtMs" to 0L)
        }
        return db.query(
            CURSORS_TABLE,
            arrayOf("cursor_seq", "snapshot_seq", "updated_at_ms"),
            "stream = ?",
            arrayOf(stream),
            null,
            null,
            null,
        ).use { c ->
            if (c.moveToFirst()) {
                mapOf(
                    "cursorSeq" to c.getLong(0),
                    "snapshotSeq" to c.getLong(1),
                    "updatedAtMs" to c.getLong(2),
                )
            } else {
                mapOf("cursorSeq" to 0L, "snapshotSeq" to 0L, "updatedAtMs" to 0L)
            }
        }
    }

    /**
     * QUÉ HACE: Aplica un lote de eventos MCP y actualiza el cursor en una única transacción atómica.
     * CÓMO FUNCIONA: Abre `beginTransactionNonExclusive()`, ejecuta `upsert` en `CanonicalMessageSqlStore`
     * para cada evento y solo guarda el nuevo cursor si todo el lote tuvo éxito.
     * POR QUÉ: Impide perder mensajes o dejar cursores adelantados si ocurre un cierre inesperado.
     */
    fun applyBatch(
        db: SQLiteDatabase,
        store: CanonicalMessageSqlStore,
        stream: String,
        nextCursor: Long,
        snapshotSeq: Long,
        rows: List<Map<String, Any?>>,
    ): Map<String, Any> {
        val key = SyncStreamKey(stream)
        require(nextCursor >= 0L && snapshotSeq >= 0L)
        require(snapshotSeq == 0L || snapshotSeq >= nextCursor)
        val safeCursor = nextCursor
        val safeSnapshot = snapshotSeq
        db.beginTransactionNonExclusive()
        try {
            val previous = (getCursor(db, stream)["cursorSeq"] as Number).toLong()
            require(safeCursor >= previous) { "MCP cursor cannot move backwards" }
            var applied = 0
            for (row in rows) {
                if (CanonicalBatchAdmission.apply(db, store, stream, row)) applied++
            }
            val values = ContentValues().apply {
                put("stream", key.id)
                put("cursor_seq", safeCursor)
                put("snapshot_seq", safeSnapshot)
                put("updated_at_ms", System.currentTimeMillis())
            }
            db.insertWithOnConflict(CURSORS_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE)
            db.setTransactionSuccessful()
            return mapOf(
                "ok" to true,
                "applied" to applied,
                "cursorSeq" to safeCursor,
                "snapshotSeq" to safeSnapshot,
            )
        } finally {
            db.endTransaction()
        }
    }

    /**
     * QUÉ HACE: Devuelve las conversaciones que tienen un mensaje entrante sin responder.
     * CÓMO FUNCIONA: Agrupa por `conversation_id`, selecciona el mensaje más reciente dentro de la
     * ventana temporal y filtra aquellos donde `direction = 'inbound'`.
     * POR QUÉ: Permite que Nano responda con evidencia real a "¿Qué tengo pendiente en WhatsApp?".
     */
    fun listPendingConversations(
        db: SQLiteDatabase,
        lookbackMs: Long,
        limit: Int,
    ): List<Map<String, Any>> {
        val minTimeMs = (System.currentTimeMillis() - lookbackMs.coerceAtLeast(60_000L)).coerceAtLeast(0L)
        val safeLimit = limit.coerceIn(1, 20)
        val sql = """
            WITH latest AS (
                SELECT conversation_id, MAX(occurred_at_ms) AS last_ms
                FROM canonical_messages
                WHERE occurred_at_ms >= ? AND direction IN ('inbound', 'outbound')
                GROUP BY conversation_id
            )
            SELECT m.conversation_id, m.sender, m.body, m.occurred_at_ms, m.provider
            FROM canonical_messages m
            INNER JOIN latest l
                ON m.conversation_id = l.conversation_id AND m.occurred_at_ms = l.last_ms
            WHERE m.direction = 'inbound' AND m.body != ''
            ORDER BY m.occurred_at_ms DESC
            LIMIT ?
        """.trimIndent()
        return db.rawQuery(sql, arrayOf(minTimeMs.toString(), safeLimit.toString())).use { c ->
            buildList {
                while (c.moveToNext()) {
                    add(
                        mapOf(
                            "conversationId" to (c.getString(0) ?: ""),
                            "sender" to (c.getString(1) ?: ""),
                            "body" to (c.getString(2) ?: ""),
                            "occurredAtMs" to c.getLong(3),
                            "provider" to (c.getString(4) ?: ""),
                        ),
                    )
                }
            }
        }
    }
}
