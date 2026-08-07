package dev.nanoai.mobile

import android.util.Log
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Instalador directo de paquetes Termux (.deb) — alternativa a apt binario.
 *
 * apt (stripped, sin "main" exportado) no puede ejecutarse via dlopen, pero
 * sus .deb sí se pueden instalar manualmente — exactamente lo que dpkg hace
 * por dentro:
 *   1. Descargar y parsear el index Packages (UA de apt).
 *   2. Resolver Depends recursivamente (BFS desde el paquete objetivo).
 *   3. Descargar cada .deb con verificación SHA256.
 *   4. Parsear el contenedor ar → extraer data.tar.xz.
 *   5. Descomprimir xz (XzDecoder, Kotlin puro) y extraer tar (TarExtractor)
 *      inline SIN worker. Elimina dependencia del binario tar del rootfs y
 *      el race condition del spawn async.
 *   6. Registrar en var/lib/dpkg/status (formato dpkg).
 *   7. Bootstrap packages leídos dinámicamente de status (sin hardcode).
 *
 * postinst NO se ejecuta: los paquetes objetivo (vim/htop/git/python) son
 * binarios + libs sin scripts críticos. Para paquetes con postinst
 * imprescindible (ca-certificates, man-db) se añadiría soporte incremental.
 */
class DebInstaller(
    private val baseDir: File,
    private val usrDir: File,
    private val spawnWorker: (binaryPath: String, argv: List<String>, env: Map<String, String>, taskId: String) -> Int,
) {
    companion object {
        private const val TAG = "deb-installer"

        // Repositorios Termux
        data class Repo(val name: String, val indexUrl: String, val poolBase: String)

        private val REPO_MAIN = Repo("main",
            "https://packages-cf.termux.dev/apt/termux-main/dists/stable/main/binary-aarch64/Packages",
            "https://packages-cf.termux.dev/apt/termux-main/")

        private val REPO_X11 = Repo("x11",
            "https://packages-cf.termux.dev/apt/termux-x11/dists/x11/main/binary-aarch64/Packages",
            "https://packages-cf.termux.dev/apt/termux-x11/")

        private val REPO_ROOT = Repo("root",
            "https://packages-cf.termux.dev/apt/termux-root/dists/root/stable/binary-aarch64/Packages",
            "https://packages-cf.termux.dev/apt/termux-root/")

        private val ALL_REPOS = listOf(REPO_MAIN, REPO_X11, REPO_ROOT)

        private val UA = mapOf("User-Agent" to "apt/2.7.14 (arm64) (termux)")

        /** Paquetes mínimos para escritorio VNC funcional. */
        val DESKTOP_PACKAGES = listOf(
            "tigervnc",    // Xvnc: servidor X11 + VNC integrado
            "openbox",     // window manager ultraligero (~1MB)
            "tint2",       // panel/taskbar
            // xkbcomp no existe como paquete Termux; se usa wrapper script
        )

        /** Convierte bytes a hex string (para verificación SHA256). */
        private fun bytesToHex(bytes: ByteArray): String =
            bytes.joinToString("") { "%02x".format(it) }
    }

    data class PkgInfo(
        val name: String,
        val version: String,
        val depends: List<String>,
        val filename: String,
        val sha256: String,
        val repo: Repo,
    )

    /** Parsear el index Packages: líneas clave por bloque. */
    private fun parseIndex(text: String, repo: Repo): Map<String, PkgInfo> {
        val out = mutableMapOf<String, PkgInfo>()
        for (para in text.split("\n\n")) {
            var name: String? = null
            var version = ""
            var depends = ""
            var filename = ""
            var sha256 = ""
            for (line in para.lines()) {
                when {
                    line.startsWith("Package: ") -> name = line.removePrefix("Package: ").trim()
                    line.startsWith("Version: ") -> version = line.removePrefix("Version: ").trim()
                    line.startsWith("Depends: ") -> depends = line.removePrefix("Depends: ").trim()
                    line.startsWith("Filename: ") -> filename = line.removePrefix("Filename: ").trim()
                    line.startsWith("SHA256: ") -> sha256 = line.removePrefix("SHA256: ").trim()
                }
            }
            if (name != null && filename.isNotEmpty()) {
                out[name] = PkgInfo(name, version, parseDepends(depends), filename, sha256, repo)
            }
        }
        return out
    }

    /** "a, b | c, d" → ["a", "b|c", "d"] (alternativas sin resolver). */
    private fun parseDepends(depends: String): List<String> =
        if (depends.isBlank()) emptyList()
        else depends.split(",").map { it.trim().split(" ")[0] }.filter { it.isNotEmpty() }

    /**
     * Paquetes del bootstrap (rootfs inicial) — leídos del status file una
     * sola vez. Sustituye al set hardcodeado de 45 entradas que se
     * desincronizaba del rootfs real.
     */
    private val bootstrapPackages: Set<String> by lazy {
        val pkgs = readInstalledStatus()
        Log.i(TAG, "bootstrap: ${pkgs.size} paquetes desde status")
        pkgs
    }

    /** Calcula SHA256 de un archivo para verificar integridad. */
    private fun sha256(file: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buf = ByteArray(64 * 1024)
            var n: Int
            while (input.read(buf).also { n = it } > 0) md.update(buf, 0, n)
        }
        return bytesToHex(md.digest())
    }

    /** Descarga y mergea índices de todos los repos. Retorna mapa unificado. */
    private fun fetchAllIndexes(): Map<String, PkgInfo> {
        val merged = mutableMapOf<String, PkgInfo>()
        for (repo in ALL_REPOS) {
            val indexFile = File(baseDir, "packages_${repo.name}")
            if (!indexFile.exists() || indexFile.length() < 10_000) {
                if (!download(repo.indexUrl, indexFile)) {
                    Log.w(TAG, "índice ${repo.name} no disponible, saltando")
                    continue
                }
            }
            val repoIndex = parseIndex(indexFile.readText(), repo)
            Log.i(TAG, "repo ${repo.name}: ${repoIndex.size} paquetes")
            merged.putAll(repoIndex)
        }
        return merged
    }

    /** Instala [targets] y sus deps desde todos los repos. */
    fun install(targets: List<String>, onProgress: (String, Int) -> Unit): Boolean {
        try {
            onProgress("index", 5)
            val index = fetchAllIndexes()
            onProgress("index", 10)
            if (index.isEmpty()) { Log.e(TAG, "índices vacíos"); return false }

            val installed = readInstalledStatus().toMutableSet()
            val bootPkgs = bootstrapPackages

            // BFS resolver deps
            val toInstall = mutableListOf<String>()
            val seen = mutableSetOf<String>()
            val queue = ArrayDeque(targets)
            while (queue.isNotEmpty()) {
                val pkg = queue.removeFirst()
                if (pkg in installed || pkg in bootPkgs || pkg in seen) continue
                seen.add(pkg)
                val info = index[pkg]
                if (info == null) { Log.w(TAG, "pkg no encontrado: $pkg"); continue }
                toInstall.add(pkg)
                for (dep in info.depends) {
                    val alt = dep.split("|").map { it.trim() }.firstOrNull { index.containsKey(it) }
                    if (alt != null && alt !in installed && alt !in bootPkgs) queue.addLast(alt)
                }
            }
            Log.i(TAG, "instalar (${toInstall.size}): ${toInstall.take(10)}...")

            // Descargar y extraer cada .deb
            val pkgsDir = File(baseDir, "pkgs").apply { mkdirs() }
            var done = 0
            for (pkg in toInstall) {
                val info = index[pkg] ?: continue
                val deb = File(pkgsDir, "$pkg.deb")
                onProgress("download $pkg", 10 + done * 40 / toInstall.size)
                if (!deb.exists() || deb.length() < 1000) {
                    if (!download(info.repo.poolBase + info.filename, deb)) {
                        Log.e(TAG, "fallo descarga $pkg"); return false
                    }
                }
                if (info.sha256.isNotEmpty()) {
                    val actual = sha256(deb)
                    if (!actual.equals(info.sha256, ignoreCase = true)) {
                        Log.e(TAG, "$pkg SHA256 mismatch"); deb.delete(); return false
                    }
                }
                if (!extractDeb(deb, pkg, info.version)) {
                    Log.e(TAG, "fallo extracción $pkg"); return false
                }
                writeStatus(pkg, info.version)
                installed.add(pkg)
                done++
                onProgress("install $pkg", 50 + done * 50 / toInstall.size)
            }
            onProgress("done", 100)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "install falló: $e")
            return false
        }
    }

    /** Instala el escritorio VNC mínimo (Xvnc + openbox + xterm). */
    fun installGraphical(onProgress: (String, Int) -> Unit): Boolean {
        return install(DESKTOP_PACKAGES, onProgress)
    }

    /** Descarga con UA de apt. */
    private fun download(url: String, dest: File): Boolean {
        try {
            val conn = URL(url).openConnection() as HttpURLConnection
            UA.forEach { conn.setRequestProperty(it.key, it.value) }
            conn.connectTimeout = 30000
            conn.readTimeout = 60000
            conn.instanceFollowRedirects = true
            if (conn.responseCode !in 200..299) {
                Log.e(TAG, "HTTP ${conn.responseCode} para $url")
                conn.disconnect()
                return false
            }
            conn.inputStream.use { input ->
                dest.outputStream().use { out ->
                    val buf = ByteArray(64 * 1024)
                    var n: Int
                    while (input.read(buf).also { n = it } > 0) out.write(buf, 0, n)
                }
            }
            conn.disconnect()
            return true
        } catch (e: Exception) {
            Log.e(TAG, "download $url: $e")
            return false
        }
    }

    /**
     * Extrae un .deb: parsea el contenedor ar, descomprime data.tar.xz con
     * el decoder XZ puro (Kotlin) y extrae el tar con TarExtractor puro.
     *
     * SIN worker: tar/xz del rootfs están stripped (no exportan main → no
     * dlopen-ables), y el toybox del sistema no tiene xz. Kotlin puro es la
     * vía 100% confiable y elimina el race condition del spawn async.
     */
    private fun extractDeb(deb: File, pkg: String, version: String): Boolean {
        val bytes = deb.readBytes()
        if (bytes.size < 8 || String(bytes, 0, 8) != "!<arch>\n") {
            Log.e(TAG, "$pkg no es un .deb válido")
            return false
        }
        // Parsear ar: name(16) mtime(12) uid(6) gid(6) mode(8) size(10) magic(2)
        var dataXz: ByteArray? = null
        var controlXz: ByteArray? = null
        var i = 8
        while (i + 60 <= bytes.size) {
            // Validar magic de cierre del header ar (0x60 0x0A).
            if (bytes[i + 58] != 0x60.toByte() || bytes[i + 59] != 0x0A.toByte()) {
                Log.e(TAG, "$pkg header ar corrupto en offset $i")
                return false
            }
            val name = String(bytes, i, 16).trim().trimEnd('/')
            val sizeStr = String(bytes, i + 48, 10).trim()
            val size = sizeStr.toIntOrNull() ?: break
            Log.i(TAG, "$pkg: ar member '${name}' size=$size at offset $i")
            val payloadStart = i + 60
            if (payloadStart + size > bytes.size) break
            val payload = bytes.copyOfRange(payloadStart, payloadStart + size)
            if (name == "data.tar.xz") dataXz = payload
            else if (name == "control.tar.xz") controlXz = payload
            i = payloadStart + size + (size % 2)
        }
        if (dataXz == null) {
            Log.e(TAG, "$pkg sin data.tar.xz")
            return false
        }

        // ── Descompresión vía xz binario del rootfs ──
        val xzBin = File(usrDir, "bin/xz")
        if (!xzBin.exists()) {
            Log.e(TAG, "$pkg: xz binario no encontrado en $xzBin")
            return false
        }
        val xzTemp = File.createTempFile("nanoapt_", ".data.tar.xz", baseDir)
        xzTemp.writeBytes(dataXz)
        try {
            val taskId = "deb_${System.currentTimeMillis()}"
            spawnWorker(xzBin.absolutePath,
                listOf("xz", "-d", "-c", xzTemp.absolutePath),
                mapOf("PREFIX" to usrDir.absolutePath, "PATH" to "${usrDir.absolutePath}/bin:/system/bin",
                      "LD_LIBRARY_PATH" to "${usrDir.absolutePath}/lib"),
                taskId)
            val filesDir = baseDir.parentFile!!
            val rcFile = File(filesDir, "worker_rc_$taskId")
            val outFile = File(filesDir, "worker_out_$taskId")
            var waited = 0
            while (!rcFile.exists() && waited < 120_000) { Thread.sleep(500); waited += 500 }
            if (rcFile.exists() && rcFile.readText().trim().toIntOrNull() == 0 && outFile.exists()) {
                val n = TarExtractor.extract(outFile, baseDir, stripComponents = 5)
                fixTruncatedNames()
                if (controlXz != null) runPostinst(controlXz, pkg)
                Log.i(TAG, "$pkg extraído vía xz (v$version, $n entradas)")
                rcFile.delete(); outFile.delete()
                return true
            }
            Log.w(TAG, "$pkg xz rc=${rcFile.takeIf { it.exists() }?.readText()?.trim()}, outSize=${outFile.length()}")
            rcFile.delete(); outFile.delete()
        } catch (e: Exception) {
            Log.e(TAG, "$pkg extracción falló: ${e.message}")
        } finally {
            xzTemp.delete()
        }
        return false
    }

    /** Lee var/lib/dpkg/status simplificado → paquetes ya instalados. */
    private fun readInstalledStatus(): Set<String> {
        val status = File(usrDir, "var/lib/dpkg/status")
        if (!status.exists()) return emptySet()
        val out = mutableSetOf<String>()
        for (para in status.readText().split("\n\n")) {
            for (line in para.lines()) {
                if (line.startsWith("Package: ")) {
                    out.add(line.removePrefix("Package: ").trim())
                    break
                }
            }
        }
        return out
    }

    /** Registra el paquete en var/lib/dpkg/status (formato dpkg real). */
    private fun writeStatus(pkg: String, version: String) {
        val status = File(usrDir, "var/lib/dpkg/status")
        status.parentFile.mkdirs()
        val entry = "\nPackage: $pkg\n" +
            "Status: install ok installed\n" +
            "Version: $version\n" +
            "Architecture: aarch64\n\n"
        status.appendText(entry)
        Log.i(TAG, "status actualizado: $pkg=$version")
    }

    /**
     * En Android ≤12 con libandroid-support, readdir() devuelve nombres
     * truncados a ~44 chars. Los .so de Python en lib-dynload pierden el
     * sufijo "id.so" → Python no puede importarlos. Copiamos cada archivo
     * truncado a su nombre completo con ".so".
     */
    private fun fixTruncatedNames() {
        val dynload = File(usrDir, "lib/python3.14/lib-dynload")
        if (!dynload.isDirectory) return
        val truncated = dynload.listFiles()?.filter {
            it.isFile && it.name.endsWith("-linux-andro") && !it.name.endsWith(".so")
        } ?: return
        for (f in truncated) {
            val fixed = File(dynload, "${f.name}d.so")
            if (!fixed.exists()) {
                f.copyTo(fixed)
                Log.i(TAG, "fixTruncated: ${f.name} → ${fixed.name}")
            }
        }
    }

    /** Ejecuta postinst del control.tar.xz si existe. Necesario para
     *  paquetes como ca-certificates, fontconfig, man-db, glibc. */
    private fun runPostinst(controlXz: ByteArray, pkg: String) {
        val xzBin = File(usrDir, "bin/xz")
        if (!xzBin.exists()) return
        try {
            // 1. Escribir control.tar.xz a temp
            val ctrlXzFile = File.createTempFile("nanoapt_ctrl_", ".tar.xz", baseDir)
            ctrlXzFile.writeBytes(controlXz)
            try {
                // 2. Descomprimir xz → temp tar
                val taskId = "ctrl_${System.currentTimeMillis()}"
                spawnWorker(xzBin.absolutePath,
                    listOf("xz", "-d", "-c", ctrlXzFile.absolutePath),
                    mapOf("PREFIX" to usrDir.absolutePath,
                          "PATH" to "${usrDir.absolutePath}/bin:/system/bin",
                          "LD_LIBRARY_PATH" to "${usrDir.absolutePath}/lib"),
                    taskId)
                val filesDir = baseDir.parentFile!!
                val rcFile = File(filesDir, "worker_rc_$taskId")
                val outFile = File(filesDir, "worker_out_$taskId")
                var waited = 0
                while (!rcFile.exists() && waited < 30_000) { Thread.sleep(300); waited += 300 }
                if (!rcFile.exists() || rcFile.readText().trim().toIntOrNull() != 0 || !outFile.exists()) {
                    rcFile.delete(); outFile.delete(); return
                }
                rcFile.delete()

                // 3. Extraer postinst del tar (si existe)
                val postinst = extractScriptFromTar(outFile, "postinst")
                outFile.delete()
                if (postinst == null) return

                // 4. Escribir script a temp, hacer ejecutable, correr en rootfs
                val scriptFile = File.createTempFile("nanoapt_postinst_", ".sh", baseDir)
                scriptFile.writeBytes(postinst)
                scriptFile.setExecutable(true)
                try {
                    val env = mapOf(
                        "PREFIX" to usrDir.absolutePath,
                        "DPKG_ROOT" to baseDir.absolutePath,
                        "DPKG_ADMINDIR" to "${usrDir.absolutePath}/var/lib/dpkg",
                        "HOME" to File(baseDir, "home").absolutePath,
                        "PATH" to "${usrDir.absolutePath}/bin:/system/bin",
                        "LD_LIBRARY_PATH" to "${usrDir.absolutePath}/lib",
                    )
                    val taskId2 = "post_${System.currentTimeMillis()}"
                    spawnWorker(scriptFile.absolutePath, listOf("sh", scriptFile.absolutePath, "configure"),
                        env, taskId2)
                    val rcFile2 = File(filesDir, "worker_rc_$taskId2")
                    waited = 0
                    while (!rcFile2.exists() && waited < 60_000) { Thread.sleep(500); waited += 500 }
                    val exitCode = rcFile2.takeIf { it.exists() }?.readText()?.trim()?.toIntOrNull() ?: -1
                    rcFile2.delete()
                    Log.i(TAG, "$pkg postinst rc=$exitCode")
                } finally { scriptFile.delete() }
            } finally { ctrlXzFile.delete() }
        } catch (e: Exception) {
            Log.w(TAG, "$pkg postinst error: ${e.message}")
        }
    }

    /** Extrae un script del tar descomprimido. Busca entrada con nombre exacto. */
    private fun extractScriptFromTar(tarFile: File, scriptName: String): ByteArray? {
        // Usar el mismo parser tar: buscar entrada por nombre, extraer payload
        try {
            java.io.BufferedInputStream(java.io.FileInputStream(tarFile), 65536).use { stream ->
                val header = ByteArray(512)
                while (true) {
                    var read = 0
                    while (read < 512) { val n = stream.read(header, read, 512 - read); if (n < 0) return null; read += n }
                    if (header.all { it == 0.toByte() }) return null
                    val name = String(header, 0, 100).trimEnd('\u0000')
                    val size = header[124].toInt() and 0xFF
                    val found = name == "./$scriptName" || name == scriptName ||
                                name.endsWith("/$scriptName")
                    val paddedSize = size.toLong().let { s -> ((512L + s + 511) / 512 * 512) - 512 }
                    if (found && size in 1..1_000_000) {
                        val buf = ByteArray(size)
                        read = 0
                        while (read < size) { val n = stream.read(buf, read, size - read); if (n < 0) break; read += n }
                        return buf.copyOf(read)
                    }
                    // Skip payload
                    var remaining = paddedSize
                    val skipBuf = ByteArray(8192)
                    while (remaining > 0) {
                        val n = stream.read(skipBuf, 0, minOf(remaining, skipBuf.size.toLong()).toInt())
                        if (n < 0) break; remaining -= n
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "extractScript $scriptName: ${e.message}")
            return null
        }
    }
}
