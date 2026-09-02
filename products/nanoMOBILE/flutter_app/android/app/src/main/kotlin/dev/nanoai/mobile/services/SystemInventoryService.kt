package dev.nanoai.mobile.services

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build

/**
 * Inventario factual del sistema y de las aplicaciones launchable.
 *
 * SRP: SOLO inspección vía PackageManager. No conoce Flutter/MethodChannel
 * (eso es [SystemInventoryChannelHandler]) y NO ejecuta intents ni apps.
 *
 * Package visibility (regla dura): NO usa QUERY_ALL_PACKAGES. Descubre apps
 * launchable mediante ACTION_MAIN + CATEGORY_LAUNCHER (el manifest ya declara
 * ese <queries>). Por lo tanto:
 *
 *   VISIBLE_APPS != ALL_INSTALLED_APPS
 *
 * `launchable` deriva de estar en la lista launcher (intent real resoluble),
 * no de la mera existencia del package.
 */
class SystemInventoryService(context: Context) {

    data class NativeInstalledApp(
        val packageName: String,
        val label: String,
        val versionName: String?,
        val versionCode: Long?,
        val enabled: Boolean,
        val systemApp: Boolean,
        val launchable: Boolean,
    )

    data class NativeDeviceProfile(
        val manufacturer: String,
        val model: String,
        val sdkInt: Int,
        val release: String,
        val defaultLauncherPackage: String?,
    )

    private val pm: PackageManager = context.applicationContext.packageManager

    fun getDeviceProfile(): NativeDeviceProfile = NativeDeviceProfile(
        manufacturer = Build.MANUFACTURER ?: "",
        model = Build.MODEL ?: "",
        sdkInt = Build.VERSION.SDK_INT,
        release = Build.VERSION.RELEASE ?: "",
        defaultLauncherPackage = resolveDefaultLauncher(),
    )

    /** Apps visibles y launchable vía launcher semantics (deduplicadas por package). */
    fun listLaunchableApps(): List<NativeInstalledApp> {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        @Suppress("DEPRECATION")
        val activities = pm.queryIntentActivities(intent, 0)
        val seen = HashSet<String>()
        val out = ArrayList<NativeInstalledApp>(activities.size)
        for (ri in activities) {
            @Suppress("DEPRECATION")
            val activityInfo = ri.activityInfo ?: continue
            val pkg = activityInfo.packageName
            if (pkg.isBlank() || !seen.add(pkg)) continue

            val appInfo: ApplicationInfo? = try {
                pm.getApplicationInfo(pkg, 0)
            } catch (e: PackageManager.NameNotFoundException) {
                null
            }
            val label: String = try {
                (appInfo?.loadLabel(pm) ?: ri.loadLabel(pm))
                    ?.toString()
                    ?.takeIf { it.isNotBlank() }
                    ?: pkg
            } catch (e: Exception) {
                pkg
            }
            val (versionName, versionCode) = readVersion(pkg)
            out.add(
                NativeInstalledApp(
                    packageName = pkg,
                    label = label,
                    versionName = versionName,
                    versionCode = versionCode,
                    enabled = appInfo?.enabled != false,
                    systemApp = isSystemApp(appInfo),
                    launchable = true, // derivado de estar en la lista launcher
                ),
            )
        }
        return out
    }

    /** Package del launcher por defecto (HOME). null si no resoluble. */
    fun getDefaultLauncher(): String? = resolveDefaultLauncher()

    private fun resolveDefaultLauncher(): String? {
        val home = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }
        return try {
            @Suppress("DEPRECATION")
            pm.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo
                ?.packageName
        } catch (e: Exception) {
            null
        }
    }

    private fun readVersion(pkg: String): Pair<String?, Long?> = try {
        val info: PackageInfo = pm.getPackageInfo(pkg, 0)
        val code: Long = if (Build.VERSION.SDK_INT >= 28) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        Pair(info.versionName, code)
    } catch (e: PackageManager.NameNotFoundException) {
        Pair(null, null)
    }

    private fun isSystemApp(appInfo: ApplicationInfo?): Boolean =
        appInfo != null && (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
}
