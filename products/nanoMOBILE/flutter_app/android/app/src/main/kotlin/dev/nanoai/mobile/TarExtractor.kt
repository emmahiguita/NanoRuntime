package dev.nanoai.mobile

import java.io.File
import java.io.FileInputStream
import java.io.BufferedInputStream

/**
 * Extractor tar puro en Kotlin — descomprime el tar plano resultante de
 * XzDecoder al rootfs, preservando archivos, permisos y symlinks.
 *
 * Formato tar (POSIX ustar): bloques de 512 bytes. Header:
 *   name(100) mode(8) uid(8) gid(8) size(12) mtime(12) chksum(8)
 *   typeflag(1) linkname(100) magic(6) version(2) uname(32) gname(32)
 *   devmajor(8) devminor(8) prefix(155) pad(12)
 *
 * typeflag: '0'/'\0'=archivo, '5'=directorio, '2'=symlink, '1'=hardlink,
 *           'x'/'g'=extended headers (GNU/PAX — se ignoran, el siguiente
 *           header es el real), 'L'=long name (GNU).
 */
object TarExtractor {

    class TarException(msg: String) : Exception(msg)

    /**
     * Extrae [tarData] dentro de [destRoot]. [stripComponents] elimina N
     * directorios del prefijo de cada entrada (los .deb Termux usan
     * ./data/data/com.termux/files/usr/... → strip 5 → usr/...).
     * Retorna el número de entradas extraídas.
     */
    fun extract(tarData: ByteArray, destRoot: File, stripComponents: Int): Int {
        return extractInternal(tarData, destRoot, stripComponents)
    }

    /** Streaming real: extrae desde archivo tar usando InputStream.
     *  Sin RandomAccessFile (evita mmap implícito en Android).
     *  Solo carga header (512B) + payload de cada entrada por vez. */
    fun extract(tarFile: File, destRoot: File, stripComponents: Int): Int {
        var count = 0
        val pendingHardlinks = mutableListOf<Pair<File, String>>()
        var pendingLongName: String? = null

        BufferedInputStream(FileInputStream(tarFile), 65536).use { stream ->
            val header = ByteArray(512)

            while (true) {
                // Leer header de 512 bytes
                var read = 0
                while (read < 512) {
                    val n = stream.read(header, read, 512 - read)
                    if (n < 0) return count // EOF
                    read += n
                }

                // Fin del tar: bloque de ceros
                if (allZero(header, 0, 512)) break

                val name = readField(header, 0, 100)
                val mode = parseOctal(header, 100, 8)
                val size = parseOctal(header, 124, 12).toLong()
                val typeFlag = header[156].toInt().toChar()
                val linkName = readField(header, 157, 100)
                val prefix = readField(header, 345, 155)

                var fullName = pendingLongName ?: if (prefix.isNotEmpty()) "$prefix/$name" else name
                pendingLongName = null
                val paddedSize = padTo512(size)

                // GNU long name: el payload contiene el nombre real de la
                // siguiente entrada. Guardarlo y continuar.
                if (typeFlag == 'L') {
                    val longBuf = ByteArray(size.toInt())
                    readFully(stream, longBuf)
                    pendingLongName = String(longBuf).trimEnd('\u0000')
                    skipFully(stream, paddedSize - size)
                    continue
                }
                // PAX extended headers: skip
                if (typeFlag == 'x' || typeFlag == 'g') {
                    skipFully(stream, paddedSize)
                    continue
                }

                val relPath = stripPrefix(fullName, stripComponents)
                if (relPath.isEmpty() || relPath == ".") {
                    skipFully(stream, paddedSize)
                    continue
                }

                val target = File(destRoot, relPath).normalize()
                if (!target.absolutePath.startsWith(destRoot.absolutePath)) {
                    skipFully(stream, paddedSize)
                    continue
                }

                when (typeFlag) {
                    '5' -> { // directorio
                        if (target.exists() && !target.isDirectory) {
                            java.nio.file.Files.deleteIfExists(target.toPath())
                        }
                        target.mkdirs()
                        target.setReadable(true, false); target.setWritable(true, false)
                        target.setExecutable(true, false)
                        count++
                        if (paddedSize > 0) skipFully(stream, paddedSize)
                    }
                    '2' -> { // symlink
                        target.parentFile?.mkdirs()
                        try {
                            // Si el destino es un DIRECTORIO (p.ej. el stub xkb de
                            // prepareX11), deleteIfExists lanza DirectoryNotEmpty.
                            // El symlink del tar debe REEMPLAZAR el directorio.
                            if (target.isDirectory) {
                                target.deleteRecursively()
                            } else {
                                java.nio.file.Files.deleteIfExists(target.toPath())
                            }
                            java.nio.file.Files.createSymbolicLink(
                                target.toPath(), java.nio.file.Paths.get(linkName))
                        } catch (_: Exception) {
                            try { target.writeText(linkName) } catch (_: Exception) {}
                        }
                        count++
                        if (paddedSize > 0) skipFully(stream, paddedSize)
                    }
                    '1' -> { // hardlink
                        pendingHardlinks.add(target to linkName)
                        count++
                        if (paddedSize > 0) skipFully(stream, paddedSize)
                    }
                    '0', '\u0000' -> { // archivo regular
                        target.parentFile?.mkdirs()
                        if (target.isDirectory) {
                            target.deleteRecursively()
                        } else if (java.nio.file.Files.isSymbolicLink(target.toPath())) {
                            java.nio.file.Files.deleteIfExists(target.toPath())
                        }
                        target.outputStream().use { out ->
                            var remaining = size
                            val buf = ByteArray(65536)
                            while (remaining > 0) {
                                val chunk = minOf(remaining, buf.size.toLong()).toInt()
                                readFully(stream, buf, chunk)
                                out.write(buf, 0, chunk)
                                remaining -= chunk
                            }
                        }
                        applyMode(target, mode)
                        count++
                        // Saltar padding después del payload
                        val pad = paddedSize - size
                        if (pad > 0) skipFully(stream, pad)
                    }
                    else -> {
                        if (paddedSize > 0) skipFully(stream, paddedSize)
                    }
                }
            }
        }

        // Resolver hardlinks
        for ((dest, linkPath) in pendingHardlinks) {
            val src = File(destRoot, linkPath)
            if (src.exists()) { dest.parentFile?.mkdirs(); src.copyTo(dest, overwrite = true) }
        }
        return count
    }

