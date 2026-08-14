# Auditoría Integral de Arquitectura y Compatibilidad — 2026-08-13

Auditoría extremo a extremo, 5 dominios en paralelo (Kotlin/Android, C/JNI, Rust nanoRUNTIME, Flutter/Dart, compatibilidad+logs) + escaneos deterministas MCP (sintaxis, manifest, arquitectura, duplicados). Objetivo: fallos concretos con evidencia y plan de corrección **real compatible** con dispositivo ColorOS (seccomp, cached-kill, loopback compartido).

Convenciones: `[CONFIRMADO]` = evidencia determinística en código o verificación empírica. `[HIPÓTESIS]` = requiere log/prueba en dispositivo. Sin evidencia no es bug.

---

## 1. Resumen ejecutivo

| Área | Estado |
|---|---|
| Build | `flutter analyze` limpio; sintaxis/JSON sin malformación |
| Android runtime | Funcional, con 2 cuelgues permanentes demostrados (probeExec, shell_executor) y 1 orphan de proceso en raza start/stop |
| Flutter | Sin leaks de `ui.Image` salvo 1 fuga nativa por "Reintentar" en VNC; 2 setState tras dispose confirmados |
| C/C++ | Intercepts nanoroot correctos en execve/dlopen/shmget; cobertura incompleta: shmat/shmctl/shmdt/chmod sin intercept → SIGSYS seccomp latente |
| JNI | Sin fugas de referencias locales; validación de argv incompleta (strdup NULL) |
| Linux | Desktop arranca; tint2 segfault bajo nanoroot reproducido aislado, sin fix |
| Rootfs | Bootstrap DebInstaller complejo; estado parcial corrupto = decisiones inconsistentes |
| Procesos | Reaper del worker centraliza waitpid; reaper reporta segfault 139 como exit 0 (WEXITSTATUS sin WIFSIGNALED) |
| Memoria | Fuga por reintento VNC (3.7 MB nativos/vez); archivo adjunto completo en RAM (OOM en gama baja) |
| Rendimiento | I/O síncrono en boot; decode VNC en isolate UI (hang 59s documentado) |
| Conectividad | Loopback Android es compartido entre apps: Xvnc sin password y API del engine sin auth = superficie expuesta a apps del mismo device |
| Seguridad | Motor Rust: bind 0.0.0.0 + CORS `*` por defecto; keystore debug en release |
| Mantenibilidad | God-files: vnc_screen.dart 1912 líneas, DebInstaller 107 ramas; duplicados reales en keyboard mapping y métricas |

**Conclusión**: no hay P0 de build, pero sí 2 P0 funcionales (keystore release bloquea publicación; tint2 segfault rompe el panel del escritorio bajo nanoroot). 18 P1 con evidencia. La línea "compatible real" exige 4 cambios de fondo: cerrar todos los syscalls que ColorOS mata (shmat/shmctl/shmdt/chmod), eliminar fork+dlopen del proceso principal, autenticar todo lo que escuche en loopback, y quitar panics que cruzan la frontera FFI.

---

## 2. Tabla maestra

