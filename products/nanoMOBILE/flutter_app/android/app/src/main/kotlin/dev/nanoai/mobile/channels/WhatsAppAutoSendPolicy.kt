package dev.nanoai.mobile.channels

/** Native-side opt-in policy shared by WhatsApp text and media intents. */
internal object WhatsAppAutoSendPolicy {
    fun isRequested(arguments: Map<*, *>?): Boolean =
        arguments?.get("autoSend") as? Boolean ?: false
}
