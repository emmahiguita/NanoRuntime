package dev.nanoai.mobile.services

/** Regla pura de la fila WhatsApp; una selección desconocida no significa borrador. */
internal object NanoWhatsAppComposerEvidence {
    /** El OPPO observado publica -1/-1 aunque entry esté enfocado y vacío.
     * Solo admite ese valor cuando un único control de voz visible sustituye
     * al de envío en el contenedor del editor. No usa palabras del contenido. */
    fun isEmpty(
        nodeSelectionStart: Int,
        nodeSelectionEnd: Int,
        visibleSendCount: Int,
        visibleVoiceCount: Int,
    ): Boolean = nodeSelectionStart in -1..0 && nodeSelectionEnd in -1..0 &&
        visibleSendCount == 0 && visibleVoiceCount == 1
}
