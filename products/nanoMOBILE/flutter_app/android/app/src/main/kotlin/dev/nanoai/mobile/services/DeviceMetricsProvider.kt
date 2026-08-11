package dev.nanoai.mobile

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Environment
import android.os.StatFs
import java.io.File

class DeviceMetricsProvider(private val context: Context) {
    fun getDeviceMetrics(): Map<String, Any?> {
        val actManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        actManager.getMemoryInfo(memInfo)

        val ramAvailableMb = memInfo.availMem / (1024.0 * 1024.0)
        val ramTotalMb = memInfo.totalMem / (1024.0 * 1024.0)

        val batteryIntent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level.toFloat() / scale.toFloat()) * 100f else -1f
        val plugged = batteryIntent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val isCharging = plugged == BatteryManager.BATTERY_PLUGGED_AC ||
            plugged == BatteryManager.BATTERY_PLUGGED_USB ||
            plugged == BatteryManager.BATTERY_PLUGGED_WIRELESS
        val batteryTempRaw = batteryIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
        val batteryTempC = if (batteryTempRaw > 0) batteryTempRaw / 10.0 else null

        val stat = StatFs(Environment.getDataDirectory().path)
        val blockSize = stat.blockSizeLong
        val totalBlocks = stat.blockCountLong
        val availBlocks = stat.availableBlocksLong
        val storageTotalGb = (totalBlocks * blockSize) / (1024.0 * 1024.0 * 1024.0)
        val storageFreeGb = (availBlocks * blockSize) / (1024.0 * 1024.0 * 1024.0)

        val cpuTempC = readCpuTemp() ?: batteryTempC
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

    fun getDeviceIdentity(): Map<String, Any?> {
        val identity = mutableMapOf<String, Any?>()

        try {
            val status = File("/proc/self/status").readText()
            for (line in status.lines()) {
                when {
                    line.startsWith("Uid:") -> {
                        val parts = line.substringAfter("Uid:").trim().split("	")
                        if (parts.isNotEmpty()) identity["uid"] = parts[0].trim().toIntOrNull()
                    }
                    line.startsWith("Gid:") -> {
                        val parts = line.substringAfter("Gid:").trim().split("	")
                        if (parts.isNotEmpty()) identity["gid"] = parts[0].trim().toIntOrNull()
                    }
                    line.startsWith("Groups:") -> {
                        identity["groups"] = line.substringAfter("Groups:").trim()
                    }
                }
            }
        } catch (_: Exception) {
        }

        try {
            identity["hostname"] = File("/proc/sys/kernel/hostname").readText().trim()
        } catch (_: Exception) {
            identity["hostname"] = "localhost"
        }

        identity["uname_sysname"] = "Linux"
        try {
            identity["uname_release"] = System.getProperty("os.version") ?: "unknown"
        } catch (_: Exception) {
            identity["uname_release"] = "unknown"
        }

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
        } catch (_: Exception) {
            identity["uname_machine"] = "unknown"
        }

        try {
            val meminfo = File("/proc/meminfo").readText()
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
        } catch (_: Exception) {
        }

        try {
            val up = File("/proc/uptime").readText().split(" ").firstOrNull()?.toDoubleOrNull()
            identity["uptimeSec"] = up
        } catch (_: Exception) {
        }

        identity["cpuCores"] = Runtime.getRuntime().availableProcessors()
        try {
            val cpuinfo = File("/proc/cpuinfo").readText()
            val hwMatch = Regex("""Hardware\s*:\s*(.+)""").find(cpuinfo)
            identity["cpuHardware"] = hwMatch?.groupValues?.getOrNull(1)?.trim()
            identity["cpuCount"] = Regex("processor", RegexOption.IGNORE_CASE).findAll(cpuinfo).count()
        } catch (_: Exception) {
        }

        try {
            val stat = StatFs(Environment.getDataDirectory().path)
            identity["storageBlockSize"] = stat.blockSizeLong
            identity["storageTotalBlocks"] = stat.blockCountLong
            identity["storageAvailBlocks"] = stat.availableBlocksLong
        } catch (_: Exception) {
        }

        android.util.Log.i(
            "device_metrics",
            "identity collected keys=${identity.keys.sorted()} cpuCores=${identity["cpuCores"]} arch=${identity["uname_machine"]}",
        )
        return identity
    }

    private fun readCpuTemp(): Double? {
        val paths = listOf(
            "/sys/class/thermal/thermal_zone0/temp",
            "/sys/class/thermal/thermal_zone1/temp",
            "/sys/devices/virtual/thermal/thermal_zone0/temp",
        )
        for (path in paths) {
            try {
                val raw = File(path).readText().trim().toDoubleOrNull()
                if (raw != null) {
                    return if (raw > 200) raw / 1000.0 else raw
                }
            } catch (_: Exception) {
            }
        }
        return null
    }
}