| ID | Prioridad | Archivo | Componente | Error | Evidencia | Causa raíz | Impacto | Solución |
|---|---|---|---|---|---|---|---|---|
| P0-X01 | P0 | android/app/build.gradle.kts:66-74 | Release | Firma con keystore debug si no hay NANOAI_KEYSTORE | `[CONFIRMADO]` fallback explícito | Sin keystore de producción | Bloquea publicación Play | Generar keystore release, CI con secretos |
| P0-X02 | P0 | tint2 + librsvg + nanoroot | Desktop Linux | tint2 EXIT=139 segfault procesando `image-x-generic.svg` CON nanoroot activa | `[CONFIRMADO]` reproducido aislado `timeout 6 env LD_PRELOAD=...` (auditoría previa FASE 3f) | Intercept nanoroot rompe algo que librsvg usa (probable: readlink/realpath sin des-prefijar, o mmap/stat en path reescrito) | Panel del escritorio muere en crash-loop | FASE 1: backtrace con gdb; revisar intercepts readlink/realpath (nanoroot.c:724 TODO conocido) |
| P1-K01 | P1 | channels/ExecBinChannelHandler.kt:111-124 | probeExec | Timeout de 30s es código muerto: `outDef.await()`/`errDef.await()` corren ANTES de `p.waitFor(30s)` | `[CONFIRMADO]` orden de líneas; proceso que no cierra pipes → await infinito | Timeout aplicado en orden equivocado | Zombie vivo + MethodChannel.Result nunca resuelto + Future Dart colgado | Mover waitFor-timeout antes de leer streams, o leer con deadline |
| P1-K02 | P1 | EngineSupervisor.kt:198-222,295 | Engine | Orphan en raza start/stop: spawnDetached retorna PID, luego `generation != gen` hace return sin matar el PID | `[CONFIRMADO]` stop() anula handle sin PID que matar (línea 295) | Generación verificada después de spawn, no antes | Motor huérfano consumiendo RAM sin owner | En mismatch de generación: kill(pid, SIGKILL) antes de return |
| P1-C01 | P1 | nanoshell.c:627 | Worker spawn | `waitpid(pid, &status, 0)` bloquea indefinido si hijo cierra pipes pero nieto hereda write-end (`bash -c 'cmd &'`) | `[HIPÓTESIS]` EOF del poll no implica salida del proceso | waitpid sin timeout | Thread del worker bloqueado para siempre; reaps posteriores penden | Loop WNOHANG + usleep + SIGKILL tras deadline, o cerrar pipes y waitpid acotado |
| P1-C02 | P1 | nanoshell.c:883 + worker_jni.c:139 | Worker spawn | SIGSEGV en hijo detached si `binary_path` NULL: `strrchr(NULL)` + strcmp sin guard | `[HIPÓTESIS]` worker_jni permite bin=NULL | Falta validación de argumento en frontera JNI | Crash del proceso hijo | Guard argc>0 && argv[0] && base_name antes de strcmp |
| P1-C03 | P1 | pty.c:106 + NanoshellBridge.kt:45 + PtyChannelHandler.kt:45 | PTY | fork()+dlopen() en proceso PRINCIPAL (con GPU/Impeller/Mali) | `[CONFIRMADO]` contradice evidencia documentada NanoshellWorkerService.kt:15-18 ("fork+dlopen en main process crashea SIEMPRE, SIGSEGV mali-compiler") | Canal PTY expuesto sin ruteo por worker | Crash de app completa en ColorOS si el terminal usa este canal | Rutear PTY por :nanoshell (como spawnDetached) o deshabilitar el canal hasta verificar |
| P1-C04 | P1 | nanoroot.c:761 | Seccomp ColorOS | Solo `shmget` interceptado; `shmat` (217), `shmctl` (195), `shmdt` (218) sin intercept → SIGSYS mata el proceso | `[CONFIRMADO]` ausencia de handlers en código | Cobertura parcial de familia SysV | Cualquier binario que llame shmat directo (sin shmget previo) muere con tombstone | Añadir intercepts shmat/shmctl/shmdt → -1/ENOSYS |
| P1-F01 | P1 | lib/core/services/shell_executor.dart:296-297 | Executor | Deadlock permanente tras timeout: `onTimeout` cancela subs y `await outSub.asFuture<void>()` NUNCA completa | `[CONFIRMADO]` verificado empíricamente (dart run x2): asFuture tras cancel cuelga | Semántica StreamSubscription.asFuture | Cada comando con timeout deja Future colgado + proceso registrado vivo | Reemplazar asFuture por Completer completado en done y en camino de cancelación |
| P1-F02 | P1 | lib/features/terminal/terminal_core.dart:154-168 | Terminal | `_out()` hace setState sin guard `_alive`/`mounted`; callbacks de `_initShell` completan tras dispose (instalación de rootfs dura minutos) | `[CONFIRMADO]` cuerpo directo setState sin chequeo | Falta guard de ciclo de vida | Crash "setState after dispose" al salir durante instalación | `if (!_alive) return;` al inicio de `_out` |
| P1-SEC01 | P1 | services/XServerBackend.kt:135-167 | VNC | Xvnc arranca `SecurityTypes None` con password vacío; `-localhost` solo limita a loopback, que en Android es COMPARTIDO entre apps | `[HIPÓTESIS]` cualquier app del device puede conectar a 127.0.0.1:5901 y operar el escritorio | Sin auth por defecto | Toma de control del escritorio por apps del device | VncAuth con password aleatorio generado y mostrado/almacenado |
| P1-SEC02 | P1 | EngineSupervisor.kt:276-282 | Engine | Server /completion en 127.0.0.1:8080 sin auth | `[HIPÓTESIS]` loopback compartido; /health falseable para DOS o engaño de estado | Sin token | Inferencia no consentida o DOS local | Token por header verificado server-side, o socket UNIX 0700 |
| P1-SEC03 | P1 | nanortime-cli/src/platform.rs:108 + server.rs:167 | Engine | bind `0.0.0.0` por defecto en headless + CORS `*` | `[CONFIRMADO]` solo warning impreso | Default inseguro | API del motor expuesta a toda la red (LAN/WiFi) | Default `127.0.0.1`; 0.0.0.0 solo opt-in explícito |
| P1-SEC04 | P1 | TarExtractor/zip/postinst (sprint-plan 08-12) | Bootstrap | SEC-1 TarExtractor symlink sin validar, SEC-2 zip sin hash, SEC-3 postinst fuera de pathPolicy — sin evidencia de cierre | `[CONFIRMADO]` pendientes documentados, solo A-22 Kali fail-closed aplicado | Sin validación de entradas | Path traversal / ejecución fuera de política al instalar rootfs | Validar symlinks, hash de zip, pathPolicy en postinst |
| P1-R01 | P1 | nanortime-ffi/src/lib.rs:76 | FFI | `LlamaBackend::init().expect(...)` en `get_or_init`: fallo = PANIC = abort de proceso; rama Err de init_backend es código muerto | `[CONFIRMADO]` panic cruza frontera extern "C" | Panic en hot path de init | App entera muere (abort) en vez de degradar a 503 | `OnceLock<Result<LlamaBackend,String>>` y propagar error |
| P1-R02 | P1 | nanortime-cli/src/server.rs:300,469 | Engine | `n_predict`/`max_tokens` sin cap server-side; cliente manda 10^12 → generación secuestra el único modelo por minutos | `[CONFIRMADO]` budget dinámico por RAM solo aplica al CLI | Falta validación | Otros clientes reciben "Model temporarily unavailable"; hilo ocupado | Cap server-side con el safe budget del CLI |
| P1-R03 | P1 | nanortime-cli/src/server.rs:152 | Engine | Thread-per-connection sin límite + sin write timeout (solo read 30s): cliente que no lee SSE retiene thread+modelo indefinido | `[CONFIRMADO]` std::thread::spawn por conexión, loop infinito serve | Sin límite de concurrencia | En hardware barato ~30 conexiones agotan RAM/threads | Semáforo de conexiones + write timeout o poll en bucle SSE |
| P2-K01 | P2 | services/AgentAccessibilityService.kt:137-156,248-287 | Agente | Leak de AccessibilityNodeInfo: hijos apilados sin recycle() (solo root y found se reciclan); hasta 800 nodos por llamada | `[CONFIRMADO]` | Nodos nativos no reciclados | Acumulación nativa por llamada del agente | recycle() al desapilar cada nodo |
| P2-K02 | P2 | services/AgentAccessibilityService.kt:64-71 | Resurrección | Heartbeat stale: timestamp solo se borra en apagado limpio; swipe-away deja timestamp y rebind posterior relanza MainActivity sola | `[CONFIRMADO]` | Validación sin antigüedad | App relanzada sin intención del usuario | Validar antigüedad del timestamp (<10 min) además de ventana anti-loop |
| P2-K03 | P2 | services/AgentAccessibilityService.kt:65-71 + RuntimeHeartbeat.kt:37 | Resurrección | Kill-loop: cada resurrección queda en background → re-kill → rebind → ciclo indefinido de 120s consumiendo batería | `[HIPÓTESIS]` | Sin señal de uso requerida | Batería drenada sin interacción | Exigir screen-on o actividad foreground reciente para re-resucitar |
| P2-K04 | P2 | EngineSupervisor.kt:139-140 | Engine | isPidAlive cuenta zombies como vivos (`File("/proc/$pid").exists()` true en estado Z); InternalXvncBackend sí filtra 'Z' | `[CONFIRMADO]` | Chequeo solo de existencia | Ready falso con proceso muerto | Leer /proc/pid/stat y descartar estado Z |
| P2-K05 | P2 | WorkerClient.kt:228-240 | Worker | killWorker() deja shuttingDown=true permanente; reuso del mismo client bloquea para siempre | `[CONFIRMADO]` | Flag sin reset | Llamadores ajenos al supervisor quedan bloqueados | Reset del flag o guarda de dueño único |
| P2-K06 | P2 | MainActivity.kt:89-101 | Lifecycle | onDestroy ejecuta runBlocking (stop con wait 2s) en MAIN thread | `[CONFIRMADO]` | Teardown síncrono | ANR en kills del sistema | Shutdown async con timeout o hilo de fondo con join acotado |
| P2-K07 | P2 | services/DownloadService.kt:32 | Descargas | instanceFollowRedirects=true sin revalidar protocolo: redirect https→http burla SecurePathPolicy | `[CONFIRMADO]` | Política valida solo URL original | Downgrade de protocolo en descargas | Resolver redirects manualmente validando cada hop |
| P2-K08 | P2 | NanoshellWorkerService.kt:52-60 | Worker | Sin onDestroy cleanup: si main muere por OOM, worker queda vivo con apt a medias y daemons huérfanos | `[HIPÓTESIS]` | Falta handler | dpkg status parcial (DebInstaller.kt:576-585) | onDestroy → workerKillGroup() |
| P2-C01 | P2 | nanoroot.c:376-385 | Intercept | errno clobber: dbg_exec (fopen/fprintf) entre real_execve y chequeo de EACCES; con NANOROOT_DEBUG_EXEC=1 la cascada linker64 se salta | `[CONFIRMADO]` | errno global sin salvar | Exec muere con ENOEXEC pese a EACCES | `int saved = errno;` inmediato tras real_execve |
| P2-C02 | P2 | jni_cstr_array.c:18 | JNI | strdup sin chequeo NULL → entrada NULL en argv → truncamiento silencioso o EFAULT | `[CONFIRMADO]` | Falta validación | Crash/abort en execve | Verificar strdup; IsInstanceOf(java/lang/String) |
| P2-C03 | P2 | nanoroot.c:772 | Intercept | Comentario afirma chmod redirigido pero NO existe intercept de chmod/fchmodat | `[CONFIRMADO]` | Cobertura incompleta | Xvnc chmod en .X11-unix hardcodeado → ENOENT | Interceptar chmod/fchmodat con redirect_path |
| P2-C04 | P2 | nanoshell.c:596 | Worker | read() con -1/EINTR/EIO tratado como EOF → salida truncada | `[HIPÓTESIS]` | EINTR no distinguido | Pérdida de salida bajo señales | Distinguir EINTR (continue) de EOF real |
| P2-C05 | P2 | nanoshell.c:715-719 | Worker | fwrite/rename con rc ignorado → worker_out corrupto y .tmp huérfanos | `[CONFIRMADO]` | rc no verificado | Dart lee rc sin stdout | Verificar fwrite == out_len y rc de rename |
| P2-C06 | P2 | worker_jni.c:153 | Worker | kill(prev, SIGKILL) sobre pid ya reapeado → PID-reuse mata proceso inocente | `[HIPÓTESIS]` | Reaper corre en paralelo | Kill a proceso ajeno | waitpid(prev, WNOHANG) antes de matar |
| P2-F01 | P2 | lib/features/desktop/presentation/screens/vnc_screen.dart:201-203 | VNC | Fuga de bitmap nativo (3.7 MB) por cada "Reintentar": `_frame = null` sin dispose() | `[CONFIRMADO]` solo onFrame libera | Dispose solo en un path | Fuga nativa acumulativa en reconexiones | `_frame?.dispose(); _frame = null;` |
| P2-F02 | P2 | lib/features/chat/presentation/screens/chat_screen.dart:122-131 | Chat | Archivo adjunto completo en RAM (withData:true + readAsBytes) | `[CONFIRMADO]` | Carga eager | OOM con video/foto grande en gama baja | withData:false + ruta, o stream por chunks |
| P2-F03 | P2 | lib/core/services/runtime_engine.dart:203-206 | Engine | Doble arranque: dos ensureReady casi simultáneas disparan dos engineStart | `[HIPÓTESIS]` si Kotlin no guarda | Sin flag en vuelo | Doble spawn nativo | Flag `_startInFlight` local |
| P2-F04 | P2 | lib/core/services/runtime_engine.dart:166-186 | Engine | refresh() pisa eventos concurrentes: state capturado antes de awaits, escrito después | `[HIPÓTESIS]` | Estado snapshotteado | Evento de estado perdido | Releer state tras cada await o merge |
| P2-F05 | P2 | lib/core/providers/chat_provider.dart:371 | Chat | _streamClient compartido clobbered: finally de primera generación anula el de la segunda; stop() no cancela la segunda | `[CONFIRMADO]` | Null sin verificar identidad | Generación no cancelable | Null solo si identical(_streamClient, client) |
| P2-F06 | P2 | lib/core/providers/settings_provider.dart:124-132 | Settings | init() pisa setters ejecutados antes de load() (main.dart:48 lanza init unawaited) | `[CONFIRMADO]` | Sobrescritura sin merge | Cambio de usuario perdido | Flag _loaded; setters encolan o merge |
| P2-F07 | P2 | lib/core/providers/dashboard_provider.dart:104-115 | Dashboard | Polls solapados: Timer.periodic 3s sin reentrancy guard | `[CONFIRMADO]` | Sin flag | Dos setState en vuelo con orden indefinido | Flag _fetching |
| P2-F08 | P2 | lib/core/services/nano_runtime_api.dart:189,239,252,269,606 | API | Sin timeouts Dart en probeExec/installPackages/installGraphical/startDesktop/engineStart | `[CONFIRMADO]` | Sin deadline | UI spinner infinito si nativo cuelga (desktop_launch _busy=true eterno) | .timeout(...) con estado failed honesto |
| P2-F09 | P2 | lib/core/services/shell_executor.dart:641 | Executor | workerKill() sin taskId mata TODOS los workers | `[CONFIRMADO]` | Kill global | Un timeout cancela tareas ajenas | Kill por pid/taskId |
| P2-F10 | P2 | lib/features/terminal/real_fs_shell.dart:275-285 | Terminal | setState tras dispose en _pump (mismo patrón que terminal_core:154) | `[CONFIRMADO]` | Falta guard | Crash al morir widget a mitad de comando | Guard _alive en callback |
| P2-R01 | P2 | nanortime-ffi/src/lib.rs:845 | FFI | nucleus_sample con probs vacías: position() → None → unwrap_or(len-1) underflow → panic index-out-of-bounds en hot path que cruza extern "C" | `[CONFIRMADO]` | Sin guard de vacío | Abort del proceso | Early-return LlamaToken::new(0) si vacío |
| P2-R02 | P2 | nanortime-ffi/src/lib.rs:544 + main.rs:352 | Sesión | save_state guarda tokens vacíos; restore reinicia n_past=0 decodificando desde 0 — "salta prefill" probablemente falso | `[HIPÓTESIS]` | Estado incompleto | Re-prefill silencioso (latencia) | Retokenizar prompt y arrancar con n_past restaurado |
| P2-R03 | P2 | nanortime-cli/src/server.rs:275 | Engine | request_id interpolado en JSON sin escape → JSON injection en /cancel | `[CONFIRMADO]` | format! manual | Body corrupto | serde_json::json! |
| P2-R04 | P2 | nanortime-web/src/main.rs:188 | Web | /api/status reporta "running" sin verificar carga del modelo; /api/chat devuelve "[Error]" con HTTP 200 | `[CONFIRMADO]` | Reporte engañoso | Violación de honestidad | Estado real (cargado/fallo); error → 5xx |
| P2-R05 | P2 | nanortime-web/src/main.rs:79 | Web | NanoRuntime completo + carga GGUF por cada /api/chat (documentado 2-10s; en hardware barato peor) | `[CONFIRMADO]` | Sin singleton | Chats concurrentes = cargas concurrentes → OOM | Runtime singleton persistente |
| P2-R06 | P2 | nanortime-ffi/src/lib.rs:947 | FFI | Contrato de orden (ctx antes que modelo, sin uso concurrente) solo documentado; punteros crudos sin validación | `[HIPÓTESIS]` | Sin tabla de handles | Bug Kotlin/JNI = use-after-free nativo | Tabla de handles con generaciones o Arc |
| P2-R07 | P2 | nanortime-core/src/orchestrator/mod.rs:630 | Core | Respuestas LAN/cloud reciben `sources = rag_docs.clone()` que ese tier nunca usó | `[CONFIRMADO]` | Atribución engañosa | Cliente cree fuentes RAG falsas | Adjuntar sources solo en tier local |

