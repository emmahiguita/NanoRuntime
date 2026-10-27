package dev.nanoai.mobile.channels

import android.util.Log
import dev.nanoai.mobile.NanoshellBridge
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.RejectedExecutionException

/**
 * Handler dedicado para el canal PTY (pseudo-terminal).
 * Delegates a NanoshellBridge (JNI) para operaciones nativas.
 */
class PtyChannelHandler : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "PtyChannel"
        const val CHANNEL_NAME = "com.nanoai/pty"
        // Conserva el orden JNI sin bloquear Flutter. No retiene Activity.
        // El hilo termina después de 30 s sin trabajo; la cola es acotada.
        private val worker = ThreadPoolExecutor(
            1, 1, 30L, TimeUnit.SECONDS, ArrayBlockingQueue<Runnable>(128),
            { task -> Thread(task, "NanoPtyWorker") }
        ).apply { allowCoreThreadTimeOut(true) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            worker.execute {
                try {
                    dispatch(call, result)
                } catch (error: Exception) {
                    result.error("pty_failed", "La operación PTY no pudo completarse", null)
                }
            }
        } catch (error: RejectedExecutionException) {
            result.error("pty_busy", "La cola PTY está ocupada", null)
        }
    }

    // MethodChannel.Result permite completar desde este trabajador.
    private fun dispatch(call: MethodCall, result: MethodChannel.Result) {
        if (!NanoshellBridge.ensureLoaded()) {
            result.error("jni_unavailable", "libnanoshell.so no cargada", null)
            return
        }

        when (call.method) {
            "ptySpawn" -> handlePtySpawn(call, result)
            "ptyWrite" -> handlePtyWrite(call, result)
            "ptyRead" -> handlePtyRead(call, result)
            "ptyResize" -> handlePtyResize(call, result)
            "ptyKill" -> handlePtyKill(call, result)
            "ptyClose" -> handlePtyClose(call, result)
            "ptyGetPid" -> handlePtyGetPid(call, result)
            "ptyIsAlive" -> handlePtyIsAlive(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handlePtySpawn(call: MethodCall, result: MethodChannel.Result) {
        val argv = (call.argument<List<String>>("argv") ?: emptyList()).toTypedArray()
        val envMap = call.argument<Map<String, String>>("envp") ?: emptyMap()
        val envp = envMap.map { "${it.key}=${it.value}" }.toTypedArray()
        val ldPreload = call.argument<String>("ldPreload")
        val rows = call.argument<Int>("rows") ?: 24
        val cols = call.argument<Int>("cols") ?: 80
        val id = NanoshellBridge.ptySpawn(argv, envp, ldPreload, rows, cols)
        Log.i(TAG, "spawn argv=$argv id=$id")
        result.success(id)
    }

    private fun handlePtyWrite(call: MethodCall, result: MethodChannel.Result) {
        val id = (call.argument<Number>("id") ?: 0L).toLong()
        val data = call.argument<ByteArray>("data")
        if (data == null) {
            result.success(0)
            return
        }
        val n = NanoshellBridge.ptyWrite(id, data)
        result.success(n)
    }

    private fun handlePtyRead(call: MethodCall, result: MethodChannel.Result) {
        val id = (call.argument<Number>("id") ?: 0L).toLong()
        val max = call.argument<Int>("maxBytes") ?: 4096
        val data = NanoshellBridge.ptyRead(id, max)
        result.success(data)
    }

    private fun handlePtyResize(call: MethodCall, result: MethodChannel.Result) {
        val id = (call.argument<Number>("id") ?: 0L).toLong()
        val rows = call.argument<Int>("rows") ?: 24
        val cols = call.argument<Int>("cols") ?: 80
        val rc = NanoshellBridge.ptyResize(id, rows, cols)
        result.success(rc)
    }

    private fun handlePtyKill(call: MethodCall, result: MethodChannel.Result) {
        val id = (call.argument<Number>("id") ?: 0L).toLong()
        val sig = call.argument<Int>("signal") ?: 2
        val rc = NanoshellBridge.ptyKill(id, sig)
        result.success(rc)
    }

    private fun handlePtyClose(call: MethodCall, result: MethodChannel.Result) {
        val id = (call.argument<Number>("id") ?: 0L).toLong()
        NanoshellBridge.ptyClose(id)
        result.success(true)
    }

    private fun handlePtyGetPid(call: MethodCall, result: MethodChannel.Result) {
        val id = (call.argument<Number>("id") ?: 0L).toLong()
        result.success(NanoshellBridge.ptyGetPid(id))
    }

    private fun handlePtyIsAlive(call: MethodCall, result: MethodChannel.Result) {
        val id = (call.argument<Number>("id") ?: 0L).toLong()
        result.success(NanoshellBridge.ptyIsAlive(id))
    }
}
