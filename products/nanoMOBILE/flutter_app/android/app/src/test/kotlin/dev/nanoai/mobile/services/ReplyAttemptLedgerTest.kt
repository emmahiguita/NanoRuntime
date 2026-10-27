package dev.nanoai.mobile.services

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ReplyAttemptLedgerTest {
    @Test
    fun `same durable capability is reserved only once across ledger instances`() {
        var durableEntries = emptySet<String>()
        fun ledger() = ReplyAttemptLedger(
            readEntries = { durableEntries },
            writeEntries = { entries -> durableEntries = entries; true },
        )
        val id = replyAttemptId("whatsapp:42", 1234L, 1, "quick_reply", "chat-a")

        assertEquals(ReplyAttemptLedger.Reservation.RESERVED, ledger().reserve(id))
        assertEquals(ReplyAttemptLedger.Reservation.DUPLICATE, ledger().reserve(id))
        assertEquals(1, durableEntries.size)
    }

    @Test
    fun `a new notification revision permits its own reply`() {
        val first = replyAttemptId("whatsapp:42", 1234L, 1, "quick_reply", "chat-a")
        val next = replyAttemptId("whatsapp:42", 5678L, 1, "quick_reply", "chat-a")

        assertNotEquals(first, next)
    }

    @Test
    fun `ledger fails closed when durable reservation cannot be written`() {
        val ledger = ReplyAttemptLedger(
            readEntries = { emptySet() },
            writeEntries = { false },
        )

        assertEquals(
            ReplyAttemptLedger.Reservation.PERSISTENCE_FAILED,
            ledger.reserve("capability"),
        )
    }

    @Test
    fun `failed remote dispatch can release its reservation for a safe retry`() {
        var durableEntries = emptySet<String>()
        val ledger = ReplyAttemptLedger(
            readEntries = { durableEntries },
            writeEntries = { entries -> durableEntries = entries; true },
        )

        assertEquals(ReplyAttemptLedger.Reservation.RESERVED, ledger.reserve("capability"))
        assertTrue(ledger.release("capability"))
        assertEquals(ReplyAttemptLedger.Reservation.RESERVED, ledger.reserve("capability"))
    }
}
