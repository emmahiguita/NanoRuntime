package dev.nanoai.mobile.automation

import android.database.sqlite.SQLiteDatabase

/** Filtra historial social por evidencia persistida, sin borrar mensajes ni buscar frases. */
internal object SocialHistoryAdmission {
    /** Añade metadata compatible: los registros anteriores no se declaran verificados por defecto. */
    @Synchronized
    fun ensureSchema(db: SQLiteDatabase, table: String) {
        val exists = db.rawQuery("PRAGMA table_info($table)", null).use { cursor ->
            val column = cursor.getColumnIndexOrThrow("name")
            var found = false
            while (cursor.moveToNext()) if (cursor.getString(column) == "message_verified") found = true
            found
        }
        if (!exists) db.execSQL("ALTER TABLE $table ADD COLUMN message_verified INTEGER NOT NULL DEFAULT 0")
    }

    /** Se aplica antes del límite y al último mensaje, conteo y detalle de cada hilo. */
    fun predicate(alias: String = ""): String {
        val prefix = if (alias.isEmpty()) "" else "$alias."
        // El tag direct + thread_id fue observado en un DM real del dispositivo.
        // Permite recuperar ese historial anterior sin fingir evidencia para avisos ambiguos.
        return """(${prefix}package_name NOT IN ('com.instagram.android', 'com.facebook.katana',
            'com.facebook.lite', 'com.facebook.orca', 'com.facebook.mlite')
            OR (${prefix}message_verified >= 1 AND ${prefix}package_name NOT IN
            ('com.facebook.katana', 'com.facebook.lite')) OR ${prefix}message_verified >= 2
            OR (${prefix}package_name = 'com.instagram.android'
            AND instr(${prefix}notification_key, '|direct|') > 0
            AND instr(${prefix}notification_key, 'thread_id:') > 0))"""
    }

    /** Revisión 2 exige admisión de DM; la revisión anterior aceptaba actividad del feed. */
    fun verification(packageName: String, admitted: Boolean): Int = when {
        !admitted -> 0
        packageName in setOf("com.facebook.katana", "com.facebook.lite") -> 2
        else -> 1
    }
}
