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

    class XzException(msg: String, cause: Throwable? = null) : Exception(msg, cause)

    fun decompressToStream(input: ByteArray, out: OutputStream): Long {
        try {
            BufferedInputStream(ByteArrayInputStream(input), 64 * 1024).use { src ->
                XZInputStream(src).use { xz ->
                    val buf = ByteArray(64 * 1024)
                    var total = 0L
                    var zeroReads = 0
                    while (true) {
                        val n = xz.read(buf)
                        if (n < 0) break
                        if (n == 0) {
                            // F13: read()==0 sin EOF no avanza el stream — si
                            // se repite es un stream colgado; continuar sería
                            // un busy-loop infinito.
                            if (++zeroReads > 32) {
                                throw XzException("read() devolvió 0 repetidamente — stream XZ colgado")
                            }
                            continue
                        }
                        zeroReads = 0
                        out.write(buf, 0, n)
                        total += n.toLong()
                    }
                    out.flush()
                    return total
                }
            }
        } catch (e: XzException) {
            throw e
        } catch (e: Exception) {
            throw XzException(e.message ?: e.javaClass.simpleName, e)
        }
    }
}
