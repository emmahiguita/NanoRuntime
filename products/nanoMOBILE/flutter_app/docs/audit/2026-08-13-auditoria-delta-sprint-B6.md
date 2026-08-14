# Auditoría Delta — Sprint B6+ (tarde 2026-08-13)

**Alcance:** re-auditoría paralela completa post-B6 (6 agentes read-only: Kotlin/Android, C/JNI/nanoroot, Flutter/Dart, Gradle/SDK, puente Linux↔Android, nanoRUNTIME Rust) sobre estado de trabajo sin commitear.
**Base:** auditoría integral matinal `2026-08-13-auditoria-integral.md` (A-01…A-2x). IDs nuevos: D-xx.

---

## 1. Resumen ejecutivo

| Área | Estado |
|---|---|
| Estado general | Funcional de extremo a extremo; 6 P1 nuevos encontrados (ninguno P0); release engineering sigue pendiente |
| Android runtime | U-10 sólido: heartbeat honesto, anti-loop 120s, a11y exento de BAL; shutdown en main thread (D-03) |
| Flutter | Race real STOP→re-envío en chat (D-04); mojibake UTF-8 en settings/vnc (D-14) |
| C/C++/JNI | nanoroot 24 símbolos estables; 4 P2 de memoria/procesos (D-07…D-10, D-23/D-24) |
| Linux/rootfs | Árbol de procesos huérfano al detener desktop (D-06); dbus sin watchdog (D-13) |
| Motor nanoAI | Supervisor honesto (PID + GET /health); races start/stop (D-11); server HTTP sin límites (D-05) |
| nanoRUNTIME core | 2 no-ops que prometen (tune-system, OOM monitor) — viola pilar honestidad (D-21) |
| Compatibilidad | Matriz completa COMPATIBLE (AGP 8.11.1/Gradle 8.14/Kotlin 2.2.20/NDK 28.2/Flutter 3.38.4/targetSdk 36) |
| Release | Firma release cae silenciosamente a debug keystore (D-19); e2e motor pendiente (device fuera de ADB) |

---

## 2. Tabla maestra delta

| ID | Prioridad | Archivo | Error | Evidencia | Solución |
|---|---|---|---|---|---|
| D-01 | P1 | `channels/ExecBinChannelHandler.kt:110-124` | Timeout 30s de probeExec es código muerto: `readBytes` (await hasta EOF) corre ANTES de `waitFor(30s)`; binario colgado congela el await para siempre. El fix A-10 no cubre este orden | Lectura directa del orden de awaits | `waitFor(30)` primero; si timeout `destroyForcibly()` y recién leer streams |
| D-02 | P1 | `cpp/pty.c:106-170` + `PtyChannelHandler.kt:20-45` | PTY fork+dlopen en proceso PRINCIPAL (Flutter+GPU). Todo el resto del puente usa worker por riesgo Mali/ColorOS documentado en `NanoshellWorkerService.kt:15-19`. bash funciona hoy (A-16), pero cualquier binario del rootfs que SIGSEGV en terminal mata la app entera | Contradicción interna: worker existe por ese riesgo, PTY no lo usa | Mover ptySpawn al worker con IPC por socket; o siempre vía `execve(linker64)` prohibiendo fallback dlopen |
| D-03 | P1 | `MainActivity.kt:97-99` → `DesktopSessionManager.kt:151-153` | Shutdown síncrono en main thread en onDestroy: `runBlocking { backend.stop() }` hasta 2s + SIGKILLs, con lock tomado | Lectura directa | Descargar stop a ioScope antes de matar worker |
| D-04 | P1 | `core/providers/chat_provider.dart:266,345,371` | STOP→re-envío: flags `_generationCancelled` compartidos entre generaciones; gen vieja muerta inserta error falso "motor no respondió" y `finally` clobberea `_streamClient` → STOP no cancela gen nueva | Traza del flujo | Token `_genId` + guard `identical(_streamClient, client)` |
| D-05 | P1 | `nanortime-cli/src/server.rs:530,539` | `read_line` sin límite de tamaño + bind 0.0.0.0 default en Linux headless → DoS de memoria sin autenticar | Lectura directa; body sí capado 64KB en :208 | `take(65536)` o read_line capado 8KB |
| D-06 | P1 | `DesktopSessionManager.kt:498-507` + `nanoshell.c:784-788` | stopDesktop mata solo PID raíz; daemons `setsid()` → `sh→bash→hud.py` siguen vivos contra X muerto reteniendo fd del log | pty.c:245-252 ya hace kill(-pid) correcto | `kill(-pid, SIGKILL)` (setsid los deja líderes de grupo propio) |

