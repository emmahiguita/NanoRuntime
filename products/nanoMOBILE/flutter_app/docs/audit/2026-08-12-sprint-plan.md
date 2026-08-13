# Plan de sprints de corrección — auditoría integral 2026-08-12

Fuentes: 4 auditorías paralelas (Flutter/Dart, Kotlin/Android, end-to-end, C/C++/CMake/Gradle) + evidencia en device (logcat, cmdline, timestamps, errno).

## Clasificación consolidada

### CONFIRMED (lectura directa del código, sin ambigüedad)

**Bloqueantes de proyección (causa raíz ya identificada):**

| ID | Severidad | Hallazgo | Estado |
|----|-----------|----------|--------|
| NAT-1 | CRITICAL | `nanoroot.c` bind()/connect() pasaban addrlen del path original (52) con path redirigido (62) → kernel trunca sun_path → EADDRINUSE errno=98. Evidencia device: `nanoroot: bind ... -> .../usr/tmp/.X11-unix/X1 (rc=-1 errno=98)` | FIX en disco, SIN build |
| NAT-2 | CRITICAL | `nanoshell.c` loop argv saltaba argv[0]=":1" (JNI pasa argv sin binary_path) → Xvnc caía a display :0 | FIX verificado en device (cmdline `[:1]`) |
| VNC-1 | CRITICAL | `vnc_client.dart _handleMessages`: handler de mensaje largo (FramebufferUpdate raw, ServerCutText) hace return con rect parcial sin resetear `_msgBytesNeeded` → while síncrono re-invoca handler → giro infinito → freeze isolate UI. Frame inicial 3.7 MB en chunks lo dispara siempre | **FIX aplicado hoy** (break tras handler parcial) |
| VNC-2 | HIGH | `vnc_screen.dart` rama "Handshake incompleto" (líneas 204-213): Timer 2s → `_connect()` sin incrementar `_reconnectAttempts` → retry infinito sin tope de 7 | Pendiente |
| VNC-3 | HIGH | GestureDetector con onTapDown/onTapUp/onPanUpdate SIN onPanEnd/onPanCancel → tras drag, el tap nunca se dispara → botón del ratón clavado | Pendiente |
| VNC-4 | HIGH | `_frame` ui.Image (3.7 MB nativa) sin dispose ni al reemplazar ni en dispose() del State → fuga por frame | Pendiente |
| VNC-5 | LOW | Completer de `_emitFrame` sin guard isCompleted. RECLASIFICADO: `Future.timeout()` NO completa el completer subyacente → no hay StateError. Fuga real: imagen huérfana tras timeout de decode sin dispose | Pendiente (leak menor) |
| VNC-6 | HIGH | Raza stale-client: onDone de socket viejo llega tras crear cliente nuevo → `_scheduleReconnect` → `_connect()` desconecta el cliente NUEVO | Pendiente |
| VNC-7 | MEDIUM | `_ensureDesktopStarted` llama `installGraphical()` incondicional en cada reconexión | Pendiente |
| E2E-1 | CRITICAL | Inconsistencia DISPLAY TCP vs UNIX: `XServerBackend.kt:50` endpoint host="127.0.0.1" → `DesktopSessionManager.kt:150-152` genera `DISPLAY=127.0.0.1:1` (TCP 6001), pero el comentario de las líneas 138-142 y todo el plumbing (ensureTmpLink, intercept connect() AF_UNIX en nanoroot, .X11-unix) asumen UNIX ":1" | HYPOTHESIS runtime (¿Xvnc Termux escucha 6001?) — se decide con openbox_err.txt |
| E2E-2 | CRITICAL | `package_service.dart:87-90` traga TODA excepción de startDesktop y devuelve false; `desktop_launch_screen.dart:252` ignora el bool → `desktop_failed`/`desktop_timeout` inalcanzables; UI navega al visor con éxito falso | Pendiente |
| K-1 | CRITICAL | Ciclo de reintento ~30s: `DesktopController.start()` crea DesktopSessionManager NUEVO por llamada (generation++, previous.stop()) × puerto 5901 aún ocupado por Xvnc previo (SIGKILL asíncrono) → nuevo Xvnc muere EADDRINUSE → error → loop Dart reintenta → cascada de spawns que se pisan | Pendiente |
| K-2 | CRITICAL | `NanoshellWorkerService` ejecuta `preloadRootfsLibs()` (System.load ~60 libs, 4 passes) + `handleSpawnDetached` en el MAIN looper del worker, sin Thread → réplica del PID puede exceder el latch de 20s (`WorkerClient.kt:211`) → falso negativo → Xvnc huérfano reteniendo 5901 | Pendiente |
| K-3 | HIGH | Daemons detached hacen setsid() → grupo propio → `workerKillGroup()` no los mata; `killPid` solo mata PIDs registrados por el manager. Force-stop o spawn con PID -1 → orfan sirve 5901 para siempre y secuestra sesiones futuras | Pendiente |
| K-4 | HIGH | `PtyChannelHandler` hace fork+dlopen en el proceso PRINCIPAL con GPU — exactamente el escenario que el worker existe para evitar (SIGSEGV Mali documentado) | Pendiente (verificar dlopen en nanoshell.c antes) |
| K-5 | HIGH | `probeExec` sin timeout, sin entorno sandbox (sin LD_PRELOAD), `readBytes()` sin límite → coroutine fugada, OOM con salida infinita | Pendiente |
| K-6 | MEDIUM | Raza start/stop: `running=true` escrito tras último `abortIfStopped` fuera del lock → desktop "ready" con PIDs muertos | Pendiente |
| K-7 | MEDIUM | `onDestroy` de MainActivity manda MSG_KILL en plena instalación → dpkg status a medias | Pendiente |
| K-8 | MEDIUM | `handleGetDesktopStatus`: `ioScopeProvider() ?: return` sin resolver result → Dart espera para siempre | Pendiente |
| C-1 | HIGH | `nanoshell.c` entre fork() y execve() el hijo ejecuta código NO async-signal-safe (strdup/setenv/malloc/dlopen/fprintf/mkdir) en proceso multithreaded → deadlock por locks heredados | Pendiente |
| C-2 | HIGH | FOREGROUND_SERVICE/SPECIAL_USE/WAKE_LOCK declarados pero nadie llama startForeground y el service no tiene foregroundServiceType → SecurityException futura en API 34+ y worker matable bajo presión | Pendiente |
| C-3 | HIGH | Signing release cae silenciosamente al keystore de debug cuando NANOAI_KEYSTORE no definida → APK release con cert debug | Pendiente |
| C-4 | MEDIUM | Intercept list incompleta en nanoroot.c: chmod/fchmodat/chown/symlink/link/rmdir/unlinkat/renameat/utimensat/truncate/statfs/statx sin interceptar → operaciones por path sin redirigir | Pendiente |
| C-5 | MEDIUM | realpath() devuelve path físico con prefijo; readlink() sin reescribir → paths inconsistentes | Pendiente |
| C-6 | MEDIUM | `_spawn_internal`: out_cap *= 2 sin tope; breaks por error cierran pipes sin matar hijo (waitpid colgado si hijo ignora SIGPIPE); kill sin grupo | Pendiente |
| C-7 | MEDIUM | argv[0] difiere entre ruta linker64 y dlopen fallback | Pendiente |
| C-8 | MEDIUM | Doble convención argv: pty.c asume argv[0]=binary_path, detached asume argv[0]=primer arg — fuente exacta del bug :1 ya corregido | Pendiente |
| C-9 | MEDIUM | pty.c ruta primaria (linker64) NO inyecta LD_PRELOAD de nanoroot (solo el fallback dlopen) | Pendiente |
| C-10 | MEDIUM | `pty_close`/`pty_registry_close` cierran master sin matar/reapear hijo → terminales huérfanos y zombies | Pendiente |
| SEC-1 | MEDIUM | TarExtractor: target de symlink sin validar; escritura a través de symlinks intermedios | Pendiente |
| SEC-2 | MEDIUM | Zip bootstrap sin verificación de integridad (solo tamaño) | Pendiente |
| SEC-3 | MEDIUM | postinst spawnado desde cacheDir saltándose `pathPolicy.requireInsideNanoFiles` | Pendiente |
| ARCH-1 | MEDIUM | God classes: DebInstaller (780 líneas, 8 responsabilidades), ExecBinChannelHandler (426 líneas, 7 features) | Pendiente |
| ARCH-2 | MEDIUM | Serialización env Map→"k=v" duplicada en 4 sitios | Pendiente |
| ARCH-3 | MEDIUM | 3 puntos "está vivo el puerto" con semánticas distintas (watchdog, getStatus, awaitReady) | Pendiente |
| DEAD-1 | LOW | `NavigationChannelHandler.kt` entero muerto; `handleKill()` sin args; `CHANNEL_WORKER`; `isLoaded`; overload TarExtractor; `XTransport.UNIX`; `dispose()` sin llamadores | Pendiente |
| DEAD-2 | LOW | Strings huérfanos "Revisa logcat: vnc-service" en vnc_screen.dart:261 y desktop_launch_screen.dart:275 (VncService borrado) | Pendiente |

