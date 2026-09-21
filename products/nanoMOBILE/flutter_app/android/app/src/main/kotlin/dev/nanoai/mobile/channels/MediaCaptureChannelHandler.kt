package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Captura una foto con la app de cámara del sistema, sin incluir un SDK. */
class MediaCaptureChannelHandler(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/media_capture"
        private const val REQUEST_CAPTURE_PHOTO = 4301
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingFile: File? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capturePhoto" -> capturePhoto(result)
            else -> result.notImplemented()
        }
    }

    private fun capturePhoto(result: MethodChannel.Result) {
        // Un solo resultado pendiente evita callbacks cruzados y Futures zombis.
        if (pendingResult != null) {
            result.error("capture_busy", "Ya hay una captura en curso", null)
            return
        }

        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        try {
            val directory = File(activity.cacheDir, "nano_capture").apply { mkdirs() }
            val output = File(directory, "photo-${System.currentTimeMillis()}.jpg")
            val uri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.fileprovider",
                output,
            )
            intent.putExtra(MediaStore.EXTRA_OUTPUT, uri)
            // Algunas cámaras solo respetan el permiso si el URI va en ClipData.
            intent.clipData = ClipData.newRawUri("NanoAI capture", uri)
            intent.addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            pendingResult = result
            pendingFile = output
            activity.startActivityForResult(intent, REQUEST_CAPTURE_PHOTO)
        } catch (error: Exception) {
            clearPending(deleteFile = true)
            result.error("camera_launch_failed", error.message, null)
        }
    }

    /** Devuelve true cuando el resultado pertenece a este handler. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_CAPTURE_PHOTO) return false
        val result = pendingResult ?: return true
        val file = pendingFile
        if (resultCode == Activity.RESULT_OK && file?.isFile == true && file.length() > 0L) {
            result.success(
                mapOf(
                    "path" to file.absolutePath,
                    "name" to file.name,
                    "sizeBytes" to file.length(),
                ),
            )
            clearPending(deleteFile = false)
        } else {
            result.success(null) // Cancelación del usuario no es un error.
            clearPending(deleteFile = true)
        }
        return true
    }

    /** Resuelve cualquier Future pendiente al destruir la Activity. */
    fun close() {
        pendingResult?.error(
            "activity_destroyed",
            "La pantalla se cerró durante la captura",
            null,
        )
        clearPending(deleteFile = true)
    }

    private fun clearPending(deleteFile: Boolean) {
        if (deleteFile) pendingFile?.delete()
        pendingResult = null
        pendingFile = null
    }
}
