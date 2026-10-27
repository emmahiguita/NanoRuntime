package dev.nanoai.mobile

import java.io.InputStream
import java.security.MessageDigest

/** Huella del ejecutable incluido en el APK para evitar reutilizar runtimes viejos. */
internal object EngineAssetFingerprint {
    // QUÉ HACE: Calcula SHA-256 de un flujo sin retener el binario completo en memoria.
    // CÓMO FUNCIONA: Lee bloques acotados, actualiza MessageDigest y convierte el resultado a hexadecimal.
    // POR QUÉ: El supervisor debe distinguir dos runtimes que tengan el mismo tamaño de archivo.
    fun sha256(input: InputStream): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(64 * 1024)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            if (count > 0) digest.update(buffer, 0, count)
        }

        val hex = "0123456789abcdef"
        val bytes = digest.digest()
        val chars = CharArray(bytes.size * 2)
        bytes.forEachIndexed { index, byte ->
            val value = byte.toInt() and 0xff
            chars[index * 2] = hex[value ushr 4]
            chars[index * 2 + 1] = hex[value and 0x0f]
        }
        return String(chars)
    }
}
