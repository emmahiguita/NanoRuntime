package dev.nanoai.mobile.shizuku

import android.app.ActivityManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder

/**
 * A14.4 — UserService de Shizuku que ejecuta operaciones TIPADAS de paquete con
 * privilegios. Cuando la app vincula este servicio vía Shizuku.bindUserService,
 * el código corre en el proceso con privilegios de Shizuku (uid shell) — por eso
 * [forceStop] y [queryPackage] alcanzan operaciones que la app normal no puede.
 * Solo se aceptan packageName validados; nunca un comando/shell libre.
 */
class PackageActionService : Service() {

    private val binder = object : IPackageAction.Stub() {
        override fun forceStop(packageName: String): Boolean {
            val pkg = packageName.trim()
            if (!isValidPackage(pkg)) return false
            return try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                // forceStopPackage es @hide en API >= 30. Reflection funciona en
                // el contexto Shizuku (uid shell). Solo packageName validado.
                val method =
                    ActivityManager::class.java.getMethod("forceStopPackage", String::class.java)
                method.invoke(am, pkg)
                true
            } catch (_: Throwable) {
                false
            }
        }

        override fun queryPackage(packageName: String): String {
            val pkg = packageName.trim()
            if (!isValidPackage(pkg)) return ""
            return try {
                val info = packageManager.getPackageInfo(pkg, 0)
                buildString {
                    append("package: ").append(info.packageName).append('\n')
                    append("versionCode: ").append(info.versionCode).append('\n')
                    append("versionName: ").append(info.versionName ?: "unknown").append('\n')
                    append("uid: ").append(info.applicationInfo?.uid ?: "unknown")
                }
            } catch (_: Exception) {
                ""
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder = binder

    private fun isValidPackage(pkg: String): Boolean =
        pkg.isNotEmpty() &&
            pkg.length <= 255 &&
            Regex("[a-zA-Z][a-zA-Z0-9._]*").matches(pkg)
}
