# Auditoría Técnica Integral — Plataforma nanoMOBILE

**Fecha:** 2026-08-13
**Alcance:** `products/nanoMOBILE/flutter_app` — Flutter + Android nativo (Kotlin/JNI/C) + runtime Linux estilo Termux
**Método:** 4 agentes de auditoría por dominio + escaneos determinísticos MCP + verificación directa de evidencia (git check-ignore, grep de referencias, diffs)

---

## 1. Resumen ejecutivo

| Área | Estado | Detalle |
|---|---|---|
| Estado general | **Funcional en device, no listo para Play** | Runtime completo verificado en hardware real; brechas de empaquetado y release |
| Build | **P0 corregido** | `.gitignore` ignoraba `lib/features/desktop/` (build roto desde clon limpio); archivos untracked referenciados por código |
| Android runtime | **P1 corregido** | targetSdk 35→36 (obligatorio Play 31-ago-2026); permisos sin uso eliminados; `allowBackup=false` |
| Flutter | **P2 corregidos** | Timers acumulados, `_cron` nunca disposed, `_ansi` dispuesto tras fin de sesión, UTF-16→PTY, writes concurrentes de settings |
| C/C++/JNI | **P1 corregidos** | `setsid()` real en daemons detached; reaping de hijos PTY (kill pgroup + waitpid WNOHANG) |
| Linux/rootfs | **Estable** | Entorno Termux + nanoroot LD_PRELOAD verificado; env GTK unificado (terminal ahora alineado con desktop) |
| Procesos | **Estable** | Watchdog con re-lanzamiento de openbox/tint2/feh; sin zombies pendientes |
| Memoria | **Sin evidencia de leak activo** | Ver revisión: reparación de accumulación de timers Dart (fuga lenta) |
| Rendimiento | **Aceptable** | Métricas en hilo fondo; preload de libs acotado a set crítico |
| Conectividad | **Estable** | TigerVNC con anti-brute-force por `/proc/<pid>/stat` (no TCP probes) |
| Seguridad | **P2 fail-closed aplicado** | Kali: sin SHA256 configurado se aborta la instalación; quedan tareas de release (keystore) |
| Mantenibilidad | **Mejora continua** | RootfsEnv centralizado; threads nombrados; imports sin duplicados |

**Veredicto:** el producto funciona de extremo a extremo en device (terminal PTY, escritorio VNC con openbox/tint2/feh, apt, apps GTK). Lo que falta para producción no es funcionalidad sino **release engineering**: keystore de producción, icono, CI, pruebas, y una validación de hipótesis en device (fork+dlopen en proceso principal).

---

## 2. Tabla maestra de hallazgos

Leyenda estado: ✅ Aplicado en esta sesión · ⏳ Pendiente (diferido con justificación) · 🔵 Preexistente verificado (fix previo del equipo)

