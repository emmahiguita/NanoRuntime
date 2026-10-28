package dev.nanoai.mobile.services

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** Cola acotada de archivos que el usuario comparte con Nano. La entrada se
 * consume solo después de confirmar importación durable en el SQLite de Nano. */
internal object NanoOwlShareInbox {
    private const val KEY = "pending"
    private fun prefs(context: Context) = context.getSharedPreferences("owl_share_inbox", Context.MODE_PRIVATE)

    @Synchronized fun list(context: Context): List<Map<String, String>> {
        val rows = JSONArray(prefs(context).getString(KEY, "[]"))
        return (0 until rows.length()).map { i ->
            val row = rows.getJSONObject(i)
            mapOf("path" to row.getString("path"), "name" to row.getString("name"))
        }
    }

    /** No acepta rutas externas como órdenes: solo archivos en nuestro inbox. */
    @Synchronized fun add(context: Context, file: File, name: String) {
        require(file.canonicalFile.parentFile == File(context.filesDir, "owl/inbox").canonicalFile)
        val rows = list(context)
        require(rows.size < 8) { "Hay 8 importaciones pendientes; abre Nano para procesarlas." }
        val updated = rows + mapOf("path" to file.canonicalPath, "name" to name)
        check(prefs(context).edit().putString(KEY, JSONArray(updated).toString()).commit())
    }

    /** Borra únicamente la copia temporal reconocida, después del ack de Dart. */
    @Synchronized fun acknowledge(context: Context, path: String): Boolean {
        val rows = list(context)
        val entry = rows.singleOrNull { it["path"] == path } ?: return false
        val file = File(entry.getValue("path"))
        if (file.canonicalFile.parentFile != File(context.filesDir, "owl/inbox").canonicalFile) return false
        if (!prefs(context).edit().putString(KEY, JSONArray(rows.filter { it !== entry }).toString()).commit()) return false
        file.delete()
        return true
    }
}
