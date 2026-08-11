package dev.nanoai.mobile

import org.tukaani.xz.XZInputStream
import java.io.BufferedInputStream
import java.io.ByteArrayInputStream
import java.io.OutputStream

/**
 * Decoder XZ real basado en la librería oficial de Tukaani.
 *
 * Mantiene la misma API local para no tocar el resto del instalador,
 * pero delega la descompresión a una implementación estándar y probada.
 */
object XzDecoder {

    class XzException(msg: String) : Exception(msg)

    fun decompressToStream(input: ByteArray, out: OutputStream): Long {
        try {
            BufferedInputStream(ByteArrayInputStream(input), 64 * 1024).use { src ->
                XZInputStream(src).use { xz ->
                    val buf = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val n = xz.read(buf)
                        if (n < 0) break
                        if (n == 0) continue
                        out.write(buf, 0, n)
                        total += n.toLong()
                    }
                    out.flush()
                    return total
                }
            }
        } catch (e: Exception) {
            throw XzException(e.message ?: e.javaClass.simpleName)
        }
    }
}
