package dev.nanoai.mobile.services

import kotlinx.coroutines.delay

enum class XTransport {
    TCP, UNIX
}

data class XDisplayEndpoint(
    val display: Int,
    val host: String?,
    val transport: XTransport
)

interface XServerBackend {
    /** Inicia el servidor X. [env] debe incluir PREFIX/HOME/LD_LIBRARY_PATH/
     *  XDG_CONFIG_HOME — Xvnc los necesita para resolver share/X11/xkb/rules
     *  y sus libs; sin ellos aborta silenciosamente antes de abrir el puerto RFB.
     *  [width]/[height] = geometría del framebuffer (px del viewport lógico);
     *  0/ausente = fallback 1280x720. */
    suspend fun start(
        env: Map<String, String> = emptyMap(),
        width: Int = 0,
        height: Int = 0,
    ): Boolean

    /** Espera activamente a que el servidor reporte estar listo. */
    suspend fun awaitReady(): Boolean

    /** Detiene el servidor X. */
    suspend fun stop()

    /** Retorna el estado y configuración actual de display. */
    fun getEndpoint(): XDisplayEndpoint

    /** Geometría real del framebuffer tras el último start (0 = nunca arrancado).
     *  Puede diferir de la pedida por el cap de memoria (resolveGeometry). */
    val fbWidth: Int get() = 0
    val fbHeight: Int get() = 0

    /** Puerto RFB del display (5900 + número de display). */
    val rfbPort: Int get() = 5900 + getEndpoint().display

    /** Último error de start/awaitReady (null si el último intento fue limpio). */
    val lastError: String?

    /** ¿Proceso del servidor X vivo? Delegado al worker (padre del proceso),
     *  SIN tocar el socket.
     * Un probe TCP que corta a mitad del handshake RFB cuenta como "security
     * failure" para el anti-brute-force de TigerVNC — tras ~5 cortes rechaza
     * TODA conexión ("Too many security failures"). Los checks periódicos
     * (watchdog, getStatus) DEBEN usar esto, nunca tcpReachable. */
    fun isAlive(): Boolean
}

/**
 * Backend interno de X11 que usa VNC.
 * Se inicia de forma independiente usando un proceso nativo desvinculado (Xvnc).
 */
