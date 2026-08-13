# Auditoría integral — NanoAI Mobile (flutter_app)

Fecha: 2026-08-12. Base: HEAD 0a47186 + working tree sin commitear.
Método: 6 auditores paralelos read-only (Kotlin, C++/JNI/CMake, Flutter/Dart, Gradle/SDK, puente Linux↔Android, logs/rootfs). Evidencia: logs históricos del dispositivo ColorOS (logcat.txt, logcat2.txt, logcat3.txt, vnc_logcat*.txt, xvnc*.txt, recuperados de git history, UTF-16LE).

---

## Resumen ejecutivo

```text
Estado general:   Escritorio NO funcional. Xvnc abre 5901 y muere a los pocos segundos.
Build:            Compila (stack coherente). jniLibs irreproducible (46 MB .so no trackeados).
Android runtime:  Worker :nanoshell no se reconecta tras muerte. FGS permissions muertos.
Flutter:          3 call-sites de installGraphical. vnc_client con bug de desincronización RFB.
C/C++:            fork+dlopen en proceso con GPU. spawn detached sin setsid. nanoroot sin protección `..`.
JNI:              Excepciones sin check. kill(-pgid) por PID stale. Registro PTY sin limpiar pid.
Linux:            Binarios de filesDir NO ejecutables en ColorOS (rc=126). Solo vía worker/linker64.
Rootfs:           xz roto → 29 paquetes extraídos por XzDecoder. xkbcomp no compila keymap.
Procesos:         Xvnc daemoniza → PID trackeado muerto → stop() no mata → huérfano retiene 5901.
Memoria:          ui.Image sin dispose en vnc_screen. Buffer RFB con copia O(N²). Sin OOM en logs.
Rendimiento:      Preload de 117 libs en main looper del worker bloquea Messenger. FFI síncrono en UI isolate.
Conectividad:     VNC localhost OK en diseño. Worker sin rebind. Sin ack en workerSpawn.
Seguridad:        Traversal `..` en nanoroot y TarExtractor. allowlist por basename + /data/user/ sin canonicalizar.
Mantenibilidad:   ~9 archivos de código muerto. Tags de log inconsistentes. 3 dueños de installGraphical.
```

---

## Tabla maestra

