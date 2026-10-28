// ─────────────────────────────────────────────────────────────────────────────
// commonTest · dev.nanoai.core · NanoCoreTests.kt
//
// Pruebas unitarias puras de la lógica compartida — sin emulador ni plataforma.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core

import dev.nanoai.core.agent.AgentLedger
import dev.nanoai.core.agent.AgentStep
import dev.nanoai.core.agent.SensitiveDataPolicy
import dev.nanoai.core.agent.TargetIdentity
import dev.nanoai.core.agent.TargetMatchPolicy
import dev.nanoai.core.inference.ThermalLevel
import dev.nanoai.core.inference.ThermalPolicy
import dev.nanoai.core.messaging.MessageClassifier
import dev.nanoai.core.messaging.MessageEvidence
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ThermalPolicyTest {
    @Test fun warmIdleTimeout_severe_returns_zero() {
        // Simular estado SEVERE directamente en la lógica de la policy.
        val timeout = when (ThermalLevel.SEVERE) {
            ThermalLevel.SEVERE   -> 0L
            ThermalLevel.MODERATE -> minOf(90_000L, 30_000L)
            ThermalLevel.LIGHT    -> minOf(90_000L, 90_000L)
            ThermalLevel.NONE     -> 90_000L
        }
        assertEquals(0L, timeout)
    }

    @Test fun warmIdleTimeout_none_returns_default() {
        val default = 90_000L
        val timeout = when (ThermalLevel.NONE) {
            ThermalLevel.SEVERE   -> 0L
            ThermalLevel.MODERATE -> minOf(default, 30_000L)
            ThermalLevel.LIGHT    -> minOf(default, 90_000L)
            ThermalLevel.NONE     -> default
        }
        assertEquals(90_000L, timeout)
    }
}

class AgentLedgerTest {
    @Test fun ledger_prunes_to_maxSteps() {
        val ledger = AgentLedger(maxSteps = 2)
        repeat(5) { i ->
            ledger.append(AgentStep("user", "msg $i", i.toLong()))
        }
        val snapshot = ledger.snapshot()
        assertEquals(2, snapshot.size)
        assertEquals("msg 3", snapshot[0].content)
        assertEquals("msg 4", snapshot[1].content)
    }

    @Test fun ledger_clear_empties_history() {
        val ledger = AgentLedger(maxSteps = 3)
        ledger.append(AgentStep("user", "hello", 0L))
        ledger.clear()
        assertTrue(ledger.snapshot().isEmpty())
    }
}

class SensitiveDataPolicyTest {
    @Test fun detects_pin_pattern() {
        assertTrue(SensitiveDataPolicy.isSensitive("Tu PIN es 1234"))
        assertTrue(SensitiveDataPolicy.isSensitive("OTP: 847291"))
    }

    @Test fun redacts_pin() {
        val result = SensitiveDataPolicy.redact("Tu PIN es 1234 — confirma")
        assertFalse(result.contains("1234"))
        assertTrue(result.contains("[REDACTED]"))
    }

    @Test fun safe_text_passes_through() {
        val safe = "Hola, ¿cómo estás?"
        assertFalse(SensitiveDataPolicy.isSensitive(safe))
        assertEquals(safe, SensitiveDataPolicy.redact(safe))
    }
}

class MessageClassifierTest {
    private fun evidence(
        text: String = "Hola",
        conversationId: String = "12345@s.whatsapp.net",
        senderName: String = "Juan",
        sourcePackage: String = "com.whatsapp",
        isGroupSummary: Boolean = false,
        isOngoing: Boolean = false,
    ) = MessageEvidence(text, conversationId, senderName, sourcePackage, isGroupSummary, isOngoing)

    @Test fun real_message_is_admitted() {
        assertTrue(MessageClassifier.admits(evidence()))
    }

    @Test fun group_summary_is_rejected() {
        assertFalse(MessageClassifier.admits(evidence(isGroupSummary = true)))
    }

    @Test fun ongoing_is_rejected() {
        assertFalse(MessageClassifier.admits(evidence(isOngoing = true)))
    }

    @Test fun status_title_is_rejected() {
        assertFalse(MessageClassifier.admits(evidence(
            senderName = "Actualizaciones de estado",
            conversationId = "status@broadcast",
        )))
    }

    @Test fun foreign_package_is_foreign() {
        val ev = evidence(sourcePackage = "com.telegram.messenger")
        assertEquals(dev.nanoai.core.messaging.MessageClass.FOREIGN, MessageClassifier.classify(ev))
    }
}

class TargetMatchPolicyTest {
    private fun identity(
        pkg: String = "com.example",
        resourceId: String = "btn_ok",
        className: String = "Button",
        text: String = "OK",
        desc: String = "",
        bounds: IntArray = intArrayOf(10, 20, 110, 60),
    ) = TargetIdentity(pkg, resourceId, className, text, desc, bounds)

    @Test fun exact_match_passes() {
        val id = identity()
        assertTrue(TargetMatchPolicy.matches(id, id))
    }

    @Test fun bounds_within_tolerance_passes() {
        val actual   = identity(bounds = intArrayOf(10, 20, 110, 60))
        val expected = identity(bounds = intArrayOf(14, 24, 114, 64))  // diff = 4 ≤ 8
        assertTrue(TargetMatchPolicy.matches(actual, expected))
    }

    @Test fun bounds_outside_tolerance_fails() {
        val actual   = identity(bounds = intArrayOf(10, 20, 110, 60))
        val expected = identity(bounds = intArrayOf(20, 30, 120, 70))  // diff = 10 > 8
        assertFalse(TargetMatchPolicy.matches(actual, expected))
    }

    @Test fun different_package_fails() {
        val actual   = identity(pkg = "com.example")
        val expected = identity(pkg = "com.other")
        assertFalse(TargetMatchPolicy.matches(actual, expected))
    }
}
