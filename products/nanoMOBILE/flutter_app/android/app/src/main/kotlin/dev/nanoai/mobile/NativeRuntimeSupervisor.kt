package dev.nanoai.mobile

import android.content.Context
import android.util.Log
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive

/**
 * Single owner for native runtime orchestration in the Android process.
 *
 * Shutdown order is intentional:
 * 1. stop VNC daemons while WorkerClient is still connected;
 * 2. ask the worker process to kill any foreground native task;
 * 3. unbind the worker service.
 *
 * MainActivity and MethodChannel handlers must go through this class instead
 * of killing worker/Desktop resources directly. This prevents split-brain cleanup
 * where MainActivity, DesktopController and WorkerClient compete for ownership.
 */
class NativeRuntimeSupervisor(
    context: Context,
    private val appFilesDir: File,
    private val pathPolicy: SecurePathPolicy,
) {
    private val appContext = context.applicationContext
    private val lock = Any()

    @Volatile private var workerClient: WorkerClient? = null
    @Volatile private var shuttingDown = false

    private var ioScope: CoroutineScope? = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val desktopController by lazy { dev.nanoai.mobile.controllers.DesktopController(appFilesDir, { workerClient }, { ioScope }) }
    private val packageInstallController by lazy { PackageInstallController(appFilesDir) { workerClient } }
    private val workerController by lazy { WorkerController(appFilesDir, pathPolicy) { workerClient } }

    fun start() {
        synchronized(lock) {
            // No resucitar después de shutdown() — estado terminal.
            if (shuttingDown) return
            if (workerClient != null && !shuttingDown) return
            shuttingDown = false
            workerClient = WorkerClient(appContext)
            // Recrear ioScope si fue cancelado
            if (ioScope?.isActive != true) {
                ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
            }
            Log.i(TAG, "native supervisor started")
        }
    }

    fun installPackages(packages: List<String>, onProgress: (String, Int) -> Unit): Boolean {
        ensureRunning()
        return packageInstallController.installPackages(packages, onProgress)
    }

    fun installGraphical(onProgress: (String, Int) -> Unit): Boolean {
        ensureRunning()
        return packageInstallController.installGraphical(onProgress)
    }

    fun spawnWorker(
        binaryPath: String,
        argv: List<String>,
        envp: List<String>,
        ldPreload: String?,
    ): String? {
        ensureRunning()
        return workerController.spawn(binaryPath, argv, envp, ldPreload)
    }

    fun startDesktop(
        onStatus: (String) -> Unit = {},
        onReady: () -> Unit = {},
        onError: (String) -> Unit = {},
    ) {
        ensureRunning()
        desktopController.start(onStatus = onStatus, onReady = onReady, onError = onError)
    }

    fun stopDesktop() {
        desktopController.stop()
    }

    fun launchApp(app: String): Boolean {
        ensureRunning()
        return desktopController.launchApp(app)
    }

    fun getDesktopStatus(callback: (Map<String, Any?>) -> Unit) {
        desktopController.getStatus(callback = callback)
    }

    fun killWorker(): Boolean {
        stopDesktop()
        val killed = workerController.killWorker()
        synchronized(lock) {
            workerClient = null
            shuttingDown = false
        }
        return killed
    }

    fun shutdown() {
        val clientToClose: WorkerClient?
        synchronized(lock) {
            if (shuttingDown && workerClient == null) return
            shuttingDown = true
            clientToClose = workerClient
            workerClient = null
        }

        Log.i(TAG, "native supervisor shutdown: stopping Desktop then worker")
        desktopController.stop()
        clientToClose?.disconnect()
        ioScope?.cancel()
        ioScope = null
    }

    private fun ensureRunning() {
        if (workerClient != null && !shuttingDown && ioScope?.isActive == true) return
        start()
    }

    private companion object {
        private const val TAG = "native-supervisor"
    }
}