> P3 (mejoras, no bloquean): ver sección 14. Resumen: probeExec timeoutRunnable sin cancelar en destroy (K), executor sin uso en AccessibilityService (K), ensureExtracted sin hash (K), poll postinst 60s sin abort temprano (K), resurrect.timestamp escrito antes de startActivity exitoso (K), DeviceMetricsChannelHandler thread por llamada (~40/min) (K), watchdog spawnBg bloqueante con stopRequested no verificado (K), nanoshell LD_PRELOAD sobrescribe previo (C), apply_rlimit_as duplicado (C), rewrite_termux_refs truncación silenciosa (C), dlclose antes de _exit (C), realpath sin des-prefijar (C, TODO 727-728), LOAD_SYM _exit(1) si dlsym falla (C), SIGPIPE en constructor nanoroot (C), jni NewByteArray sin ExceptionCheck (C), dedup spawn no atómico (C), accept loop sin backoff (R), bind panic en web (R), --preload síncrono (R), ruta experta hardcodeada (R), token vacío en EOS (R), CStr sin validación NUL (R), unsafe Sync NanoLoraAdapter (R), RwLock retenido en trabajo bloqueante (R), headers sin cap (R), request_id colisión en cancel (R), flush ignorado (R), build_android.sh NDK hardcodeado (R), log spam /health (R), boot I/O síncrono (F), _saveHistory fire-and-forget (F), _outputSub sin cancelar (F), probes solapados launcher (F), blink timer en pestañas ocultas (F), wttr.in cleartext (X), backoff 6s vs documentado (X).