| D-07 | P2 | `cpp/worker_jni.c:151-156` | `kill(prev, SIGKILL)` sin verificar liveness: PID reciclado → mata proceso ajeno; reaper no limpia slot | Lectura directa | `kill(prev,0)` + /proc antes del SIGKILL; reaper limpia slot bajo lock |
| D-08 | P2 | `cpp/nanoshell.c:571-580` | poll 30s fijo → SIGKILL incondicional: apt update/tar legítimos silenciosos >30s mueren a mitad de instalación (dpkg corrupto) | Comentario propio documenta apt sin input | Timeout por env `NANOAI_SPAWN_TIMEOUT_MS`; SIGTERM→gracia→SIGKILL |
| D-09 | P2 | `cpp/nanoshell.c:313,321,331` | `apply_rlimit_as()` duplicado y aplicado ANTES de execve directo; contradice evidencia propia pty.c:136-138 (MapShadow Android 14/15) | Contradicción interna | Solo en path dlopen |
| D-10 | P2 | `cpp/nanoshell.c:497-504` | `_elf_entry_of` devuelve base=0 si dl_iterate_phdr no matchea → jump a dirección absurda → SIGSEGV child. Path detached sí usa dlinfo (robusto) | Comparación de paths | dlinfo primero, validar base!=0 |
| D-11 | P2 | `EngineSupervisor.kt:205-224` | Race start/stop: generation mismatch abandona pid recién spawn-eado sin matar → nanortime huérfano hasta próximo start | Lectura directa | Matar pid en branches de mismatch |
| D-12 | P2 | `EngineSupervisor.kt:139`, `DesktopSessionManager.kt:385,592,607` | `File("/proc/$pid").exists()` = true para zombies → proceso muerto reportado vivo, watchdog no relanza | Solo XServerBackend.kt:332-345 chequea estado | Helper común: `/proc/<pid>/stat` estado != 'Z' |
| D-13 | P2 | `DesktopSessionManager.kt:576-652` | Watchdog vigila Xvnc/openbox/tint2/terminal pero NO dbus-daemon: bus muerto = gvfs/trash:// roto sin aviso ni restart | Lectura directa | Mismo patrón granular |
| D-14 | P2 | `settings_screen.dart:102,107,140,151,205,357,399,459`, `vnc_screen.dart:152` | Mojibake real verificado por bytes UTF-8: 'Control TÃ©rmico', 'BaterÃa', 'ConexiÃ³n perdida'… | Bytes del archivo | Re-guardar archivos en UTF-8 limpio |
| D-15 | P2 | `core/services/llm_engine_client.dart:222` | `controller.add` en loop SSE sin guard `isClosed` (catchs sí lo usan) → StateError → addError relanza → red screen debug | Lectura directa | Guard en el add del loop |
| D-16 | P2 | `nanortime-core/src/execution/model_manager.rs:612-661` | Single-flight por diseño: 2º /completion falla "No model loaded"; panic entre take() y restore() deja slot None para siempre | Traza take/restore | RAII guard que restaure en Drop + cola/Mutex async |
| D-17 | P2 | `nanortime-core/src/execution/tool_executor.rs:311-336,407-492` | execute_mcp: 7 paths `child.kill()` sin `child.wait()` → zombies; timeout 30s no mata hijo | Lectura directa | `let _ = child.wait().await;` tras cada kill |
| D-18 | P2 | `AgentChannelHandler.kt:174-245`, `AgentAccessibilityService.kt:96-156,248-287` | dumpScreen/findText en main thread (jank) + hijos AccessibilityNodeInfo sin recycle en findText/findFirstClickable/findFocusedEditable | Lectura directa | Executor del service + recycle al desencolar |
| D-19 | P2 | `android/app/build.gradle.kts:66-74` | Release firmado con debug keystore si faltan env NANOAI_KEYSTORE_* — silencioso, Play rechaza | Lectura directa (A-05 seguía ⏳) | `require()` en release, fallback solo debug |
| D-20 | P2 | `nanortime-cli/src/server.rs:226-235` | Runtime tokio current-thread nuevo por request con `.unwrap()` (panic en path caliente); `tokio::spawn` del orquestador abandonados al dropear runtime | Lectura directa | Runtime global reusado |
| D-21 | P2 | `platform.rs:148`, `main.rs:251-268` | `--tune-system` no toca nada (solo geteuid==0, logea "System optimization enabled"); monitor OOM nunca lee `_oom_rx` — promesas falsas, viola filosofía honestidad | Cargo feature `v2` off + rx jamás leído | Implementar real o renombrar a "check only" y loguear honesto |
| D-22 | P2 | `nanoshell.c:810`, `DesktopSessionManager.kt:67`, `shell_executor.dart:71,74,442`, `boot_orchestrator.dart:209`, `proot_manager.dart:107` | Paquete hardcodeado `/data/data/dev.nanoai.mobile/...` en 5 archivos; cambio de applicationId deja rootfs huérfano | Grep multi-archivo | Derivar de `context.applicationInfo.dataDir` |
| D-23 | P2 (HIPÓTESIS) | `cpp/nanoshell.c:763-860`, `pty.c:119` | Child detached no cierra fds 3..255: hereda pipes de spawns concurrentes → poll del padre no ve EOF → SIGKILL a los 30s de tarea legítima | Traza de herencia de fds | `close_range(3, ~0U, 0)` (API 30+) o O_CLOEXEC |
| D-24 | P2 (HIPÓTESIS) | `cpp/pty.c:51` | `ptsname()` no reentrante (bionic usa buffer estático): 2 ptySpawn concurrentes → carrera | Uso de API | `ptsname_r()` |
| D-25 | P2 | `ExecBinChannelHandler.kt:228-233` | Raza timeout 60s startDesktop: onReady tras error deja desktop corriendo con UI "failed" (auto-sana al próximo start, desync transitorio) | Lectura directa | Estado tardío → actualizar UI |
| D-26 | P2 | `dashboard_provider.dart:108-115`, `runtime_engine.dart:166,233`, `nano_runtime_api.dart:75` | Escritura de estado post-await sin re-chequear mounted (dispose en vuelo); `_handshake ??=` memoiza también el FALLO → runtime "unavailable" de por vida en proceso | Lectura directa | Guard `mounted` tras cada await; memoizar solo éxito |