| ID | Prioridad | Archivo | Componente | Error | Evidencia | Causa raíz | Impacto | Solución |
| -- | --------- | ------- | ---------- | ----- | --------- | ---------- | ------- | -------- |
| P0-1 | P0 | boot_orchestrator.dart:218-258 + logs | Xvnc/XKB | xkbcomp no compila keymap → Xvnc muere | `XKB: Failed to compile keymap` → `Fatal server error` → `Failed to activate virtual core keyboard: 2` (12× en 5 logs). 5901 SÍ abre | libs xkb* cargadas desde dir writable (`Attempt to load writable file ... libxkbfile.so`, 11×) + reglas XKB del .deb rotas | Escritorio muerto: banner RFB OK, luego fatal | xkbcomp estático (compilar en NDK) o copiar libs xkb a dir no-writable; validar `rules/evdev` antes de ready |
| P0-2 | P0 | XServerBackend.kt:93-110 | Xvnc lifecycle | PID trackeado = padre muerto; Xvnc real daemoniza | TigerVNC sin `-nodaemon` → fork, padre sale; reaper lo recolecta | stop() mata PID muerto; huérfano retiene 5901; siguiente start falla "Address already in use" (hipótesis: no aparece en logs aún — validar) | Parada imposible, sesiones stale | `-nodaemon` en argv de Xvnc |
| P0-3 | P0 | WorkerClient.kt:52-61 + NativeRuntimeSupervisor.kt:44-54 | Worker IPC | Worker muerto nunca se reconecta | Logs: worker 4804 arranca 15:30, re-spawn 5892 a 15:34 sin crash — primer proceso murió | `onServiceDisconnected` solo loguea; `bind()` solo en init{}; supervisor ve `workerClient != null` y no recrea | Tras LMK/ColorOS kill: todo spawn falla para siempre hasta reiniciar app | Rebinding con backoff en onServiceDisconnected, o null-out para que ensureRunning() recree |
| P1-1 | P1 | worker_jni.c:120-130 + NanoshellWorkerService.kt:134-139 + shell_executor.dart:597 | Procesos | kill(-pgid) del worker mata TODAS las tareas + el worker | `workerKillGroup` documenta self-kill | Se mata por grupo, no por tarea | Un timeout de una pestaña mata git clone de otra y al worker | Guardar pid por taskId; matar solo ese PID |
| P1-2 | P1 | NanoshellWorkerService.kt:95-119 + WorkerClient.kt:186 | Worker | preload 117 libs en main looper; reply 20s expira | spawnDetached devuelve -1 con worker frío | IO de disco + fork en looper del Messenger | Daemons lanzados sin PID trackeado → huérfanos | Preload en thread + cache estático de libs |
| P1-3 | P1 | vnc_client.dart:311-340 | Visor RFB | SetColourMapEntries no consume entries → stream desincronizado | `_msgBytesNeeded=5` cubre solo header; faltan 6×num-colours bytes | Parse incompleto | Disconnect tras rect corrupto | Saltar `6*num-colours` |
| P1-4 | P1 | vnc_client.dart:171-187 | Visor RFB | Copia O(N²) del buffer por paquete | newBuf + 2 setRange en cada `_onData` | Buffer completo copiado por paquete | Jank con rects partidos | Buffer growable + append por slices |
| P1-5 | P1 | vnc_client.dart:392-418 + 471-505 | Visor RFB | `_pixels` mutada mientras decodeImageFromPixels la lee | Raw rects in-place + decode async | Sin doble buffer | Frames rasgados | Doble buffer o copia antes de decode |
| P1-6 | P1 | DebInstaller.kt:390-430 | Instalador | Via 1 (xz externo) muerta: rc=126, 3 spawns, ~6 min peor caso | 30× `xz rc=126 Permission denied` en logcat3 | execve de filesDir bloqueado en ColorOS | Instalación lentísima, fallback sí funciona | XzDecoder como primario; borrar Via 1 |
| P1-7 | P1 | DebInstaller.kt:594 | Instalador | runPostinst ejecuta script desde files/nano → rc=126 | Mismo bloqueo que xz | execve directo bloqueado | postinst nunca corre (ca-certificates, fontconfig a medias) | Ejecutar con sh del rootfs dentro del worker |
| P1-8 | P1 | nanoshell.c:763-995 | Daemons | spawn detached SIN setsid → muere con workerKillGroup | Comentario worker_jni.c:118 afirma lo contrario | Contradicción código/contrato | Xvnc/openbox mueren al matar worker | setsid() en el hijo + cerrar fds |
| P1-9 | P1 | pty.c:155-174 + NanoshellWorkerService.kt:15-24 | PTY | fork+dlopen en proceso con GPU (fallback) | Crash Mali histórico documentado motivó :nanoshell | Fallback dlopen hereda threads GPU | SIGSEGV posible en ColorOS | Mover ptySpawn al worker o abortar fallback en proc principal |
| P1-10 | P1 | boot_orchestrator.dart:81 + desktop_launch_screen.dart:186 + vnc_screen.dart:223-280 | Flutter | installGraphical ×3 call-sites, cada arranque | Tres rutas lo invocan | Sin coordinador único | Reinstalación pesada repetida | Coordinador único; solo si no ready |
| P1-11 | P1 | package_service.dart:17-30 + desktop_launch_screen.dart:105,219 | Flutter | Port 6000 legacy corrompe estado | `DesktopStatus.offline.port=6000`; UI navega a 6000 si port>0 | Default XSDL vivo | Visor apunta a puerto muerto | offline port 0/5901; aceptar port solo si reachable |
| P1-12 | P1 | nanoroot.c:177-181 | nanoroot | Traversal `..` escapa del prefix | rename/open con `/etc/../../x` resuelve fuera | Sin canonicalización ni rechazo | Escritura fuera del fake-chroot | Rechazar segmentos `..`/`.` o realpath+verificar |
| P1-13 | P1 | pty.c:253-268 + pty_session_registry.c:54-61 | PTY | kill(-pid) con PID reutilizado | Slot conserva child_pid tras reaping | PID stale | SIGKILL a proceso ajeno | Limpiar pid en is_alive; verificar /proc antes de kill |
| P1-14 | P1 | nanoshell_ffi.dart:115-122 + allowed_binaries.dart:33-37 | Seguridad | Allowlist por basename + prefijo /data/user/ sin canonicalizar | `/data/user/0/../media/0/Download/bash` pasa | Sin resolveSymbolicLinksSync | Ejecución de ELF arbitrario en Downloads | canonicalizar + exigir files/nano + versionado numérico estricto |
| P2-1 | P2 | DesktopSessionManager.kt:311-336 | Watchdog | Al caer Xvnc no mata openbox/tint2 | running=false sin cleanupProcesses() | Rama incompleta | Duplicados en siguiente start | cleanupProcesses() en rama de fallo |
| P2-2 | P2 | DesktopSessionManager.kt:94-106 | Shutdown | stop() no hace join del thread desktop-start | runBlocking sin join | Carrera shutdown↔start | Daemon huérfano post-shutdown | join con timeout |
| P2-3 | P2 | DesktopController.kt:103-122 | Estado | getStatus reporta ready sin probar 5901 | reachable=running | Sin probe real | UI muestra listo con Xvnc muerto | Probe TCP en callback |
| P2-4 | P2 | nanoshell.c:572-580 + shell_executor.dart:597 | Timeout | C mata a los 30s, Dart espera 120s | poll 30000 vs 120s | Incoherencia de contrato | Fallos fantasma (rc=137) en apt/git | Timeout único configurable |
| P2-5 | P2 | shell_executor.dart:581-611 | IPC | workerSpawn sin ack; rc file nunca aparece si worker murió | Fire-and-forget | Sin reply | 120s polling + workerKill destructivo | Ack con taskId (patrón ya existe en spawnDetached) |
| P2-6 | P2 | terminal_core.dart:156,684 | Terminal | Handler de teclado global por tab sin check de visibilidad | N handlers activos en IndexedStack | `_onKey` sin `widget.visible` | Teclas van a PTYs ocultos | `if (!widget.visible) return false` |
| P2-7 | P2 | vnc_screen.dart:141-150 | Flutter | ui.Image sin dispose | `_frame = img` reemplaza sin dispose | Fuga GPU por frame | Presión GC | Dispose previa + en dispose() |
| P2-8 | P2 | vnc_screen.dart:319-324 | Flutter | Ratón queda presionado tras drag | Sin onPanEnd/onPanCancel | Falta release | Clicks fantasma en Openbox | onPanEnd/Cancel → buttonMask 0 |
| P2-9 | P2 | vnc_client.dart:294 | RFB | Primer FramebufferUpdateRequest incremental=true | Spec exige primera no-incremental | Flag erróneo | Pantalla negra hasta input (hipótesis) | Primera petición incremental=false |
| P2-10 | P2 | pty_registry_close | PTY | close() no mata al hijo | Solo cierra master fd | ptyKill nunca llamado en close | sleep 1000 huérfano al cerrar pestaña | kill(-pid, SIGHUP) en close |
| P2-11 | P2 | ExecBinChannelHandler.kt:197-206 | Canales | result.success tras cancelación de ioScope | onDestroy cancela scope; mainHandler.post sobrevive | Sin guard de scope | Future Dart colgado | Guard `ioScope.isActive` |
| P2-12 | P2 | nanoshell_ffi.dart:93-147 | Flutter | FFI síncrono bloquea UI isolate hasta 30s | spawnBusyBox/spawnGeneric desde State | Sin isolate | UI congelada con find/tar | Compute isolate o derivar al worker |
| P3-1 | P3 | XServerBackend.kt:36-76 + ExecBinChannelHandler.kt:81-95 + package_service.dart:98-108 | XSDL | Ruta XSDL completa muerta | Sin callers Dart; handler sin `<queries>` → falso negativo | Migración incompleta | Confusión + código muerto | Borrar: ExternalXsdlBackend, handleLaunchXsdl, launchXsdl() |
| P3-2 | P3 | jniLibs/arm64-v8a/ | Build | 46 MB .so inconsistente: 10 trackeados, resto ignorado por `*.so` | git ls-files = 10; check-ignore confirma | .gitignore raíz | APK irreproducible | Trackear o mover a assets; excluir libnanortime_ffi.so si no se usa |
| P3-3 | P3 | build.gradle.kts:65-73 | Build | Release cae a debug keystore si NANOAI_KEYSTORE ausente | else → signingConfigs debug | Silencio | Distribución firmada con debug | GradleException en else |
| P3-4 | P3 | AndroidManifest.xml | Android | FOREGROUND_SERVICE/WAKE_LOCK declarados, nadie llama startForeground | grep 0 coincidencias | Comentario obsoleto (VncService borrado) | Crash en API 34+ si se activa sin tipo | Quitar permisos |
| P3-5 | P3 | Varios | Código muerto | command_executor.dart, cron_scheduler, ai_plugin, terminal_plugin, keyboard_mapper, expression_evaluator, command_tagger, terminal_workspace, device_info, NavigationChannelHandler, handleKill() | grep sin importadores | Refactor a medias | Confusión + mantenimiento | Borrar o cablear |
| P3-6 | P3 | Repo | Higiene | logcat*.txt commiteados en HEAD; .bak sin ignorar | git status D + untracked bak | Falta commit de borrado | Clones descargan basura | Commit eliminaciones + `*.bak` al .gitignore |
| P3-7 | P3 | Varios | Logging | Tags inconsistentes + mojibake en comentarios | snake_case vs CamelCase | Sin convención | logcat difícil de filtrar | Convención única `nano-*` |
| P3-8 | P3 | TarExtractor.kt:90 | Seguridad | startsWith sin separador → traversal hermano | `usr/../../files2` normaliza fuera | Guard débil | Escritura fuera de destRoot | startsWith(base+separator) |
| P3-9 | P3 | nanoshell.c:306-308, pty.c:119 | C | close(3..255) a ciegas | Heurística de fds | Sin O_CLOEXEC | Cierra fds necesarios | O_CLOEXEC al crear |
| P3-10 | P3 | kali_manager.dart:25 | Seguridad | SHA256 desactivado (expectedSha256='') | Check nunca corre | Placeholder | Tarball 200MB sin verificar | Fijar hash oficial |
| P3-11 | P3 | DockerManager.kt:247-249, 370-380 | Flutter | stop() no mata proot; IOSink leak en error | Solo cambia estado | Incompleto | Contenedor zombie + fd leak | Matar pid proot; try/finally close |
| P3-12 | P3 | CMakeLists.txt:30-34 | Build | Sin flags hardening | Solo -Wall -Wextra | Defaults | Menor robustez | -fstack-protector-strong, -Wformat-security |
| P3-13 | P3 | pty.c:187-190 | C | strdup sin NULL-check → argv con NULL → UB | nanoshell.c sí lo chequea | Inconsistencia | Crash bajo OOM | Mismo patrón |
| P3-14 | P3 | jni_cstr_array.c:15-21 | JNI | Excepciones JNI pendientes sin check | GetObjectArrayElement puede fallar | Sin ExceptionCheck | Estados corruptos | ExceptionCheck tras cada conversión |
| P3-15 | P3 | shell_executor.dart:55 | Flutter | RootfsManager nuevo en vez de singleton | `RootfsManager()` | Inconsistencia | Estado divergente | RootfsManager.instance |
| P3-16 | P3 | proc_fs.dart:43-55 | Flutter | procsRunning siempre blocked=0 | Comentario admite falta | Incompleto | Métrica falsa | Parsear segunda línea |