---

## 3. Arquitectura encontrada (real)

```
┌─────────────────────────────────────────────────────────────────────┐
│ Flutter UI (Dart, Riverpod + go_router)                             │
│  dashboard │ chat │ terminal │ settings │ desktop(VNC)              │
└───────────┬─────────────────────────────────────────────────────────┘
            │ MethodChannel "dev.nanoai.mobile/..." (channels/*.kt)
┌───────────▼─────────────────────────────────────────────────────────┐
│ MainActivity (Kotlin)                                                │
│  ├─ EngineSupervisor        → nanortime engine (Rust) via :nanoshell │
│  ├─ NativeRuntimeSupervisor → worker lifecycle + heartbeats          │
│  ├─ RuntimeHeartbeat        → resurrección por accessibility         │
│  ├─ DesktopSessionManager   → Xvnc/openbox/tint2/feh/terminal/dbus   │
│  ├─ DebInstaller            → bootstrap rootfs (.deb, postinst)      │
│  └─ NanoshellBridge.ptySpawn → fork+dlopen EN PROCESO PRINCIPAL ⚠    │
└───────────┬─────────────────────────────────────────────────────────┘
            │ bindService (:nanoshell)
┌───────────▼─────────────────────────────────────────────────────────┐
│ NanoshellWorkerService + worker_jni.c                                │
│  spawnDetached → setsid + reaper thread (waitpid) + anti-duplicados  │
└───────────┬─────────────────────────────────────────────────────────┘
            │ LD_PRELOAD=nanoroot (intercepts execve/dlopen/shmget/...) │
┌───────────▼─────────────────────────────────────────────────────────┐
│ Linux rootfs (Termux-like): Xvnc :1 (RFB 5901 loopback)             │
│   → openbox → tint2 → lxterminal │ dbus │ feh │ apt/dpkg            │
└───────────┬─────────────────────────────────────────────────────────┘
            │ RFB 3.3/3.8 cliente propio
┌───────────▼─────────────────────────────────────────────────────────┐
│ VncClient (Dart, FSM RFB sólida)                                     │
└─────────────────────────────────────────────────────────────────────┘

Motor (Rust, 3 superficies):
  libnanortime_ffi.so (FFI desde app) │ nanortime-cli server :8080 │ nanortime-web
```

