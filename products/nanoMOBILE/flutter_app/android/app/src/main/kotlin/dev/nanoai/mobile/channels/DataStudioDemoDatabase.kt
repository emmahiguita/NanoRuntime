package dev.nanoai.mobile.channels

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File

/**
 * QUÉ: base SQLite persistente con un conjunto profesional de demostración.
 * CÓMO: crea relaciones, claves foráneas y vistas que Data Studio consulta.
 * POR QUÉ: permite validar el flujo real sin presentar datos sintéticos como hechos.
 */
object DataStudioDemoDatabase {
    private const val FILE_NAME = "nano_professional_demo.db"
    private const val SCHEMA_VERSION = 4

    /** Abre el archivo real y crea el ejemplo solo cuando falta su versión. */
    fun open(context: Context): File = context.getDatabasePath(FILE_NAME).also { file ->
        file.parentFile?.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(file, null).use(::seedIfNeeded)
    }

    private fun seedIfNeeded(db: SQLiteDatabase) {
        val version = db.rawQuery("PRAGMA user_version", null).use { cursor ->
            if (cursor.moveToFirst()) cursor.getInt(0) else 0
        }
        if (version >= SCHEMA_VERSION) return

        db.beginTransaction()
        try {
            dropSchema(db)
            createSchema(db)
            DataStudioDemoSeed.insertAll(db)
            createViews(db)
            db.execSQL("PRAGMA user_version = $SCHEMA_VERSION")
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    // Elimina versiones anteriores para que las vistas y columnas sean coherentes.
    private fun dropSchema(db: SQLiteDatabase) {
        listOf(
            "VIEW IF EXISTS dashboard_servicios",
            "VIEW IF EXISTS rendimiento_servicios",
            "VIEW IF EXISTS dashboard_ventas",
            "VIEW IF EXISTS rendimiento_productos",
            "TABLE IF EXISTS pagos",
            "TABLE IF EXISTS proyectos",
            "TABLE IF EXISTS clientes",
            "TABLE IF EXISTS servicios_programacion",
            "TABLE IF EXISTS detalle_pedido",
            "TABLE IF EXISTS pedidos",
            "TABLE IF EXISTS productos",
        ).forEach { db.execSQL("DROP $it") }
    }

    // Define el modelo relacional que usan las consultas y reportes.
    private fun createSchema(db: SQLiteDatabase) {
        db.execSQL("""CREATE TABLE servicios_programacion (
            id INTEGER PRIMARY KEY, nombre TEXT NOT NULL, categoria TEXT NOT NULL,
            precio_cop REAL NOT NULL, precio_usd REAL NOT NULL,
            descripcion TEXT NOT NULL, activo INTEGER NOT NULL DEFAULT 1)""")
        db.execSQL("""CREATE TABLE clientes (
            id INTEGER PRIMARY KEY, nombre TEXT NOT NULL, sector TEXT NOT NULL,
            ciudad TEXT NOT NULL, contacto TEXT NOT NULL, alta TEXT NOT NULL)""")
        db.execSQL("""CREATE TABLE proyectos (
            id INTEGER PRIMARY KEY, cliente_id INTEGER NOT NULL, servicio_id INTEGER NOT NULL,
            titulo TEXT NOT NULL, fecha_ini TEXT NOT NULL, fecha_fin TEXT,
            valor_cop REAL NOT NULL, estado TEXT NOT NULL,
            FOREIGN KEY(cliente_id) REFERENCES clientes(id),
            FOREIGN KEY(servicio_id) REFERENCES servicios_programacion(id))""")
        db.execSQL("""CREATE TABLE pagos (
            id INTEGER PRIMARY KEY, proyecto_id INTEGER NOT NULL,
            fecha TEXT NOT NULL, monto_cop REAL NOT NULL,
            metodo TEXT NOT NULL, nota TEXT,
            FOREIGN KEY(proyecto_id) REFERENCES proyectos(id))""")
    }

    // Las vistas calculan KPIs desde filas persistidas; Flutter no fija cifras.
    private fun createViews(db: SQLiteDatabase) {
        db.execSQL("""CREATE VIEW dashboard_servicios AS
            SELECT sp.categoria,
              substr(pg.fecha,1,7) AS periodo,
              ROUND(SUM(pg.monto_cop),0) AS [ingresos cop],
              ROUND(SUM(pg.monto_cop)/3800.0,2) AS [ingresos usd],
              COUNT(DISTINCT pr.id) AS proyectos,
              COUNT(DISTINCT pr.cliente_id) AS clientes
            FROM pagos pg
            JOIN proyectos pr ON pr.id = pg.proyecto_id
            JOIN servicios_programacion sp ON sp.id = pr.servicio_id
            GROUP BY sp.categoria, periodo
            ORDER BY periodo, [ingresos cop] DESC""")

        db.execSQL("""CREATE VIEW rendimiento_servicios AS
            SELECT sp.nombre AS servicio, sp.categoria,
              COUNT(DISTINCT pr.id) AS contratos,
              ROUND(COALESCE(SUM(pg.monto_cop),0),0) AS [total cobrado cop],
              ROUND(COALESCE(AVG(pg.monto_cop),0),0) AS [promedio pago cop],
              sp.precio_cop AS [precio base cop]
            FROM servicios_programacion sp
            LEFT JOIN proyectos pr ON pr.servicio_id = sp.id
            LEFT JOIN pagos pg ON pg.proyecto_id = pr.id
            GROUP BY sp.id
            ORDER BY [total cobrado cop] DESC""")
    }
}
