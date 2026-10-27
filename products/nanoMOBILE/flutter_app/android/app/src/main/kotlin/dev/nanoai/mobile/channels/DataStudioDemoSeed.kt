package dev.nanoai.mobile.channels

import android.database.sqlite.SQLiteDatabase

/**
 * QUÉ: inserta registros sintéticos claramente identificados para la demostración.
 * CÓMO: usa lotes deterministas dentro de la transacción abierta por la base.
 * POR QUÉ: ofrece relaciones y métricas repetibles sin usar datos personales.
 */
internal object DataStudioDemoSeed {
    fun insertAll(db: SQLiteDatabase) {
        insertServices(db)
        insertClients(db)
        insertProjects(db)
        insertPayments(db)
    }

    // Catálogo ilustrativo con importes de ejemplo, no una lista comercial.
    private fun insertServices(db: SQLiteDatabase) {
        arrayOf(
            arrayOf(1, "Aplicación móvil", "Mobile", 3_500_000.0, 921.0,
                "Flutter, Material 3 y canal nativo"),
            arrayOf(2, "Integración de base de datos", "Backend", 1_200_000.0, 316.0,
                "SQLite, PostgreSQL o MySQL"),
            arrayOf(3, "API REST autenticada", "Backend", 2_000_000.0, 526.0,
                "API documentada con roles"),
            arrayOf(4, "Migración de datos", "Datos", 800_000.0, 210.0,
                "Limpieza, normalización y ETL"),
            arrayOf(5, "Panel administrativo", "Frontend", 2_500_000.0, 658.0,
                "CRUD y panel de métricas"),
            arrayOf(6, "Automatización de mensajería", "Automatización", 1_800_000.0, 474.0,
                "Flujos, agenda y seguimiento"),
            arrayOf(7, "Integración de modelo local", "IA", 3_000_000.0, 789.0,
                "Inferencia local y búsqueda semántica"),
            arrayOf(8, "Auditoría de código", "Consultoría", 900_000.0, 237.0,
                "Diagnóstico y refactorización"),
        ).forEach {
            db.execSQL(
                "INSERT INTO servicios_programacion VALUES (?,?,?,?,?,?,1)",
                it,
            )
        }
    }

    // Identidades y correos reservados para documentación evitan datos reales.
    private fun insertClients(db: SQLiteDatabase) {
        arrayOf(
            arrayOf(1, "Cliente demostración 01", "Tecnología", "Medellín",
                "cliente01@example.invalid", "2025-01-10"),
            arrayOf(2, "Cliente demostración 02", "Comercio", "Bogotá",
                "cliente02@example.invalid", "2025-03-05"),
            arrayOf(3, "Cliente demostración 03", "Salud", "Cali",
                "cliente03@example.invalid", "2025-04-18"),
            arrayOf(4, "Cliente demostración 04", "Marketing", "Medellín",
                "cliente04@example.invalid", "2025-06-01"),
            arrayOf(5, "Cliente demostración 05", "Construcción", "Pereira",
                "cliente05@example.invalid", "2025-07-20"),
            arrayOf(6, "Cliente demostración 06", "Servicios", "Remoto",
                "cliente06@example.invalid", "2025-09-02"),
        ).forEach { db.execSQL("INSERT INTO clientes VALUES (?,?,?,?,?,?)", it) }
    }

    // Los estados y fechas ejercitan filtros, series temporales y relaciones.
    private fun insertProjects(db: SQLiteDatabase) {
        arrayOf(
            arrayOf(1, 1, 1, "Proyecto móvil A", "2025-01-15", "2025-03-30", 3_500_000.0, "Entregado"),
            arrayOf(2, 1, 7, "Proyecto IA A", "2025-04-01", "2025-05-15", 3_000_000.0, "Entregado"),
            arrayOf(3, 2, 2, "Proyecto datos A", "2025-03-10", "2025-03-28", 1_200_000.0, "Entregado"),
            arrayOf(4, 2, 4, "Migración A", "2025-04-05", "2025-04-10", 800_000.0, "Entregado"),
            arrayOf(5, 3, 3, "API A", "2025-04-20", "2025-06-10", 2_000_000.0, "Entregado"),
            arrayOf(6, 3, 5, "Panel A", "2025-06-15", "2025-08-01", 2_500_000.0, "Entregado"),
            arrayOf(7, 4, 6, "Automatización A", "2025-06-05", "2025-07-01", 1_800_000.0, "Entregado"),
            arrayOf(8, 5, 1, "Proyecto móvil B", "2025-07-25", null, 3_500_000.0, "En curso"),
            arrayOf(9, 5, 2, "Proyecto datos B", "2025-08-01", null, 1_200_000.0, "En curso"),
            arrayOf(10, 6, 8, "Auditoría A", "2025-09-05", "2025-09-20", 900_000.0, "Entregado"),
        ).forEach { db.execSQL("INSERT INTO proyectos VALUES (?,?,?,?,?,?,?,?)", it) }
    }

    // Pagos sintéticos permiten validar sumas y agrupaciones con SQL real.
    private fun insertPayments(db: SQLiteDatabase) {
        arrayOf(
            arrayOf(1, 1, "2025-01-15", 1_750_000.0, "Transferencia", "Anticipo"),
            arrayOf(2, 1, "2025-04-01", 1_750_000.0, "Transferencia", "Saldo"),
            arrayOf(3, 2, "2025-04-01", 3_000_000.0, "Transferencia", "Pago completo"),
            arrayOf(4, 3, "2025-03-10", 600_000.0, "Transferencia", "Anticipo"),
            arrayOf(5, 3, "2025-03-29", 600_000.0, "Transferencia", "Saldo"),
            arrayOf(6, 4, "2025-04-10", 800_000.0, "Transferencia", "Pago completo"),
            arrayOf(7, 5, "2025-04-20", 1_000_000.0, "Transferencia", "Anticipo"),
            arrayOf(8, 5, "2025-06-11", 1_000_000.0, "Transferencia", "Saldo"),
            arrayOf(9, 6, "2025-08-02", 2_500_000.0, "Transferencia", "Pago completo"),
            arrayOf(10, 7, "2025-06-05", 900_000.0, "Transferencia", "Anticipo"),
            arrayOf(11, 7, "2025-07-02", 900_000.0, "Transferencia", "Saldo"),
            arrayOf(12, 8, "2025-07-25", 1_750_000.0, "Transferencia", "Anticipo"),
            arrayOf(13, 10, "2025-09-20", 900_000.0, "Transferencia", "Pago completo"),
        ).forEach { db.execSQL("INSERT INTO pagos VALUES (?,?,?,?,?,?)", it) }
    }
}
