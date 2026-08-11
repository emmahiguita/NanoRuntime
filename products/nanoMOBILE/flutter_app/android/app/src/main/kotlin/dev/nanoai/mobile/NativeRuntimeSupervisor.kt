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
 * of killing worker/VNC resources directly. This prevents split-brain cleanup
 * where MainActivity, VncController and WorkerClient compete for ownership.
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

    private val vncController by lazy { VncController(appFilesDir, { workerClient }, { ioScope }) }
    private val packageInstallController by lazy { PackageInstallController(appFilesDir) { workerClient } }
    private val workerController by lazy { WorkerController(appFilesDir, pathPolicy) { workerClient } }

    fun start() {
        synchronized(lock) {
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

    fun startVnc(
        onStatus: (String) -> Unit = {},
        onPort: (Int) -> Unit = {},
        onError: (String) -> Unit = {},
    ) {
        ensureRunning()
        vncController.start(onStatus = onStatus, onPort = onPort, onError = onError)
    }

    fun stopVnc() {
        vncController.stop()
    }

    fun getVncStatus(callback: (Map<String, Any>) -> Unit) {
        vncController.getStatus(callback = callback)
    }

    fun killWorker(): Boolean {
        stopVnc()
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

        Log.i(TAG, "native supervisor shutdown: stopping VNC then worker")
        vncController.stop()
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