---

## 3. Qué está inyectado / interceptado (exacto)

**libnanoroot.so — LD_PRELOAD, 24 símbolos (nanoroot.c):** open:558, openat:579, stat:602, lstat:611, fstatat:620, access:633, faccessat:642, mkdir:655, mkdirat:664, opendir:677, **dlopen:693** (linker resuelve paths con open internos — fix 5d897b6), readlink:706, realpath:719, unlink:732, rename:743, **shmget→ENOSYS:761** (anti-SIGSYS seccomp ColorOS syscall 194), bind:769 (addrlen recomputado:791), connect:805, popen:832, **execve:453/execl:428/execvp:458/execvpe:508** → cascada `nano_execve_core:323` → **linker64:266** con dlsym lazy `real_execve:274` (fix SIGSEGV pc=0 en aterm) → dlopen+dlsym(main):400. Constructor lee NANO_ROOTFS:879. Redirección /usr /etc /tmp /var /home /bin /sbin /lib /root + rewrite de prefijo Termux:98-216.

**libnanoshell.so — JNI (nanoshell.c/pty.c/worker_jni.c):** fork+execve/dlopen+main in-child:262; daemons detached fork+setsid:784 + execve→linker64:898→dlopen:949; trampolín `_start` ARM64 naked:127; `android_create_namespace`/`dlopen_ext`:386-468; PTY emulado (posix_openpt→login_tty:75, fork:106); reaper thread waitpid:112-130; kill(-pgid):198; atomic rename de outputs worker:709-719; anti-duplicado daemons con registro persistente.

**jniLibs pre-cargadas (arm64-v8a):** 84 .so incluyendo `libtermux-exec-*` (4 variantes), `libbusybox.so`, `libnanortime_ffi.so`, TLS/gnutls/curl/ssh2/readline/ncurses/procps…

**Android:** resurrección U-10 por `AgentAccessibilityService` (a11y exento de BAL, anti-loop 120s, heartbeat `alive.timestamp` honesto, solo stop limpio lo borra); VNC RFB 3.8 loopback; dbus session socket; worker por Binder/Messenger.

## 4. Qué funciona (verificado en código por dominio)