    private fun readFully(input: java.io.InputStream, buf: ByteArray) {
        readFully(input, buf, buf.size)
    }

    private fun readFully(input: java.io.InputStream, buf: ByteArray, len: Int) {
        var off = 0
        while (off < len) {
            val n = input.read(buf, off, len - off)
            if (n < 0) throw TarException("EOF inesperado en tar")
            off += n
        }
    }

    private fun skipFully(input: java.io.InputStream, n: Long) {
        var remaining = n
        while (remaining > 0) {
            val skipped = input.skip(remaining)
            if (skipped <= 0) {
                // skip() puede retornar 0; leer y descartar como fallback
                val dummy = ByteArray(minOf(remaining, 65536L).toInt())
                val r = input.read(dummy)
                if (r < 0) throw TarException("EOF inesperado en skip de tar")
                remaining -= r
            } else {
                remaining -= skipped
            }
        }
    }

    private fun extractInternal(tarData: ByteArray, destRoot: File, stripComponents: Int): Int {
        var pos = 0
        var count = 0
        // Pares path→target para hardlinks (se resuelven al final).
        val pendingHardlinks = mutableListOf<Pair<File, String>>()

        while (pos + 512 <= tarData.size) {
            // Fin del tar: bloque de ceros.
            if (allZero(tarData, pos, 512)) break

            val name = readField(tarData, pos, 100)
            val mode = parseOctal(tarData, pos + 100, 8)
            val size = parseOctal(tarData, pos + 124, 12)
            val typeFlag = tarData[pos + 156].toInt().toChar()
            val linkName = readField(tarData, pos + 157, 100)
            val prefix = readField(tarData, pos + 345, 155)

            var fullName = if (prefix.isNotEmpty()) "$prefix/$name" else name
            // PAX 'L' (GNU long name): el nombre real está en el payload.
            if (typeFlag == 'L') {
                val longName = String(tarData, pos + 512, size.toInt()).trimEnd('\u0000')
                fullName = longName
                pos += 512 + padTo512(size)
                continue
            }
            // PAX 'x'/'g': extended headers — saltar, el header siguiente
            // contiene los datos reales con el nombre correcto.
            if (typeFlag == 'x' || typeFlag == 'g') {
                pos += 512 + padTo512(size)
                continue
            }

            val relPath = stripPrefix(fullName, stripComponents)
            if (relPath.isEmpty() || relPath == ".") {
                pos += 512 + padTo512(size)
                continue
            }
            // Path traversal guard: el destino debe quedar dentro de destRoot.
            val target = File(destRoot, relPath).normalize()
            if (!target.absolutePath.startsWith(destRoot.absolutePath)) {
                pos += 512 + padTo512(size)
                continue
            }

            when (typeFlag) {
                '5' -> { // directorio
                    if (target.exists() && !target.isDirectory) {
                        java.nio.file.Files.deleteIfExists(target.toPath())
                    }
                    target.mkdirs()
                    target.setReadable(true, false)
                    target.setWritable(true, false)
                    target.setExecutable(true, false)
                    count++
                }
                '2' -> { // symlink
                    target.parentFile?.mkdirs()
                    try {
                        // Si el destino es un DIRECTORIO (p.ej. el stub xkb de
                        // prepareX11), deleteIfExists lanza DirectoryNotEmpty.
                        // El symlink del tar debe REEMPLAZAR el directorio.
                        if (target.isDirectory) {
                            target.deleteRecursively()
                        } else {
                            java.nio.file.Files.deleteIfExists(target.toPath())
                        }
                        java.nio.file.Files.createSymbolicLink(
                            target.toPath(), java.nio.file.Paths.get(linkName)
                        )
                        count++
                    } catch (e: Exception) {
                        // Sin permiso symlink: escribir el target como texto.
                        try { target.writeText(linkName) } catch (_: Exception) {}
                        count++
                    }
                }
                '1' -> { // hardlink: resolver después
                    pendingHardlinks.add(target to linkName)
                    count++
                }
                '0', '\u0000' -> { // archivo regular
                    target.parentFile?.mkdirs()
                    if (target.isDirectory) {
                        target.deleteRecursively()
                    } else if (java.nio.file.Files.isSymbolicLink(target.toPath())) {
                        java.nio.file.Files.deleteIfExists(target.toPath())
                    }
                    val payload = java.io.ByteArrayInputStream(
                        tarData, pos + 512, size.toInt()
                    )
                    payload.use { inp ->
                        target.outputStream().use { outp ->
                            inp.copyTo(outp)
                        }
                    }
                    applyMode(target, mode)
                    count++
                }
                else -> { /* 'D' etc. — ignorar */ }
            }
            pos += 512 + padTo512(size)
        }

        // Resolver hardlinks (copiar del target referenciado).
        for ((dest, linkPath) in pendingHardlinks) {
            val src = File(destRoot, linkPath)
            if (src.exists()) {
                dest.parentFile?.mkdirs()
                src.copyTo(dest, overwrite = true)
            }
        }
        return count
    }