| ID | Prioridad | Archivo | Componente | Error | Evidencia | Causa raíz | Impacto | Solución | Estado |
|---|---|---|---|---|---|---|---|---|---|
| A-01 | P0 | `.gitignore:47` (raíz repo) | Build/repo | Regla `desktop/` ignoraba `lib/features/desktop/` entera | `git check-ignore -v lib/features/desktop/vnc_client.dart` | Patrón sin ancla `/` aplica a cualquier nivel | Build roto desde clon limpio (pantalla desktop ausente) | `/desktop/` anclado a raíz | ✅ |
| A-02 | P0 | `AgentChannelHandler.kt`, `AgentAccessibilityService.kt`, `accessibility_service_config.xml`, `assets/exe/hud.py`, `assets/exe/nano-wallpaper.png`, `lib/features/desktop/` | Build/repo | Archivos referenciados por código sin commitear | `git status --porcelain` muestra `??`; `MainActivity.kt:10` importa AgentChannelHandler | Workflow sin `git add` de archivos nuevos | Build roto desde clon limpio | `git add` + commit | ✅ |
| A-03 | P1 | `android/app/build.gradle.kts` | Gradle/Play | targetSdk 35 | Inspección directa | Sin actualizar tras requisito Play | Rechazo en Play a partir de 31-ago-2026 | `targetSdk = 36` | ✅ |
| A-04 | P1 | `AndroidManifest.xml` | Play/seguridad | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `WAKE_LOCK` declarados sin uso; `allowBackup` default true | Inspección directa; grep sin usos | Declaraciones heredadas de plantilla | Escrutinio Play; backup de datos de app sin cifrar | Eliminar permisos; `allowBackup="false"` | ✅ |
| A-05 | P1 | `build.gradle.kts` signingConfig | Release | APK release firmado con certificado debug | Inspección del bloque signing | Fallback debug para desarrollo | Imposible actualizar app en Play (mismo certificado requerido de por vida) | Keystore de producción del usuario | ⏳ (requiere input del usuario: contraseñas) |
| A-06 | P1 | `terminal_core.dart:202-205` | Flutter/PTY | PtyManager sin `onSessionEnd` → `_ansi` apuntaba a ChangeNotifier dispuesto | Lectura de `pty_manager.dart:213-221` (dispose diferido a post-frame) | Callback no cableado | Crash "used after being disposed" al rebuild tras Ctrl-D/exit | Cablear `onSessionEnd` → `setState(_ansi = null)` | ✅ |
| A-07 | P1 | `DesktopSessionManager.kt` | Desktop | `fehPid` no trackeado; wallpaper huérfano | Inspección: spawn sin guardar PID; cleanupProcesses no lo mataba | Campo no añadido al añadir feh | feh vivo tras cierre de sesión + watchdog no lo relanzaba | Campo `@Volatile fehPid` + kill + watchdog | ✅ |
| A-08 | P1 | `DesktopSessionManager.kt` | Desktop | `startInternal` sin try/catch: excepción dejaba `starting=true` | Inspección del flujo de excepción | Sin wrapper de error | Estado stuck, sin onError al usuario | Wrapper → `startInternalImpl` con cleanup + onError | ✅ |
| A-09 | P1 | `XServerBackend.kt` | Desktop | `xvncPid` sin `@Volatile` | Inspección | Race watchdog/hilo de spawn | Lectura stale del PID | `@Volatile` | ✅ |
| A-10 | P1 | `ExecBinChannelHandler.kt` | Desktop | `probeExec` sin timeout | Inspección: `p.waitFor()` sin límite | Binario colgado | Hilo de arranque de desktop colgado indefinido | `waitFor(30, SECONDS)` + destroyForcibly | ✅ |
| A-11 | P1 | `ExecBinChannelHandler.kt` | Desktop | Race onReady/onError/timeout con Boolean plano | Inspección | Estado compartido sin atomicidad | Doble callback (VNC abierto 2 veces, estado corrupto) | `AtomicBoolean.compareAndSet` | ✅ |
| A-12 | P1 | `MainActivity.kt` | Android lifecycle | `pendingStorageResult` sin resolver en onDestroy | Inspección | Callback de permisos nunca llega si Activity muere | Future Dart colgado para siempre | Resolver con error `activity_destroyed` en onDestroy | ✅ |
| A-13 | P1 | `DeviceMetricsChannelHandler.kt` | Android/rendimiento | getMetrics/getDeviceIdentity sync en main thread | Inspección | Handler de canal ejecutado en main | Jank cada 3s (poll del dashboard) | Hilos `metrics-fetch`/`metrics-identity` | ✅ |
| A-14 | P1 | `nanoshell.c` (`nanoshell_worker_spawn_detached`) | C/procesos | Daemons detached sin `setsid()` real — vivían en el pgroup del worker | Inspección del código C; comentario Kotlin (`NanoshellWorkerService.kt:141-143`) que lo afirmaba era FALSO | Función sin llamada al sistema | `workerKillGroup` mataba Xvnc/openbox al matar el worker (pantalla negra en kill switch) | `setsid()` real en child + log warning | ✅ |
| A-15 | P1 | `pty_session_registry.c` | C/procesos | Hijos PTY sin reaping: zombies acumulados | Inspección: close liberaba slot sin waitpid | Falta de harvest | Zombies por sesión PTY cerrada | kill(-child, SIGHUP/SIGKILL) + loop waitpid WNOHANG | ✅ |
| A-16 | P1 | `lib/core/services/pty_shell.dart` | Flutter/FFI | `ptySpawn` (fork+dlopen) en proceso principal con GPU Mali/Impeller | Hipótesis con precedente: worker existe porque fork en principal SIGSEGV (documentado en `NanoshellWorkerService.kt:14-18`) | Arquitectura histórica | **HIPÓTESIS A VALIDAR**: SIGSEGV al usar PTY nativo en ciertos devices | Validar en device; si crashea, mover ptySpawn al worker | ⏳ |
| A-17 | P2 | `terminal_core.dart:143` | Flutter/timers | `_after` acumulaba Timers muertos en `_timers` | Inspección: remove nunca llamado | Olvido en callback | Fuga lenta en sesiones largas (htop/relojes) | `_timers.remove(t)` al disparar | ✅ |
| A-18 | P2 | `terminal_core.dart:289-290` | Flutter/timers | `CronScheduler` inline sin guardar: `dispose()` (existente) nunca llamado | Grep: cero callers de `CronScheduler.dispose` | Instancia no retenida | Timers de crontab/watch vivos tras cerrar terminal | Campo `_cron` + dispose | ✅ |
| A-19 | P2 | `command_executor.dart:141` | Flutter/PTY | `[...cmd.codeUnits, 0x0d]` — UTF-16 crudo al PTY | Inspección | Asumir ASCII | Comandos con acentos/emoji corruptos | `utf8.encode(cmd)` + CR | ✅ |
| A-20 | P2 | `keyboard_mapper.dart:74` | Flutter/PTY | `return [ch]` con codeUnit >0x7F | Inspección (fallback keyLabel sin límite superior) | Asumir ASCII | Byte suelto inválido al PTY (teclados locales) | Codificar UTF-8 si >0x7F | ✅ |
| A-21 | P2 | `settings_provider.dart:136-139` | Flutter/persistencia | `_persist` sin try/catch y writes concurrentes | Inspección: setters lanzan save() sin esperar | Sin serialización | Ráfaga de sliders persistía estado viejo; fallo de disco crasheaba UI | Cola FIFO + try/catch justificado | ✅ |
| A-22 | P2 | `kali_manager.dart:24` | Seguridad | `expectedSha256 = ''` saltaba verificación de integridad | Inspección: rama `if (expectedSha256.isNotEmpty) ... else skip` | Placeholder sin hash real | Rootfs de ~200MB por HTTP sin verificar: suministro comprometido posible | **Fail-closed**: sin hash se aborta la instalación | ✅ |
| A-23 | P2 | `device_metrics.dart:6` | Flutter | `static bool _available` cacheaba fallo transitorio permanente | Inspección: set false sin reset | Asumir fallo permanente | Dashboard a ceros hasta reiniciar app (fallo al arranque en frío) | Sin cache: cada fetch reintenta | ✅ |
| A-24 | P2 | `plugins/system_plugin.dart:130-131` | Flutter/terminal | Handler `type` vacío; `which` sí delegado a realCommands pero `type` NO está en realCommands | Grep `realCommands` en `terminal_types.dart:17`: sin `'type'` | Asumir delegación que no existe | `type <cmd>` moría en silencio (éxito falso) | Implementar `type` real (realCommands/alias/env) | ✅ |
| A-25 | P2 | `rootfs_env.dart` | Linux/env | Faltaban `GSETTINGS_SCHEMA_DIR`, `GIO_EXTRA_MODULES`, `XDG_DATA_DIRS`, `XDG_RUNTIME_DIR` | Contraste con `DesktopSessionManager.kt:89-96` (mismas vars con evidencia device 2026-08-12) | Env centralizado sin el bloque GTK | Apps GTK lanzadas desde PTY morían como en el desktop pre-fix | Añadir las 4 vars | ✅ |
| A-26 | P2 | `expression_evaluator.dart` | Flutter/terminal | `expr "1+"`, `"()"`, `"2/0"` lanzaban FormatException/UnsupportedError | Lectura del parser | Parser sin guardas | Crash del dispatch en input malformado | try/catch documentado + `_parseTerm` con token vacío y paréntesis sin cerrar | ✅ |
| A-27 | P2 | `command_executor.dart:296-319` | Flutter/terminal | Fallback silencioso rc=127 → ejecutar en host | Inspección | Sin alternativa al rootfs | Comando falla en rootfs y se ejecuta fuera — semántica engañosa | Fallback honesto: stderr del rootfs tal cual, sin host fallback (campos runRealSync/realOut eliminados) | ✅ |
| A-28 | P2 | FFI (`nanoshell.dart`-style) | Flutter/FFI | Llamadas FFI bloqueantes en UI isolate | Inspección de call sites | Sin isolate dedicado | Jank bajo carga (tar, apt) | `Isolate.run` en `_execBusyBox`/`execRootfs` + `seedAllowed` (allowlist no cruza isolates; lastError capturado dentro del closure) | ✅ |
| A-29 | P2 | `docker` command | Terminal | `docker stop` no real (sin implementación) | Inspección del handler | Scope | `docker ps` funciona, stop no — expectativa rota | `trackTag: docker:<id>` → `ShellExecutor.killTracked` (SIGTERM + SIGKILL a 2s); guard del estado `stopped` en run | ✅ |
| A-30 | P2 | AndroidManifest `<queries>` | Android | Sin `<queries>` para `launchPackage` | Inspección del manifest | Paquete no declarado | `launchPackage` silenciosamente falla en Android 11+ | `<queries>` MAIN/LAUNCHER (caso permitido por Play sin QUERY_ALL_PACKAGES) | ✅ |
| A-31 | P3 | `ansi_parser.dart:82` | Flutter/terminal | 0x7F (DEL) caía al buffer y dibujaba glifo fantasma | Inspección: `ch >= 0x20` admite 0x7F | Switch sin case DEL | Basura visual con teclas kbs=^? | Case 0x7F → backspace (VT100 clásico) | ✅ |
| A-32 | P3 | App icon | Release | Icono genérico | Inspección de recursos | No priorizado | Presentación Play pobre | Generar icono + adaptive icon | ⏳ |
| A-33 | P3 | CI | Release | Sin workflow de build/test | Inspección de `.github/` | No configurado | Sin regresión automática | GitHub Actions: analyze + test + assembleDebug | ⏳ |

