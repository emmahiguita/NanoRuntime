package dev.nanoai.mobile

import java.io.File
import java.net.URL

/** Centraliza la politica de rutas y URLs aceptadas por los canales nativos. */
class SecurePathPolicy(private val appFilesDir: File) {
    private fun nanoFilesDir(): File = File(appFilesDir, "nano").canonicalFile

    fun isInsideNanoFiles(file: File): Boolean {
        val base = nanoFilesDir()
        val candidate = file.canonicalFile
        return candidate.path == base.path || candidate.path.startsWith(base.path + File.separator)
    }

    fun requireInsideNanoFiles(file: File, label: String): File {
        val candidate = file.canonicalFile
        if (!isInsideNanoFiles(candidate)) {
            throw IllegalArgumentException("$label fuera de files/nano")
        }
        return candidate
    }

    fun requireSafeDownloadUrl(urlStr: String) {
        val url = URL(urlStr)
        val protocol = url.protocol.lowercase()
        val host = url.host.lowercase()
        val loopback = host == "127.0.0.1" || host == "localhost" || host == "::1" || host == "[::1]"
        if (protocol != "https" && !(protocol == "http" && loopback)) {
            throw IllegalArgumentException("solo HTTPS o HTTP loopback")
        }
    }
}