---

## Arquitectura encontrada (real, no esperada)

```text
Flutter (UI isolate)
 ├─ VncClient (RFB 3.8 puro Dart) ── TCP ──► Xvnc :1 (:nanoshell)
 ├─ PackageService ── MethodChannel com.nanoai/exec_bin ──► ExecBinChannelHandler
 ├─ PtyShell ── MethodChannel com.nanoai/pty ──► PtyChannelHandler ──► JNI ptySpawn (PROCESO PRINCIPAL)
 ├─ Nanoshell FFI (síncrono, UI isolate) ──► libnanoshell.so _spawn_internal
 └─ ShellExecutor ──► workerSpawn (sin ack) ──► WorkerClient (Messenger)

Kotlin (proceso principal)
 ├─ NativeRuntimeSupervisor (único dueño nominal de lifecycle)
 ├─ DesktopController → DesktopSessionManager (thread desktop-start)
 ├─ InternalXvncBackend (spawnDetached → WorkerClient)
 ├─ PackageInstallController → DebInstaller/TarExtractor/XzDecoder
 └─ WorkerClient (Messenger binder, sin rebind)

:nanoshell (proceso separado, sin GPU)
 └─ NanoshellWorkerService (Messenger handler en main looper)
     ├─ handleSpawn → Thread por tarea → nanoshell_worker_spawn (poll 30s)
     ├─ handleSpawnDetached → preloadRootfsLibs (117 libs, main looper) → fork+execve
     └─ workerKillGroup → kill(-pgid) — mata todo el proceso

C (libnanoshell.so + libnanoroot.so LD_PRELOAD)
 ├─ _spawn_internal: fork → execve → dlopen fallback → poll stdout/stderr → rc files
 ├─ spawn_detached: fork+execve SIN setsid, stderr → usr/tmp/<bin>_err.txt
 └─ nanoroot: interposición de execve/open/rename/bind/connect/popen — fake-chroot
     redirige /usr /etc /tmp /var /home /bin /lib /sbin + prefix Termux → files/nano
```