### HYPOTHESIS_TO_VALIDATE

- E2E-1 runtime: ¿el Xvnc de Termux escucha TCP 6001? Decisivo: contenido de `openbox_err.txt` post-build. Si dice "unable to open display" → fix DISPLAY=":1" (host vacío).
- K-2 en hardware real: ¿preload supera 20s en el device? Decisivo: logcat `nanoshell-worker` con timestamps del primer spawn frío.

### DISCARDED

- VNC-5 crash por StateError: `Future.timeout` no completa el completer subyacente. Reclasificado a leak menor.
- Puertos fantasma 41740/46982 en logs del visor: puerto LOCAL efímero de dart:io en OSError, no bug.

### INFORMATIONAL

- `proc_fs.dart` solo lo usa la terminal, no el desktop.
- VncService/VncController: sin referencias colgantes en código, solo texto en docs.

### Ya arreglados en disco (sin build en device)

- NAT-1 addrlen bind/connect (nanoroot.c) — APK device 12:43:13 es ANTERIOR al fix 12:42:54 (imposible build en 19s).
- NAT-2 argv[0] nanoshell.c — verificado en device vía cmdline.
- DebInstaller nullable (checkNotNull línea 688).
- VNC-1 parser loop — aplicado hoy.

---

## Sprints

### SPRINT 0 — BASELINE [HECHO]
Este documento + 4 informes de auditoría + evidencia device.

