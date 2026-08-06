package dev.nanoai.mobile

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.nanoai/device_metrics"
    private const val CHANNEL_BIN = "com.nanoai/exec_bin"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMetrics" -> result.success(getDeviceMetrics())
                "getDeviceIdentity" -> result.success(getDeviceIdentity())
                else -> result.notImplemented()
            }
        }

        // Terminal REAL PATH: marca un binario del app-data-dir como ejecutable.
        // SELinux permite exec de los propios archivos de la app; dart:io no
        // tiene chmod, por eso lo hace la plataforma.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_BIN)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "makeExecutable" -> {
                        val path = call.arguments as? String
                        if (path == null) { result.error("bad_args", "path requerido", null); return@setMethodCallHandler }
                        val f = java.io.File(path)
                        val ok = f.setExecutable(true, false)
                        android.util.Log.w("exec_bin", "makeExecutable path=$path ownerCanExec=${f.canExecute()} set=$ok")
                        result.success(ok)
                    }
                    // Directorio privado de datos de la app (files/, NO cache).
                    // SELinux le permite exec de binarios propios; cache tiende a
                    // montarse noexec y se limpia en reinstalación.
                    "getFilesDir" -> {
                        val base = java.io.File(filesDir.absolutePath, "nano")
                        if (!base.exists()) base.mkdirs()
                        result.success(base.absolutePath)
                    }
                    // DEBUG: exec real dentro del proceso de la app para aislar
                    // el ENOENT. Retorna stdout/stderr real o mensaje de la
                    // excepción (p. ej. "Permission denied" vs "No such file").
                    "probeExec" -> {
                        val spec = call.arguments as? Map<*, *>
                        val path = spec?.get("path") as? String
                        val args = spec?.get("args") as? List<*> ?: emptyList<Any?>()
                        if (path == null) { result.error("bad_args", "path requerido", null); return@setMethodCallHandler }
                        try {
                            val cmd = java.util.ArrayList<String>().apply { add(path); args.forEach { add(it.toString()) } }
                            val p = java.lang.ProcessBuilder(cmd).redirectErrorStream(false).start()
                            val out = p.inputStream.readBytes().toString(Charsets.UTF_8)
                            val err = p.errorStream.readBytes().toString(Charsets.UTF_8)
                            val rc = p.waitFor()
                            result.success(mapOf("rc" to rc, "out" to out, "err" to err))
                        } catch (e: Exception) {
                            android.util.Log.w("exec_bin", "probeExec FAIL path=$path ex=$e")
                            result.success(mapOf("error" to "${e.javaClass.simpleName}: ${e.message}"))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getDeviceMetrics(): Map<String, Any?> {
        val actManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        actManager.getMemoryInfo(memInfo)

        // RAM: availMem is most accurate for "available" RAM
        val ramAvailableMb = memInfo.availMem / (1024.0 * 1024.0)
        val ramTotalMb = memInfo.totalMem / (1024.0 * 1024.0)

        // Battery
        val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level.toFloat() / scale.toFloat()) * 100f else -1f
        val plugged = batteryIntent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val isCharging = plugged == BatteryManager.BATTERY_PLUGGED_AC ||
                plugged == BatteryManager.BATTERY_PLUGGED_USB ||
                plugged == BatteryManager.BATTERY_PLUGGED_WIRELESS
        // Battery temperature in tenths of a degree Celsius (real data, no root required)
        val batteryTempRaw = batteryIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
        val batteryTempC = if (batteryTempRaw > 0) batteryTempRaw / 10.0 else null

        // Storage (internal)
        val stat = StatFs(Environment.getDataDirectory().path)
        val blockSize = stat.blockSizeLong
        val totalBlocks = stat.blockCountLong
        val availBlocks = stat.availableBlocksLong
        val storageTotalGb = (totalBlocks * blockSize) / (1024.0 * 1024.0 * 1024.0)
        val storageFreeGb = (availBlocks * blockSize) / (1024.0 * 1024.0 * 1024.0)

        // CPU temperature (thermal zones — may require root on some devices)
        val cpuTempC = readCpuTemp() ?: batteryTempC

        // CPU cores
        val cpuCores = Runtime.getRuntime().availableProcessors()

        return mapOf(
            "ramAvailableMb" to ramAvailableMb,
            "ramTotalMb" to ramTotalMb,
            "batteryPct" to batteryPct,
            "isCharging" to isCharging,
            "storageTotalGb" to storageTotalGb,
            "storageFreeGb" to storageFreeGb,
            "cpuTempC" to cpuTempC,
            "cpuCores" to cpuCores,
        )
    }

    private fun getDeviceIdentity(): Map<String, Any?> {
        val identity = mutableMapOf<String, Any?>()

        // uid / gid / groups desde /proc/self/status
        try {
            val status = java.io.File("/proc/self/status").readText()
            for (line in status.lines()) {
                when {
                    line.startsWith("Uid:") -> {
                        val parts = line.substringAfter("Uid:").trim().split("\t")
                        if (parts.isNotEmpty()) identity["uid"] = parts[0].trim().toIntOrNull()
                    }
                    line.startsWith("Gid:") -> {
                        val parts = line.substringAfter("Gid:").trim().split("\t")
                        if (parts.isNotEmpty()) identity["gid"] = parts[0].trim().toIntOrNull()
                    }
                    line.startsWith("Groups:") -> {
                        identity["groups"] = line.substringAfter("Groups:").trim()
                    }
                }
            }
        } catch (_: Exception) {}

        // hostname
        try {
            identity["hostname"] = java.io.File("/proc/sys/kernel/hostname").readText().trim()
        } catch (_: Exception) { identity["hostname"] = "localhost" }

        // uname: kernel version desde System.getProperty (no necesita /proc)
        identity["uname_sysname"] = "Linux"
        try {
            // os.version da el release del kernel en Android (ej: "6.6.82-android15-8-...")
            identity["uname_release"] = System.getProperty("os.version") ?: "unknown"
        } catch (_: Exception) { identity["uname_release"] = "unknown" }
        // arquitectura desde Build.SUPPORTED_ABIS (no necesita /proc)
        try {
            val abis = android.os.Build.SUPPORTED_ABIS
            val arch = when {
                abis.any { it.contains("arm64") || it.contains("aarch64") } -> "aarch64"
                abis.any { it.contains("armeabi") } -> "armv7l"
                abis.any { it.contains("x86_64") } -> "x86_64"
                abis.any { it.contains("x86") } -> "i686"
                else -> abis.firstOrNull() ?: "unknown"
            }
            identity["uname_machine"] = arch
        } catch (_: Exception) { identity["uname_machine"] = "unknown" }

        // meminfo básico para free
        try {
            val meminfo = java.io.File("/proc/meminfo").readText()
            for (line in meminfo.lines()) {
                when {
                    line.startsWith("MemTotal:") -> {
                        identity["memTotalKb"] = line.replace(Regex("[^0-9]"), "").toLongOrNull()
                    }
                    line.startsWith("MemAvailable:") -> {
                        identity["memAvailKb"] = line.replace(Regex("[^0-9]"), "").toLongOrNull()
                    }
                    line.startsWith("SwapTotal:") -> {
                        identity["swapTotalKb"] = line.replace(Regex("[^0-9]"), "").toLongOrNull()
                    }
                    line.startsWith("SwapFree:") -> {
                        identity["swapFreeKb"] = line.replace(Regex("[^0-9]"), "").toLongOrNull()
                    }
                }
            }
        } catch (_: Exception) {}

        // uptime desde /proc/uptime
        try {
            val up = java.io.File("/proc/uptime").readText().split(" ").firstOrNull()?.toDoubleOrNull()
            identity["uptimeSec"] = up
        } catch (_: Exception) {}

        // CPU cores y freq
        identity["cpuCores"] = Runtime.getRuntime().availableProcessors()
        try {
            val cpuinfo = java.io.File("/proc/cpuinfo").readText()
            // Extraer model name para cpu info
            val hwMatch = Regex("""Hardware\s*:\s*(.+)""").find(cpuinfo)
            identity["cpuHardware"] = hwMatch?.groupValues?.getOrNull(1)?.trim()
            // Contar processors
            identity["cpuCount"] = Regex("processor", RegexOption.IGNORE_CASE).findAll(cpuinfo).count()
        } catch (_: Exception) {}

        // Storage (para df)
        try {
            val stat = android.os.StatFs(android.os.Environment.getDataDirectory().path)
            identity["storageBlockSize"] = stat.blockSizeLong
            identity["storageTotalBlocks"] = stat.blockCountLong
            identity["storageAvailBlocks"] = stat.availableBlocksLong
        } catch (_: Exception) {}

        android.util.Log.w("device_metrics", "identity=$identity")
        return identity
    }

    private fun readCpuTemp(): Double? {
        // Try common thermal zone paths (no root required on most devices)
        val paths = listOf(
            "/sys/class/thermal/thermal_zone0/temp",
            "/sys/class/thermal/thermal_zone1/temp",
            "/sys/devices/virtual/thermal/thermal_zone0/temp",
        )
        for (path in paths) {
            try {
                val raw = java.io.File(path).readText().trim().toDoubleOrNull()
                if (raw != null) {
                    // Most return millidegrees (e.g. 38500 = 38.5°C)
                    return if (raw > 200) raw / 1000.0 else raw
                }
            } catch (_: Exception) { }
        }
        return null
    }
}
