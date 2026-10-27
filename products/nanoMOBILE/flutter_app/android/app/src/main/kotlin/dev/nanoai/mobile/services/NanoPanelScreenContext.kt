package dev.nanoai.mobile.services

/** Describe únicamente lectura de accesibilidad; no captura píxeles ni fotos.
 * La consulta mantiene su texto original y Flutter recibe los datos por separado. */
internal object NanoPanelScreenContext {
    private val explicitReference = Regex(
        "\\b(pantalla|screen)\\b|qu[eé]\\s+ves|lo\\s+que\\s+ves|" +
            "(?:esta|esa)\\s+(?:foto|imagen)|(?:foto|imagen)\\s+(?:actual|visible)",
        RegexOption.IGNORE_CASE,
    )

    /** Solo observa al pedir explícitamente pantalla o seleccionar su lector. */
    fun isRequested(tool: String, prompt: String): Boolean =
        tool == "Resumir" || explicitReference.containsMatchIn(prompt)

    /** Etiqueta el origen y límite real para impedir inferencias visuales. */
    fun asBridgeData(screen: NanoScreenReader.ScreenData?): Map<String, Any?> = mapOf(
        "source" to "accessibility_text",
        "imageAvailable" to false,
        "package" to screen?.packageName.orEmpty(),
        "text" to screen?.visibleText.orEmpty(),
        "links" to screen?.links.orEmpty(),
    )

    /** El lector muestra evidencia textual sin atribuir comprensión de imágenes. */
    fun reading(screen: NanoScreenReader.ScreenData?): String =
        if (screen == null || screen.visibleText.isBlank()) {
            "No hay texto accesible de pantalla disponible. Activa la accesibilidad de Nano " +
                "desde Automatización. Este lector no analiza fotos ni imágenes."
        } else {
            "Texto accesible de ${screen.packageName}:\n\n${screen.visibleText}\n\n" +
                "Lectura textual; no se capturó ni analizó una imagen."
        }
}
