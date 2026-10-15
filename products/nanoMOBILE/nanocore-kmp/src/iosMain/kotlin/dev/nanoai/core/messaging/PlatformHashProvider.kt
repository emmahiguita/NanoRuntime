// ─────────────────────────────────────────────────────────────────────────────
// iosMain · dev.nanoai.core.messaging · PlatformHashProvider.kt
//
// QUÉ  : `actual object PlatformHashProvider` para iOS.
//         Usa CommonCrypto (CC_SHA256) disponible en todos los iPhones/iPads.
// CÓMO : Kotlin/Native puede importar CommonCrypto directamente mediante
//         `import platform.Security.*` o mediante cinterop con CommonCrypto.def.
//         Aquí se usa la aproximación Foundation/CryptoKit disponible en iOS 13+.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.messaging

import platform.Foundation.NSData
import platform.Foundation.NSString
import platform.Foundation.NSUTF8StringEncoding
import platform.Foundation.dataUsingEncoding

actual object PlatformHashProvider {
    actual fun sha256Hex(input: String): String {
        // CryptoKit está disponible desde iOS 13 — mínimo del proyecto es ≥ 15.
        // La implementación completa usa CryptoKit vía cinterop o SHA256.hash(data:).
        // Aquí se proporciona la firma correcta; el cuerpo real se conecta en la
        // tarea de cinterop de CryptoKit.def.
        val data: NSData = (input as NSString).dataUsingEncoding(NSUTF8StringEncoding) ?: return ""
        return CryptoKitBridge.sha256Hex(data)
    }
}

/**
 * Stub del bridge hacia CryptoKit / CommonCrypto para iOS.
 * Se implementará con la función C CC_SHA256() mediante cinterop.
 */
internal object CryptoKitBridge {
    fun sha256Hex(data: NSData): String {
        // Implementación real: CC_SHA256(data.bytes, data.length, digest)
        TODO("Implementar cinterop con CommonCrypto / CryptoKit")
    }
}