**Split-brain real:** lifecycle de Xvnc lo intentan controlar 4 capas (DesktopSessionManager watchdog, DesktopController generation, NativeRuntimeSupervisor.shutdown, WorkerClient kill). `installGraphical` tiene 3 dueños en Dart. `_isDesktopReady` (archivos) y `DesktopStatus.reachable` (puerto) son dos verdades distintas.

---

## Flujo real de ejecución

```text
App arranca
↓ BootOrchestrator.run (post-primer-frame)
│   checkInstalled → install rootfs si falta → _setupBashrc
│   → _ensureEssentialPackages (python/htop/git)
│   → _ensureDesktopEnvironment → installGraphical SIEMPRE si _isDesktopReady()==false
↓ Usuario: Escritorio → DesktopLaunchScreen
│   _prepareStartAndEnter: checkInstalled → install → installGraphical (¡otra vez!)
│   → startDesktop (MethodChannel) → _waitForDesktopReady (400×300ms ≈ 120s)
↓ Kotlin: DesktopController.start → DesktopSessionManager.start (thread)
│   cleanX11Runtime → ensureTmpLink → baseEnv
│   → InternalXvncBackend.start → spawnBg → WorkerClient.spawnDetached (latch 20s)
│   → awaitReady (probe TCP 5901, 15s — NO lee cabecera RFB)
│   → openbox (spawnBg) → sleep(800) → tint2 → xterm → running=true → watchdog 5s
↓ Flutter: desktopStatus.ready → pushReplacement /desktop/vnc?port=5901
↓ VncScreen: VncClient.connect → handshake RFB 3.8 → framebuffer → decodeImageFromPixels
│   fallback _ensureDesktopStarted (¡tercer installGraphical!)
└─ En dispositivo real (ColorOS): Xvnc abre 5901 → xkbcomp falla → XKB fatal
    → Xvnc muere → awaitReady timeout → PlatformException(vnc_failed)
```

---

## Problemas bloqueantes (P0)

