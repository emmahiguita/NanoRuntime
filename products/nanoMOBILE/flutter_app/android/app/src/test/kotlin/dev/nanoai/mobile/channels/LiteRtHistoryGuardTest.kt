package dev.nanoai.mobile.channels

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LiteRtHistoryGuardTest {

    @Test
    fun `reconstruye si SQLite agrega estado de evidencia que no estaba en KV`() {
        val expected = listOf(
            LiteRtGeneration.Turn("user", "Hola, cómo vas?"),
            LiteRtGeneration.Turn("assistant", "¡Todo muy bien! ¿Y tú qué tal?"),
        )
        val incomingFromSqlite = listOf(
            LiteRtGeneration.Turn("user", "Hola, cómo vas?"),
            LiteRtGeneration.Turn(
                "assistant",
                "[Mensaje despachado por Nano; entrega no verificada]\n¡Todo muy bien! ¿Y tú qué tal?",
            ),
        )

        assertFalse(
            LiteRtGeneration.canReuseHistory(
                expected = expected,
                incoming = incomingFromSqlite,
                forceReset = false,
            ),
        )
    }

    @Test
    fun `invalida sesion cuando QualityGate rechaza el borrador y se reintenta el mismo turno`() {
        // Tras el intento 1, la sesión nativa quedó con el turno rechazado al final:
        val expectedAfterAttempt1 = listOf(
            LiteRtGeneration.Turn("user", "Hola"),
            LiteRtGeneration.Turn("assistant", "¡Hola! ¿Cómo estás?"),
            LiteRtGeneration.Turn("user", "Me gusta el fútbol"),
            LiteRtGeneration.Turn("assistant", "¡Genial! ¿Eres fan del fútbol?"),
        )
        // Al reintentar en QualityGate, el historial canónico de SQLite NO contiene el turno rechazado:
        val incomingForRetry = listOf(
            LiteRtGeneration.Turn("user", "Hola"),
            LiteRtGeneration.Turn("assistant", "¡Hola! ¿Cómo estás?"),
        )

        assertFalse(
            "No debe reutilizar la sesión contaminada con el turno rechazado",
            LiteRtGeneration.canReuseHistory(
                expected = expectedAfterAttempt1,
                incoming = incomingForRetry,
                forceReset = false,
            ),
        )
    }

    @Test
    fun `invalida sesion en el siguiente turno si el borrador anterior fue descartado y no enviado`() {
        val expectedAfterRejectedTurn = listOf(
            LiteRtGeneration.Turn("user", "Qué haces?"),
            LiteRtGeneration.Turn("assistant", "Estoy trabajando en la oficina"),
        )
        // En el siguiente turno, SQLite registró el mensaje entrante previo pero NO la respuesta rechazada:
        val incomingOnNextTurn = listOf(
            LiteRtGeneration.Turn("user", "Qué haces?"),
        )

        assertFalse(
            "No debe reutilizar la sesión si la respuesta anterior fue descartada por seguridad",
            LiteRtGeneration.canReuseHistory(
                expected = expectedAfterRejectedTurn,
                incoming = incomingOnNextTurn,
                forceReset = false,
            ),
        )
    }

    @Test
    fun `no reutiliza KV cuando se retiro el contexto vivo del turno anterior`() {
        val promptWithLiveFacts = """
            <DATOS EN VIVO>
            Fecha y hora local actual: viernes 16 de octubre de 2026, 12:30.
            </DATOS EN VIVO>

            Mensaje actual:
            ¿Ya almorzaste?
        """.trimIndent()

        assertFalse(LiteRtGeneration.canReuseHistory(
            listOf(LiteRtGeneration.Turn("user", promptWithLiveFacts)),
            listOf(LiteRtGeneration.Turn("user", "¿Ya almorzaste?")),
        ))
    }

    @Test fun `solo el historial identico puede reutilizar KV`() {
        val turns = listOf(LiteRtGeneration.Turn("user", "hola"), LiteRtGeneration.Turn("assistant", "Hola"))
        assertTrue(LiteRtGeneration.canReuseHistory(turns, turns))
        assertFalse(LiteRtGeneration.canReuseHistory(turns, turns, true))
        assertFalse(LiteRtGeneration.canReuseHistory(turns, turns.takeLast(1)))
    }

    @Test fun `una alternativa elegida no equivale a todas las alternativas generadas`() {
        assertFalse(LiteRtGeneration.canReuseHistory(
            listOf(LiteRtGeneration.Turn("assistant", "Primera || Segunda")),
            listOf(LiteRtGeneration.Turn("assistant", "Primera")),
        ))
    }
}
