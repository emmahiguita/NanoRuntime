package dev.nanoai.mobile.channels

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WhatsAppAutoSendPolicyTest {
    @Test
    fun `missing or malformed opt in never enables auto send`() {
        assertFalse(WhatsAppAutoSendPolicy.isRequested(null))
        assertFalse(WhatsAppAutoSendPolicy.isRequested(emptyMap<String, Any?>()))
        assertFalse(WhatsAppAutoSendPolicy.isRequested(mapOf("autoSend" to null)))
        assertFalse(WhatsAppAutoSendPolicy.isRequested(mapOf("autoSend" to "true")))
    }

    @Test
    fun `only an explicit true enables auto send`() {
        assertTrue(WhatsAppAutoSendPolicy.isRequested(mapOf("autoSend" to true)))
        assertFalse(WhatsAppAutoSendPolicy.isRequested(mapOf("autoSend" to false)))
    }
}