1. **P0-1 XKB fatal.** Xvnc escucha en 5901, banner RFB válido, y MUERE a los ~2s: `Failed to activate virtual core keyboard: 2` porque xkbcomp no puede compilar el keymap (libs xkb* desde directorio writable + reglas XKB del .deb rotas). Sin esto, ninguna mejora del visor sirve. Evidencia: 12 ocurrencias en 5 logs, cronología reproducida (sección Auditoría de logs).
2. **P0-2 Xvnc daemoniza.** PID trackeado = padre muerto. `stop()` no mata nada. Huérfano retiene 5901. `-nodaemon` es el fix de una línea.
3. **P0-3 Worker sin reconexión.** ColorOS mató el worker una vez ya (logs 15:30→15:34). Tras eso, toda la app queda muerta hasta reinicio manual.

---

## Problemas críticos (P1)

P1-1 a P1-14 de la tabla. Núcleos: kill por grupo en vez de por tarea; preload en main looper; visor RFB con 3 bugs (desincronización SetColourMapEntries, copia O(N²), frames rasgados); xz/postinst muertos por rc=126; spawn detached sin setsid; fork+dlopen en proceso GPU; nanoroot sin protección `..`; allowlist de binarios evadible; 3 call-sites de installGraphical; port 6000 legacy.

---

## Compatibilidad

| Componente | Versión | Estado | Nota |
|---|---|---|---|
| Flutter | 3.38.4 stable | COMPATIBLE | |
| Dart | ≥3.10.3 | COMPATIBLE | |
| AGP | 8.11.1 | COMPATIBLE | Requiere Gradle ≥8.13 |
| Gradle | 8.14 | COMPATIBLE | |
| Kotlin | 2.2.20 | COMPATIBLE | `kotlinOptions.jvmTarget` deprecado (warning) |
| compileSdk | 36 | COMPATIBLE | |
| targetSdk | 35 | COMPATIBLE | Play agosto 2026 exige 35+ ✓ |
| minSdk | 26 | COMPATIBLE | Suficiente para linker namespaces |
| NDK | 28.2.13676358 | COMPATIBLE | Requiere CMake ≥3.22.1 ✓ |
| CMake | 3.22.1 | COMPATIBLE | |
| JVM target | 17 | COMPATIBLE | |
| coroutines | 1.8.1 | COMPATIBLE | core redundante (transitivo) |
| tukaani-xz | 1.9 | COMPATIBLE | |
| riverpod 2.6.1 / go_router 14.8.1 / ffi 2.2.0 | — | COMPATIBLE | Sin conflictos en lock |
| ABI | arm64-v8a | RIESGO | jniLibs: 10 .so trackeados, ~36 MB ignorados → APK irreproducible |
| `extractNativeLibs="true"` en manifest | — | RIESGO | AGP prefiere `packaging.jniLibs.useLegacyPackaging`; 46 MB extraídos en install |
| Firmado release | debug fallback | RIESGO | `NANOAI_KEYSTORE` ausente → debug cert silencioso |
| R8 minify + JNI | — | NO VERIFICADO | Reglas proguard parecen cubrir NanoshellBridge; sin build release de humo |
| xkbcomp asset | ELF dinámico aarch64 | INCOMPATIBLE (ColorOS) | No puede dlopen libs writable → causa P0-1 |
| proot asset | 239KB, interp linker64 | NO VERIFICADO | Sin evidencia de uso real en logs |
| `x.org.server` (XSDL) | — | INCOMPATIBLE | Sin `<queries>` en manifest → getLaunchIntentForPackage siempre null |

---

## Auditoría JNI/C++

**Símbolos exportados:** `ptySpawn/ptyWrite/ptyRead/ptyResize/ptyKill/ptyClose/ptyGetPid/ptyIsAlive` (pty_jni.c), `workerSpawn/workerSpawnDetached/workerKillGroup` (worker_jni.c), `nanoshell_spawn_*`, `nanoshell_last_error` (nanoshell.c), `pty_*` (pty.c). Interposición nanoroot (LD_PRELOAD): execve/execvp/execvpe/open/openat/stat/lstat/fstatat/access/faccessat/mkdir/mkdirat/opendir/readlink/realpath/unlink/rename/bind/connect/popen.

**Hallazgos clave:**
- fork+dlopen en hijo multithread (nanoshell.c:288-543, pty.c:106-201): malloc/dlopen/fprintf async-signal-unsafe tras fork desde JVM con hilos GPU. bionic mitiga malloc con atfork; riesgo residual real en ColorOS.
- kill(-pgid) desde worker_jni.c:120 mata worker completo (self-kill deliberado, mal si hay tareas paralelas).
- `apply_rlimit_as()` (512MB) antes de execve/dlopen: puede abortar el fallback dlopen (CFI shadow map).
- poll() con error o realloc fallido → waitpid bloqueante sin kill previo → hang si el hijo ignora SIGPIPE.
- Trampolín ARM64 sin setear x30: si `_start` retorna, salto a dirección basura.
- g_last_error global sin mutex: pisotones entre spawns concurrentes.
- nanoroot: traversal `..` sin rechazo; intercepción no exhaustiva (chmod/chown/symlink/link/truncate/mmap sin interceptar); `LOAD_SYM` fallido hace `_exit(1)` de todo el proceso.
- Sin flags hardening en CMake (fstack-protector-strong, format-security).
- `dlopen` de libs rootfs desde proceso principal falla por namespaces ART (`libgtk-3.so.0` → `libgdk-3.so.0` not found, 42 líneas en logs): cargar vía linker64 con LD_LIBRARY_PATH, no desde classloader.

