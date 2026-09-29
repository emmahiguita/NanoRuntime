package dev.nanoai.mobile.services

import java.security.MessageDigest

/**
 * Durable at-most-once guard for a WhatsApp notification reply capability.
 * A notification key + revision is the unit Android exposes for RemoteInput;
 * replaying it must never create a second outgoing message.
 */
internal class ReplyAttemptLedger(
    private val readEntries: () -> Set<String>,
    private val writeEntries: (Set<String>) -> Boolean,
    private val capacity: Int = 1024,
) {
    enum class Reservation { RESERVED, DUPLICATE, PERSISTENCE_FAILED }

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

/** Hashes capability metadata so persisted idempotency records contain no chat text or raw notification key. */
internal fun replyAttemptId(
    notificationKey: String,
    notificationRevision: Long,
    actionIndex: Int,
    remoteInputKey: String,
    contextFingerprint: String,
): String {
    val canonical = listOf(
        notificationKey,
        notificationRevision.toString(),
        actionIndex.toString(),
        remoteInputKey,
        contextFingerprint,
    ).joinToString("\u0000")
    return MessageDigest.getInstance("SHA-256")
        .digest(canonical.toByteArray(Charsets.UTF_8))
        .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
}