---

## 3. Arquitectura encontrada (real)

```text
┌─────────────────────────── Proceso principal (Flutter, CON GPU) ───────────────────────────┐
│  Flutter UI (dashboard / terminal / desktop / settings)                                    │
│    ├─ lib/features/terminal/  Terminal ANSI propio + PTY (pty_manager, terminal_core)      │
│    ├─ lib/features/desktop/   Cliente VNC (vnc_client, vnc_des) + pantallas                │
│    └─ lib/core/               services (nano_runtime_api, rootfs_env, package_service...)  │
│  MethodChannels → Kotlin handlers (ExecBin, Runtime, PTY, DeviceMetrics, Agent)            │
│    ├─ DesktopSessionManager: Xvnc + openbox + tint2 + feh + aterm (via worker detached)    │
│    ├─ DebInstaller / PackageService: dpkg/apt via worker                                    │
│    └─ NativeRuntimeSupervisor: arranque apagado ordenado del worker                        │
└────────────────────────────────────────────────────────────────────────────────────────────┘
                              │ Binder (Messenger)
┌─────────────────────────── Worker `:nanoshell` (SIN GPU) ──────────────────────────────────┐
│  NanoshellWorkerService + libnanoshell.so (C): fork+dlopen seguro                           │
│    ├─ workerSpawn: apt/dpkg/tar (fork + waitpid, stdout→files/)                            │
│    └─ workerSpawnDetached: Xvnc/openbox/tint2/feh (setsid() → pgroup propio)               │
└────────────────────────────────────────────────────────────────────────────────────────────┘
                              │ execve/dlopen sobre rootfs
┌─────────────────────────────── Rootfs Termux (files/nano/) ────────────────────────────────┐
│  usr/bin (bash, Xvnc, openbox, tint2, feh, aterm, apt...) + usr/lib (300+ .so)             │
│  nanoroot (LD_PRELOAD): redirección de rutas hardcodeadas (NANO_ROOTFS)                    │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

Decisiones de diseño verificadas (no refactorizadas — correctas):
- **Worker separado**: fork()+dlopen() en el proceso principal crashea siempre (SIGSEGV — driver Mali/Impeller heredado inconsistente; evidencia device documentada en `NanoshellWorkerService.kt:14-18`).
- **setsid() en daemons** (ahora real en C): el kill switch del worker mata solo tareas propias, no el desktop.
- **Ready ≠ PID**: TigerVNC anti-brute-force prohíbe probes TCP; readiness vía `/proc/<pid>/stat` + socket X11 + ventana de estabilidad 2s.

## 4. Flujo real de ejecución

```text
App fría
  └─ MainActivity.onCreate (MainActivity.kt:44)
       └─ postDelayed 1.5s → NativeRuntimeSupervisor.start()
            └─ bind worker :nanoshell (NanoshellWorkerService)
                 ├─ loadLibrary("nanoshell")
                 └─ Messenger listo
  └─ Dashboard (lib/main.dart → features/dashboard)

