package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.util.Log
import dev.nanoai.mobile.MainActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Canal `com.nanoai/model_storage` — detección y uso directo de modelos
 * (GGUF/safetensors/onnx) en el storage del device vía SAF.
 *
 * Flujo:
 *  1. `pickTree` abre ACTION_OPEN_DOCUMENT_TREE una vez; el uri se persiste
 *     (takePersistableUriPermission) y `persistedTree` lo devuelve.
 *  2. `scan` recorre el árbol con ContentResolver (BFS, tope de entradas y
 *     tiempo), filtra por extensión y valida el magic GGUF en los primeros
 *     4 bytes. Sin copias: solo metadatos.
 *  3. `openFd` abre el documento y transfiere el fd al worker :nanoshell
 *     (inyectado como [openFdInWorker]); el engine lo hereda y lee el GGUF
 *     vía /proc/self/fd/N.
 */
class ModelStorageChannelHandler(
    private val activity: MainActivity,
    private val ioScope: CoroutineScope,
    private val mainHandler: Handler,
    private val openFdInWorker: (String, ParcelFileDescriptor) -> String?,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "ModelStorage"
        const val CHANNEL_NAME = "com.nanoai/model_storage"

        /** requestCode del ACTION_OPEN_DOCUMENT_TREE clásico. MainActivity
         *  reenvía el resultado en onActivityResult (FlutterActivity no
         *  expone ActivityResultRegistry). */
        const val REQUEST_PICK_TREE = 0xA12E

        private const val PREFS_NAME = "nanoai_model_storage"
        private const val KEY_TREE_URI = "tree_uri"

        /** Tope del walk: entradas visitadas y tiempo máximo. Un árbol con
         *  cientos de miles de nodos no debe bloquear el escaneo. */
        private const val MAX_ENTRIES = 20_000
        private const val SCAN_TIMEOUT_MS = 10_000L

        private val MODEL_EXTENSIONS = setOf("gguf", "safetensors", "onnx")
    }

    private val prefs by lazy {
        activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    private var pendingPick: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickTree" -> handlePickTree(result)
            "persistedTree" -> result.success(persistedTreeUri())
            "scan" -> handleScan(result)
            "openFd" -> handleOpenFd(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handlePickTree(result: MethodChannel.Result) {
        pendingPick?.error("pick_pending", "solicitud anterior aún abierta", null)
        pendingPick = result
        try {
            activity.startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE),
                REQUEST_PICK_TREE,
            )
        } catch (e: Exception) {
            pendingPick = null
            result.error("launch_failed", e.message, null)
        }
    }

    /** Reenvío de MainActivity.onActivityResult: resuelve pickTree. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK_TREE) return
        val pending = pendingPick ?: return
        pendingPick = null

        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            pending.success(null) // usuario canceló
            return
        }
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            prefs.edit().putString(KEY_TREE_URI, uri.toString()).apply()
        } catch (e: Exception) {
            Log.w(TAG, "takePersistableUriPermission falló: ${e.message}")
        }
        pending.success(uri.toString())
    }

    private fun persistedTreeUri(): String? = prefs.getString(KEY_TREE_URI, null)

    private fun handleScan(result: MethodChannel.Result) {
        val treeStr = persistedTreeUri()
        if (treeStr == null) {
            result.success(null)
            return
        }
        ioScope.launch {
            val found = walkTree(Uri.parse(treeStr))
            mainHandler.post { result.success(found) }
        }
    }

    /**
     * BFS sobre el árbol SAF. Devuelve solo modelos por extensión; para GGUF
     * además verifica el magic. `sizeBytes` es -1 cuando el provider no lo
     * reporta (honesto, la UI muestra "—").
     */
    private fun walkTree(root: Uri): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val queue = ArrayDeque<Uri>().apply { add(root) }
        val deadline = System.currentTimeMillis() + SCAN_TIMEOUT_MS
        var visited = 0

        while (queue.isNotEmpty() && visited < MAX_ENTRIES &&
            System.currentTimeMillis() < deadline
        ) {
            val dir = queue.removeFirst()
            val children = try {
                activity.contentResolver.query(dir, null, null, null, null)
            } catch (e: Exception) {
                Log.w(TAG, "query falló en $dir: ${e.message}")
                null
            } ?: continue

            while (children.moveToNext() && visited < MAX_ENTRIES) {
                visited++
                val name = children.getString(
                    children.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                ) ?: continue
                val mime = children.getString(
                    children.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE),
                ) ?: ""
                val docId = children.getString(
                    children.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
                ) ?: continue
                val childUri = DocumentsContract.buildDocumentUriUsingTree(dir, docId)

                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    queue.addLast(childUri)
                    continue
                }

                val ext = name.substringAfterLast('.', "").lowercase()
                if (ext !in MODEL_EXTENSIONS) continue

                val sizeIdx = children.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
                val size = if (sizeIdx >= 0) children.getLong(sizeIdx) else -1L
                val magicOk = if (ext == "gguf") isGguf(childUri) else true
                if (ext == "gguf" && !magicOk) {
                    Log.w(TAG, "extensión .gguf sin magic GGUF: $name")
                }

                out.add(
                    mapOf(
                        "name" to name,
                        "sizeBytes" to size,
                        "uri" to childUri.toString(),
                        "format" to ext,
                        "magicOk" to magicOk,
                    ),
                )
            }
            children.close()
        }
        return out
    }

    /** Lee los primeros 4 bytes y compara contra el magic "GGUF". */
    private fun isGguf(uri: Uri): Boolean {
        return try {
            val pfd = activity.contentResolver.openFileDescriptor(uri, "r") ?: return false
            val ok = pfd.use { fd ->
                val fis = java.io.FileInputStream(fd.fileDescriptor)
                val header = ByteArray(4)
                fis.read(header) == 4 &&
                    header.contentEquals("GGUF".toByteArray(Charsets.US_ASCII))
            }
            ok
        } catch (e: Exception) {
            false
        }
    }

    private fun handleOpenFd(call: MethodCall, result: MethodChannel.Result) {
        val uriStr = call.argument<String>("uri") ?: run {
            result.error("bad_args", "falta uri", null)
            return
        }
        ioScope.launch {
            val pfd = try {
                activity.contentResolver.openFileDescriptor(Uri.parse(uriStr), "r")
            } catch (e: Exception) {
                Log.w(TAG, "openFileDescriptor falló: ${e.message}")
                null
            }
            if (pfd == null) {
                mainHandler.post {
                    result.error("open_failed", "no se pudo abrir $uriStr", null)
                }
                return@launch
            }
            val fdPath = openFdInWorker(uriStr, pfd)
            try { pfd.close() } catch (_: Exception) {}
            mainHandler.post {
                if (fdPath != null) {
                    result.success(fdPath)
                } else {
                    result.error("worker_fd_failed", "worker rechazó el fd", null)
                }
            }
        }
    }
}