### SPRINT 1 — BUILD + VERIFICACIÓN DE PROYECCIÓN [BLOQUEADO POR OK DEL USUARIO]
Objetivo: build APK con NAT-1/NAT-2/VNC-1 y verificar proyección real.
- Build: `flutter build apk --debug` (verificar exit code ANTES de instalar, no encadenar con pipes).
- Instalar en device.
- Verificación en 10 pasos (del informe end-to-end):
  1. logcat `nanoshell-detached`: execve(linker64) argc=5 + nanoroot loaded
  2. logcat `nanoshell-worker`: detached pid=N → Xvnc
  3. logcat `InternalXvncBackend` + `desktop-session` + `ExecBinChannel`: "VNC listo y estable" → openbox/tint2/terminal PIDs → "Escritorio listo"
  4. `cat files/nano/usr/tmp/Xvnc_err.txt`: **`bind ... rc=0 errno=0`** (prueba del fix NAT-1)
  5. `ls files/nano/usr/tmp/.X11-unix` → existe X1
  6. `cat openbox_err.txt` → si "unable to open display 127.0.0.1:1" → aplicar fix E2E-1 (host vacío)
  7. `cat tint2_err.txt` / `aterm_err.txt` → mismos criterios
  8. logcat flutter: `[vnc] Server: RFB 003.008`, `Framebuffer: 1280x720`
  9. Visor 12-15s → heartbeat silencioso (sin freeze del parser = VNC-1 verificado)
  10. Matar Xvnc a los ~6s → reconexión automática