    private fun applyMode(f: File, mode: Int) {
        if (mode <= 0) return
        f.setReadable((mode and 0x124) != 0, false)
        f.setWritable((mode and 0x092) != 0, false)
        f.setExecutable((mode and 0x049) != 0, false)
    }

    private fun stripPrefix(path: String, n: Int): String {
        if (n <= 0) return path.trimStart('/')
        var p = path.trimStart('/')
        var count = n
        while (count > 0) {
            val idx = p.indexOf('/')
            if (idx < 0) return ""
            p = p.substring(idx + 1)
            count--
        }
        return p
    }

    private fun padTo512(size: Int): Int {
        val full = 512L + size
        return ((full + 511) / 512 * 512).toInt() - 512
    }

    private fun padTo512(size: Long): Long {
        val full = 512L + size
        return ((full + 511) / 512 * 512) - 512
    }

    private fun readField(b: ByteArray, off: Int, len: Int): String {
        val end = (off + len).coerceAtMost(b.size)
        var i = off
        while (i < end && b[i] != 0.toByte()) i++
        return String(b, off, i - off).trim()
    }

    private fun parseOctal(b: ByteArray, off: Int, len: Int): Int {
        var v = 0
        val end = (off + len).coerceAtMost(b.size)
        for (i in off until end) {
            val c = b[i].toInt()
            if (c == 0 || c == ' '.code) break
            if (c == '0'.code && v == 0) continue
            if (c < '0'.code || c > '7'.code) break
            v = v * 8 + (c - '0'.code)
        }
        return v
    }

    private fun allZero(b: ByteArray, off: Int, len: Int): Boolean {
        val end = (off + len).coerceAtMost(b.size)
        for (i in off until end) if (b[i] != 0.toByte()) return false
        return true
    }
}
