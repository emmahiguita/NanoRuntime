package dev.nanoai.mobile

import android.util.Log
import java.io.File
import java.util.concurrent.TimeUnit
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
 *   8. postinst SÍ se ejecuta — de forma DIFERIDA: tras extraer todo el
 *      batch (deps ya en disco), en orden inverso al BFS (deps primero).
 *      Un postinst con rc != 0 hace fallar la instalación y el paquete
 *      queda reintentable (se elimina de status dpkg).
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
            "tigervnc",       // Xvnc: servidor X11 + VNC integrado
            "openbox",        // window manager ultraligero (~1MB)
            "libpng",         // para Xvnc (libpng16.so)
            "brotli",         // runtime de brotli y libbrotlidec.so
            "libandroid-support", // soporte POSIX Android
            "libxcb",         // X protocol C-language Binding
            "libx11",         // Core X11 client library
            "libxau",         // X authorization library
            "libxdmcp",       // X display manager control protocol
            "libxext",        // X extension library
            "libxrender",     // Render library para Xvnc/tint2/cairo
            "libpixman",      // Pixel manipulation library para Xvnc
            "libxfont2",      // X font handling library para Xvnc
            "libxkbfile",     // XKB keyboard file handling library para Xvnc
            "fontconfig",     // Font configuration library (contiene libfontconfig.so)
            "libexpat",       // XML parser library (libexpat.so.1) requerido por fontconfig
            "libunistring",   // Unicode string library (libunistring.so) requerido por libidn2
            "libidn2",        // IDN library (libidn2.so)
            "libandroid-shmem", // POSIX shm de Android — requerido por libcairo (dep de tint2)
            "xkeyboard-config", // reglas de teclado XKB — Xvnc aborta sin rules/evdev
            "xorg-xkbcomp",     // compilador de reglas XKB (nombre exacto en repo Termux X11: xorg-xkbcomp)
            "libglvnd",         // libGL/libGLX/libOpenGL requeridas por Xvnc moderno
            "mesa",             // implementación OpenGL que satisface libGL.so.1
            "lxterminal",      // terminal GTK real usada por el escritorio NanoAI
            "dbus",             // bus de mensajes: base de at-spi2 y futuro XFCE (dbus-launch ya estaba en disco sin status)
            "pcmanfm",          // gestor de archivos GTK3 (~7 MB; GTK3 ya instalado)
            "feh",              // visor de imágenes y wallpaper (~1 MB)
            "mousepad",         // editor gráfico XFCE (~15 MB con gtksourceview4+gspell)
            "gvfs",             // VFS de GLib: papelera (trash://) y mounts en pcmanfm
            "file-roller",      // compresor/gestor de archivos .zip/.tar/.gz
            "xpdf",             // visor PDF ligero para documentación
            "hicolor-icon-theme", // tema de íconos base XDG para GTK3/pcmanfm
            "adwaita-icon-theme", // tema de íconos premium para GTK3
            "librsvg",          // renderizador de íconos vectoriales SVG para aplicaciones GTK
            "psmisc",           // utilidades de procesos: pstree, killall, fuser
            "nano",             // editor de código/texto en terminal
            "curl",             // cliente de red y transferencia HTTP
            "wget",             // descargador de archivos por red
            "ttf-dejavu",       // Fuentes vectoriales TrueType DejaVu (Sans, Sans Mono) para Xft/GTK
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
     * Paquetes del bootstrap (rootfs inicial) — leídos del status file y validados.
     * Si la librería esencial no existe en disco, se elimina del set para que se instale.
     */
    private val bootstrapPackages: Set<String> by lazy {
        val pkgs = readInstalledStatus().toMutableSet()
        val libDir = File(usrDir, "lib")
        val binDir = File(usrDir, "bin")
        if (!File(binDir, "Xvnc").exists()) pkgs.remove("tigervnc")
        if (!File(binDir, "openbox").exists()) pkgs.remove("openbox")
        if (!File(libDir, "libandroid-support.so").exists()) pkgs.remove("libandroid-support")
        if (!File(libDir, "libpng16.so").exists()) pkgs.remove("libpng")
        if (!File(libDir, "libbrotlidec.so").exists()) { pkgs.remove("libbrotli"); pkgs.remove("brotli") }
        if (libDir.listFiles()?.any { it.name.startsWith("libxcb.so") } != true) pkgs.remove("libxcb")
        Log.i(TAG, "bootstrap validado: ${pkgs.size} paquetes verdaderamente en disco")
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
    private fun fetchAllIndexes(forceRefresh: Boolean = false): Map<String, PkgInfo> {
        val merged = mutableMapOf<String, PkgInfo>()
        for (repo in ALL_REPOS) {
            val indexFile = File(baseDir, "packages_${repo.name}")
            if (forceRefresh || !indexFile.exists() || indexFile.length() < 10_000) {
                if (!download(repo.indexUrl, indexFile)) {
                    Log.w(TAG, "índice ${repo.name} no disponible, saltando")
                    if (!forceRefresh) continue
                }
            }
            if (indexFile.exists()) {
                val repoIndex = parseIndex(indexFile.readText(), repo)
                Log.i(TAG, "repo ${repo.name}: ${repoIndex.size} paquetes")
                // F7: putIfAbsent en vez de putAll — el orden de ALL_REPOS
                // (main → x11 → root) marca la preferencia: gana el primero.
                for ((name, info) in repoIndex) merged.putIfAbsent(name, info)
            }
        }
        return merged
    }

    /** Instala [targets] y sus deps desde todos los repos. */
    fun install(targets: List<String>, onProgress: (String, Int) -> Unit): Boolean {
        try {
            onProgress("index", 5)
            var index = fetchAllIndexes(forceRefresh = false)
            if (targets.any { it !in index }) {
                Log.i(TAG, "Paquete objetivo falta en el índice cacheado -> Forzando descarga fresca de índices")
                index = fetchAllIndexes(forceRefresh = true)
            }
            onProgress("index", 10)
            if (index.isEmpty()) { Log.e(TAG, "índices vacíos"); return false }

            val installed = readInstalledStatus().toMutableSet()
            val binDir = File(usrDir, "bin")
            val libDir = File(usrDir, "lib")
            if (!File(binDir, "Xvnc").exists()) installed.remove("tigervnc")
            if (!File(binDir, "openbox").exists()) installed.remove("openbox")
            if (!File(libDir, "libfontconfig.so.1").exists() && !File(libDir, "libfontconfig.so").exists()) installed.remove("fontconfig")
            if (!File(libDir, "libexpat.so.1").exists() && !File(libDir, "libexpat.so").exists()) installed.remove("libexpat")

            val bootPkgs = bootstrapPackages

            // BFS resolver deps
            val toInstall = mutableListOf<String>()
            val seen = mutableSetOf<String>()
            val missing = mutableListOf<String>()
            val queue = ArrayDeque(targets)
            while (queue.isNotEmpty()) {
                val pkg = queue.removeFirst()
                if (!seen.add(pkg)) continue
                val info = index[pkg]
                if (info == null) {
                    // F1: objetivo ausente del índice = fallo duro. Antes se
                    // saltaba en silencio e install() devolvía true con
                    // binarios ausentes (éxito falso).
                    Log.w(TAG, "pkg no encontrado en índices: $pkg")
                    missing.add(pkg)
                    continue
                }

                val alreadyPresent = pkg in installed || pkg in bootPkgs
                if (!alreadyPresent) {
                    toInstall.add(pkg)
                }

                for (dep in info.depends) {
                    val alt = dep.split("|").map { it.trim() }.firstOrNull { index.containsKey(it) }
                    if (alt != null) {
                        if (alt !in installed && alt !in bootPkgs && alt !in seen) {
                            queue.addLast(alt)
                        }
                    } else {
                        // Puede ser paquete virtual (Provides) — no es fallo
                        // duro, pero queda registrado.
                        Log.w(TAG, "dep sin resolver en índices: $dep (de $pkg)")
                    }
                }
            }
            if (missing.isNotEmpty()) {
                Log.e(TAG, "instalación abortada — objetivos ausentes del índice: $missing")
                return false
            }
            Log.i(TAG, "instalar (${toInstall.size}): ${toInstall.take(10)}...")

            // Descargar y extraer cada .deb. control.tar.xz se difiere para
            // ejecutar postinsts tras el batch completo (F2: deps ya en disco).
            val pkgsDir = File(baseDir, "pkgs").apply { mkdirs() }
            val postinsts = mutableListOf<Pair<String, ByteArray>>()
            var done = 0
            for (pkg in toInstall) {
                val info = index[pkg]
                if (info == null) {
                    Log.e(TAG, "$pkg no está en el índice"); return false
                }
                val deb = File(pkgsDir, "$pkg.deb")
                onProgress("download $pkg", 10 + done * 40 / toInstall.size)
                if (!deb.exists() || deb.length() < 1000) {
                    if (!download(info.repo.poolBase + info.filename, deb)) {
                        Log.e(TAG, "fallo descarga $pkg"); return false
                    }
                }
                if (info.sha256.isNotEmpty()) {
                    var actual = sha256(deb)
                    if (!actual.equals(info.sha256, ignoreCase = true)) {
                        // F12: reintentar la descarga una vez antes de abortar.
                        Log.w(TAG, "$pkg SHA256 mismatch — reintentando descarga")
                        deb.delete()
                        if (download(info.repo.poolBase + info.filename, deb)) {
                            actual = sha256(deb)
                        }
                        if (!actual.equals(info.sha256, ignoreCase = true)) {
                            Log.e(TAG, "$pkg SHA256 mismatch"); deb.delete(); return false
                        }
                    }
                }
                val control = extractDeb(deb, pkg, info.version)
                if (control == null) {
                    Log.e(TAG, "fallo extracción $pkg"); return false
                }
                writeStatus(pkg, info.version)
                installed.add(pkg)
                if (control.isNotEmpty()) postinsts.add(pkg to control)
                done++
                onProgress("install $pkg", 50 + done * 50 / toInstall.size)
            }

            // F1: verificación final — todos los objetivos deben quedar instalados.
            val notInstalled = targets.filter { it !in installed }
            if (notInstalled.isNotEmpty()) {
                Log.e(TAG, "instalación incompleta — faltan: $notInstalled")
                return false
            }

            // F2/F3: postinsts diferidos, en orden inverso (deps primero).
            // rc != 0 → fallo + paquete reintentable (se quita del status).
            for ((pkg, control) in postinsts.asReversed()) {
                onProgress("postinst $pkg", 90)
                if (!runPostinst(control, pkg)) {
                    Log.e(TAG, "$pkg postinst falló — paquete marcado reintentable")
                    removeInstalledStatusPackages(listOf(pkg))
                    return false
                }
            }
            onProgress("done", 100)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "install falló: $e")
            return false
        }
    }

    /** Instala el escritorio VNC mínimo (Xvnc + openbox + lxterminal + libpng + libbrotli + libxcb). */
    fun installGraphical(onProgress: (String, Int) -> Unit): Boolean {
        val libDir = File(usrDir, "lib")
        val hasExpat = File(libDir, "libexpat.so.1").exists() || File(libDir, "libexpat.so").exists()
        val hasFontcfg = File(libDir, "libfontconfig.so.1").exists() || File(libDir, "libfontconfig.so").exists()
        val hasXcb = libDir.listFiles()?.any { it.name.startsWith("libxcb.so") } == true
        val hasXkbcomp = File(usrDir, "bin/xkbcomp").exists()
        val hasGl = File(libDir, "libGL.so.1").exists() || File(libDir, "libGL.so").exists()

        if (!hasExpat || !hasFontcfg || !hasXcb || !hasXkbcomp || !hasGl) {
            Log.i(TAG, "Forzando actualización limpia de paquetes gráficos de Termux")
            removeInstalledStatusPackages(DESKTOP_PACKAGES + "opengl")
        }
        // Reglas XKB inválidas (stub o ausentes) → forzar reinstall de
        // xkeyboard-config. El dpkg status puede decir "instalado" con los
        // archivos rotos (symlink muerto) — el reinstall re-extrae las
        // reglas reales. Sin esto, xkbcomp falla y Xvnc aborta con
        // "Failed to activate virtual core keyboard".
        val evdev = File(usrDir, "share/X11/xkb/rules/evdev")
        if (!evdev.exists() || evdev.length() < 200) {
            Log.i(TAG, "Reglas XKB inválidas — forzando reinstall de xkeyboard-config")
            removeInstalledStatusPackages(listOf("xkeyboard-config"))
        }
        val res = install(DESKTOP_PACKAGES, onProgress)
        if (res) {
            libDir.listFiles()?.forEach { f ->
                if (f.name.contains(".so.") && !f.name.endsWith(".so")) {
                    val baseName = f.name.substringBefore(".so.") + ".so"
                    val target = File(libDir, baseName)
                    if (!target.exists()) {
                        try {
                            f.copyTo(target)
                            Log.i(TAG, "Symlink/Copy creado: ${f.name} -> $baseName")
                        } catch (e: Exception) {
                            Log.w(TAG, "SymlinkCopy falló: ${f.name} -> ${e.message}")
                        }
                    }
                }
            }
        }
        return res
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
            // F12: si quedó un .deb parcial (>= 1000 bytes se reusaría como
            // válido en el siguiente intento), borrarlo.
            if (dest.exists()) dest.delete()
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
     *
     * @return null = fallo; ByteArray vacío = éxito sin control.tar.xz;
     *         otro valor = payload del control.tar.xz (F2: diferido —
     *         install() ejecuta los postinsts tras el batch completo).
     */
    private fun extractDeb(deb: File, pkg: String, version: String): ByteArray? {
        val bytes = deb.readBytes()
        if (bytes.size < 8 || String(bytes, 0, 8) != "!<arch>\n") {
            Log.e(TAG, "$pkg no es un .deb válido")
            return null
        }
        // Parsear ar: name(16) mtime(12) uid(6) gid(6) mode(8) size(10) magic(2)
        var dataXz: ByteArray? = null
        var controlXz: ByteArray? = null
        var i = 8
        while (i + 60 <= bytes.size) {
            // Validar magic de cierre del header ar (0x60 0x0A).
            if (bytes[i + 58] != 0x60.toByte() || bytes[i + 59] != 0x0A.toByte()) {
                Log.e(TAG, "$pkg header ar corrupto en offset $i")
                return null
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
            return null
        }

        // -- Descompresion: xz real del sandbox -> fallback XzDecoder Kotlin --
        // Android 10+ bloquea execve() de binarios extraidos por la propia app
        // a su almacenamiento privado (W^X / SELinux): ejecutar
        // `files/nano/usr/bin/xz` directamente siempre falla con
        // "Permission denied" (rc=126), en cualquier subruta de filesDir.
        // Workaround: invocar el binario a traves de /system/bin/linker(64),
        // el propio cargador dinamico del sistema. Ese binario SI tiene
        // permiso de ejecucion (vive en /system) y actua como loader generico
        // de ELFs PIE arbitrarios sin pasar por el execve() bloqueado sobre el
        // archivo extraido — mismo truco ya usado para xkbcomp en
        // boot_orchestrator.dart (linker64 "$PREFIX/xkbcomp.real" "$@").
        var xzSuccess = false

        // -- Via 1: xz real via ProcessBuilder (a traves del linker del sistema) --
        val xzPaths = listOf(
            File(baseDir, "xz"),
            File(usrDir, "bin/xz"),
            File("/system/bin/xz"),
        )
        for (xzBin in xzPaths) {
            if (!xzBin.exists()) continue
            xzBin.setExecutable(true)
            val xzTemp = File.createTempFile("nanoapt_", ".data.tar.xz", baseDir)
            val tarFile = File.createTempFile("nanoapt_", ".tar", baseDir)
            val errFile = File.createTempFile("nanoapt_", ".stderr", baseDir)
            xzTemp.writeBytes(dataXz)
            try {
                val pb = ProcessBuilder("/system/bin/sh", "-c", "${execCmd(xzBin.absolutePath)} -d -c \"${xzTemp.absolutePath}\"")
                pb.directory(baseDir)
                pb.redirectOutput(tarFile)
                pb.redirectError(errFile)
                val env = pb.environment()
                env["PREFIX"] = usrDir.absolutePath
                env["PATH"] = "${usrDir.absolutePath}/bin:/system/bin"
                env["LD_LIBRARY_PATH"] = "${usrDir.absolutePath}/lib"
                val proc = pb.start()
                if (!proc.waitFor(120_000, TimeUnit.MILLISECONDS)) {
                    proc.destroyForcibly()
                    Log.w(TAG, "$pkg ${xzBin.absolutePath} timeout")
                    continue
                }
                val rc = proc.exitValue()
                val errText = errFile.takeIf { it.exists() && it.length() > 0 }?.readText()?.trim()
                if (rc == 0 && tarFile.length() > 0) {
                    val n = TarExtractor.extract(tarFile, baseDir, stripComponents = 5)
                    fixTruncatedNames()
                    Log.i(TAG, "$pkg extraído vía ProcessBuilder/${xzBin.name} (v$version, $n entradas)")
                    xzSuccess = true
                    break
                }
                Log.w(TAG, "$pkg ${xzBin.absolutePath} rc=$rc outSize=${tarFile.length()} err=${errText?.take(400)}")
            } catch (e: Exception) {
                Log.e(TAG, "$pkg ${xzBin.absolutePath} ProcessBuilder falló: ${e.message}")
            } finally {
                xzTemp.delete()
                tarFile.delete()
                errFile.delete()
            }
        }

        // -- Vía 2: fallback XzDecoder Kotlin --
        if (!xzSuccess) {
            val tarFile = File.createTempFile("nanoapt_", ".tar", baseDir)
            try {
                // F18: descompresión y extracción con atribución separada —
                // antes cualquier excepción de TarExtractor se logueaba como
                // "XzDecoder error".
                try {
                    java.io.BufferedOutputStream(java.io.FileOutputStream(tarFile)).use { tarOut ->
                        XzDecoder.decompressToStream(dataXz, tarOut)
                    }
                } catch (e: XzDecoder.XzException) {
                    Log.w(TAG, "$pkg XzDecoder falló: ${e.message}")
                    return null
                }
                val n = try {
                    TarExtractor.extract(tarFile, baseDir, stripComponents = 5)
                } catch (e: Exception) {
                    Log.w(TAG, "$pkg TarExtractor falló: ${e.message}")
                    return null
                }
                chmodBinaries()
                fixTruncatedNames()
                Log.i(TAG, "$pkg extraído vía XzDecoder (v$version, $n entradas)")
                xzSuccess = true
            } finally {
                tarFile.delete()
            }
        }

        if (xzSuccess) return controlXz ?: ByteArray(0)
        Log.e(TAG, "fallo extracción $pkg: xz y XzDecoder fallaron")
        return null
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

    /** Removes full dpkg status paragraphs, not just Package lines. */
    private fun removeInstalledStatusPackages(packages: Collection<String>) {
        val status = File(usrDir, "var/lib/dpkg/status")
        if (!status.exists()) return

        val names = packages.toSet()
        val kept = status.readText()
            .split(Regex("\n{2,}"))
            .filterNot { paragraph ->
                paragraph.lineSequence().any { line ->
                    line.startsWith("Package: ") && line.removePrefix("Package: ").trim() in names
                }
            }
            .filter { it.isNotBlank() }

        status.writeText(kept.joinToString("\n\n", postfix = "\n"))
    }

    /** Registra el paquete en var/lib/dpkg/status (formato dpkg real). */
    private fun writeStatus(pkg: String, version: String) {
        val status = File(usrDir, "var/lib/dpkg/status")
        status.parentFile?.mkdirs()
        val entry = "\nPackage: $pkg\n" +
            "Status: install ok installed\n" +
            "Version: $version\n" +
            "Architecture: aarch64\n\n"
        status.appendText(entry)
        Log.i(TAG, "status actualizado: $pkg=$version")
    }

    /**
     * Construye el comando para ejecutar [binPath] evitando el bloqueo
     * execve() (W^X / SELinux) sobre binarios extraidos a almacenamiento
     * privado de la app. Los binarios bajo /system ya tienen permiso de
     * ejecucion; el resto se carga a traves de /system/bin/linker(64), el
     * cargador dinamico del sistema, que si tiene permiso de ejecucion y
     * puede mapear ELFs PIE arbitrarios (mismo truco usado para xkbcomp en
     * boot_orchestrator.dart).
     */
    private fun execCmd(binPath: String): String {
        if (binPath.startsWith("/system/")) return "\"$binPath\""
        val linker = if (android.os.Process.is64Bit()) "/system/bin/linker64" else "/system/bin/linker"
        return "\"$linker\" \"$binPath\""
    }

    private fun chmodBinaries() {
        val binDir = File(usrDir, "bin")
        if (!binDir.isDirectory) return
        binDir.listFiles()?.forEach { file ->
            if (file.isFile) {
                file.setExecutable(true, false)
            }
        }
    }

    /**
     * En Android â‰¤12 con libandroid-support, readdir() devuelve nombres
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

    /**
     * Ejecuta postinst del control.tar.xz (F2: diferido — install() lo llama
     * tras instalar el batch completo, deps primero). Devuelve true solo si
     * el script no existe (no es fallo) o terminó con rc == 0.
     *
     * F3: antes el rc se ignoraba y la instalación se daba por exitosa.
     * F4: intérprete explícito — execve(script) resuelve el shebang del
     *     propio script y los shebangs de Termux
     *     (/data/data/com.termux/files/usr/bin/sh) no existen en este
     *     rootfs; sin intérprete explícito el postinst nunca corría (rc=-1).
     */
    private fun runPostinst(controlXz: ByteArray, pkg: String): Boolean {
        // F5: misma doble vía que extractDeb — xz real, fallback XzDecoder.
        var controlTarBytes: ByteArray? = null

        // Vía 1: xz real
        val xzBin = listOf(File(baseDir, "xz"), File(usrDir, "bin/xz"), File("/system/bin/xz")).firstOrNull { it.exists() }
        if (xzBin != null) {
            try {
                val ctrlXzFile = File.createTempFile("nanoapt_ctrl_", ".tar.xz", baseDir)
                val outFile = File.createTempFile("nanoapt_ctrl_", ".tar", baseDir)
                val errFile = File.createTempFile("nanoapt_ctrl_", ".stderr", baseDir)
                try {
                    ctrlXzFile.writeBytes(controlXz)
                    val pb = ProcessBuilder("/system/bin/sh", "-c", "${execCmd(xzBin.absolutePath)} -d -c \"${ctrlXzFile.absolutePath}\"")
                    pb.directory(baseDir)
                    pb.redirectOutput(outFile)
                    pb.redirectError(errFile)
                    val env = pb.environment()
                    env["PREFIX"] = usrDir.absolutePath
                    env["PATH"] = "${usrDir.absolutePath}/bin:/system/bin"
                    env["LD_LIBRARY_PATH"] = "${usrDir.absolutePath}/lib"
                    val proc = pb.start()
                    if (!proc.waitFor(30_000, TimeUnit.MILLISECONDS)) {
                        proc.destroyForcibly()
                        Log.w(TAG, "$pkg control xz timeout")
                    } else if (proc.exitValue() == 0 && outFile.length() > 0) {
                        controlTarBytes = outFile.readBytes()
                    } else {
                        Log.w(TAG, "$pkg control xz rc=${proc.exitValue()}")
                    }
                } finally {
                    ctrlXzFile.delete()
                    outFile.delete()
                    errFile.delete()
                }
            } catch (e: Exception) {
                Log.w(TAG, "$pkg control xz (binario) falló: ${e.message}")
            }
        }

        // Vía 2: fallback XzDecoder
        if (controlTarBytes == null) {
            try {
                java.io.ByteArrayOutputStream().use { out ->
                    XzDecoder.decompressToStream(controlXz, out)
                    controlTarBytes = out.toByteArray()
                }
            } catch (e: Exception) {
                Log.w(TAG, "$pkg control XzDecoder falló: ${e.message}")
                return false
            }
        }

        // Extraer postinst del control.tar
        val postinst = try {
            val tarFile = File.createTempFile("nanoapt_ctrltar_", ".tar", baseDir)
            try {
                tarFile.writeBytes(checkNotNull(controlTarBytes))
                extractScriptFromTar(tarFile, "postinst")
            } finally {
                tarFile.delete()
            }
        } catch (e: Exception) {
            Log.w(TAG, "$pkg control tar corrupto: ${e.message}")
            null
        } ?: return true // sin postinst: no es fallo

        return try {
            val scriptFile = File.createTempFile("nanoapt_postinst_", ".sh", baseDir)
            try {
                // P3 (evidencia device 2026-08-12): los postinsts de Termux
                // hardcodean /data/data/com.termux/files/usr como prefix.
                // En nuestro rootfs esa ruta no existe: mkdir falla y
                // dbus-uuidgen aborta con SIGABRT (rc=134) al no poder
                // tocar el machine-id de su path compilado. Se traduce el
                // prefix Termux al nuestro ANTES de ejecutar el script.
                val termuxPrefix = "/data/data/com.termux/files/usr"
                val rewritten = String(postinst, Charsets.UTF_8)
                    .replace(termuxPrefix, usrDir.absolutePath)
                scriptFile.writeBytes(rewritten.toByteArray(Charsets.UTF_8))
                scriptFile.setExecutable(true)
                val envMap = mapOf(
                    "PREFIX" to usrDir.absolutePath,
                    "DPKG_ROOT" to baseDir.absolutePath,
                    "DPKG_ADMINDIR" to "${usrDir.absolutePath}/var/lib/dpkg",
                    "HOME" to File(baseDir, "home").absolutePath,
                    "PATH" to "${usrDir.absolutePath}/bin:/system/bin",
                    "LD_LIBRARY_PATH" to "${usrDir.absolutePath}/lib",
                )
                // F17: id único — System.currentTimeMillis() podía colisionar
                // entre paquetes del mismo batch.
                val taskId = "post_${java.util.UUID.randomUUID()}"
                val filesDir = baseDir.parentFile!!
                // F4: bin = intérprete explícito. El worker hace
                // execve(bin, argv) con argv tal cual; si bin fuera el
                // script, el kernel resolvería su shebang Termux y fallaría.
                // Preferimos el sh del sistema (sin bloqueo W^X de execve).
                val sh = listOf(File("/system/bin/sh"), File(usrDir, "bin/sh")).firstOrNull { it.exists() }
                if (sh == null) {
                    Log.e(TAG, "$pkg sin intérprete sh disponible")
                    return false
                }
                spawnWorker(sh.absolutePath, listOf(sh.name, scriptFile.absolutePath, "configure"), envMap, taskId)
                val rcFile = File(filesDir, "worker_rc_$taskId")
                var waited = 0
                while (!rcFile.exists() && waited < 60_000) { Thread.sleep(500); waited += 500 }
                val exitCode = rcFile.takeIf { it.exists() }?.readText()?.trim()?.toIntOrNull() ?: -1
                rcFile.delete()
                Log.i(TAG, "$pkg postinst rc=$exitCode")
                exitCode == 0
            } finally {
                scriptFile.delete()
            }
        } catch (e: Exception) {
            Log.w(TAG, "$pkg postinst error: ${e.message}")
            false
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
                    val sizeStr = String(header, 124, 12).trimEnd('\u0000').trim()
                    val size = if (sizeStr.isNotEmpty()) sizeStr.toLong(8) else 0L
                    val found = name == "./$scriptName" || name == scriptName ||
                                name.endsWith("/$scriptName")
                    val paddedSize = ((512L + size + 511) / 512 * 512) - 512
                    if (found && size in 1..1_000_000) {
                        val sz = size.toInt()
                        val buf = ByteArray(sz)
                        read = 0
                        while (read < sz) { val n = stream.read(buf, read, sz - read); if (n < 0) break; read += n }
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








