package dev.nanoai.mobile.channels

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import dev.nanoai.mobile.NanoshellBridge
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * QUÉ: expone SQLite Android y estadísticas C++ a Data Studio.
 * CÓMO: abre bases locales con android.database.sqlite y devuelve valores tipados.
 * POR QUÉ: elimina la dependencia inexistente del ejecutable externo `sqlite3`.
 */
class DataStudioChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "defaultDatabase" -> result.success(defaultDatabase().absolutePath)
                "demoDatabase" -> result.success(DataStudioDemoDatabase.open(context).absolutePath)
                "createDatabase" -> result.success(createDatabase(call.argument<String>("name") ?: "datos"))
                "listTables" -> result.success(listTables(resolvePath(call.argument("path"))))
                "query" -> result.success(query(call))
                "createTable" -> result.success(createTable(call))
                "statistics" -> result.success(statistics(call.argument<List<Number>>("values") ?: emptyList()))
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error("data_studio_error", error.message ?: error.javaClass.simpleName, null)
        }
    }

    private fun defaultDatabase(): File = context.getDatabasePath(DEFAULT_DB).also {
        it.parentFile?.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(it, null).use(DataStudioDemoDatabase::seedIfNeeded)
    }

    private fun createDatabase(rawName: String): String {
        val name = identifier(rawName).lowercase()
        return context.getDatabasePath("$name.db").also {
            it.parentFile?.mkdirs()
            SQLiteDatabase.openOrCreateDatabase(it, null).close()
        }.absolutePath
    }

    private fun resolvePath(raw: String?): File =
        if (raw.isNullOrBlank()) defaultDatabase() else File(raw).canonicalFile

    private fun isWritable(path: File): Boolean {
        val root = context.getDatabasePath(DEFAULT_DB).parentFile!!.canonicalFile
        return path.path.startsWith(root.path + File.separator)
    }

    private fun open(path: File, write: Boolean): SQLiteDatabase {
        if (write && !isWritable(path)) error("Las bases externas se abren en modo de solo lectura")
        val flags = if (write) SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.CREATE_IF_NECESSARY
        else SQLiteDatabase.OPEN_READONLY
        return SQLiteDatabase.openDatabase(path.path, null, flags)
    }

    private fun listTables(path: File): List<String> = open(path, false).use { db ->
        db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata' ORDER BY name",
            null,
        ).use { cursor -> buildList { while (cursor.moveToNext()) add(cursor.getString(0)) } }
    }

    private fun query(call: MethodCall): Map<String, Any?> {
        val path = resolvePath(call.argument("path"))
        val sql = call.argument<String>("sql")?.trim().orEmpty()
        require(sql.isNotEmpty()) { "La consulta SQL está vacía" }
        require(!FORBIDDEN.containsMatchIn(sql)) { "Consulta bloqueada por política local" }
        val read = READ_QUERY.containsMatchIn(sql)
        return open(path, !read).use { db ->
            if (!read) {
                db.execSQL(sql)
                mapOf("columns" to emptyList<String>(), "rows" to emptyList<List<Any?>>(), "affectedRows" to changes(db), "path" to path.path)
            } else db.rawQuery(sql, null).use { cursor -> cursorPayload(cursor, path) }
        }
    }

    private fun cursorPayload(cursor: Cursor, path: File): Map<String, Any?> {
        val rows = ArrayList<List<Any?>>()
        var truncated = false
        while (cursor.moveToNext()) {
            // Lee una fila extra solo para distinguir 5000 exactas de un recorte real.
            if (rows.size == MAX_ROWS) {
                truncated = true
                break
            }
            rows += List(cursor.columnCount) { index ->
                when (cursor.getType(index)) {
                    Cursor.FIELD_TYPE_INTEGER -> cursor.getLong(index)
                    Cursor.FIELD_TYPE_FLOAT -> cursor.getDouble(index)
                    Cursor.FIELD_TYPE_STRING -> cursor.getString(index)
                    Cursor.FIELD_TYPE_BLOB -> "<BLOB ${cursor.getBlob(index).size} bytes>"
                    else -> null
                }
            }
        }
        return mapOf(
            "columns" to cursor.columnNames.toList(),
            "rows" to rows,
            "truncated" to truncated,
            "path" to path.path,
        )
    }

    private fun createTable(call: MethodCall): Map<String, Any?> {
        val path = resolvePath(call.argument("path"))
        val table = identifier(call.argument<String>("table") ?: error("Falta nombre de tabla"))
        val columns = call.argument<List<Map<String, String>>>("columns") ?: emptyList()
        require(columns.isNotEmpty()) { "La tabla necesita al menos una columna" }
        val schema = columns.joinToString(", ") { column ->
            val name = identifier(column["name"] ?: error("Columna sin nombre"))
            val type = column["type"]?.uppercase() ?: "TEXT"
            require(type in TYPES) { "Tipo SQLite no permitido: $type" }
            "\"$name\" $type"
        }
        open(path, true).use { it.execSQL("CREATE TABLE IF NOT EXISTS \"$table\" ($schema)") }
        return mapOf("path" to path.path, "table" to table, "created" to true)
    }

    private fun statistics(values: List<Number>): Map<String, Any> {
        check(NanoshellBridge.ensureLoaded()) { "El motor C++ no está disponible" }
        val output = NanoshellBridge.dataStatistics(values.map { it.toDouble() }.toDoubleArray())
        return mapOf("count" to output[0], "sum" to output[1], "min" to output[2], "max" to output[3], "mean" to output[4], "stddev" to output[5], "engine" to "c++20")
    }

    private fun changes(db: SQLiteDatabase): Long = db.rawQuery("SELECT changes()", null).use {
        if (it.moveToFirst()) it.getLong(0) else 0L
    }

    private fun identifier(value: String): String {
        require(IDENTIFIER.matches(value)) { "Identificador SQLite inválido: $value" }
        return value
    }

    companion object {
        const val CHANNEL_NAME = "com.nanoai/data_studio"
        private const val DEFAULT_DB = "nano_data.db"
        private const val MAX_ROWS = 5_000
        private val IDENTIFIER = Regex("^[A-Za-z_][A-Za-z0-9_]{0,63}$")
        private val TYPES = setOf("TEXT", "INTEGER", "REAL", "BLOB", "NUMERIC")
        private val READ_QUERY = Regex("^(SELECT|WITH|PRAGMA|EXPLAIN)\\b", RegexOption.IGNORE_CASE)
        private val FORBIDDEN = Regex("\\b(ATTACH|DETACH|load_extension|writable_schema|VACUUM\\s+INTO)\\b", RegexOption.IGNORE_CASE)
    }
}