---

## 4. Flujo real de ejecución

```text
Boot: main.dart:48 init settings (unawaited)
  → BootOrchestrator: I/O síncrono (writeAsBytesSync boot_orchestrator.dart:283,325,357;
    Process.runSync chmod :402) + bootstrap DebInstaller (status→validación binarios)
  → Dashboard: Timer.periodic 3s → DeviceMetricsChannelHandler (thread nuevo por llamada)
Arranque escritorio: startDesktop (nano_runtime_api.dart:269, SIN timeout Dart)
  → XServerBackend spawnDetached Xvnc (SecurityTypes None, :135-167)
  → DesktopSessionManager: openbox/tint2/feh/terminal/dbus (spawnBg, latch 20s)
  → watchdog 5s re-lanza terminales muertas (DesktopSessionManager.kt:578-652)
  → VncClient conecta 127.0.0.1:5901 (RFB 3.3, anti-brute-force TigerVNC)
Kill ColorOS (cached-kill) → accessibility rebind → RuntimeHeartbeat resurrección
  (timestamp stale sin validación de edad, P2-K02) → ciclo kill-loop (P2-K03)
Engine: EngineSupervisor → worker spawn nanortime → server :8080 (sin auth)
  → /completion SSE; n_predict sin cap (P1-R02); thread por conexión (P1-R03)
```

---

## 5. Problemas bloqueantes (P0)

| ID | Problema | Evidencia | Cómo reproducir |
|---|---|---|---|
| P0-X01 | Release firmado con keystore debug | build.gradle.kts:66-74 fallback explícito | `./gradlew assembleRelease` sin NANOAI_KEYSTORE |
| P0-X02 | tint2 segfault bajo nanoroot | Reproducido aislado: `timeout 6 env LD_PRELOAD=... tint2` con `image-x-generic.svg` → EXIT=139 | Arrancar desktop con panel activo en ColorOS |