- **Boot:** main → settings init pre-frame → BootOrchestrator post-frame: handshake memoizado → rootfs (descarga bootstrap.zip ~30MB si falta) → paquetes esenciales → desktop env (valida Xvnc/openbox/libs/xkb/evdev) → symlinks + wrapper xkbcomp + shim libandroid-shmem. Todo degrada con debugPrint, nunca bloquea arranque.
- **Desktop:** Xvnc ready = PID + socket X11 + 2s estable, sin TCP probes (evita anti-brute TigerVNC — memoria verificada); watchdog 5s relanza openbox/tint2/terminal; openbox/tint2/feh/dbus por worker detached con reaper (cero zombies).
- **Chat LLM:** send → ensureReady (poll 45s, /api/status honesto) → SSE flush 32ms → persistencia; stop cooperativo; selectModel debounce 600ms cancelable; disposals completos (timers/streams/controllers).
- **Terminal:** binarios reales host con cache, pipes reales, cwd lógico no escapable, errores honestos; PTY con kill(-pgid) + waitpid acotado; dup-fd bajo mutex sin race.
- **VNC:** RFB 3.8/3.3, auth None+VNC, raw+copyrect FSM incremental, backpressure 1 FBU, heartbeat 30s + frame-timeout 60s, reconexión 1→30s ×7, dispose de bitmaps.
- **Engine:** EngineSupervisor con generation counter, health poll backoff honesto vía /proc + GET /health (body `"status":"ok"`), SIGTERM→3s→SIGKILL; PID muerto → Idle sin mentir. Reaper waitpid + WIFSIGNALED honesto. shutdown order engine→worker con guard terminal.
- **nanoRUNTIME:** chat interactivo completo (spawn_blocking stdin, Ctrl+C limpio, streaming, historia bounded 40, /model /tools /clear); /completion SSE con cancel real (incluso durante prefill); /health /cancel /api/status, 503 honesto en --no-model; 7 tests por socket; allowlist 3 capas sin shell, timeouts 30s; guards de calidad (early-exit, alucinación), abort real del loop llama.
- **Seguridad Android:** allowBackup=false, sin FGS (worker bind-only, coherente Android 14), cleartext cerrado salvo loopback/wttr.in, a11y exported con BIND_ACCESSIBILITY_SERVICE, queries sin QUERY_ALL_PACKAGES, permisos con uso real verificado, gestos agente con bounds reales + allowlist regex + caps MAX_NODES/MAX_DEPTH.
- **Compatibilidad:** matriz completa COMPATIBLE (sección 7 del informe integral): AGP 8.11.1/Gradle 8.14/Kotlin 2.2.20/NDK 28.2.13676358/JDK 17/Flutter 3.38.4/Dart 3.10.3/CMake 3.22.1; targetSdk 36 cumple deadline Play 31-ago-2026; minSdk 26 sin features que exijan más.

## 5. Qué falta

1. **Aislamiento PTY** (D-02) — único camino que fork+dlopen en proceso con GPU.
2. **Timeout probeExec real** (D-01) — el fix A-10 quedó inefectivo por orden de awaits.
3. **Shutdown async** (D-03) — ANR en onDestroy.
4. **Race chat STOP→re-envío** (D-04) — error falso visible al usuario.
5. **Límites server nanoRUNTIME** (D-05, D-20) — DoS + panics en path caliente.
6. **Árbol de procesos desktop** (D-06, D-07, D-11, D-12, D-13) — huérfanos, PID reciclado, zombies reportados vivos, dbus sin watchdog.
7. **Honestidad nanoRUNTIME** (D-21) — tune-system y OOM monitor prometen sin hacer.
8. **Release engineering:** keystore producción (D-19), icono, CI, e2e motor completo en device (pendiente: device fuera de ADB), empaquetado x86_64 para emulador (documentar).
9. **UTF-8** (D-14) — mojibake visible en settings/VNC.
10. **Concurrencia inferencia** (D-16) — 2º request falla en vez de encolar; KV session solo en modo --prompt.

## 6. Plan de fases (delta)

- **FASE 1 (P1, hoy):** D-01 reordenar awaits; D-03 stop a ioScope; D-04 token generación; D-05 cap read_line; D-06 kill(-pid); D-02 decidir worker-PTY o prohibir fallback dlopen.
- **FASE 2 (P2 procesos):** D-07 verificación liveness; D-11 matar pid en mismatch; D-12 helper estado /proc; D-13 dbus watchdog; D-25 estado tardío.
- **FASE 3 (P2 C):** D-08 timeout por env; D-09 RLIMIT solo dlopen; D-10 dlinfo primero; D-23 close_range; D-24 ptsname_r.
- **FASE 4 (P2 Dart/Rust):** D-14 UTF-8; D-15 guard isClosed; D-16 RAII + cola; D-17 wait tras kill; D-20 runtime global; D-21 honestidad; D-26 guards mounted + handshake memo.
- **FASE 5 (release):** D-19 require keystore; D-22 derivar dataDir; CI; icono; e2e motor.

Criterio salida por fase: cada D-xx con evidencia de fix (diff + prueba o log) y sin regresión de los A-xx ya aplicados.
