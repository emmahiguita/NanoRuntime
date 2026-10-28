// ─────────────────────────────────────────────────────────────────────────────
// commonMain · dev.nanoai.core.agent · SensitiveDataPolicy.kt
//
// QUÉ  : Detección y redacción de datos sensibles (contraseñas, PINs, OTPs).
//         Traslado de NanoSensitiveDataPolicy (Dart) a Kotlin puro.
// POR QUÉ: La misma política de privacidad debe aplicarse en Android e iOS
//           antes de que cualquier texto llegue al motor de inferencia local
//           o a una respuesta saliente.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.agent

/**
 * Política de privacidad compartida: detecta y redacta información sensible.
 * Implementación 100 % Kotlin/stdlib — sin dependencias de plataforma.
 */
object SensitiveDataPolicy {
    // PIN / código de 4-8 dígitos precedido de palabras clave.
    private val pinPattern = Regex(
        """(?i)\b(pin|código|code|contraseña|password|clave|otp|token|cvv)\b[:\s]*\d{4,8}\b""",
    )

    // Secuencia de dígitos sola (≥6) entre espacios o inicio/fin — OTP probable.
    private val otpPattern = Regex("""(?<!\d)\d{6,8}(?!\d)""")

    /** true si el texto contiene información potencialmente sensible. */
    fun isSensitive(text: String): Boolean =
        pinPattern.containsMatchIn(text) || otpPattern.containsMatchIn(text)

    /**
     * Reemplaza los fragmentos sensibles detectados con `[REDACTED]`.
     * Nunca lanza: si el regex falla, devuelve el texto original.
     */
    fun redact(text: String): String = runCatching {
        var result = pinPattern.replace(text) { m ->
            m.value.replace(Regex("""\d{4,8}"""), "[REDACTED]")
        }
        result = otpPattern.replace(result, "[REDACTED]")
        result
    }.getOrDefault(text)
}
