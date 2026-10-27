package dev.nanoai.mobile.services

/** Fuentes reales del selector Flutter existente; preparar nunca envía archivos. */
internal object NanoPanelAttachments {
    val options = listOf(
        NanoPanelTool("AttachCamera", "Cámara", "Preparar una foto desde la cámara."),
        NanoPanelTool("AttachPhotos", "Fotos", "Preparar una imagen de la galería."),
        NanoPanelTool("AttachFiles", "Archivos", "Preparar un archivo del dispositivo."),
    )

    /** Traduce exclusivamente las opciones de adjuntos al contrato del puente. */
    fun source(tool: String): String? = when (tool) {
        "AttachCamera" -> "camera"
        "AttachPhotos" -> "photos"
        "AttachFiles" -> "files"
        else -> null
    }
}
