# Changelog

## [1.0.0+1] — 2026-08-08

### Fixed
- B1: JNI local reference leak in `pty_jni.c:_jstrarr_to_c` (Added `DeleteLocalRef`)
- B2: NULL pointer dereference in `nanoshell.c:537` (Added `malloc` check + `_exit(126)`)
- B3: `_cronJobs[].timer` not canceled in `dispose()` (Added `_cronJobs.clear()`)
- B4: Missing `.catchError` on `execRootfsWorker` chains in `CommandDispatcher`
- Pipe deadlock: replaced sequential `_slurp_fd` with concurrent `poll()` drain (30s timeout)
- ANSI cell corruption: deep copy via `.clone()` in `insertLines`/`deleteLines`/`scrollUp`
- `clear`/`whoami`/`uname`/`id`/`date` removed from dispatcher `realCmds` (device-aware versions now used)
- `_realHead`/`_realTail`: `lastWhere` now uses `orElse`, `skip` clamped to avoid `RangeError`
- `c.env['USER']` null-assert replaced with `?? 'nanoai'`
- `PtyManager`: added `_disposed` guard to prevent race between `open()` and `dispose()`
- `_ptyOpen`: added `_ptyOpening` serialization lock to prevent concurrent PTY sessions
- `setState` in `clear`/`Ctrl+L` guarded with `mounted`

### Security
- VNC: added `-localhost` flag to Xvnc args
- `network_security_config.xml`: cleartext blocked except for loopback and `wttr.in`
- Removed `usesCleartextTraffic="true"` from AndroidManifest
- R8/ProGuard enabled for release builds with JNI keep rules
- Removed unused dependencies: `google_fonts`, `intl`, `flutter_animate`

### Build
- CMake: `util.c` shared module extracted, `-O2 -DNDEBUG` Release flags added
- Gradle: explicit `compileSdk=36`, `minSdk=26`, `targetSdk=35`, `ndkVersion=28.2`
- Dart SDK constraint tightened to `>=3.10.3 <4.0.0`
- Release signing config documented with environment variable pattern

### Architecture (SOLID)
- **SRP**: `RealFileSystem` extracted from `_TermState` (~200 lines)
- **SRP**: `DeviceInfo` extracted (CPU temp / GPU info readers)
- **SRP**: `AllowedBinaries` config loader extracted from `nanoshell_ffi.dart`
- **OCP**: `TerminalPlugin` + `CmdRegistrar` plugin system created
- **OCP**: `AiPlugin` extracts `ai`/`infer` commands from `_TermState`
- **DIP**: `IBinExecutor` interface created; `ShellExecutor` implements it; `CommandDispatcher` accepts `IBinExecutor?`
- **DIP**: `ShellResult` moved to `terminal_types.dart` to break circular dependency
- **DRY**: `_apply_env`, `_count_argv`, `apply_rlimit_as` extracted to shared `util.h`/`util.c`
- **DRY**: `_rootfsEnv` centralized in `TerminalDependencies.rootfsEnv()`
- **DRY**: Removed ~80 lines of duplicate command registrations from `_TermState._buildRegistry()`
- Deleted `terminal_subsystems.dart` (dead simulation layer)

### Lifecycle
- `WidgetsBindingObserver` added to `_TermState`: pauses PTY polling in background
- Worker process killed in `MainActivity.onDestroy()` (VNC daemons + `:nanoshell` process)
- `MSG_KILL` added to `NanoshellWorkerService` via `WorkerClient.kill()`
- Memory limit: `RLIMIT_AS=512MB` applied in child processes via `apply_rlimit_as()`

### Performance
- PTY polling interval reduced from 20ms (50/sec) to 50ms (20/sec)
- `RepaintBoundary` on `AnsiTerminalView`
- `execRootfsWorker` accepts configurable timeout parameter

### Testing
- Added 20 unit tests for `RealFileSystem` (path normalization, file operations)
- Added 9 unit tests for `AnsiTerminal` (VT100/ANSI, deep copy verification)
- Added 7 unit tests for `CommandDispatcher` and `TerminalCtx`
- Added CI/CD workflow: `flutter analyze` + `flutter test` + `dart format` on push/PR
