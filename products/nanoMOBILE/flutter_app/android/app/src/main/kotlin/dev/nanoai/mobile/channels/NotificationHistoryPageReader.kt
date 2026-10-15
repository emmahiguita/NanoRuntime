package dev.nanoai.mobile.channels

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.os.Handler
import android.os.Looper
import dev.nanoai.mobile.automation.NotificationHistorySqlStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.RejectedExecutionException

/** Lectura paginada del archivo existente: sin otro escritor ni trabajo SQLite en la UI. */
internal class NotificationHistoryPageReader(context: Context) {
    // Nombre real del StoreDb existente; NO crea una segunda base ni descifra secciones.
    private val path = context.applicationContext.getDatabasePath("nano_automation_store.db").path
    private val main = Handler(Looper.getMainLooper())
    // Cola acotada y el trabajador desaparece tras 15 s inactivo: no deja hilos residentes.
    private val io = ThreadPoolExecutor(0, 1, 15, TimeUnit.SECONDS, ArrayBlockingQueue(8),
        { task -> Thread(task, "nano-history-read").apply { isDaemon = true } })

    /** Solo acepta argumentos tipados; el SQL/cursor pertenece al mismo repositorio. */
    fun read(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("historyId").orEmpty()
        val limit = call.argument<Number>("limit")?.toInt() ?: 200
        val beforeMs = call.argument<Number>("beforeMs")?.toLong()
        val beforeId = call.argument<String>("beforeId")
        try {
            io.execute {
                try {
                    val page = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                        db.rawQuery("PRAGMA busy_timeout=2000", null).use { it.moveToFirst() }
                        NotificationHistorySqlStore({ db }, { error("Lectura sin permisos de escritura") })
                            .pageMessages(id, limit, beforeMs, beforeId)
                    }
                    main.post { result.success(page) }
                } catch (error: Exception) {
                    // Publica el tipo, nunca texto SQL, mensajes personales ni rutas de credenciales.
                    main.post { result.error("HISTORY_READ_FAILED", error.javaClass.simpleName, null) }
                }
            }
        } catch (_: RejectedExecutionException) {
            result.error("HISTORY_BUSY", "Lectura ocupada; vuelve a intentar", null)
        }
    }
}
