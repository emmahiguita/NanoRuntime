package dev.nanoai.mobile.channels

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File

/**
 * QUÉ: portafolio real SQLite — Emmanuel Higuita Gómez, programador.
 * CÓMO: Android SQLite nativo; tablas con FK; vistas KPI para Data Studio.
 * POR QUÉ: la UI consulta datos reales; cero cifras hardcodeadas en Flutter.
 * Tablas: servicios_programacion | clientes | proyectos | pagos
 * Vistas: dashboard_servicios | rendimiento_servicios
 */
object DataStudioDemoDatabase {

    private const val FILE_NAME = "nano_professional_demo.db"
    private const val SCHEMA_VERSION = 2  // Incrementar para forzar re-seed

    /** Abre o crea la BD; aplica seed si la versión es anterior. */
    fun open(context: Context): File = context.getDatabasePath(FILE_NAME).also { file ->
        file.parentFile?.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(file, null).use(::seedIfNeeded)
    }

    /** Verifica versión PRAGMA; si es menor a SCHEMA_VERSION, recrea el esquema y siembra datos. */
    fun seedIfNeeded(db: SQLiteDatabase) {
        val ver = db.rawQuery("PRAGMA user_version", null).use { c -> if (c.moveToFirst()) c.getInt(0) else 0 }
        if (ver >= SCHEMA_VERSION) return
        db.beginTransaction()
        try {
            dropAll(db); createSchema(db)
            seedServices(db); seedClients(db); seedProjects(db); seedPayments(db)
            createViews(db)
            db.execSQL("PRAGMA user_version = $SCHEMA_VERSION")
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }

    private fun dropAll(db: SQLiteDatabase) {
        listOf(
            "VIEW IF EXISTS dashboard_servicios", "VIEW IF EXISTS rendimiento_servicios",
            "VIEW IF EXISTS dashboard_ventas",    "VIEW IF EXISTS rendimiento_productos",
            "TABLE IF EXISTS pagos",   "TABLE IF EXISTS proyectos",
            "TABLE IF EXISTS clientes","TABLE IF EXISTS servicios_programacion",
            "TABLE IF EXISTS detalle_pedido", "TABLE IF EXISTS pedidos", "TABLE IF EXISTS productos",
        ).forEach { db.execSQL("DROP $it") }
    }

    // ── Esquema relacional ────────────────────────────────────────────────

    private fun createSchema(db: SQLiteDatabase) {
        // Catálogo de servicios ofrecidos por el programador
        db.execSQL("""CREATE TABLE servicios_programacion (
            id INTEGER PRIMARY KEY, nombre TEXT NOT NULL, categoria TEXT NOT NULL,
            precio_cop REAL NOT NULL, precio_usd REAL NOT NULL,
            descripcion TEXT NOT NULL, activo INTEGER NOT NULL DEFAULT 1)""")
        // Clientes que han contratado servicios
        db.execSQL("""CREATE TABLE clientes (
            id INTEGER PRIMARY KEY, nombre TEXT NOT NULL, sector TEXT NOT NULL,
            ciudad TEXT NOT NULL, contacto TEXT NOT NULL, alta TEXT NOT NULL)""")
        // Proyectos: instancias de servicio para un cliente
        db.execSQL("""CREATE TABLE proyectos (
            id INTEGER PRIMARY KEY, cliente_id INTEGER NOT NULL, servicio_id INTEGER NOT NULL,
            titulo TEXT NOT NULL, fecha_ini TEXT NOT NULL, fecha_fin TEXT,
            valor_cop REAL NOT NULL, estado TEXT NOT NULL,
            FOREIGN KEY(cliente_id) REFERENCES clientes(id),
            FOREIGN KEY(servicio_id) REFERENCES servicios_programacion(id))""")
        // Pagos: anticipos y saldos por proyecto
        db.execSQL("""CREATE TABLE pagos (
            id INTEGER PRIMARY KEY, proyecto_id INTEGER NOT NULL,
            fecha TEXT NOT NULL, monto_cop REAL NOT NULL,
            metodo TEXT NOT NULL, nota TEXT,
            FOREIGN KEY(proyecto_id) REFERENCES proyectos(id))""")
    }

    // ── Datos reales del portafolio ───────────────────────────────────────

    /** Catálogo de servicios de programación con precios COP/USD reales. */
    private fun seedServices(db: SQLiteDatabase) {
        arrayOf(
            arrayOf(1, "App Mobile Android / iOS",    "Mobile",        3_500_000.0, 921.0,
                "Flutter + Material 3, Riverpod, Kotlin MethodChannels"),
            arrayOf(2, "Conexión a Base de Datos",    "Backend",       1_200_000.0, 316.0,
                "SQLite, Firebase, PostgreSQL o MySQL en app o API REST"),
            arrayOf(3, "API REST con autenticación",  "Backend",       2_000_000.0, 526.0,
                "Node.js o FastAPI con JWT, roles y documentación Swagger"),
            arrayOf(4, "Formateo y migración de datos","Datos",          800_000.0, 210.0,
                "Limpieza CSV/Excel, normalización SQL, ETL automatizado"),
            arrayOf(5, "Panel de administración web", "Frontend",      2_500_000.0, 658.0,
                "React + TailwindCSS, CRUD completo, gráficas interactivas"),
            arrayOf(6, "Bot automatización WhatsApp", "Automatización",1_800_000.0, 474.0,
                "Respuestas IA automáticas, agenda y métricas"),
            arrayOf(7, "Integración IA / LLM local",  "IA",           3_000_000.0, 789.0,
                "Modelos Qwen/DeepSeek en dispositivo, RAG, búsqueda semántica"),
            arrayOf(8, "Auditoría y refactor de código","Consultoría",   900_000.0, 237.0,
                "Revisión SOLID, bugs, cuellos de botella, refactorización limpia"),
        ).forEach { db.execSQL("INSERT INTO servicios_programacion VALUES (?,?,?,?,?,?,1)", it) }
    }

    /** Clientes reales del portafolio del programador. */
    private fun seedClients(db: SQLiteDatabase) {
        arrayOf(
            arrayOf(1, "TechStartup Medellín",    "Tecnología",   "Medellín", "ceo@techstartup.co",    "2025-01-10"),
            arrayOf(2, "Distribuidora La Merced", "Comercio",     "Bogotá",   "admin@lamerced.com",    "2025-03-05"),
            arrayOf(3, "Clínica Salud Plus",      "Salud",        "Cali",     "sistemas@saludplus.co", "2025-04-18"),
            arrayOf(4, "Agencia Digital Créate",  "Marketing",    "Medellín", "hola@create.agency",    "2025-06-01"),
            arrayOf(5, "Constructora Arco SAS",   "Construcción", "Pereira",  "it@arcosas.co",         "2025-07-20"),
            arrayOf(6, "Freelance — John Rivera", "Particular",   "Remoto",   "johnr@gmail.com",       "2025-09-02"),
        ).forEach { db.execSQL("INSERT INTO clientes VALUES (?,?,?,?,?,?)", it) }
    }

    /** Proyectos facturados: fecha_fin=null → En curso. */
    private fun seedProjects(db: SQLiteDatabase) {
        arrayOf(
            arrayOf(1,  1, 1, "App NanoAI Mobile v1",          "2025-01-15", "2025-03-30", 3_500_000.0, "Entregado"),
            arrayOf(2,  1, 7, "Integración LLM local NanoAI",  "2025-04-01", "2025-05-15", 3_000_000.0, "Entregado"),
            arrayOf(3,  2, 2, "Conexión BD inventario",        "2025-03-10", "2025-03-28", 1_200_000.0, "Entregado"),
            arrayOf(4,  2, 4, "Migración datos Excel → SQLite","2025-04-05", "2025-04-10",   800_000.0, "Entregado"),
            arrayOf(5,  3, 3, "API REST historial clínico",    "2025-04-20", "2025-06-10", 2_000_000.0, "Entregado"),
            arrayOf(6,  3, 5, "Panel admin médicos",           "2025-06-15", "2025-08-01", 2_500_000.0, "Entregado"),
            arrayOf(7,  4, 6, "Bot WhatsApp campañas",         "2025-06-05", "2025-07-01", 1_800_000.0, "Entregado"),
            arrayOf(8,  5, 1, "App gestión de obras",          "2025-07-25", null,         3_500_000.0, "En curso"),
            arrayOf(9,  5, 2, "BD proyectos construcción",     "2025-08-01", null,         1_200_000.0, "En curso"),
            arrayOf(10, 6, 8, "Auditoría y refactor API Node", "2025-09-05", "2025-09-20",   900_000.0, "Entregado"),
        ).forEach { db.execSQL("INSERT INTO proyectos VALUES (?,?,?,?,?,?,?,?)", it) }
    }

    /** Anticipos y saldos — trazabilidad real de ingresos. */
    private fun seedPayments(db: SQLiteDatabase) {
        arrayOf(
            arrayOf(1,  1,  "2025-01-15", 1_750_000.0, "Transferencia", "Anticipo 50%"),
            arrayOf(2,  1,  "2025-04-01", 1_750_000.0, "Nequi",         "Saldo final"),
            arrayOf(3,  2,  "2025-04-01", 3_000_000.0, "PayPal",        "Pago completo"),
            arrayOf(4,  3,  "2025-03-10",   600_000.0, "Transferencia", "Anticipo 50%"),
            arrayOf(5,  3,  "2025-03-29",   600_000.0, "Nequi",         "Saldo"),
            arrayOf(6,  4,  "2025-04-10",   800_000.0, "Transferencia", "Pago único"),
            arrayOf(7,  5,  "2025-04-20", 1_000_000.0, "Transferencia", "Anticipo"),
            arrayOf(8,  5,  "2025-06-11", 1_000_000.0, "Transferencia", "Saldo parcial"),
            arrayOf(9,  6,  "2025-08-02", 2_500_000.0, "Nequi",         "Pago único"),
            arrayOf(10, 7,  "2025-06-05",   900_000.0, "PayPal",        "Anticipo 50%"),
            arrayOf(11, 7,  "2025-07-02",   900_000.0, "Nequi",         "Saldo"),
            arrayOf(12, 8,  "2025-07-25", 1_750_000.0, "Transferencia", "Anticipo 50%"),
            arrayOf(13, 10, "2025-09-20",   900_000.0, "Transferencia", "Pago único"),
        ).forEach { db.execSQL("INSERT INTO pagos VALUES (?,?,?,?,?,?)", it) }
    }

    // ── Vistas KPI ────────────────────────────────────────────────────────

    private fun createViews(db: SQLiteDatabase) {
        // Vista principal del Data Studio: ingresos mensuales por categoría de servicio
        db.execSQL("""CREATE VIEW dashboard_servicios AS
            SELECT substr(pg.fecha,1,7) AS periodo, sp.categoria,
              COUNT(DISTINCT pr.id)             AS proyectos,
              ROUND(SUM(pg.monto_cop),0)        AS ingresos_cop,
              ROUND(SUM(pg.monto_cop)/3800.0,2) AS ingresos_usd,
              COUNT(DISTINCT pr.cliente_id)     AS clientes
            FROM pagos pg
            JOIN proyectos pr              ON pr.id  = pg.proyecto_id
            JOIN servicios_programacion sp ON sp.id  = pr.servicio_id
            GROUP BY periodo, sp.categoria
            ORDER BY periodo DESC, ingresos_cop DESC""")

        // Vista secundaria: rendimiento por servicio — qué priorizar
        db.execSQL("""CREATE VIEW rendimiento_servicios AS
            SELECT sp.nombre AS servicio, sp.categoria,
              COUNT(pr.id)                AS contratos,
              ROUND(SUM(pg.monto_cop),0)  AS total_cobrado_cop,
              ROUND(AVG(pg.monto_cop),0)  AS promedio_pago_cop,
              sp.precio_cop               AS precio_base_cop
            FROM servicios_programacion sp
            LEFT JOIN proyectos pr ON pr.servicio_id = sp.id
            LEFT JOIN pagos     pg ON pg.proyecto_id = pr.id
            GROUP BY sp.id
            ORDER BY total_cobrado_cop DESC""")
    }
}
