// ─────────────────────────────────────────────────────────────────────────────
// androidMain · dev.nanoai.core.messaging · PlatformHashProvider.kt
//
// QUÉ  : `actual object PlatformHashProvider` para Android.
//         Usa java.security.MessageDigest (disponible desde API 1).
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.messaging

import java.security.MessageDigest

actual object PlatformHashProvider {
    actual fun sha256Hex(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(input.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
    }
}