Usuario abre Terminal
  └─ TerminalCore._buildRegistry (terminal_core.dart:202)
       ├─ PtyManager(rootfs, rootfsEnv, onTitle, onSessionEnd)     ← A-06
       ├─ plugins + realCommands + CronScheduler (guardado: A-18)  ← A-17/A-18
       └─ comando "!" → Nanoshell FFI → workerSpawn (worker, sin GPU)
            └─ fork + dlopen → execve en rootfs → stdout a files/ → stream al UI

Usuario abre Desktop
  └─ ExecBinChannelHandler.handleStartDesktop (AtomicBoolean: A-11)
       ├─ probeExec con timeout 30s (A-10)
       ├─ killLingeringXvnc por uid+cmdline (K-1 EADDRINUSE)
       └─ DesktopSessionManager.startInternalImpl (try/catch: A-08)
            └─ XServerBackend.start: workerSpawnDetached(Xvnc)  [setsid: A-14]
                 └─ readiness: /proc/<pid>/stat + socket X11 + 2s estabilidad
            └─ wmEnv (GSETTINGS/GIO/XDG) → openbox, tint2, feh (fehPid: A-07)
            └─ watchdog: relanza openbox/tint2/feh si /proc/<pid> ausente
  └─ VncClient (lib/features/desktop/vnc_client.dart) conecta RFB 5901

Usuario cierra terminal (Ctrl-D / exit)
  └─ PtyManager.onSessionEnd → _ansi = null (A-06)
  └─ TerminalCore.dispose → _timers + _cron.dispose (A-17/A-18)

App muere
  └─ MainActivity.onDestroy (MainActivity.kt:71)
       ├─ pendingStorageResult resuelto con error (A-12)
       └─ supervisor.shutdown → DesktopSessionManager.cleanupProcesses
            └─ Xvnc + openbox + tint2 + feh (A-07) + worker stopSelf
