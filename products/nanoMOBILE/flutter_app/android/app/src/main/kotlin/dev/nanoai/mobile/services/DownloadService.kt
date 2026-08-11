package dev.nanoai.mobile

import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

/** Servicio unico para descargas controladas hacia el sandbox files/nano. */
class DownloadService(private val pathPolicy: SecurePathPolicy) {
    companion object {
        const val DEFAULT_MAX_DOWNLOAD_BYTES: Long = 1024L * 1024L * 1024L // 1 GiB
        const val BOOTSTRAP_MAX_DOWNLOAD_BYTES: Long = 2L * 1024L * 1024L * 1024L // 2 GiB
    }

    fun downloadToFile(
        urlStr: String,
        destFile: File,
        readTimeoutMs: Int = 300_000,
        maxBytes: Long = DEFAULT_MAX_DOWNLOAD_BYTES,
        onProgress: (Int, String) -> Unit,
    ) {
        require(maxBytes > 0) { "maxBytes must be positive" }
        pathPolicy.requireSafeDownloadUrl(urlStr)
        val safeDest = pathPolicy.requireInsideNanoFiles(destFile, "destPath")
        safeDest.parentFile?.mkdirs()
        val partFile = File(safeDest.parentFile, "${safeDest.name}.part")

        val conn = URL(urlStr).openConnection() as HttpURLConnection
        conn.connectTimeout = 15_000
        conn.readTimeout = readTimeoutMs
        conn.instanceFollowRedirects = true
        try {
            conn.connect()
            val total = conn.contentLengthLong
            if (total > maxBytes) {
                throw IllegalStateException("Download too large: $total bytes > limit $maxBytes bytes")
            }
            if (partFile.exists() && !partFile.delete()) {
                throw IllegalStateException("Cannot remove stale partial download: ${partFile.absolutePath}")
            }
            BufferedInputStream(conn.inputStream).use { input ->
                FileOutputStream(partFile).use { output ->
                    val buffer = ByteArray(8192)
                    var downloaded = 0L
                    var bytesRead: Int
                    var lastPct = -1
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        val nextDownloaded = downloaded + bytesRead
                        if (nextDownloaded > maxBytes) {
                            throw IllegalStateException(
                                "Download exceeded limit: $nextDownloaded bytes > $maxBytes bytes"
                            )
                        }
                        output.write(buffer, 0, bytesRead)
                        downloaded = nextDownloaded
                        if (total > 0) {
                            val pct = (downloaded * 100 / total).toInt()
                            if (pct != lastPct) {
                                lastPct = pct
                                onProgress(pct, "$downloaded/$total")
                            }
                        }
                    }
                }
            }
            if (safeDest.exists() && !safeDest.delete()) {
                throw IllegalStateException("Cannot replace existing file: ${safeDest.absolutePath}")
            }
            if (!partFile.renameTo(safeDest)) {
                partFile.copyTo(safeDest, overwrite = true)
                if (!partFile.delete()) {
                    android.util.Log.w("download", "partial file cleanup failed: ${partFile.absolutePath}")
                }
            }
            onProgress(100, "done")
        } catch (e: Exception) {
            if (partFile.exists() && !partFile.delete()) {
                android.util.Log.w("download", "partial file cleanup failed: ${partFile.absolutePath}")
            }
            throw e
        } finally {
            conn.disconnect()
        }
    }
}
