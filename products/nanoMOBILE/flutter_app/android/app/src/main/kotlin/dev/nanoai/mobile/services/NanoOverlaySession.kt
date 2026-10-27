package dev.nanoai.mobile.services

/** Estado de la sesión propietaria del overlay, independiente de la ventana.
 * Apartar el panel para abrir WhatsApp no destruye el borrador ni el resultado.
 * No persiste conversaciones ni ficheros fuera de este servicio Android. */
internal class NanoOverlaySession {
    var tool = "Chat"
    var draft = ""
    var result: String? = null

    /** Consume el aviso guardado; el historial de ejecución pertenece al
     * coordinador, no a esta copia temporal de presentación. */
    fun takeResult(): String? = result.also { result = null }
}
