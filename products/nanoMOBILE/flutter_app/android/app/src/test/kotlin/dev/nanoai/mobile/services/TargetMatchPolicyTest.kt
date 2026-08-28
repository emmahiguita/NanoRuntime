package dev.nanoai.mobile.services

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TargetMatchPolicyTest {
    private val expected = TargetIdentity(
        packageName = "com.chat",
        resourceId = "com.chat:id/send",
        className = "android.widget.Button",
        text = "",
        description = "Enviar",
        bounds = intArrayOf(900, 1800, 1040, 1960),
    )

    @Test
    fun `exact identity matches`() {
        assertTrue(TargetMatchPolicy.matches(expected.copy(), expected))
    }

    @Test
    fun `bounds tolerate only minor layout drift`() {
        assertTrue(
            TargetMatchPolicy.matches(
                expected.copy(bounds = intArrayOf(908, 1792, 1048, 1968)),
                expected,
            ),
        )
        assertFalse(
            TargetMatchPolicy.matches(
                expected.copy(bounds = intArrayOf(909, 1800, 1040, 1960)),
                expected,
            ),
        )
    }

    @Test
    fun `changed package id or description is rejected`() {
        assertFalse(TargetMatchPolicy.matches(expected.copy(packageName = "com.other"), expected))
        assertFalse(TargetMatchPolicy.matches(expected.copy(resourceId = "com.chat:id/delete"), expected))
        assertFalse(TargetMatchPolicy.matches(expected.copy(description = "Eliminar"), expected))
    }

    @Test
    fun `blank optional fields behave as wildcards but package never does`() {
        val minimal = expected.copy(
            resourceId = "",
            className = "",
            text = "",
            description = "",
        )
        assertTrue(TargetMatchPolicy.matches(expected, minimal))
        assertFalse(TargetMatchPolicy.matches(expected.copy(packageName = ""), minimal))
    }
}
