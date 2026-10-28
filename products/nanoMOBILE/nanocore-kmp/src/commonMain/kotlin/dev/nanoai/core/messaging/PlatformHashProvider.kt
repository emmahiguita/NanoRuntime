package dev.nanoai.core.messaging

/**
 * Proveedor de hash criptográfico SHA-256 multiplataforma.
 * - En Android delega a java.security.MessageDigest.
 * - En iOS delega a CommonCrypto (CC_SHA256).
 */
expect object PlatformHashProvider {
    fun sha256Hex(input: String): String
}
