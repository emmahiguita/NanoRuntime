package dev.nanoai.mobile

import java.io.File

class PackageInstallController(
    private val appFilesDir: File,
    private val workerClientProvider: () -> WorkerClient?,
) {
    @Synchronized
    fun installPackages(packages: List<String>, onProgress: (String, Int) -> Unit): Boolean {
        return newInstaller().install(packages, onProgress)
    }

    @Synchronized
    fun installGraphical(onProgress: (String, Int) -> Unit): Boolean {
        return newInstaller().installGraphical(onProgress)
    }

    private fun newInstaller(): DebInstaller {
        val baseDir = File(appFilesDir, "nano")
        val usrDir = File(baseDir, "usr")
        return DebInstaller(
            baseDir = baseDir,
            usrDir = usrDir,
            spawnWorker = { bin, argv, env, taskId ->
                val sent = workerClientProvider()?.spawn(
                    bin,
                    argv,
                    env.map { "${it.key}=${it.value}" },
                    null,
                    taskId,
                    appFilesDir.absolutePath,
                ) ?: false
                if (sent) 1 else -1
            },
        )
    }
}