class InternalXvncBackend(
    private val usrDir: java.io.File,
    private val spawnBg: (binaryPath: String, argv: List<String>, envp: Map<String, String>) -> Long,
    private val vncPassword: String = "",
    // Liveness delegado al worker (:nanoshell), padre real de Xvnc. El
    // proceso principal NO puede leer /proc/<pid> de los hijos del worker
    // (Android restringe /proc a hijos directos del lector) — leerlo aquí
    // devolvía false siempre, awaitReady reportaba "murió durante el
    // arranque" 1 ms tras el spawn y stop() mataba a un Xvnc vivo con
    // SIGKILL. Evidencia device 2026-08-14: reap "signal=9" + kill del app.
    private val isPidAlive: (Long) -> Boolean = { false },
    // BUG-2 FIX: kill de Xvnc delegado al worker (padre real). El kill local
    // Process.killProcess lanzaba SecurityException en Android 12+ (proceso
    // ajeno al app) — tragada por el catch, Xvnc seguía vivo y huérfano
    // ocupando 5901 hasta que el próximo start() lo mataba vía anti-duplicado.
    private val killPid: (Long) -> Boolean = { false },
) : XServerBackend {
    companion object {
        private const val TAG = "InternalXvncBackend"

        // Máscara XOR fija del formato vncpasswd (TigerVNC). El archivo guarda
        // el password de 8 bytes XOR-eado con esta máscara; NO es cifrado real
        // — solo evita el dump casual. La seguridad real la da VNC Auth
        // (DES challenge) en el wire protocol.
        private val VNC_PASS_MASK = byteArrayOf(
            0x17, 0x52.toByte(), 0x6b.toByte(), 0x06,
            0x35, 0x78.toByte(), 0x88.toByte(), 0x07,
        )
    }

    @Volatile private var xvncPid: Long = -1
    @Volatile private var resolvedWidth = 0
    @Volatile private var resolvedHeight = 0
    private val endpoint = XDisplayEndpoint(
        display = 1,
        host = null,
        transport = XTransport.UNIX
    )

    override val fbWidth: Int get() = resolvedWidth
    override val fbHeight: Int get() = resolvedHeight

    @Volatile override var lastError: String? = null
        private set

    /**
     * Geometría del framebuffer a partir del viewport lógico. Reglas:
     *  - 0/ausente → 1280x720 (comportamiento previo).
     *  - Lado mayor capado a 1920: en loopback un frame Raw de 1080x2400x4
     *    (~10 MB) ya es pesado para el raster; en 1440x3120 (~18 MB) el
     *    primer FBU completo satura el decodificador. El cap escala AMBOS
     *    lados por el mismo factor → aspect exacto del device preservado
     *    (el visor no distorsiona ni deja bandas).
     *  - Múltiplo de 8: evita filas de píxeles muertos en el borde con
     *    algunos builds de Xvnc/TigerVNC.
     */
    private fun resolveGeometry(w: Int, h: Int): Pair<Int, Int> {
        var width = if (w > 0) w else 1280
        var height = if (h > 0) h else 720
        val cap = 1920
        val maxDim = maxOf(width, height)
        if (maxDim > cap) {
            val k = cap.toDouble() / maxDim
            width = (width * k).toInt().coerceAtLeast(8)
            height = (height * k).toInt().coerceAtLeast(8)
        }
        width = (width / 8) * 8
        height = (height / 8) * 8
        return width to height
    }

    override suspend fun start(
        env: Map<String, String>,
        width: Int,
        height: Int,
    ): Boolean {
        // K-1: el anti-duplicado ahora vive en el worker (worker_jni.c,
        // registro g_daemons: cada spawn de un binario mata con SIGKILL al
        // anterior ANTES del fork — evidencia logcat "matando duplicado Xvnc
        // pid=... antes del spawn"). El viejo killLingeringXvnc de acá
        // escaneaba /proc, invisible para el proceso principal desde el
        // refactor al worker (cero hallazgos K-1 con duplicados vivos).
        val vncPort = rfbPort

        // Con contraseña → VNC Auth (-rfbauth). Sin contraseña → None, como
        // siempre. Solo afecta a ESTE arranque: cambiar el password requiere
        // stop + start del escritorio.
        val secTypes: String
        val rfbAuthArg: List<String>
        if (vncPassword.isNotEmpty()) {
            val passFile = writeVncPassFile()
            if (passFile != null) {
                secTypes = "VncAuth"
                rfbAuthArg = listOf("-rfbauth", passFile.absolutePath)
            } else {
                android.util.Log.w(TAG, "Fallo escribiendo vncpasswd — cayendo a SecurityTypes None")
                secTypes = "None"
                rfbAuthArg = emptyList()
            }
        } else {
            secTypes = "None"
            rfbAuthArg = emptyList()
        }

        // D-1: geometry ANTES fija 1280x720 (landscape 16:9). En un device
        // portrait (1080x2400) el visor mostraba el framebuffer como una
        // franja centrada con bandas enormes (fit mantiene aspect — s1.png).
        // Ahora el framebuffer nace con el aspect del viewport: sin bandas
        // y sin distorsión (BoxFit.fill con aspect igual).
        val (geoW, geoH) = resolveGeometry(width, height)
        resolvedWidth = geoW
        resolvedHeight = geoH
        val argv = listOf(
            ":${endpoint.display}",
            "-geometry", "${geoW}x$geoH",
            "-depth", "24",
            "-rfbport", "$vncPort",
            "-SecurityTypes", secTypes,
            "-localhost", "yes",
            "-listen", "tcp",
            // DPI móvil: hace que las apps Xft/GTK escalen fuentes y widgets
            // (144 = 1.5x sobre 96 — menús y ventanas grandes para dedos;
            // DESKTOP-FIX-01 subió desde 120 tras feedback físico de iconos
            // y textos pequeños; los iconos del escritorio pcmanfm y el panel
            // tint2 llevan su propio tamaño explícito, no escalan por dpi).
            // Flag verificado con `Xvnc -help` en el rootfs (soportado por
            // el binario TigerVNC de Termux).
            "-dpi", "144",
            // U-9: sin -fp el Xvnc nace SIN fuentes core (xdpyinfo vivo: sin
            // "default font path" — los defaults compilados apuntan a paths
            // que no existen en Android). aterm (que NO linkea libXft) caía
            // a "fixed" inexistente y renderizaba glifos basura. misc trae
            // fixed.bdf (6x13, fonts.dir + alias "fixed"), 75dpi las UTBI__10.
            // Paths reales del rootfs: el proceso corre bajo nanoroot y estos
            // archivos viven en su propio files dir — acceso directo sin
            // depender de redirecciones.
            "-fp", "${usrDir.absolutePath}/share/fonts/misc,${usrDir.absolutePath}/share/fonts/75dpi",
        ) + rfbAuthArg
        // NOTA (evidencia device 2026-08-12): este binario Xvnc de Termux NO
        // soporta "-kb" — "Unrecognized option: -kb" y exit 1 antes de abrir
        // el puerto RFB. El flag estaba oculto por el bug de argv desplazado
        // (NAT-2); con el argv correcto aborta en el parseo de opciones.
        // El fallback de xkbcomp lo cubre el wrapper desplegado en
        // usr/bin/xkbcomp (ver boot_orchestrator).
        // Sin -nodaemon: Xvnc de TigerVNC invocado directamente queda en
        // foreground (el fork lo hace el wrapper vncserver, no Xvnc) — pasar
        // un flag inexistente lo haría abortar en el arranque.
        // Xvnc necesita el mismo entorno que openbox (PREFIX, HOME,
        // LD_LIBRARY_PATH, XDG_CONFIG_HOME...) para resolver sus libs y las
        // reglas XKB en share/X11/xkb/rules/evdev. Sin esto aborta antes de
        // abrir el puerto RFB (fallo silencioso bajo Android/ColorOS).
        lastError = null
        xvncPid = spawnBg("${usrDir.absolutePath}/bin/Xvnc", argv, env)
        if (xvncPid <= 0) lastError = "spawnBg de Xvnc devolvió PID inválido ($xvncPid)"
        return xvncPid > 0
    }

    override suspend fun awaitReady(): Boolean {
        val maxTimeoutMs = 15_000L
        val start = System.currentTimeMillis()

        // Readiness SIN tocar TCP: un probe que corta a mitad del handshake
        // RFB suma un "security failure" al anti-brute-force de TigerVNC
        // (tras ~5 cortes rechaza TODA conexión). Además, con daemons
        // huérfanos de ciclos previos, el puerto abierto no prueba que el
        // Xvnc PROPIO (xvncPid) sea el que escucha — evidencia device
        // 2026-08-12: "VNC listo y estable" con xvncPid muerto status=1
        // (bind fail) y un servidor ajeno respondiendo.
        //
        // Señales locales de readiness:
        //   1. xvncPid vivo (delegado al worker: kill(pid, 0) del padre,
        //      sin tocar sockets).
        //   2. Socket X11 del display creado por el proceso: Xvnc crea
        //      usr/tmp/.X11-unix/X<display> al abrir el display, incluso con
        //      -listen tcp (verificado en device).
        //   3. Estabilización: ambos siguen bien 2s después (cubre el fallo
        //      de libs/xkb post-bind del P0-2 sin probe de red).
        val xSock = java.io.File(usrDir, "tmp/.X11-unix/X${endpoint.display}")
        while (System.currentTimeMillis() - start < maxTimeoutMs) {
            if (!isAlive()) {
                lastError = "Xvnc (PID $xvncPid) murió durante el arranque " +
                    "(status capturado por el reaper del worker en logcat)"
                android.util.Log.e(TAG, lastError!!)
                return false
            }
            if (xSock.exists()) {
                delay(2000)
                if (!isAlive()) {
                    lastError = "Xvnc (PID $xvncPid) murió tras crear el socket X11 " +
                        "(fallo post-bind de libs/xkb)"
                    android.util.Log.e(TAG, lastError!!)
                    return false
                }
                android.util.Log.i(TAG, "Xvnc listo: PID vivo + socket X11 + 2s estable")
                return true
            }
            delay(200)
        }
        lastError = "Xvnc no creó el socket X11 en $maxTimeoutMs ms"
        android.util.Log.e(TAG, lastError!!)
        return false
    }

    override suspend fun stop() {
        if (xvncPid > 0) {
            val delegated = killPid(xvncPid)
            if (delegated) {
                android.util.Log.i("InternalXvncBackend", "Xvnc PID $xvncPid terminated (delegado al worker)")
            } else {
                // Fallback: kill local. No puede matar hijos del worker en
                // Android 12+, pero cubre un spawn local o worker caído.
                try {
                    android.os.Process.killProcess(xvncPid.toInt())
                    android.util.Log.i("InternalXvncBackend", "Xvnc PID $xvncPid terminated (fallback local)")
                } catch (e: Exception) {
                    android.util.Log.w("InternalXvncBackend", "kill Xvnc PID $xvncPid: ${e.message}")
                }
            }
            // K-1: SIGKILL es asíncrono. Esperar (bounded) a que /proc/<pid>
            // desaparezca para que el puerto 5901 quede libre antes del próximo
            // start(); sin esto el nuevo Xvnc muere EADDRINUSE.
            val deadline = System.currentTimeMillis() + 2000
            while (System.currentTimeMillis() < deadline && isAlive()) {
                delay(50)
            }
            xvncPid = -1
        }
    }

    /**
     * Escribe usr/.vnc/passwd en el formato vncpasswd de TigerVNC: el password
     * truncado/padded a 8 bytes, XOR-eado con [VNC_PASS_MASK]. Permisos
     * owner-only (0600) — Xvnc rechaza archivos con permisos abiertos en
     * algunos builds. Retorna el archivo, o null si falló la escritura.
     */
    private fun writeVncPassFile(): java.io.File? {
        return try {
            val dir = java.io.File(usrDir, ".vnc").apply { mkdirs() }
            val file = java.io.File(dir, "passwd")
            val raw = ByteArray(VNC_PASS_MASK.size)
            val pw = vncPassword.take(VNC_PASS_MASK.size).toByteArray(Charsets.UTF_8)
            pw.copyInto(raw, 0, 0, minOf(pw.size, VNC_PASS_MASK.size))
            val obfuscated = ByteArray(VNC_PASS_MASK.size) { i ->
                (raw[i].toInt() xor VNC_PASS_MASK[i].toInt()).toByte()
            }
            file.writeBytes(obfuscated)
            file.setReadable(false, false)
            file.setReadable(true, true)
            file.setWritable(false, false)
            file.setExecutable(false, false)
            android.util.Log.i(TAG, "vncpasswd escrito: ${file.absolutePath} (${obfuscated.size} bytes)")
            file
        } catch (e: Exception) {
            android.util.Log.w(TAG, "writeVncPassFile: ${e.message}")
            null
        }
    }


    override fun getEndpoint(): XDisplayEndpoint = endpoint

    override fun isAlive(): Boolean {
        val pid = xvncPid
        if (pid <= 0) return false
        // Delegado al worker (padre de Xvnc). El proceso principal no puede
        // leer /proc/<pid> de los hijos del worker — Android restringe /proc
        // a los hijos directos del proceso lector. Sin delegar, esto devolvía
        // false siempre y el backend mataba a un Xvnc vivo (SIGKILL propio).
        return isPidAlive(pid)
    }
}