```

## 5. Problemas bloqueantes (P0)

Ambos corregidos en esta sesión:

1. **A-01** — `.gitignore` rompía el build desde clon limpio: `desktop/` → `/desktop/`.
2. **A-02** — Archivos untracked referenciados por código (AgentChannelHandler, assets del desktop, `lib/features/desktop/`): añadidos al control de versiones en este commit.

Sin estos dos, `flutter build apk` desde un clon limpio no compilaba: faltaba la pantalla de desktop y los handlers de agente.

## 6. Problemas críticos (P1)

| ID | Fix aplicado | Cómo verificar |
|---|---|---|
| A-03 targetSdk 36 | ✅ | `./gradlew assembleDebug` compila; subir bundle a Play antes de 31-ago-2026 |
| A-04 permisos + allowBackup | ✅ | `aapt dump permissions app-debug.apk` — sin FOREGROUND_SERVICE ni WAKE_LOCK |
| A-05 keystore release | ⏳ | **Bloquea publicación**: generar keystore con el usuario (contraseñas) y configurar `NANOAI_KEYSTORE*` |
| A-06 onSessionEnd | ✅ | Ctrl-D en PTY + volver a pantalla terminal: sin crash "used after being disposed" |
| A-07 fehPid | ✅ | Cerrar desktop: `ps -A \| grep feh` vacío; abrir de nuevo: wallpaper presente |
| A-08 startInternal try/catch | ✅ | Forzar fallo de Xvnc (puerto ocupado): onError llega, stage="failed", no queda stuck |
| A-09 @Volatile xvncPid | ✅ | Arrancar/parar desktop repetido: watchdog no lee PID stale |
| A-10 probeExec timeout | ✅ | Binario colgado: arranque de desktop no queda colgado >30s |
| A-11 AtomicBoolean | ✅ | Doble tap rápido en "abrir desktop": un solo onReady |
| A-12 pendingStorageResult | ✅ | Girar pantalla/destruir Activity con diálogo de permisos abierto: sin Future colgado |
| A-13 métricas en hilo | ✅ | `adb shell dumpsys gfxinfo` / perfil: sin jank cada 3s en dashboard |
| A-14 setsid real | ✅ | Kill switch del worker: desktop (Xvnc) sigue vivo, tareas propias mueren |
| A-15 reaping PTY | ✅ | N sesiones PTY cerradas: `ps` sin zombies de bash/aterm |
| A-16 ptySpawn en principal | ⏳ HIPÓTESIS A VALIDAR | Probar PTY nativo en device con GPU Mali; si SIGSEGV, migrar spawn al worker |

## 7. Compatibilidad

| Componente | Versión | Estado |
|---|---|---|
| compileSdk | 36 | ✅ |
| targetSdk | 36 (era 35) | ✅ **corregido** — requisito Play a partir de 31-ago-2026 |
| minSdk | 26 (Android 8.0) | ✅ |
| NDK | 28.2.13676358 | ✅ |
| Gradle | 8.14 | ✅ |
| AGP | 8.11.1 | ✅ |
| Kotlin | 2.2.20 | ✅ |
| Java | 17 | ✅ |
| Flutter | 3.38.4 | ✅ |
| Dart | 3.10.3 | ✅ |
| ABI | arm64-v8a (único) | ✅ intencional — rootfs Termux es arm64; documentar en Play listing |
| CMake | vía AGP | ✅ |
| librerías rootfs | Termux 0.118 + 300+ .so | ✅ device-verificado (apt, GTK, X) |

Sin incompatibilidades detectadas. Riesgo latente: preload de libs por `System.load` — SDK 35 ya advierte "Attempt to load writable file"; el set crítico está acotado (ver `NanoshellWorkerService.kt:233-240`) pero en SDK 36 puede volverse throw. Vigilar en FASE 2.

## 8. Auditoría JNI/C++

Archivos: `android/app/src/main/cpp/nanoshell.c`, `pty_session_registry.c`.

| Aspecto | Hallazgo | Estado |
|---|---|---|
| fork/exec | fork+dlopen en principal = SIGSEGV (Mali) — por eso existe el worker | ✅ diseño correcto |
| setsid() | **A-14**: daemons detached sin setsid real — comentario Kotlin lo afirmaba falsamente | ✅ corregido en C |
| waitpid | **A-15**: close de PTY sin harvest — zombies | ✅ corregido: kill pgroup + waitpid WNOHANG ×40 |
| LD_LIBRARY_PATH/HOME/TMPDIR/NANO_ROOTFS | Ahora condicionales `if (!getenv(...))` — Kotlin baseEnv es fuente de verdad | ✅ corregido (evita pisar env del caller) |
| dlsym lazy | Fix previo verificado: real_execve NULL en hijos linker64 causaba SIGSEGV pc=0 en aterm | 🔵 preexistente |
| Punteros entre procesos | Nunca cruzan — todo vía archivos en `files/` | ✅ diseño correcto |

## 9. Auditoría Linux/Android

- **Ejecución Linux**: rootfs Termux en `files/nano/`; binarios ELF arm64 ejecutados vía execve con nanoroot (`LD_PRELOAD`) que redirige rutas hardcodeadas (`NANO_ROOTFS`). Fallback dlopen() cuando execve devuelve EACCES (ColorOS/OPPO — verificado).
- **PTY**: `PtySessionRegistry` C + `pty_manager.dart`; UTF-8 incremental en `ansi_terminal.dart` (bytes partidos entre chunks ya no producen U+FFFD).
- **X/desktop**: Xvnc framebuffer + openbox/tint2/feh; env GTK completo (GSETTINGS_SCHEMA_DIR, GIO_EXTRA_MODULES, XDG_DATA_DIRS, XDG_RUNTIME_DIR, XCURSOR_SIZE) — ahora también en terminal (A-25).
- **Limitación conocida**: no hay acceso root real; todo vía sandbox de app + redirecciones nanoroot. `su`/`sudo` no disponibles (esperado).
- **Anti-brute-force TigerVNC**: checks de salud NUNCA por TCP desnudo a 5901 (satura contador de intentos fallidos); readiness por `/proc/<pid>/stat` + socket X11.

## 10. Auditoría de procesos

| Proceso | Owner | PID lifecycle | Quién inicia | Quién detiene | Quién hace wait | Riesgo zombie |
|---|---|---|---|---|---|---|
| Flutter main | app | hasta onDestroy | sistema | usuario/sistema | Android | bajo |
| Worker `:nanoshell` | app | bind→stopSelf | NativeRuntimeSupervisor | supervisor / handleKill | Android (Service) | bajo |
| Xvnc | worker detached | setsid pgroup propio | DesktopSessionManager | cleanupProcesses | init (huérfano re-parent) | bajo — killLingeringXvnc por uid+cmdline |
| openbox | worker detached | setsid pgroup propio | DesktopSessionManager | cleanup + watchdog relanza | init | bajo |
| tint2 | worker detached | setsid pgroup propio | DesktopSessionManager | cleanup + watchdog relanza | init | bajo |
| feh (wallpaper) | worker detached | setsid pgroup propio | DesktopSessionManager | cleanup (**A-07**) + watchdog relanza | init | bajo |
| aterm | desktop | hijo de openbox/env | openbox/SHELL | pgroup desktop | DesktopSessionManager | bajo |
| PTY shell (bash) | PTY registry | hijo de ptySpawn | PtyManager | kill pgroup SIGHUP/SIGKILL (**A-15**) | registry waitpid WNOHANG | **corregido** |
| apt/dpkg/tar | worker task | fork+waitpid | workerSpawn | handleKill (killGroup) | worker waitpid | bajo |
| Daemons (sshd etc.) | usuario | detached setsid | comando manual | manual | init | documentado |

## 11. Auditoría de memoria

| Heap | Hallazgo |
|---|---|
| Dart heap | **A-17/A-18 corregidos**: timers acumulados sin cancelar y CronScheduler sin dispose = fuga lenta en sesiones largas. `_ansi` dispuesto (A-06) eliminaba crash, no leak |
| Java heap | Sin evidencia de leak; handlers stateless; DeviceMetricsChannelHandler sin retención |
| Native heap (C) | nanoshell: buffers de argv/envp acotados por llamada; sin malloc persistente identificado |
| mmap | libs rootfs (300+) mapeadas bajo demanda vía dlopen; set crítico preload acotado |
| GPU | Driver Mali solo en proceso principal; worker sin GPU (diseño) |
| Buffers | VNC framebuffer en Xvnc (worker, sin GPU del sistema); streaming RFB al cliente Dart |
| rootfs/procesos | Xvnc+openbox+tint2+feh ~100-200MB en devices gama baja — vigilar con thermalLimit (existe setting) |

## 12. Auditoría de rendimiento

- **Cuello demostrado corregido (previo)**: `AnsiMetrics.measure` hacía 2 TextPainter.layout por frame — cache por clave de estilo (ver `ansi_terminal.dart:59-105`).
- **Cuello corregido (esta sesión)**: métricas del device en main thread (A-13) — poll de 3s jankeaba la UI.
- **Cuello residual conocido**: preloadRootfsLibs (~70 System.load) en cada spawn de daemon — amortizado por el diseño detached (solo 4 daemons), no en hot path.
- **FFI bloqueante en UI isolate (A-28)**: corregido en FASE 3 — `Isolate.run` en `_execBusyBox`/`execRootfs` con seed del allowlist y lastError capturado dentro del isolate.

## 13. Auditoría de logs

- **"LOGS OVER PROC QUOTA, rows DROPPED"** en worker (evidencia device 2026-08-12): preload logueaba ~50 WARN por spawn × 4 daemons — corregido previo con resumen en una línea (`NanoshellWorkerService.kt:228-231`).
- **Reaps de aterm invisibles** por la misma cuota — resuelto con el resumen de preload.
- **Watchdog**: mensaje corregido — antes "puerto VNC no responde" cuando en realidad era `IOException` en isAlive (Xvnc muerto); ahora "proceso Xvnc muerto (IOException en isAlive)".
- Threads nombrados (`worker-task-*`, `worker-detach-*`, `metrics-*`) — trazabilidad en logcat.

## 14. Código duplicado y deuda técnica

- **Duplicados exactos**: `duplicate_code_scan` no reportó bloques exactos relevantes entre archivos (los tres constructores de env preexistentes ya estaban centralizados en `RootfsEnv` — deuda pagada antes).
- **Imports**: `imports_audit_tool` — cero duplicados CONFIRMED, cero wildcards.
- **Código muerto**: `handleKill()` sin args en worker eliminado (verificado sin callers).
- **Deuda restante**: rutas hardcodeadas residuales en Dart/C (parcialmente mitigadas por NANO_ROOTFS); sin tests automatizados de la app.

## 15. Funciones faltantes / incompletas (demostradas)

| Función | Estado |
|---|---|
| `type` en terminal | ✅ implementado (A-24) |
| Verificación SHA256 de Kali | ✅ fail-closed (A-22) + hash real poblado (A-22b) — URL actualizada a `kali-nethunter-rootfs-minimal-arm64.tar.xz` (la anterior daba 404) |
| `docker stop` | ✅ implementación real (A-29): SIGTERM + SIGKILL a 2s vía killTracked |
| Fallback 127→host en command_executor | ✅ eliminado (A-27): stderr del rootfs tal cual, sin ejecución fuera |
| Keystore release | ⏳ A-05 |
| Icono de app | ⏳ A-32 |
| CI | ⏳ A-33 |
| `<queries>` para launchPackage | ✅ añadido MAIN/LAUNCHER (A-30) |
| Tests | ⏳ cero tests de la app Flutter; el guardián de repo (herramienta externa) tiene 19/19 |

## 16. Matriz SOLID

| Principio | Veredicto | Archivo | Corrección (si viola) |
|---|---|---|---|
| SRP | Cumple | command_executor (DIP bundle), keyboard_mapper, system_plugin | — |
| OCP | Cumple | plugins registry (r(cmd, fn)) | — |
| LSP | Cumple | terminal_core hereda State con overrides canónicos | — |
| ISP | Cumple | CmdExecCtx / TerminalServices (interfaces finas) | — |
| DIP | Cumple | PtyManager/IBinExecutor inyectados | — |

Sin violaciones estructurales. La deuda SOLID histórica (métodos de 265 líneas, acoplamiento widget-servicio) ya fue pagada con la extracción de CommandExecutor/CmdExecCtx.

## 17. Plan de corrección por fases

### FASE 0 — Estabilización (esta sesión) ✅
- **Archivos**: los 24 de la tabla con estado ✅.
- **Cambios permitidos**: fixes localizados vinculados a hallazgos A-01…A-31.
- **Cambios prohibidos**: refactors amplios, cambios de arquitectura.
- **Criterio de salida**: `flutter analyze` 0 issues + `gradlew assembleDebug` OK. ✅ (verificado abajo)

### FASE 1 — Release readiness (próxima, requiere usuario)
- **Archivos**: `android/key.properties`, keystore nuevo, iconos mipmap.
- **Cambios**: generar keystore de producción (con el usuario — contraseñas), configurar `NANOAI_KEYSTORE*`, adaptive icon.
- **Cambios prohibidos**: re-firmar con debug.
- **Criterio de salida**: `./gradlew assembleRelease` firmado con certificado de producción; bundle subible a Play.

### FASE 2 — Validación en device
- **Archivos**: `pty_shell.dart`, logs de crash.
- **Cambios**: probar PTY nativo en device con GPU (A-16); vigilar warning de `System.load` writable en SDK 36.
- **Criterio de salida**: PTY sin SIGSEGV en 3 devices o migración al worker implementada.

### FASE 3 — Refactors diferidos ✅ (completada 2026-08-13)
- **Archivos**: FFI→isolate (A-28), `docker stop` (A-29), fallback 127→host (A-27), `<queries>` (A-30), hash Kali real (A-22b).
- **Criterio de salida**: cada cambio vinculado a su hallazgo; `flutter analyze` 0 issues + `gradlew assembleDebug` BUILD SUCCESSFUL (13s) verificado. ✅
- Pendiente device: validar en dispositivo que el isolate no rompe el fork del worker (A-28) y que `docker stop` mata el proot real.

### FASE 3b — Escritorio Linux: diseño/resolución ✅ (completada 2026-08-13)

Pedido: escritorio completo sin errores de diseño, resolución, colores o píxeles. Evidencia de partida: `build/s1.png` (screenshot 1080x2400 portrait) — el escritorio aparecía como franja 1080x607 centrada con bandas enormes.

**D-1 — Resolución: framebuffer con el aspect del device.** `Xvnc -geometry 1280x720` fijo (landscape) contra device portrait → el visor (fit=contain) mostraba el fb como franja centrada. Además la cadena `startDesktop` no propagaba width/height (Dart solo enviaba `vncPassword`; `DesktopSessionManager.start(width, height)` recibía parámetros que nadie usaba). Fix: cadena completa `vnc_screen`/`desktop_launch_screen` (MediaQuery.sizeOf) → `package_service` → `nano_runtime_api` → `ExecBinChannelHandler` → `NativeRuntimeSupervisor` → `DesktopController` → `DesktopSessionManager` → `XServerBackend.resolveGeometry` (cap 1920 preservando aspect, múltiplo de 8, fallback 1280x720 si llega 0). Resultado: sin bandas, sin distorsión, sin franjas de píxeles muertos.

**D-2 — Diseño/escala para fb 1:1.** Con fb 1280 estirado a 1080px, la fuente 14px quedaba en ~11.8px físicos. Escalas subidas para fb 1:1 del device: tint2 `pixelsize=14→16`, `panel_size 46→52`, `task_font 11→12`, `time1_font 12→13`, `XCURSOR_SIZE 24→28`, GTK `gtk-font-name 14→16`.

**D-3 — Fondo de pantalla por aspect.** PNG 1280x720 con `--bg-fill` en fb portrait recortaba a franja central. Fix: `wallpaperForLaunch()` elige el PNG solo si su aspect (IHDR real) casa con el fb ±5%; si no, genera PPM gradiente vertical y lo aplica con `--bg-scale`. `setupWallpaper` ahora regenera el PPM siempre (sin early return).

**Colores**: verificados correctos — visor negocia RGB888 (32bpp, depth 24, shifts r=16 g=8 b=0), sin banding. No se tocaron.

**Verificación**: `flutter analyze` 0 issues; `gradlew assembleDebug` BUILD SUCCESSFUL (1m13s, compileDebugKotlin ejecutado). Pendiente device: captura nueva para confirmar fb portrait completo.

### FASE 3c — UX del escritorio ✅ (completada 2026-08-13)

Pedido: mejorar UX del escritorio Linux en 4 frentes elegidos por el usuario.

**U-1 — pcmanfm: papelera (trash://) vía gvfs + session bus D-Bus.**
Evidencia de partida: `bin/dbus-launch` instalado pero NADIE lo lanzaba (grep en repo: 2 menciones); sin session bus, pcmanfm borra directo sin papelera.
Fix: `gvfs` añadido a DESKTOP_PACKAGES; `DesktopSessionManager` lanza `dbus-daemon --session --nofork --address=unix:path=<tmp>/dbus-session.sock` antes de openbox y exporta `DBUS_SESSION_BUS_ADDRESS` en wmEnv (todos los hijos comparten el bus); gate `graphicalExtras` ampliado con `libexec/gvfsd-trash` para que devices existentes reciban gvfs vía installGraphical incremental (idempotente, salta lo registrado en dpkg).
Verificado en device: gvfs 1.60.2 `install ok installed` en dpkg; `gvfsd-trash` + `trash.mount` presentes; dbus-daemon vivo con socket UNIX en usr/tmp; openbox/tint2 arriba con el env. (Nota: el postinst de gvfs reporta rc=1 — `gschemas.compiled` y binarios presentes, sin impacto funcional detectado.)

**U-2 — Touch: long-press = clic derecho, scroll 2 dedos.**
Long-press 550ms sin mover (≥8px cancela) suelta el botón izquierdo y envía clic derecho (RFB mask 4) en el punto, con HapticFeedback. Scroll 2 dedos: decisión sticky al inicio del gesto (desplazamiento vertical dominante = wheel RFB cada 40px acumulados; |scale-1| ≥ 0.05 = pinch zoom).

**U-3 — Visor VNC: toolbar con teclas rápidas X11.**
Fila nueva bajo los controles de mouse/rueda/zoom: Esc, Tab, Ctrl (sticky), Alt (sticky), Enter, ← ↑ ↓ → (keysyms 0xFF1B/0xFF09/0xFFE3/0xFFE9/0xFF0D/0xFF51-0xFF54). Ctrl/Alt sticky con estado visual (chip turquesa) y haptics — sin teclado físico se puede hacer Ctrl+C o cerrar diálogos.

**U-4 — Fuentes y temas: verificado óptimo, sin cambios.**
Fontconfig del device ya en configuración correcta para framebuffer sin subpixel LCD: `10-yes-antialias.conf` (antialias), `10-hinting-slight.conf`, `10-sub-pixel-none.conf`; DejaVu instaladas en `share/fonts/TTF/` con cache generada. Subpixel RGB/LCD sería INCORRECTO en fb — no se tocó nada.

**Fix colateral descubierto — nanoroot: intercept de dlopen (feh roto).**
Al verificar U-1/U-4, feh fallaba en bucle (`No Imlib2 loader for that file format`) y el wallpaper nunca se aplicaba. Causa raíz demostrada: imlib2 dlopenea sus loaders con el path compilado `/data/data/com.termux/files/usr/lib/imlib2/loaders/pnm.so`; el dynamic linker de Android resuelve ese path con sus propios open/stat INTERNOS, que NO pasan por los intercepts open/openat de nanoroot → `dlopen failed: library not found` → imlib2 sin loaders. La redirección de openat era insuficiente para dlopen. Fix: intercept de `dlopen` en nanoroot (redirect_path antes de llamar real_dlopen). Verificado: `imlib2_load`/`imlib2_conv` convierten PPM→PNG (pnm.so+png.so cargados vía dlopen redirigido); root window del Xvnc capturado con imlib2_grab muestra el wallpaper aplicado (1668 colores, promedio RGB 22/82/119 — fondo azul del tema, no negro).
Efecto colateral positivo: cualquier app que dlopenea paths Termux (GIO modules, GTK immodules, gstreamer plugins) queda cubierta.

**U-6 — Toolbar rediseñada: táctil y plegable (feedback del usuario).**
El usuario reportó el diseño "con error, no manejable" con capturas. Diagnóstico en device: la toolbar usaba FittedBox scaleDown — como la fila de teclas (9 chips) era más ancha que la de botones, TODA la columna se encogía al ancho de la más ancha: botones de ~30px, imposibles de tocar. Rediseño: (1) sin FittedBox — barra con ancho fijo (94% de pantalla, máx 1200); (2) fila de teclas plegable (toggle con icono de teclado, colapsada por defecto para no tapar el framebuffer); (3) targets táctiles reales; (4) el hint del touchpad se oculta al expandir (la toolbar lo tapaba).
Dos bugs del rediseño encontrados y corregidos midiendo en device con uiautomator dump (1080x2400 @3.0): (a) el tope de ancho anterior (720px) hacía desbordar el Row y el toggle de teclado quedaba fuera de pantalla; (b) en Flutter 3.38 (M3) el tap target mínimo de IconButton (48dp) vive en el `style` y se imponía por encima de los constraints — `tapTargetSize: shrinkWrap` en `IconButton.styleFrom` lo destraba. Resultado verificado: 8 botones de 40dp (120px) completos incluido el toggle (antes cortado a 81px), fila de teclas con chips de 44dp de alto (antes 31dp), toggle cambia label Mostrar/Ocultar y colapsa/expande correctamente.

**Verificación**: `flutter analyze` 0 issues; `gradlew assembleDebug` BUILD SUCCESSFUL; instalado en device (VGL7MVFMDYQG8T55): gvfs instalado, dbus vivo, wallpaper aplicado, toolbar verificada por uiautomator dump en ambos estados (colapsada y expandida) con bounds reales.

### FASE 4 — Calidad
- **Archivos**: tests (Dart unit + widget para terminal/parser), CI en GitHub Actions.
- **Criterio de salida**: analyze + test + assembleDebug en cada push.

### FASE 5 — Optimización
- Solo con evidencia de cuello (perfil de traces): preload, VNC streaming, memoria en gama baja.

### FASE 6 — Validación final
- Play Console: bundle firmado, ficha, política de privacidad, test en device track cerrado, monitor de ANR/crash (Play Vitals).

**Rollback**: cada fase es commiteable por separado; fixes de FASE 0 son revertibles por archivo (no tocan arquitectura).

---

## Qué tenemos (verificado) y qué falta para producción 100%

### Tenemos — funcionalidad verificada en device real

1. **Terminal completo**: ANSI parser propio (256 colores, DECSTBM, SGR, DA/DSR, OSC 8/52, alt screen, mouse, bracketed paste), PTY real con rootfs, UTF-8 incremental, crontab/watch reales, historial.
2. **Escritorio Linux**: Xvnc + openbox + tint2 + feh + aterm, cliente VNC propio, watchdog que relanza procesos muertos, anti-brute-force sin probes TCP.
3. **Paquetes**: apt/dpkg funcionales (DebInstaller, PackageService) vía worker sin GPU.
4. **Runtime**: nanoroot LD_PRELOAD con redirección de rutas, dlsym lazy fix, setsid para daemons, reaping de PTY.
5. **Resiliencia**: kill switch del worker, killLingeringXvnc, try/catch de sesión desktop, timeouts en probes, AtomicBoolean anti-race.
6. **Honestidad del producto** (filosofía NanoRuntime): sin estados falsos, fail-closed en seguridad (Kali), fallbacks explícitos.
7. **Build verde**: `flutter analyze` 0 issues, `gradlew assembleDebug` compila.

### Falta para producción 100%

| # | Brecha | Bloqueante | Dueño |
|---|---|---|---|
| 1 | **Keystore de producción** (A-05) — hoy firma con debug | Sí — no se puede publicar | Usuario (contraseñas) |
| 2 | **targetSdk 36 subido** ✅ pero falta generar y subir el bundle firmado antes de 31-ago-2026 | Sí (deadline) | Equipo |
| 3 | Icono de app (A-32) | No (Play exige, es trivial) | Equipo |
| 4 | Validar A-16 (PTY en principal con GPU) en device | Sí — riesgo de crash en producción | Equipo |
| 5 | Tests automatizados (cero hoy) | Recomendado | Equipo |
| 6 | CI (analyze+test+build por push) | Recomendado | Equipo |
| 7 | Hash SHA256 real de Kali en el código (fail-closed ya está; falta poblarlo) | No (instalación Kali bloqueada hasta ponerlo) | Equipo |
| 8 | Refactors diferidos (FFI isolate, docker stop, fallback 127, `<queries>`) | No | Equipo |
| 9 | Play Console: ficha, privacidad, track de pruebas, Play Vitals | Sí (para publicar) | Usuario |

**Camino crítico**: 1 → 2 → 4 → 9. Con eso, la app es publicable. 3/5/6/7/8 antes o justo después del primer release.