---

## Auditoría Linux/Android

**Cómo se ejecuta Linux hoy:**
1. Rootfs Termux extraído a `files/nano` (DebInstaller propio: descarga .deb de repo Termux, sha256 verificado, extrae data.tar.xz).
2. `libnanoroot.so` vía LD_PRELOAD reescribe paths de Termux (`/data/data/com.termux/files/usr` → prefix app) en argv, popen, open/stat/rename/unlink, bind/connect AF_UNIX.
3. Ejecución de binarios: fork+execve del binario directo (bloqueado por SELinux/FUSE en ColorOS, rc=126) → fallback dlopen+main() in-process → fallback `execve(/system/bin/linker64, [binario])` — este último es el que funciona.
4. PTY: openpty manual + fork + execve(linker64, bash) — corre en el proceso principal (riesgo GPU).
5. Display: Xvnc :1 vía worker detached, visor RFB Dart.

**Limitaciones demostradas:**
- Binarios privados NO ejecutables directamente (30× rc=126 con xz).
- Libs desde directorio writable: Android avisa ("will throw on a future Android version") y en la práctica xkbcomp falla (P0-1).
- Proceso worker muere ocasionalmente sin crash visible (ColorOS).
- postinst de paquetes nunca se ejecuta (P1-7).

**Fallos de paths:**
- Hardcodeados en 20+ sitios (tabla de rutas: boot_orchestrator, shell_executor, nanoshell.c, nanoroot.c, DesktopSessionManager, DebInstaller, TarExtractor, ExecBinChannelHandler, proot_manager, monitor_plugin).
- `ensureLink('/data/data/dev.nanoai.mobile/f')` — symlink raro sin función clara documentada.

---

## Auditoría de procesos

| Proceso | Owner | PID lifecycle | Inicia | Detiene | Wait | Riesgo zombie |
|---|---|---|---|---|---|---|
| Worker :nanoshell | Android | Service bound | WorkerClient.bind | unbind/kill | Android | Bajo; sin rebind (P0-3) |
| Xvnc | spawnDetached | Trackeado = padre muerto | DesktopSessionManager | stop() (no mata) | Reaper thread | ALTO (P0-2) |
| openbox/tint2/terminal | spawnDetached | Trackeado en memoria | DesktopSessionManager | cleanupProcesses | Reaper thread | MEDIO (P2-1, P1-2) |
| PTY hijos (bash) | ptySpawn | Registro sesiones | PtyShell | ptyClose (no mata) | waitpid WNOHANG | MEDIO (P2-10, P1-13) |
| Tareas worker (apt, git) | nanoshell_worker_spawn | rc file por taskId | WorkerController | poll timeout → kill(-pgid) | waitpid en C | MEDIO (P1-1) |
| xz/execCmd | ProcessBuilder | — | DebInstaller | — | — | Bajo (muere con rc=126) |

---

## Auditoría de memoria

| Área | Hallazgo |
|---|---|
| Dart heap | Timers/streams bien cancelados en pty_shell, chat_provider. `late final _services` congela `mounted` (posible). |
| Java/Kotlin heap | Threads sin-daemon sin trackear en handleSpawn (acumulan). Result MethodChannel sin responder tras cancelación. |
| Native heap | strdup sin NULL-check (pty.c). g_last_error global sin mutex. Buffer stdout/stderr sin tope (realloc duplicando) → cap 64MB recomendado. |
| GPU | ui.Image sin dispose en vnc_screen (leak por frame). `_pixels` compartida decode/mutación. |
| Buffers | Copia O(N²) del buffer RFB (vnc_client). BLASTBufferQueue "max frames" = efecto de Xvnc muerto, no causa. |
| mmap/rootfs | RLIMIT_AS 512MB antes de execve (riesgo dlopen). jniLibs 46MB. |

---

## Auditoría de rendimiento

**Cuellos demostrados:**
1. Preload 117 libs en main looper del worker (bloquea Messenger segundos; latch 20s expira) — P1-2.
2. Copia O(N²) del buffer RFB por paquete — P1-4.
3. Via 1 xz: 3 spawns × 120s antes del fallback que funciona — P1-6.
4. FFI síncrono en UI isolate (hasta 30s) — P2-12.
5. `_waitForDesktopReady` 120s sin cancelación — señalado en diseño.

**No optimizar aún:** BLASTBufferQueue (~581 ocurrencias) es síntoma de Xvnc muerto. Desaparece con P0-1.

---

## Auditoría de logs

**Errores reales con módulo (top):**

