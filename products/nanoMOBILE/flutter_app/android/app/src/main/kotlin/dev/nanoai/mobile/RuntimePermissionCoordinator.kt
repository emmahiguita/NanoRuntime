package dev.nanoai.mobile

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.MethodChannel

/**
 * Coordina los diálogos runtime de Android y garantiza un único resultado vivo.
 *
 * QUÉ: solicita lotes mínimos para almacenamiento, centro de permisos o WebRTC.
 * CÓMO: guarda el Result hasta recibir onRequestPermissionsResult.
 * POR QUÉ: evita Futures huérfanos, solicitudes superpuestas y permisos ajenos.
 */
internal class RuntimePermissionCoordinator(private val activity: Activity) {
    private data class Pending(val requestCode: Int, val result: MethodChannel.Result)

    private var pending: Pending? = null

    /** Solicita únicamente lectura de medios usada por el escritorio local. */
    fun requestStorage(result: MethodChannel.Result) {
        val permissions = if (Build.VERSION.SDK_INT >= 33) {
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
                Manifest.permission.READ_MEDIA_AUDIO,
            )
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        request(permissions, REQUEST_STORAGE, result)
    }

    /** Solicita el lote que el centro de permisos presenta al usuario. */
    fun requestDefaults(result: MethodChannel.Result) {
        val permissions = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= 33) {
            permissions += Manifest.permission.POST_NOTIFICATIONS
            permissions += Manifest.permission.READ_MEDIA_IMAGES
            permissions += Manifest.permission.READ_MEDIA_VIDEO
            permissions += Manifest.permission.READ_MEDIA_AUDIO
        } else {
            permissions += Manifest.permission.READ_EXTERNAL_STORAGE
        }
        request(permissions.toTypedArray(), REQUEST_DEFAULTS, result)
    }

    /** Pide solo los dispositivos solicitados por la página ya confirmada. */
    fun requestWebMedia(
        camera: Boolean,
        microphone: Boolean,
        result: MethodChannel.Result,
    ) {
        val permissions = buildList {
            if (camera) add(Manifest.permission.CAMERA)
            if (microphone) add(Manifest.permission.RECORD_AUDIO)
        }
        request(permissions.toTypedArray(), REQUEST_WEB_MEDIA, result)
    }

    /** Resuelve exclusivamente la solicitud que sigue pendiente. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        val current = pending ?: return false
        if (current.requestCode != requestCode) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        current.result.success(granted)
        pending = null
        return true
    }

    /** Evita dejar una llamada Dart esperando si Android destruye la Activity. */
    fun close() {
        pending?.result?.error(
            "activity_destroyed",
            "Activity destruida antes de contestar permisos",
            null,
        )
        pending = null
    }

    private fun request(
        permissions: Array<String>,
        requestCode: Int,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < 23 || permissions.isEmpty()) {
            result.success(true)
            return
        }
        val missing = permissions.filter {
            activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        if (pending != null) {
            result.error("permission_pending", "solicitud anterior aún abierta", null)
            return
        }
        pending = Pending(requestCode, result)
        activity.requestPermissions(missing.toTypedArray(), requestCode)
    }

    private companion object {
        const val REQUEST_STORAGE = 4101
        const val REQUEST_DEFAULTS = 4102
        const val REQUEST_WEB_MEDIA = 4103
    }
}
