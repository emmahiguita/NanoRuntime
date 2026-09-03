package dev.nanoai.mobile.appfunctions

import android.app.AppOpsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process

/**
 * APPFN-01 — sonda de disponibilidad de App Functions (Android 16+, API 36).
 *
 * Reglas duras del sprint:
 * - SOLO consulta. En v1 jamás se ejecuta una AppFunction: el canal no
 *   expone ningún método de ejecución.
 * - Honestidad: cada resultado lleva el sdkInt real y la razón factual de
 *   por qué no está disponible. En un Oppo con Android 15 el cierre es
 *   `apiSupported=false`: el camino correctamente cerrado, no un fallo.
 * - Nunca se referencia `android.app.appfunctions.AppFunctionManager` aquí:
 *   la clase no existe en < API 36 y cargarla daría NoClassDefFoundError.
 *   La sonda solo usa Build.VERSION, PackageManager y AppOpsManager
 *   (disponibles desde antes de minSdk 26).
 */
object AppFunctionProbe {
    const val PERMISSION = "android.permission.EXECUTE_APP_FUNCTIONS"
    const val MIN_SDK = 36

    /** Resultado factual de la sonda. Ningún campo se maquilla. */
    data class AppFunctionAvailability(
        val sdkInt: Int,
        val apiSupported: Boolean,
        val permissionDeclared: Boolean,
        val permissionGranted: Boolean,
        val available: Boolean,
        val reason: String,
    )

    fun probe(context: Context): AppFunctionAvailability {
        val sdk = Build.VERSION.SDK_INT
        val apiSupported = sdk >= MIN_SDK

        // Sin permiso declarado en el manifest, checkPermission devuelve
        // PERMISSION_DENIED: distingue "no declarado" de "declarado y denegado".
        val permissionDeclared = context.packageManager.checkPermission(
            PERMISSION, context.packageName,
        ) != PackageManager.PERMISSION_DENIED

        // EXECUTE_APP_FUNCTIONS es appop: checkSelfPermission no refleja el
        // estado real; AppOpsManager sí. permissionToOp es API 29+: en < 29
        // el op no puede existir -> honestamente no concedido.
        val appOps = context.getSystemService(AppOpsManager::class.java)
        val op = if (sdk >= 29) AppOpsManager.permissionToOp(PERMISSION) else null
        val permissionGranted = op != null && appOps.unsafeCheckOpNoThrow(
            op, Process.myUid(), context.packageName,
        ) == AppOpsManager.MODE_ALLOWED

        val available = apiSupported && permissionGranted
        val reason = when {
            available -> "App Functions disponibles (solo probe; sin ejecución en v1)"
            !apiSupported ->
                "API de App Functions requiere Android 16 (API 36); sdk=$sdk"
            !permissionDeclared -> "permiso EXECUTE_APP_FUNCTIONS no declarado"
            else -> "permiso EXECUTE_APP_FUNCTIONS no concedido"
        }
        return AppFunctionAvailability(
            sdkInt = sdk,
            apiSupported = apiSupported,
            permissionDeclared = permissionDeclared,
            permissionGranted = permissionGranted,
            available = available,
            reason = reason,
        )
    }
}