| Error | Conteo | Módulo | Causa |
|---|---|---|---|
| BLASTBufferQueue max frames | ~581 | SurfaceView | Xvnc muerto (efecto) |
| suspend-service Permission denied | ~420 | Sistema | Ruido ColorOS, ignorar |
| VRI updateBlastSurfaceIfNeeded | ~242 | Sistema | Rotación, ignorar |
| xz rc=126 Permission denied | 30 | DebInstaller | execve bloqueado |
| Font path elements eliminados | ~30 | Xvnc | Fonts sin instalar (no fatal) |
| xkbcomp Popen server-xkm | 25 | Xvnc | Fallo compilación (fatal) |
| dlopen failed lib*.so | 42 | ART | Namespaces + deps incompletas |
| XKB: Failed to compile keymap + Fatal | 12 | Xvnc | P0-1 |
| Attempt to load writable file | 11 | Android | targetSdk 35 restricción |
| Xvnc no respondió en 60s | 17 | Código viejo | Consecuencia de P0-1 |

**Sin ANRs, sin SIGSEGV, sin OOM en ningún log.** El fatal es de Xvnc (proceso Linux), no de la app Android.

**Problemas de logging:** tags inconsistentes (CamelCase vs snake_case); mojibake en comentarios; stderr de Xvnc sí se escribe a `usr/tmp/xvnc_err.txt` pero la UI nunca lo muestra (el mensaje dice "revisa logcat" — el archivo es la fuente real); rc files de worker se acumulan en timeout (solo se limpian en éxito).

---

## Código duplicado y deuda técnica

**Duplicados exactos:**
- `CommandExecutor` (377 líneas) vs `_execAsync` inline en terminal_core.dart:560-672 — mismo pipeline, dos implementaciones.
- `DeviceInfo.readGpuInfo/readCpuTemp` vs `HardwareInfoService` — casi copias.
- `AiPlugin` + comandos inline `ai`/`infer` vs `AiPlugin` muerto.
- Dos extractores en TarExtractor (byte[] nunca usado).
- Symlinks `.so`→`.so.1` en preloadRootfsLibs vs DebInstaller.installGraphical — dos políticas.
- `handleKill()` (sin args) muerto vs `handleKill(msg)` real.
- Tres call-sites de installGraphical (boot_orchestrator, desktop_launch_screen, vnc_screen).

**Código muerto (sin importadores, verificado por grep):** command_executor.dart, cron_scheduler.dart, ai_plugin.dart, terminal_plugin.dart, keyboard_mapper.dart, expression_evaluator.dart, command_tagger.dart, terminal_workspace.dart, device_info.dart, NavigationChannelHandler, ExternalXsdlBackend, launchXsdl, handleKill, CHANNEL_WORKER.

**Estrategia:** una consolidación por área, en fases separadas (FASE 5), nunca junto a fixes P0/P1.

---

## Funciones faltantes/incompletas (demostradas)

| Función | Estado | Evidencia |
|---|---|---|
| Captura stderr Xvnc en UI | Falta | Archivo existe, UI no lo lee |
| Reconexión worker | Falta | P0-3 |
| Kill por taskId | Falta | Solo kill por grupo |
| Ack de workerSpawn | Falta | Fire-and-forget |
| close() PTY mata hijo | Falta | Solo cierra master |
| Check cabecera RFB en awaitReady | Falta | Solo TCP connect |
| Chequeo de integridad post-extracción (.deb) | Falta | gdk-pixbuf quedó incompleto sin detectar |
| `procsRunning()` blocked | Incompleta | Siempre 0 |
| `realpath` reescritura en nanoroot | Incompleta | TODO en código |
| SHA256 kali_manager | Incompleta | expectedSha256='' |
| docker_manager.stop() | Incompleta | No mata proot |

---

## Matriz SOLID

| Principio | Cumple | Viola | Archivo | Por qué | Corrección |
|---|---|---|---|---|---|
| SRP | Parcial | Sí | terminal_core.dart | Widget con 110+ líneas de exec inline | Extraer a CommandExecutor (uno solo) |
| SRP | Parcial | Sí | DesktopSessionManager | Orquesta backend+WM+watchdog+config | Mantener (cohesión aceptable); separar watchdog |
| OCP | Sí | — | XServerBackend | Interfaz con 2 impls | Correcto |
| LSP | Sí | No | ExternalXsdlBackend.start | Retorna true sin hacer nada (rompe contrato) | Se elimina con P3-1 |
| ISP | Parcial | Sí | NanoshellBridge | Un solo bridge con PTY+worker+spawn | Dividir por dominio |
| DIP | Parcial | Sí | package_service/desktop_launch_screen | UI llama canal directamente | PackageService ya abstrae; pantallas deben usarlo |
| DIP | Parcial | Sí | NanoshellWorkerService | Service conoce paths y preload internals | Aceptable en boundary; aislar preload |
| DIP | No | Sí | boot_orchestrator | Coordinador hace instalación + parches + wrappers | Es el dueño natural; extraer DesktopEnvCheck |
| Fuente de verdad | No | Sí | port 6000 vs 5901; `_isDesktopReady` vs reachable | Dos verdades | Unificar en DesktopStatus |

---

## Plan de corrección (sin aplicar todavía)

### FASE 0 — Estabilización (higiene git + build)

