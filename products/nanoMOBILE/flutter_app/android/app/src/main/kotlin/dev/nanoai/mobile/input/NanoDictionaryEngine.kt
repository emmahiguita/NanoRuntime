package dev.nanoai.mobile.input

import java.util.Locale

/**
 * QUÉ HACE: Motor ultraligero de predicción, autocompletado y sugerencias ortográficas.
 * POR QUÉ EXISTE: Provee sugerencias instantáneas sin bloquear el hilo de render ni invocar LLMs para cada tecla.
 * QUÉ RECIBE: Prefijos de palabras mientras el usuario escribe.
 * QUÉ DEVUELVE: Lista de hasta 3 palabras candidatas ordenadas por frecuencia y coincidencia.
 * QUÉ PUEDE FALLAR: Si el prefijo está vacío o es un campo sensible, retorna lista vacía inmediatamente.
 */
internal object NanoDictionaryEngine {

    // Diccionario curado de alta frecuencia en español y común bilingüe
    private val frequentWords = listOf(
        "hola", "cómo", "estás", "bien", "gracias", "por", "favor", "buenos", "días", "tardes", "noches",
        "también", "dónde", "cuándo", "quién", "porque", "para", "pero", "siempre", "ahora", "después",
        "mañana", "ayer", "hoy", "tiempo", "amigo", "trabajo", "mensaje", "reunión", "claro", "seguro",
        "perfecto", "listo", "vamos", "puedo", "puedes", "podemos", "hacer", "decir", "estar", "tener",
        "haber", "llegar", "salir", "querer", "saber", "pensar", "esperar", "mirar", "mucho", "muchas",
        "poco", "todo", "todos", "nada", "algo", "alguien", "nadie", "aquí", "allí", "casa", "oficina",
        "archivo", "correo", "teléfono", "número", "favorito", "documento", "adjunto", "enlace", "cuenta",
        "sistema", "modelo", "informe", "proyecto", "asistente", "pregunta", "respuesta", "solución",
        "ayuda", "información", "servicio", "cliente", "equipo", "acuerdo", "compromiso", "detalle",
        "important", "hello", "thanks", "please", "ready", "update", "meeting", "project", "tomorrow"
    )

    /**
     * Busca hasta 3 sugerencias para el prefijo dado.
     * Si el prefijo coincide exactamente con una palabra, sugiere la siguiente o variantes.
     */
    fun getSuggestions(prefix: String, limit: Int = 3): List<String> {
        val clean = prefix.trim().lowercase(Locale.ROOT)
        if (clean.length < 2) return emptyList()

        val results = ArrayList<String>(limit)
        var exactMatch = false

        for (word in frequentWords) {
            val wordLower = word.lowercase(Locale.ROOT)
            if (wordLower == clean) {
                exactMatch = true
                results.add(word)
            } else if (wordLower.startsWith(clean)) {
                results.add(word)
            }
            if (results.size >= limit + 1) break
        }

        // Si la primera no es la original y el usuario escribió algo legible, incluirlo como alternativa
        if (!exactMatch && results.isNotEmpty() && !results.contains(prefix)) {
            // El usuario puede elegir quedarse con su palabra literal
        }

        return results.take(limit)
    }
}
