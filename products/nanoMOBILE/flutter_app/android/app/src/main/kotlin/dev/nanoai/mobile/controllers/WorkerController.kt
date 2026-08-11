package dev.nanoai.mobile

import java.io.File

class WorkerController(
    private val appFilesDir: File,
    private val pathPolicy: SecurePathPolicy,
    private val workerClientProvider: () -> WorkerClient?,
) {
    fun spawn(
        binaryPath: String,
        argv: List<String>,
        envp: List<String>,
        ldPreload: String?,
    ): String? {
        val executable = pathPolicy.requireInsideNanoFiles(File(binaryPath), "binaryPath")
        val baseDir = pathPolicy.requireInsideNanoFiles(File(appFilesDir, "nano"), "baseDir")
        if (!baseDir.exists()) baseDir.mkdirs()

        val taskId = "t${System.currentTimeMillis()}"
        val ok = workerClientProvider()?.spawn(
            executable.absolutePath,
            argv,
            envp,
            ldPreload,
            taskId,
            baseDir.absolutePath,
        ) == true
        return if (ok) taskId else null
    }

    fun killWorker(): Boolean = workerClientProvider()?.killWorker() == true
}