---

## 6. Problemas críticos (P1)

Ver tabla maestra: P1-K01, P1-K02, P1-C01..C04, P1-F01, P1-F02, P1-SEC01..SEC04, P1-R01..R03.

Agrupados por tema de solución:

**Cuelgues permanentes (fix mecánico, alto valor):**
- P1-K01 reordenar timeout en probeExec.
- P1-F01 Completer en shell_executor (verificado empíricamente, el más grave de Dart).
- P1-C01 waitpid acotado en nanoshell.

**Compatibilidad ColorOS (requisito del device, no opcional):**
- P1-C03 eliminar fork+dlopen del proceso principal (evidencia documentada de crash Mali).
- P1-C04 completar familia shm* (SIGSYS).
- P2-C03 chmod/fchmodat (Xvnc .X11-unix).

**Seguridad en loopback compartido Android:**
- P1-SEC01..03: VncAuth por defecto, token en engine, bind 127.0.0.1.

**Integridad del bootstrap:**
- P1-SEC04 path traversal en instalador.

**Motor que no aborte la app:**
- P1-R01 panic → degradación 503.

---

## 7. Compatibilidad

| Componente | Versión | Estado | Nota |
|---|---|---|---|
| compileSdk/targetSdk | 36 | COMPATIBLE | Requisito Play 31-ago-2026 cumplido |
| minSdk | 26 | COMPATIBLE | Linker namespaces requieren 24+ |
| NDK | 28.2.13676358 | RIESGO | `System.load` de libs writable: SDK 35 advierte, SDK 36 podría volverse throw; ~70 preloads por spawn (K-2) |
| Gradle / AGP | 8.14 / 8.11.1 | COMPATIBLE | — |
| Kotlin | 2.2.20 | RIESGO | `kotlinOptions` deprecated; migración a compilerOptions pendiente |
| Java | 17 | COMPATIBLE | — |
| Dart / Flutter | >=3.10.3 / 3.38.4 | COMPATIBLE | — |
| ABI | arm64-v8a solo | COMPATIBLE | Intencional (rootfs aarch64) |
| assets/bin/nanortime | 15.2 MiB, ELF PIE aarch64 | COMPATIBLE | Not stripped |
| extractNativeLibs | "true" | RIESGO | Plan pedía false previa verificación de dlopen — pendiente |
| Keystore release | debug fallback | INCOMPATIBLE | P0-X01 |
| READ_EXTERNAL_STORAGE | maxSdk 32 | COMPATIBLE | Correctamente acotado; en 13+ pcmanfm no ve archivos no-media (limitación no documentada) |
| Accessibility | Declarado correcto (BIND + config XML) | COMPATIBLE | Es el vector de resurrección U-10, verificado en device |
| Seccomp ColorOS | shmget cubierto; shmat/shmctl/shmdt NO | INCOMPATIBLE | P1-C04 |

---

## 8. Auditoría JNI/C++

Confirmado correcto: intercept `shmget→ENOSYS` (nanoroot.c:761-765), dlsym lazy de `real_execve` (fix SIGSEGV pc=0), cascada execve→linker64→dlopen con frees correctos de argv reescrito en ambos retornos.

Hallazgos: P1-C01..C04, P2-C01..C06 + P3 listados. Riesgo transversal: PID-reuse en kills (P2-C06, pty_session_registry.c:84, pty.c:257) — patrón repetido en 3 archivos, fix centralizable: helper `kill_if_alive(pid)` con `kill(pid,0)` + waitpid(WNOHANG).

---

## 9. Auditoría Linux/Android

- Linux corre en rootfs Termux-like vía :nanoshell con setsid + LD_PRELOAD=nanoroot. Limitación estructural: nanoroot reescribe paths pero readlink/realpath sin des-prefijar (TODO nanoroot.c:727-728) — causa probable del segfault de librsvg/tint2 (P0-X02).
- Loopback Android es compartido entre procesos: todo lo que escuche en 127.0.0.1 debe autenticarse (P1-SEC01..03).
- ColorOS cached-kill manejado con resurrección por accessibility (funciona, verificado SIGKILL en device) pero con stale heartbeat (P2-K02) y riesgo de kill-loop (P2-K03).
- Foreground service: bind-only intencional (exención accessibility). Sin BOOT_COMPLETED ni FGS types — coherente, documentar.

---

## 10. Auditoría de procesos

| Proceso | Owner | PID lifecycle | Inicia | Detiene | Wait | Riesgo zombie |
|---|---|---|---|---|---|---|
| nanortime engine | EngineSupervisor.handle | spawnDetached→worker | EngineSupervisor:198 | stop() SIGTERM→SIGKILL | reaper C worker | Bajo; orphan real en raza P1-K02 |
| Xvnc | InternalXvncBackend.xvncPid | spawnDetached→worker | XServerBackend:196 | killProcess + killLingering | reaper C | Bajo; huérfano transitorio si spawn en vuelo durante stop |
| openbox/tint2/feh/terminal/dbus | DesktopSessionManager pids | spawnDetached→worker | DSM:320-374 | cleanupProcesses | reaper C | Bajo; re-lanzados por watchdog; raza stop→respawn (P3) |
| probeExec | JVM Process | execve directo | ExecBinChannelHandler:107 | destroyForcibly en timeout | JVM reaper | ALTO: timeout nunca corre (P1-K01) |
| postinst (apt) | worker thread | MSG_SPAWN | DebInstaller:746 | MSG_KILL kill(-pgid) | waitpid worker | Bajo; apt colgado bloquea reaper |
| ptySpawn | libnanoshell (proceso principal) | fork+dlopen app | NanoshellBridge:42 | ptyIsAlive | C | P1-C03 crash Mali |