- Exit criteria: frame visible en visor + escritorio con openbox/tint2/terminal.

### SPRINT 2 — CRASHES Y PARSER DEL VISOR
- VNC-1: YA FIXEADO (regresión en sprint 1 paso 9).
- VNC-2: incrementar `_reconnectAttempts` en la rama handshake incompleto.
- VNC-6: guard de generación del socket en `_onClientDisconnected` (ignorar onDone de clientes no-actuales).
- VNC-5: dispose de la imagen huérfana tras timeout.
- VNC-7: gate `statusBefore.installed` como en launch screen.
- Exit: visor reconecta sin freeze ni retry infinito.

### SPRINT 3 — ORQUESTACIÓN Y LIFECYCLE (Kotlin)
- K-1: sesión única (reusar DesktopSessionManager si running/starting) + detección de port-owner 5901 antes de spawn (escanear /proc/*/cmdline por Xvnc de nuestro UID, matarlo).
- K-2: preloadRootfsLibs a onCreate en Thread; handleSpawnDetached en Thread; latch >30s.
- K-3: pidfiles por daemon (worker escribe al hacer setsid); verificación de identidad por /proc/<pid>/cmdline antes de matar.
- E2E-2: startDesktop devuelve resultado real; la UI lee el bool y muestra error.
- E2E-3: ventana probe-5s → segundo probe espaciado ≥8s.
- E2E-4: callback pendiente para el caller cuando running||starting.
- K-6: `running=true` bajo el mismo lock; `stop()` marca terminal.
- K-7: shutdown no MSG_KILL con instalación activa.
- K-8: resolver result con DesktopStatus.offline en el else.
- Exit: arranque/parada idempotente, sin huérfanos, error visible en UI.

### SPRINT 4 — CONCURRENCIA Y PROCESOS (C)
- C-1: hijo post-fork solo async-signal-safe (preparar environ antes del fork; mínimo mover setenv/strdup/malloc fuera del hijo).
- C-10: pty_registry_close kill(-pid, SIGHUP) + waitpid WNOHANG.
- C-7/C-8: unificar contrato argv (argv[0]=binary siempre, derivado de binaryPath) + comentario en ambos loops.
- C-9: inyectar LD_PRELOAD antes del primer execve en pty.
- C-6: tope de captura 64 MB, kill(-pid) en todos los breaks, waitpid WNOHANG.
- Exit: zero zombies tras 10 ciclos start/stop; terminales cerradas sin hijos.

### SPRINT 5 — COMPATIBILIDAD Y MANIFEST
- E2E-1: decidido por evidencia del sprint 1 (cambiar host a "" si openbox muere).
- C-2: eliminar permisos FGS muertos O declarar foregroundServiceType="specialUse" + propiedad y startForeground con tarea activa.
- C-3: fallar build release en CI sin keystore (GradleException).
- targetSdk 36; xz 1.10+; kotlinOptions → compilerOptions; extractNativeLibs="false" (verificar dlopen) + allowBackup="false".
- C-4: interceptar chmod/chown/utimensat/rmdir/symlink/unlinkat/renameat con patrón existente.
- C-5: realpath/readlink con prefijo reescrito.
- Exit: build release correcto; binarios apt/dpkg con paths redirigidos completos.

### SPRINT 6 — SEGURIDAD
- SEC-1: resolver path canónico del padre antes de escribir; validar target de symlink.
- SEC-2: hash del zip bootstrap.
- SEC-3: postinst dentro de files/nano + pathPolicy.
- K-5: probeExec timeout + límites + env del worker.
- Exit: sin escrituras fuera del sandbox; binarios colgados mueren.

### SPRINT 7 — UI Y DISEÑO (Flutter)
- VNC-3: añadir onPanEnd/onPanCancel (liberar botón).
- VNC-4: dispose del frame viejo al reemplazar y en dispose().
- Diseño: migrar colores hardcodeados de vnc_screen.dart (0xFF0A0D14, 0xFF10B981) a design_tokens (ya hecho en desktop_launch_screen).
- Verificar pantallas duplicadas en lib/features/ (dashboard, chat, settings, terminal) — borrar muertas.
- Exit: drag suelta el botón; memoria estable en sesión larga; UI con tokens.

### SPRINT 8 — ARQUITECTURA / SOLID / CLEANUP
- ARCH-1: extraer DebExtractor, DpkgStatus, PostinstRunner; DesktopLifecycleHandler separado.
- ARCH-2: helper único de serialización env + convención única filesDir.
- ARCH-3: único punto de health check del puerto.
- DEAD-1/DEAD-2: borrar código muerto y strings huérfanos.
- Borrar backups .bak/.bak2 del repo (nanoshell.c.bak, nanoshell.c.bak2).
- Exit: -400 líneas muertas; responsabilidades con dueño único.

### SPRINT 9 — REGRESIÓN FINAL
- Ciclo completo en device: arranque frío → proyección → interacción → cierre → re-arranque ×3.
- Force-stop con desktop activo → sin huérfanos (verificar /proc).
- Verificar apt/dpkg sigue funcional (el rootfs no se toca en sprints 2-8).
- Exit: checklist de 10 pasos del sprint 1 en verde + cero regresiones en terminal/paquetes.

## Closure gates activos

| Bug | Root cause | Patch | Static | Build | Runtime | Lifecycle |
|-----|-----------|-------|--------|-------|---------|-----------|
| NAT-1 | ✓ | ✓ | ✓ | PENDIENTE | PENDIENTE | PENDIENTE |
| NAT-2 | ✓ | ✓ | ✓ | ✓ device | ✓ device | ✓ |
| VNC-1 | ✓ | ✓ HOY | PENDIENTE | PENDIENTE | PENDIENTE | — |
| VNC-8 | ✓ | ✓ HOY | ✓ | ✓ | ✓ device | — |
| XKB-1 | ✓ | ✓ HOY | ✓ | ✓ | PENDIENTE | — |

## VNC-8 — handshake RFB 3.3 legacy no soportado por el visor (CONFIRMADO 2026-08-12)

- **Síntoma:** visor en bucle cada ~6s: `[vnc] Server: RFB 003.003` + `[vnc] Tipos seguridad no soportados: []`. En paralelo `xvnc_err.txt`: `Connections: Blacklisted: 127.0.0.1`.
- **Evidencia de bytes reales (captura directa del socket 5901):**
  `RFB 003.003\n` + U32 `00000000` + U32 len `0000001a` + `"Too many security failures"`
- **Causa raíz (cadena):**
  1. Xvnc (TigerVNC 1.16.2 Termux build) con `-SecurityTypes None` ofrece **RFB 3.3**, no 3.8. En 3.3 el server manda el security type como **U32 directo** (None=1), no la lista count+types de 3.7+, y tras None **no hay SecurityResult** — ServerInit llega directo.
  2. El visor asumía 3.7+: leía el primer byte del U32 `00 00 00 01` como count=0 → lista vacía → `Tipos seguridad no soportados: []` → disconnect sin completar el handshake.
  3. Cada retry (~6s) cortaba a mitad de la fase de security → el contador anti-brute-force de TigerVNC se satura → el server pasó a rechazar TODAS las conexiones con `Too many security failures` (por eso el U32=0 en la captura).
  4. Nota: el check de `awaitReady` (Kotlin) solo valida el prefijo `RFB 003.00` → nunca detectó el 3.3.
- **Fix aplicado (4 ediciones en `vnc_client.dart`):** `_legacy33` detectado en `_handleVersion`; `_handleSecurity` con rama 3.3 (U32, None=1, salto directo a ServerInit); ClientInit tras ServerInit en modo 3.3; reset de `_legacy33` en `disconnect()`.
- **Runtime VERIFICADO (device, 2026-08-12 ~14:05):** app fresca + Xvnc nuevo → el server ofreció `RFB 003.008` y el visor completó el handshake 3.8 estándar: `[vnc] Framebuffer: 1280x720, depth=24, "u0_a344@localhost"`. Screenshot del device muestra el frame real del escritorio X proyectado (root window + cursor). El camino 3.3 queda como defensa para servers legacy; no se ejercitó en runtime.
- **Nota de instalación:** tras `adb install -r`, ColorOS mantuvo viva la instancia vieja de la app (retries con código viejo en logcat hasta ~14:02); la instancia nueva arrancó sola después. Verificar siempre con logs post-arranque, no con el primer launch.

## VNC-9 — decodeImageFromPixels hung a los ~59s del connect (CONFIRMADO, sprint 2)

- **Evidencia:** `[vnc] Error decodificando frame: TimeoutException: decodeImageFromPixels hung` a las 14:06:57 (connect 14:05:58) y 14:18:14 (connect 14:17:15) — SIEMPRE ~59s tras el Framebuffer. Reproducible 2/2.
- **Impacto:** el pipeline de decode pierde un frame, pero la conexión sobrevive (sin reconexiones posteriores) y el frame anterior sigue visible. No bloquea la proyección; degrada latencia de actualización.
- **Causa probable:** el decode del primer FBU no incremental (3.7 MB raw) en el isolate de UI + timeout de 60s del decode. Investigar en sprint 2 junto a VNC-4 (fuga de `_frame` sin dispose).

## CH-1 — channel startDesktop: cast bool→Map (CONFIRMADO, fix HOY)

- **Evidencia:** `[desktop] startDesktop error: type 'bool' is not a subtype of type 'Map<dynamic, dynamic>?' in type cast` en cada arranque del desktop (14:17:15).
- **Causa:** `ExecBinChannelHandler.handleStartDesktop` responde `result.success(true)` (Boolean) y `package_service.dart` invocaba `invokeMethod<Map<dynamic, dynamic>>`. Mismatch de firma del refactor.
- **Fix:** `invokeMethod<bool>` + `ok == true` en package_service.dart. No bloqueaba el arranque (el error se loggeaba y el flujo continuaba) pero ensuciaba el log y podía confundir el `_ensureDesktopStarted`.

## XKB-1 — off-by-one en fix xkbcomp (bloqueante del keymap, CONFIRMADO 2026-08-12)

- **Síntoma:** `XKB: Failed to compile keymap` → `Failed to activate virtual core keyboard: 2` → Xvnc exit 1 tras abrir 5901.
- **Cadena causal (evidencia device):** Popen de os/utils.c usa `execl("/bin/sh", "sh", "-c", cmd)` → en bionic execl liga execve por símbolo interno NO interposable → los intercepts execve/execvp/execvpe de nanoroot jamás corrían para el Popen (Xvnc binario: execl=1, execve=0, posix_spawn=0). Evidencia: xkbcomp.log viejo, server-1.xkm inexistente, sin fprintf.
- **Fix-1 (aplicado):** intercept `execl` nuevo en nanoroot que reconstruye argv de varargs y delega al core compartido `nano_execve_core`. VERIFICADO en device: el sh corrió con el comando reescrito (`cmdline=[linker64 usr/bin/sh -c "/data/user/0/.../xkbcomp" ...]`).
- **Fix-2 (aplicado):** el fix xkbcomp del core comparaba sufijo de 11 chars contra "/bin/xkbcomp" (12) — off-by-one, jamás aplicó; la cascada lanzaba linker64 contra el SCRIPT wrapper: `error: "...xkbcomp" has bad ELF magic: 23212f73` (0x23212f73 = "#!/s"). Corregido a 12 en execve core/execvp/execvpe.
- **Runtime:** pendiente de verificación en device (spawn tras reinstalación completa del stack gráfico).
