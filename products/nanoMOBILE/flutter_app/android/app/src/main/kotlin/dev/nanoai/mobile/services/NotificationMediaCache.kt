package dev.nanoai.mobile.services

import android.app.Notification
import android.app.Notification.MessagingStyle
import android.content.ContentResolver
import android.graphics.Bitmap
import android.os.Bundle
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

/**
 * QUÉ HACE:
 * Gestiona el almacenamiento temporal y la purga automática de adjuntos multimedia
 * (imágenes, audios de voz, videos, PDFs) extraídos de las notificaciones entrantes.
 *
 * CÓMO FUNCIONA:
 * - Guarda los archivos en el subdirectorio de caché `nano_notif_media/`.
 * - Aplica una política de purga FIFO/TTL antes de cada escritura:
 *   - Límite máximo de cuota: 50 MB.
 *   - TTL máximo por archivo: 48 horas.
 * - Si se excede la cuota o el tiempo, elimina los archivos más antiguos primero.
 *
 * POR QUÉ:
 * Previene fugas de almacenamiento masivo y saturación del almacenamiento interno del
 * dispositivo móvil en chats de alto volumen multimedia (solución auditada [MEM-001]).
 */
object NotificationMediaCache {
    private const val MEDIA_DIR_NAME = "nano_notif_media"
    private const val MAX_CACHE_BYTES = 50L * 1024L * 1024L // 50 MB
    private const val MAX_FILE_AGE_MS = 48L * 3600L * 1000L // 48 horas

    fun getMediaDir(cacheDir: File): File {
        val dir = File(cacheDir, MEDIA_DIR_NAME)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    /**
     * Purga oportunista de archivos viejos o que superen la cuota en caché.
     */
    fun purgeMediaCache(cacheDir: File) {
        try {
            val dir = File(cacheDir, MEDIA_DIR_NAME)
            if (!dir.exists() || !dir.isDirectory) return

            val files = dir.listFiles() ?: return
            val now = System.currentTimeMillis()
            var totalBytes = 0L

            // 1. Eliminar archivos que superen el TTL de 48h
            for (file in files) {
                if (now - file.lastModified() > MAX_FILE_AGE_MS) {
                    file.delete()
                } else {
                    totalBytes += file.length()
                }
            }

            // 2. Si la suma excede 50MB, eliminar los más antiguos primero
            if (totalBytes > MAX_CACHE_BYTES) {
                val remainingFiles = dir.listFiles()?.sortedBy { it.lastModified() } ?: return
                for (file in remainingFiles) {
                    if (totalBytes <= MAX_CACHE_BYTES) break
                    val len = file.length()
                    if (file.delete()) {
                        totalBytes -= len
                    }
                }
            }
        } catch (_: Exception) {
            // Ignorar fallos de IO en purga de caché temporal
        }
    }

    fun saveImage(
        cacheDir: File,
        contentResolver: ContentResolver,
        extras: Bundle?,
        messages: List<MessagingStyle.Message>?,
        postTime: Long
    ): String? {
        if (extras == null) return null
        purgeMediaCache(cacheDir)
        return try {
            val imgMsg = messages?.lastOrNull {
                it.dataMimeType?.startsWith("image/") == true && it.dataUri != null
            }
            val dir = getMediaDir(cacheDir)
            if (imgMsg?.dataUri != null) {
                val extension = when (imgMsg.dataMimeType?.lowercase(Locale.ROOT)) {
                    "image/png" -> "png"
                    "image/webp" -> "webp"
                    else -> "jpg"
                }
                val file = File(dir, "img_${postTime}.$extension")
                contentResolver.openInputStream(imgMsg.dataUri!!)?.use { input ->
                    FileOutputStream(file).use { out -> input.copyTo(out) }
                } ?: return null
                file.absolutePath
            } else {
                val bitmap = extras.get(Notification.EXTRA_PICTURE) as? Bitmap
                    ?: (extras.getParcelable("android.picture") as? Bitmap)
                if (bitmap == null) return null
                val file = File(dir, "img_${postTime}.jpg")
                FileOutputStream(file).use { out ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                }
                file.absolutePath
            }
        } catch (_: Exception) {
            null
        }
    }

    fun saveVideo(
        cacheDir: File,
        contentResolver: ContentResolver,
        messages: List<MessagingStyle.Message>?,
        postTime: Long
    ): String? {
        if (messages == null || messages.isEmpty()) return null
        purgeMediaCache(cacheDir)
        return try {
            val vidMsg = messages.lastOrNull {
                it.dataMimeType?.startsWith("video/") == true && it.dataUri != null
            } ?: return null
            val dir = getMediaDir(cacheDir)
            val file = File(dir, "vid_${postTime}.mp4")
            contentResolver.openInputStream(vidMsg.dataUri!!)?.use { input ->
                FileOutputStream(file).use { out -> input.copyTo(out) }
            } ?: return null
            file.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    fun saveAudio(
        cacheDir: File,
        contentResolver: ContentResolver,
        messages: List<MessagingStyle.Message>?,
        postTime: Long
    ): String? {
        if (messages == null || messages.isEmpty()) return null
        purgeMediaCache(cacheDir)
        return try {
            val audioMsg = messages.lastOrNull {
                it.dataMimeType?.startsWith("audio/") == true && it.dataUri != null
            } ?: return null
            val dir = getMediaDir(cacheDir)
            val file = File(dir, "voice_${postTime}.opus")
            contentResolver.openInputStream(audioMsg.dataUri!!)?.use { input ->
                FileOutputStream(file).use { out -> input.copyTo(out) }
            } ?: return null
            file.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    fun savePdf(
        cacheDir: File,
        contentResolver: ContentResolver,
        messages: List<MessagingStyle.Message>?,
        postTime: Long
    ): String? {
        if (messages == null || messages.isEmpty()) return null
        purgeMediaCache(cacheDir)
        return try {
            val pdfMsg = messages.lastOrNull {
                it.dataMimeType.equals("application/pdf", ignoreCase = true) && it.dataUri != null
            } ?: return null
            val dir = getMediaDir(cacheDir)
            val file = File(dir, "document_${postTime}.pdf")
            contentResolver.openInputStream(pdfMsg.dataUri!!)?.use { input ->
                FileOutputStream(file).use { out -> input.copyTo(out) }
            } ?: return null
            file.absolutePath
        } catch (_: Exception) {
            null
        }
    }
}
