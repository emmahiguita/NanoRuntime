// ─────────────────────────────────────────────────────────────────────────────
// iosMain · dev.nanoai.core.messaging · PlatformHashProvider.kt
//
// QUÉ  : `actual object PlatformHashProvider` para iOS.
//         Usa CommonCrypto (CC_SHA256) disponible de forma nativa en iOS.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.messaging

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import platform.CoreCrypto.CC_SHA256
import platform.CoreCrypto.CC_SHA256_DIGEST_LENGTH

actual object PlatformHashProvider {
    @OptIn(ExperimentalForeignApi::class)
    actual fun sha256Hex(input: String): String {
        val bytes = input.encodeToByteArray()
        if (bytes.isEmpty()) {
            // SHA-256 de cadena vacía
            return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
        val digest = UByteArray(CC_SHA256_DIGEST_LENGTH.toInt())
        bytes.usePinned { pinnedBytes ->
            digest.usePinned { pinnedDigest ->
                CC_SHA256(
                    pinnedBytes.addressOf(0),
                    bytes.size.toUInt(),
                    pinnedDigest.addressOf(0),
                )
            }
        }
        return digest.joinToString("") { byte ->
            byte.toString(16).padStart(2, '0')
        }
    }
}
