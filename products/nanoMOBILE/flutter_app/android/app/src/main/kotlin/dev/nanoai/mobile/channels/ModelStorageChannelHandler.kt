package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.Settings
import android.util.Log
import dev.nanoai.mobile.MainActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.io.File

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
    private var pendingAllFiles: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickTree" -> handlePickTree(result)
            "persistedTree" -> result.success(persistedTreeUri())
            "scan" -> handleScan(result)
            "openFd" -> handleOpenFd(call, result)
            "scanAll" -> handleScanAll(result)
            "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
            "requestAllFilesAccess" -> handleRequestAllFilesAccess(result)
            else -> result.notImplemented()
        }
    }

    // ── Escaneo de todo el storage compartido (MANAGE_EXTERNAL_STORAGE) ──

    /** Reenvío de MainActivity.onResume: resuelve requestAllFilesAccess con
     *  el estado real del permiso al volver de la pantalla del sistema. */
    fun onResume() {
        val pending = pendingAllFiles ?: return
        pendingAllFiles = null
        pending.success(hasAllFilesAccess())
    }

    private fun hasAllFilesAccess(): Boolean =
        Build.VERSION.SDK_INT < 30 || Environment.isExternalStorageManager()

    private fun handleRequestAllFilesAccess(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 30 || hasAllFilesAccess()) {
            result.success(true)
            return
        }
        pendingAllFiles?.error("pending", "solicitud anterior aún abierta", null)
        pendingAllFiles = result
        try {
            activity.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:${activity.packageName}"),
                ),
            )
        } catch (e: Exception) {
            pendingAllFiles = null
            result.error("launch_failed", e.message, null)
        }
    }

    private fun handleScanAll(result: MethodChannel.Result) {
        if (!hasAllFilesAccess()) {
            result.success(null)
            return
        }
        ioScope.launch {
            val found = walkAllReadableRoots()
            mainHandler.post { result.success(found) }
        }
    }

    /** Escanea todas las raices legibles relevantes, no solo Download.
     *
     * Cubre almacenamiento compartido primario, aliases de Android
     * (/sdcard, /storage/self/primary) y carpetas externas propias de la app.
     * Deduplica por canonicalPath para no reportar el mismo GGUF dos veces por
     * symlinks/aliases.
     */
    private fun walkAllReadableRoots(): List<Map<String, Any?>> {
        val seen = LinkedHashSet<String>()
        val out = ArrayList<Map<String, Any?>>()
        for (root in scanRoots()) {
            val canonical = try {
                root.canonicalPath
            } catch (_: Exception) {
                root.absolutePath
            }
            if (!seen.add(canonical)) continue
            out.addAll(walkFileTree(root, seen))
        }
        return out
    }

    private fun scanRoots(): List<File> {
        val roots = ArrayList<File>()
        // Common primary aliases
        roots.add(Environment.getExternalStorageDirectory())
        roots.add(File("/sdcard"))
        roots.add(File("/storage/self/primary"))
        roots.add(File("/storage/emulated/0"))

        // Add app-specific external and media dirs
        activity.getExternalFilesDirs(null).filterNotNull().forEach { roots.add(it) }
        activity.getExternalMediaDirs().filterNotNull().forEach { roots.add(it) }

        // Include all mount points under /storage (covers removable SD cards
        // and vendor-specific mount points like /storage/XXXX-XXXX). Also
        // include /mnt for older devices/emulators.
        try {
            val storageRoot = File("/storage")
            val storageChildren = storageRoot.listFiles()
            if (storageChildren != null) {
                storageChildren.filter { it.exists() && it.canRead() }.forEach { roots.add(it) }
            }
        } catch (_: Exception) {}

        try {
            val mntRoot = File("/mnt")
            val mntChildren = mntRoot.listFiles()
            if (mntChildren != null) {
                mntChildren.filter { it.exists() && it.canRead() }.forEach { roots.add(it) }
            }
        } catch (_: Exception) {}

        // Deduplicate and return only readable roots
        return roots.filter { it.exists() && it.canRead() }
            .distinctBy {
                try { it.canonicalPath } catch (_: Exception) { it.absolutePath }
            }
    }

    /**
     * BFS con java.io.File sobre /storage/emulated/0. Mismos topes que el
     * walk SAF: entradas visitadas y tiempo máximo. Sin permiso
     * MANAGE_EXTERNAL_STORAGE listFiles devuelve null en Android 11+ y el
     * resultado queda vacío (honesto: no hay nada legible).
     */
    private fun walkFileTree(
        root: File,
        seenPaths: MutableSet<String> = LinkedHashSet(),
    ): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val queue = ArrayDeque<File>().apply { add(root) }
        val deadline = System.currentTimeMillis() + SCAN_TIMEOUT_MS
        var visited = 0

        while (queue.isNotEmpty() && visited < MAX_ENTRIES &&
            System.currentTimeMillis() < deadline
        ) {
            val dir = queue.removeFirst()
            val children = try {
                dir.listFiles()
            } catch (e: Exception) {
                Log.w(TAG, "listFiles falló en ${dir.absolutePath}: ${e.message}")
                null
            } ?: continue

            for (child in children) {
                if (visited >= MAX_ENTRIES) break
                visited++
                if (child.isDirectory) {
                    queue.addLast(child)
                    continue
                }
                val pathKey = try {
                    child.canonicalPath
                } catch (_: Exception) {
                    child.absolutePath
                }
                if (!seenPaths.add(pathKey)) continue

                val name = child.name
                val ext = name.substringAfterLast('.', "").lowercase()
                if (ext !in MODEL_EXTENSIONS) continue

                val magicOk = if (ext == "gguf") isGgufFile(child) else true
                if (ext == "gguf" && !magicOk) {
                    Log.w(TAG, "extensión .gguf sin magic GGUF: ${child.absolutePath}")
                }

                out.add(
                    mapOf(
                        "name" to name,
                        "sizeBytes" to child.length(),
                        "path" to child.absolutePath,
                        "format" to ext,
                        "magicOk" to magicOk,
                    ),
                )
            }
        }
        return out
    }

    /** Lee los primeros 4 bytes del archivo y compara contra "GGUF". */
    private fun isGgufFile(file: File): Boolean {
        return try {
            file.inputStream().use { fis ->
                val header = ByteArray(4)
                fis.read(header) == 4 &&
                    header.contentEquals("GGUF".toByteArray(Charsets.US_ASCII))
            }
        } catch (e: Exception) {
            false
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
