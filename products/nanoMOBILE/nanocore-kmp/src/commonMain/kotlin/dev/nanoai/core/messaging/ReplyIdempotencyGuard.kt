// ─────────────────────────────────────────────────────────────────────────────
// commonMain · dev.nanoai.core.messaging · ReplyIdempotencyGuard.kt
//
// QUÉ  : Guard de idempotencia para envíos de respuesta.
//         Puerto directo de ReplyAttemptLedger.kt (Android) a commonMain.
// POR QUÉ: En iOS las respuestas se envían por URLScheme / CallKit en lugar
//           de RemoteInput, pero el guard de at-most-once es exactamente igual.
//           Un único archivo evita dos implementaciones que diverjan.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.messaging

/** Resultado de intentar reservar un intento de envío. */
enum class Reservation { RESERVED, DUPLICATE, PERSISTENCE_FAILED }

/**
 * Guard de at-most-once para envíos de respuesta.
 * [readEntries] y [writeEntries] son lambdas inyectadas por cada plataforma:
 *   - Android usa SharedPreferences.
 *   - iOS usa UserDefaults.
 */
class ReplyIdempotencyGuard(
    private val readEntries: () -> Set<String>,
    private val writeEntries: (Set<String>) -> Boolean,
    private val capacity: Int = 1024,
) {
    @Synchronized
    fun reserve(attemptId: String): Reservation {
        if (attemptId.isBlank() || capacity < 1) return Reservation.PERSISTENCE_FAILED
        val entries = try {
            LinkedHashSet(readEntries())
        } catch (_: Exception) {
            return Reservation.PERSISTENCE_FAILED
        }
        if (attemptId in entries) return Reservation.DUPLICATE
        entries += attemptId
        while (entries.size > capacity) entries.remove(entries.first())
        return if (runCatching { writeEntries(entries) }.getOrDefault(false)) {
            Reservation.RESERVED
        } else {
            Reservation.PERSISTENCE_FAILED
        }
    }

    @Synchronized
    fun release(attemptId: String): Boolean {
        val entries = try {
            LinkedHashSet(readEntries())
        } catch (_: Exception) {
            return false
        }
        if (!entries.remove(attemptId)) return true
        return runCatching { writeEntries(entries) }.getOrDefault(false)
    }
}

/**
 * Calcula un ID de intento sin información sensible usando SHA-256.
 * Función de utilidad pura; compilable en commonMain gracias a kotlin.io.
 *
 * NOTE: kotlinx-crypto está disponible en KMP; aquí usamos una
 *       implementación mínima para no añadir dependencias.
 */
fun replyAttemptId(
    notificationKey: String,
    notificationRevision: Long,
    actionIndex: Int,
    remoteInputKey: String,
    contextFingerprint: String,
    attemptNonce: String = "",
): String {
    val canonical = listOf(
        notificationKey,
        notificationRevision.toString(),
        actionIndex.toString(),
        remoteInputKey,
        contextFingerprint,
        attemptNonce,
    ).joinToString("\u0000")
    // En commonMain no hay MessageDigest; delegamos el hash a la plataforma.
    return PlatformHashProvider.sha256Hex(canonical)
}

/**
 * Proveedor de SHA-256 que cada plataforma implementa.
 * Android: java.security.MessageDigest
 * iOS    : CommonCrypto (CC_SHA256) vía cinterop
 */
expect object PlatformHashProvider {
    fun sha256Hex(input: String): String
}
