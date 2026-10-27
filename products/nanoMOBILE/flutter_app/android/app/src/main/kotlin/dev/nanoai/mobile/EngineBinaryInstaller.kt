package dev.nanoai.mobile

import android.content.res.AssetManager
import android.util.Log
import java.io.File
import java.io.FileOutputStream

/** QUÉ: instala el runtime del APK sin colisiones entre arranques concurrentes.
 * CÓMO: un lock de proceso protege copia, SHA-256 y rename como una transacción.
 * POR QUÉ: dos corutinas escribían nanortime.tmp y reportaban falsos hashes corruptos.
 */
internal object EngineBinaryInstaller {
    private val lock = Any()

    fun install(assets: AssetManager, assetPath: String, assetSize: Long, dest: File): File =
        synchronized(lock) {
        if (!dest.parentFile!!.exists()) dest.parentFile!!.mkdirs()
        // QUÉ HACE: Reutiliza el binario solo si coincide el contenido real del APK.
        // CÓMO FUNCIONA: Compara SHA-256 además del tamaño para detectar builds distintos iguales en bytes.
        // POR QUÉ: El tamaño por sí solo conservaba en el teléfono un runtime nativo obsoleto.
        val assetHash = assets.open(assetPath).use(EngineAssetFingerprint::sha256)
        if (dest.exists() && dest.length() == assetSize) {
            val installedHash = dest.inputStream().use(EngineAssetFingerprint::sha256)
            if (installedHash == assetHash) return@synchronized dest
        }

        assets.open(assetPath).use { input ->
            val tmp = File(dest.parentFile, "nanortime.tmp")
            FileOutputStream(tmp).use { output ->
                val buffer = ByteArray(64 * 1024)
                var total = 0L
                var len: Int
                while (input.read(buffer).also { len = it } > 0) {
                    output.write(buffer, 0, len)
                    total += len
                }
                if (total != assetSize) {
                    tmp.delete()
                    throw IllegalStateException(
                        "extracción incompleta: $total de $assetSize bytes (¿asset corrupto?)",
                    )
                }
            }
            // Impide instalar una extracción truncada o distinta del asset compilado.
            val extractedHash = tmp.inputStream().use(EngineAssetFingerprint::sha256)
            if (extractedHash != assetHash) {
                tmp.delete()
                throw IllegalStateException("SHA-256 del runtime extraído no coincide con el asset")
            }
            // Rename atómico: Dart/Kotlin nunca ven un binario a medio escribir.
            if (!tmp.renameTo(dest)) {
                tmp.delete()
                throw IllegalStateException("rename atómico falló para ${dest.name}")
            }
        }
        if (!dest.setExecutable(true, false)) {
            Log.w("EngineSupervisor", "setExecutable devolvió false — verificando flag real")
        }
        check(dest.canExecute()) { "PIE extraído sin bit de ejecución: ${dest.absolutePath}" }
        Log.i("EngineSupervisor", "PIE listo: ${dest.absolutePath} (${dest.length()} bytes, exec=${dest.canExecute()})")
        return@synchronized dest
    }
}