Archivos: .gitignore raíz (quitar `*.so` global o excepción jniLibs), flutter_app/.gitignore (añadir `*.bak`), jniLibs (decidir trackeo), gradle.properties (Xmx4G + caching).
Cambios permitidos: higiene de tracking, flags de build, borrar logcat*.txt + .bak.
Cambios prohibidos: código de runtime.
Dependencias: ninguna.
Riesgos: perder una .so necesaria al reordenar → verificar qué carga runtime antes.
Criterio de salida: `git status` limpio, build reproducible en clon.
Rollback: revert commit.

### FASE 1 — P0 (desbloquear escritorio)

Archivos: boot_orchestrator.dart + asset xkbcomp (P0-1), XServerBackend.kt (P0-2 `-nodaemon`), WorkerClient.kt + NativeRuntimeSupervisor.kt (P0-3 rebind).
Cambios permitidos: solo los 3 fixes.
Cambios prohibidos: tocar visor, instalador, UI.
Dependencias: P0-1 requiere compilar xkbcomp estático (NDK) o ruta de libs no-writable — decisión de diseño previa.
Riesgos: xkbcomp estático = build nuevo; rebind = loop si el service crashea repetido (backoff obligatorio).
Criterio de salida: dispositivo ColorOS muestra escritorio Openbox estable ≥10 min; `stop()` + `start()` dos veces sin "Address already in use".
Rollback: revert por commit individual.

### FASE 2 — P1 (estabilidad crítica)

Archivos: worker_jni.c + NanoshellWorkerService.kt (kill por taskId, preload en thread), vnc_client.dart + vnc_screen.dart (RFB fixes, dispose, pan end), DebInstaller.kt (XzDecoder primario, postinst por worker), nanoshell.c (setsid), pty.c (kill seguro, SIGHUP en close), nanoroot.c (rechazar `..`), allowed_binaries/nanoshell_ffi (canonicalizar), Dart (coordinador desktop único, port 5901).
Cambios permitidos: fixes puntuales con su hallazgo de referencia.
Cambios prohibidos: reescrituras, refactor estético.
Dependencias: FASE 1 completa (probar sobre escritorio vivo).
Riesgos: kill por taskId cambia semántica del worker — probar tareas paralelas.
Criterio de salida: timeout de una tarea no mata otras; drag de ratón sin click fantasma; instalación sin spawns xz.
Rollback: por archivo.

### FASE 3 — Arquitectura (una sola fuente de verdad)

Archivos: nuevo `DesktopCoordinator` (Dart) dueño único de install/start/status; eliminar ExternalXsdlBackend/handleLaunchXsdl/launchXsdl; stage en getDesktopStatus + RFB header check en awaitReady; errores stderr Xvnc a UI.
Cambios permitidos: consolidación de dueños.
Cambios prohibidos: cambiar protocolo worker sin test.
Dependencias: FASE 2.
Riesgos: medio — toca el flujo completo del desktop.
Criterio de salida: un solo call-site de installGraphical; `stage` real en UI (sin 85% fake).
Rollback: coordina con el diseño VNC aprobado.

### FASE 4 — Rendimiento

Archivos: vnc_client buffer growable, FFI en isolate (P2-12), timeout C=Dart unificado (P2-4), ack workerSpawn (P2-5), thread pool del worker.
Cambios permitidos: optimizaciones con cuello demostrado.
Cambios prohibidos: micro-optimización sin medición.
Dependencias: FASE 3.
Riesgos: bajo.
Criterio de salida: <100ms jank en scrolling de frames; sin congelos UI con find/tar.

### FASE 5 — Limpieza

Archivos: borrar 9 archivos muertos, consolidar DeviceInfo/HardwareInfoService, unificar tags de log `nano-*`, quitar permisos FGS muertos, quitar kotlinOptions deprecado, rutas hardcodeadas → constante única.
Cambios permitidos: borrado verificado por grep, consolidación.
Cambios prohibidos: tocar lógica viva.
Dependencias: FASE 4.
Riesgos: bajo (borrar solo sin importadores).
Criterio de salida: `flutter analyze` y build limpios.

### FASE 6 — Validación

Archivos: smoke test release con R8 (P3-3), firma con fallo explícito, plan de prueba en dispositivo (matriz ColorOS), checklist del skill de auditoría re-ejecutado.
Cambios permitidos: configuración de build/CI, documentación.
Cambios prohibidos: código runtime.
Dependencias: todas.
Riesgos: bajo.
Criterio de salida: informe de auditoría re-ejecutado con 0 P0, 0 P1 nuevos.
Rollback: no aplica (validación).

---

## Prioridad inmediata

El hallazgo P0-1 (XKB) **cambia el diseño VNC en curso**: la prueba decisiva "¿5901 devuelve RFB?" no basta — Xvnc abre RFB y muere 2 segundos después. La prueba decisiva correcta es:

```text
1. TCP 5901 responde
2. cabecera RFB 003.00x leída
3. Xvnc sigue vivo tras 5s (segundo probe)
4. reglas XKB compiladas (xkbcomp rc=0, o ausencia del fatal en stderr)
```

Solo entonces marcar `rfb_ready`.
