package dev.nanoai.mobile.media

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import androidx.core.content.ContextCompat

/** Consulta incremental del proveedor Android; sin búsqueda recursiva ni acceso privado. */
internal class WhatsAppMediaCatalogSource(private val context: Context, private val db: WhatsAppMediaCatalogDb) {
    /** Permisos actuales, no cacheados. Selección parcial no autoriza enumerar toda la galería. */
    fun allowedKinds(): Set<String> = listOf("image", "video", "audio").filter { kind ->
        val permission = if (Build.VERSION.SDK_INT < 33) Manifest.permission.READ_EXTERNAL_STORAGE else when (kind) {
            "image" -> Manifest.permission.READ_MEDIA_IMAGES
            "video" -> Manifest.permission.READ_MEDIA_VIDEO
            else -> Manifest.permission.READ_MEDIA_AUDIO
        }
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }.toSet()

    /** Un lote de 120 cambios por tipo; persiste generación + ID para reanudar. */
    fun scan(): Map<String, Any> {
        check(Build.VERSION.SDK_INT >= 30) { "Incremental index requires Android 11" }
        val allowed = allowedKinds()
        require(allowed.isNotEmpty()) { "No media permission" }
        val volume = MediaStore.VOLUME_EXTERNAL_PRIMARY
        val version = MediaStore.getVersion(context, volume).orEmpty()
        var count = 0
        var more = false
        for (kind in allowed) {
            val collection = when (kind) {
                "image" -> MediaStore.Images.Media.getContentUri(volume)
                "video" -> MediaStore.Video.Media.getContentUri(volume)
                else -> MediaStore.Audio.Media.getContentUri(volume)
            }
            val (generation, itemId) = db.checkpoint(kind, version)
            val rows = mutableListOf<ContentValues>()
            var nextGeneration = generation
            var nextId = itemId
            val selection = "(relative_path LIKE ? OR relative_path LIKE ?) AND " +
                "(generation_modified > ? OR (generation_modified = ? AND _id > ?))"
            val args = Bundle().apply {
                putString(android.content.ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                putStringArray(android.content.ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, arrayOf(
                    "Android/media/com.whatsapp/WhatsApp/Media/%",
                    "Android/media/com.whatsapp.w4b/WhatsApp Business/Media/%",
                    "$generation", "$generation", "$itemId"))
                putString(android.content.ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "generation_modified ASC,_id ASC")
                putInt(android.content.ContentResolver.QUERY_ARG_LIMIT, 121)
            }
            context.contentResolver.query(collection, arrayOf("_id", "_display_name", "mime_type", "_size",
                "date_modified", "relative_path", "generation_modified"), args, null)?.use { c ->
                while (c.moveToNext()) {
                    if (rows.size == 120) { more = true; break }
                    val id = c.getLong(0)
                    nextGeneration = c.getLong(6); nextId = id
                    rows += ContentValues().apply {
                        put("uri", ContentUris.withAppendedId(collection, id).toString()); put("kind", kind)
                        put("name", c.getString(1).orEmpty()); put("mime", c.getString(2).orEmpty())
                        put("size", c.getLong(3)); put("modified", c.getLong(4) * 1000L)
                        put("generation", nextGeneration)
                        put("source", if (c.getString(5).orEmpty().startsWith("Android/media/com.whatsapp.w4b/")) "WhatsApp Business" else "WhatsApp")
                    }
                }
            } ?: error("Media provider unavailable")
            db.save(kind, version, rows, nextGeneration, nextId)
            count += rows.size
        }
        return mapOf("indexed" to count, "hasMore" to more)
    }
}
