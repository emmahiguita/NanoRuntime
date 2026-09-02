package dev.nanoai.mobile.shizuku

import android.app.ActivityManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.IBinder
import java.io.File

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

        override fun installPackage(apkPath: String): Boolean {
            val path = apkPath.trim()
            if (path.isEmpty()) return false
            val file = File(path)
            if (!file.exists() || !file.isFile) return false
            return try {
                // PackageInstaller es la API PÚBLICA de instalación. Con el
                // contexto Shizuku (uid shell) tiene privilegios para instalar.
                val installer = packageManager.packageInstaller
                val params = PackageInstaller.SessionParams(
                    PackageInstaller.SessionParams.MODE_FULL_INSTALL,
                )
                val sessionId = installer.createSession(params)
                val session = installer.openSession(sessionId)
                try {
                    session.openWrite("nano.apk", 0, -1).use { out ->
                        file.inputStream().use { it.copyTo(out) }
                    }
                    val intent = Intent("dev.nanoai.mobile.INSTALL_DONE").apply {
                        setPackage(packageName)
                    }
                    val sender = PendingIntent.getBroadcast(
                        this@PackageActionService,
                        0,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ).intentSender
                    session.commit(sender)
                } finally {
                    session.close()
                }
                true
            } catch (_: Throwable) {
                false
            }
        }

        override fun grantPermission(packageName: String, permission: String): Boolean {
            val pkg = packageName.trim()
            val perm = permission.trim()
            if (!isValidPackage(pkg) || perm.isEmpty()) return false
            // grantRuntimePermission es @hide. Reflection en contexto Shizuku.
            // Solo permissionName validado; UserHandle es público.
            return try {
                val method = packageManager.javaClass.getMethod(
                    "grantRuntimePermission",
                    String::class.java,
                    String::class.java,
                    android.os.UserHandle::class.java,
                )
                method.invoke(packageManager, pkg, perm, android.os.Process.myUserHandle())
                true
            } catch (_: Throwable) {
                false
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder = binder

    private fun isValidPackage(pkg: String): Boolean =
        pkg.isNotEmpty() &&
            pkg.length <= 255 &&
            Regex("[a-zA-Z][a-zA-Z0-9._]*").matches(pkg)
}