---

## 11. Auditoría de memoria

| Heap | Hallazgo |
|---|---|
| Dart | `ui.Image` VNC: 1 fuga por "Reintentar" (P2-F01, 3.7 MB nativos/vez); decode 3.7 MB en isolate UI (VNC-DEC-1 pendiente, hang 59s documentado); archivo adjunto completo en RAM (P2-F02) |
| Java/Kotlin | AccessibilityNodeInfo sin recycle (P2-K01, hasta 800 nodos/llamada); postDelayed 1.5s retiene activity (benigno) |
| Native C | strdup sin chequeo (P2-C02); kill de pid reapeado (P2-C06); sin leak clásico flagrante |
| mmap/GPU | BLASTBufferQueue "max frames 4" es síntoma del P0 río arriba — no tocar |
| Rootfs/procesos | Orphan del motor (P1-K02); zombie probeExec (P1-K01); worker huérfano sin onDestroy (P2-K08) |

---

## 12. Auditoría de rendimiento

Cuellos demostrados (no especulativos):
- probeExec/zombie: comando colgado = hilo + proceso retenidos indefinidamente (P1-K01).
- shell_executor: Future colgado por comando con timeout (P1-F01).
- decode VNC en isolate UI: hang 59s documentado (informe 08-12, sin evidencia de fix).
- I/O síncrono en boot: writeAsBytesSync/Process.runSync en main isolate (boot_orchestrator.dart:283-402).
- Thread-per-connection + SSE sin write timeout en server Rust (P1-R03).
- NanoRuntime recargado por request en web (P2-R05, OOM con chats concurrentes).
- DeviceMetricsChannelHandler: thread nuevo por llamada, ~40/min (P3).

---

## 13. Auditoría de logs

Fuente: docs/audit + commits (no existe logcat.txt en git). Errores reales conocidos:

| Error | Estado |
|---|---|
| SIGSYS seccomp 194 (shmget) matando lxterminal, crash-loop tombstones | Fix aplicado (commit 08d40ff) — incompleto: falta shmat/shmctl/shmdt (P1-C04) |
| `No Imlib2 loader` (dlopen imlib2) | Fix intercept dlopen (5d897b6) |
| SIGSEGV pc=0 en aterm (real_execve NULL) | Fix dlsym lazy |
| `XKB: Failed to compile keymap` off-by-one xkbcomp | Fix aplicado |
| `Unknown msg type: 24` + `Encoding 39173` (VNC) | Fix _end descrito, 100% repro previo |
| `TimeoutException: decodeImageFromPixels` 59s | PENDIENTE (VNC-DEC-1) |
| `Blacklisted: 127.0.0.1` anti-brute-force | Fix RFB 3.3 verificado |
| tint2 EXIT=139 librsvg bajo nanoroot | PENDIENTE (P0-X02) — falta backtrace |
| Xvnc release muere ~2ms tras spawn | HIPÓTESIS H4 sin confirmar: NANO_ROOTFS ausente en env del spawn release |
| reaper `status=0` para segfault 139 | PENDIENTE: WEXITSTATUS sin WIFSIGNALED (H3) |
| `LOGS OVER PROC QUOTA, rows DROPPED` | ~50 WARN por spawn; mitigar con resumen 1 línea (NanoshellWorkerService.kt:228-231) |

---

## 14. Código duplicado y deuda técnica

Duplicados reales (P3, fuera de tests):
- Mapeo F1-F12 + keyLabel: `keyboard_mapper.dart:18-92` vs `terminal_core.dart:836-885` — extraer a helper único.
- `_Glow`: dashboard_screen.dart:569-581 vs nano_screen_shell.dart:109-121 — mover a core/widgets.
- Parse gpuLoad: device_info.dart:164-166 vs hardware_info_service.dart:66-68.
- `stream()`: i_bin_executor.dart:54 vs shell_executor.dart:233.
- `startDesktop`: nano_runtime_api.dart:269 vs package_service.dart:87.
- Setup repetido en integration tests (extractable a helper).

Deuda: god-files vnc_screen.dart (1912 líneas, 105 ramas), DebInstaller.kt (107 ramas), terminal_core.dart (201 ramas), nanoroot.c (145 ramas), nanoshell.c (135), real_fs_shell.dart (135), ansi_parser.dart (117). Estrategia: no refactor masivo; descomponer solo al tocar cada archivo por hallazgo vinculado.

---

## 15. Funciones faltantes/incompletas

- nanoroot: intercepts faltantes chmod/fchmodat/symlink/link/utimensat (P2-C03, sprint C-4/C-5 sin cierre); realpath sin des-prefijar (TODO 727-728).
- Descarga de modelos: verificación de integridad/checksum vive en Flutter (model_downloader.dart) — sin auditar en este pase; el Rust solo asume GGUF presente (falla honesto con ModelNotFound).
- MVP motor: B6 e2e parcial (MVP 2/15/16/17) — device OPPO cayó del ADB; retest con instrumentación pendiente.
- Testing: no hay tests de nanoroot intercepts ni de DebInstaller edge cases.

---

## 16. Matriz SOLID

| Principio | Estado | Dónde | Corrección |
|---|---|---|---|
| SRP | Viola | vnc_screen.dart (UI+FSM+toolbar+auth en 1912 líneas); DesktopSessionManager (spawn+watchdog+estado) | Extraer VncToolbar/VncOverlay; separar watchdog |
| OCP | Cumple | Intercepts nanoroot por tabla de syscalls | Mantener tabla extensible |
| LSP | Cumple | IBinExecutor/shell_executor | — |
| ISP | Viola | nano_runtime_api.dart: interfaz monolítica con métodos sin timeout coherente | Agrupar por dominio con deadlines |
| DIP | Cumple | Providers Riverpod + servicios inyectados | — |

---

## 17. Plan de corrección por fases

Principio rector: **cada cambio vincula un ID de hallazgo**. Nada de refactor estético. Probar en device real ColorOS antes de declarar cerrado.

### FASE 0 — Estabilización de cuelgues (P1-K01, P1-F01, P1-C01, P1-C02, P1-F02, P2-F10, P1-K02)
- Archivos: ExecBinChannelHandler.kt, shell_executor.dart, nanoshell.c, worker_jni.c, terminal_core.dart, real_fs_shell.dart, EngineSupervisor.kt
- Permitido: reordenar timeout; Completer en stream(); waitpid acotado; guards de null; guards _alive; kill en mismatch de generación
- Prohibido: cambiar protocolo del canal o semántica de spawn
- Criterio salida: `flutter test` verde + prueba en device: comando con timeout sale en ~30s sin colgar UI
- Rollback: revert por archivo (fixes independientes)

### FASE 1 — Compatibilidad ColorOS (P1-C03, P1-C04, P2-C03, P0-X02, H3, H4)
- Archivos: nanoroot.c, pty.c, NanoshellBridge.kt, PtyChannelHandler.kt, nanoshell.c (reaper WIFSIGNALED), XServerBackend.kt (env NANO_ROOTFS release)
- Permitido: intercepts nuevos (shmat/shmctl/shmdt/chmod/fchmodat con redirect_path); rutear ptySpawn por worker o desactivar canal; backtrace tint2 con gdb
- Prohibido: tocar la cascada execve→linker64 ya verificada
- Riesgo: intercept de shmat puede romper apps que SÍ usan shm vía shmget exitoso — interceptar solo el fallo de seccomp, no el éxito
- Criterio salida: `timeout 6 env LD_PRELOAD=... tint2` sin EXIT=139; tombstones shm* = 0 en 30 min de desktop

### FASE 2 — Seguridad de red (P1-SEC01..04, P1-R03, P2-K07)
- Archivos: XServerBackend.kt (VncAuth default), EngineSupervisor.kt (token), nanortime-cli platform.rs/server.rs (bind 127.0.0.1, CORS), TarExtractor/zip/postinst (pathPolicy), DownloadService.kt
- Permitido: auth por password aleatorio mostrado al usuario; token por header; validar redirects hop a hop
- Prohibido: romper el flujo de auto-conexión VNC (el cliente Dart debe leer el password generado)
- Criterio salida: `adb shell` otra app conecta a 5901 y recibe auth challenge; /completion sin token → 401

### FASE 3 — Motor Rust (P1-R01, P1-R02, P2-R01..R07)
- Archivos: nanortime-ffi/src/lib.rs, nanortime-cli/src/server.rs, nanortime-web/src/main.rs, nanortime-core/orchestrator
- Permitido: Result en OnceLock; caps server-side; serde_json; singleton web; guard de probs vacías
- Prohibido: cambiar contrato FFI público sin versión
- Criterio salida: init con backend ausente → error propagado (no abort); /api/chat con n_predict 10^12 → 4xx

### FASE 4 — Flutter lifecycle y estado (P2-F01..F10)
- Archivos: vnc_screen.dart, chat_screen.dart, runtime_engine.dart, chat_provider.dart, settings_provider.dart, dashboard_provider.dart, nano_runtime_api.dart, pty_manager.dart, desktop_launch_screen.dart
- Permitido: dispose en reintento; flags reentrancy; timeouts Dart; guards mounted
- Criterio salida: 10 reconexiones VNC sin crecimiento de memoria nativa (dumpsys meminfo)

### FASE 5 — Deuda y rendimiento (P3 + sección 12)
- Archivos: boot_orchestrator.dart (Isolate.run), ansi_terminal.dart (TickerMode), DeviceMetricsChannelHandler.kt (executor), duplicados sección 14
- Criterio salida: boot sin jank medible (frame timings)

### FASE 6 — Release (P0-X01, extractNativeLibs, SDK 36 writable libs)
- Archivos: build.gradle.kts, CI
- Permitido: keystore producción con secretos; verificar dlopen antes de extractNativeLibs=false
- Criterio salida: `assembleRelease` firmado con keystore propio; aapt dump verifica firma

Orden de ejecución sugerido: FASE 0 → FASE 1 → FASE 2 (seguridad en loopback es barata) → FASE 3 → FASE 4 → FASE 6 (desbloquea publicación) → FASE 5.

---

## Separación obligatoria

1. **Problemas demostrados**: tabla maestra [CONFIRMADO] + P0-X02 reproducido.
2. **Hipótesis**: marcadas [HIPÓTESIS] — requieren log/backtrace en device (H4 Xvnc release, P1-C01, P1-C03).
3. **Mejoras opcionales**: P3 listados en sección 14.

Nada se aplica sin aprobación. Próximo paso sugerido: FASE 0 (6 archivos, fixes mecánicos e independientes).
