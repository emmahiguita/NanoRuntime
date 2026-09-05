import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'nano_runtime_api.dart';
import 'rootfs_manager.dart';
import 'nanoshell_ffi.dart';
import 'rootfs_env.dart';
import '../../features/terminal/terminal_types.dart';
import '../../features/terminal/i_bin_executor.dart';
import '../utils/security_utils.dart';

/// Ejecuta comandos reales con streaming de salida.
///
/// Dos fases:
///   Fase 1 (pre-bootstrap): extrae bash + toybox de assets/bin/ como bootstrap
///     loader mínimo. Permite comandos básicos mientras se descarga el rootfs.
///   Fase 2 (post-bootstrap): usa el rootfs Termux completo en
///     files/nano/usr/ con bash real, coreutils, apt, dpkg, etc.
///
/// La transición es automática: si RootfsManager.isInstalled == true,
/// los paths de binarios apuntan a files/nano/usr/bin/. Si no, a files/nano/.
///
/// DIFERENCIA CLAVE vs Termux: no usamos PTY (requiere JNI + forkpty).
/// En su lugar usamos Process.start con stdout/stderr pipeados. Esto
/// significa que los programas interactivos (vim, htop, python REPL)
/// no funcionarán — pero todo lo demás (compiladores, curl, git, pip,
/// compilaciones largas) emite output en tiempo real.
class ShellExecutor implements IBinExecutor {
  /// AND-009: Path base de último recurso. Solo se usa en tests/desktop
  /// donde no existe MethodChannel; en Android gana getFilesDir() real.
  static const _fallbackBaseDir = '/data/data/dev.nanoai.mobile/files/nano';

  final RootfsManager _rootfs;

  String? _baseDir; // files/nano/
  String? _assetBinDir; // files/nano/ (binarios de assets)
  bool _initialized = false;
  @override
  bool get initialized => _initialized;

  /// Procesos activos. Se limpian en dispose() para no dejar zombies.
  final List<Process> _running = [];

  /// Procesos etiquetados (docker stop): tag → Process en vuelo.
  final Map<String, Process> _tracked = {};

  /// Directorio de binarios activo: rootfs/bin si instalado, assets si no.
  @override
  String? get binDir =>
      _rootfs.isInstalled ? '${_rootfs.usrDir}/bin' : _assetBinDir;

  /// Path completo al rootfs usr/ (null si no instalado).
  @override
  String? get usrDir => _rootfs.usrDir;

  /// El directorio base files/nano/ (padre de usr/).
  @override
  String? get baseDir => _baseDir;

  ShellExecutor({RootfsManager? rootfs}) : _rootfs = rootfs ?? RootfsManager();

  @override
  Future<void> init() async {
    if (_initialized) return;

    // 1. Obtener directorio base (files/nano/).
    try {
      _baseDir = await NanoRuntimeApi.instance.getFilesDir();
    } catch (_) {
      // AND-009 FIX: Fallback sin channel (tests, desktop). En device real
      // getFilesDir() siempre gana; este literal solo aplica fuera de Android.
      _baseDir = _fallbackBaseDir;
    }
    if (_baseDir == null || _baseDir!.isEmpty) {
      _baseDir = _fallbackBaseDir;
    }
    _assetBinDir = _baseDir;

    // 2. NanoShell: cargar libnanoshell.so para ejecución real vía BusyBox.
    //    Esto NO requiere assets, channels, ni symlinks.
    try {
      Nanoshell.instance.load();
      if (Nanoshell.instance.isLoaded) {
        await Nanoshell.instance.loadConfig();
        debugPrint(
          '[shell_executor] Nanoshell cargado, BusyBox real disponible',
        );
      }
    } catch (e) {
      debugPrint('[shell_executor] Nanoshell no disponible: $e');
    }

    // 3. (Opcional) Extraer assets + symlinks para dispositivos sin Nanoshell.
    //    Si falla, no bloquea — Nanoshell ya cubre la ejecución real.
    try {
      await _extractAsset('assets/bin/bash', '$_assetBinDir/bash');
      await _extractAsset('assets/bin/toybox', '$_assetBinDir/toybox');
      await NanoRuntimeApi.instance.makeExecutable('$_assetBinDir/bash');
      await NanoRuntimeApi.instance.makeExecutable('$_assetBinDir/toybox');
      await _setupBusyBoxSymlinks();
    } catch (_) {
      // Sin assets: solo se pierde el fallback Process.start().
      // Nanoshell sigue funcionando.
    }

    // 4. Verificar rootfs (independiente de Nanoshell).
    try {
      await _rootfs.checkInstalled();
    } catch (_) {
      // Sin acceso a filesystem: rootfs no disponible.
    }

    _initialized = true;
  }

  /// Crea symlinks para los applets más comunes de BusyBox en el dir base.
  /// BusyBox es un multi-call binary: necesita ser invocado con argv[0] igual
  /// al nombre del applet. Usamos dart:io Link.create() (syscall nativo, sin
  /// proceso) porque Process.run() tiene Permission denied en Android/SELinux.
  Future<void> _setupBusyBoxSymlinks() async {
    const applets = [
      'ls',
      'cat',
      'echo',
      'mkdir',
      'rm',
      'cp',
      'mv',
      'touch',
      'chmod',
      'chown',
      'ps',
      'kill',
      'top',
      'free',
      'df',
      'du',
      'mount',
      'umount',
      'grep',
      'find',
      'wc',
      'head',
      'tail',
      'sort',
      'uniq',
      'cut',
      'tr',
      'tar',
      'gzip',
      'gunzip',
      'xz',
      'bzip2',
      'unzip',
      'zip',
      'wget',
      'ping',
      'netstat',
      'nslookup',
      'ifconfig',
      'route',
      'vi',
      'sed',
      'awk',
      'diff',
      'patch',
      'stat',
      'file',
      'which',
      'xargs',
      'id',
      'whoami',
      'uname',
      'hostname',
      'uptime',
      'date',
      'sleep',
      'env',
      'clear',
      'reset',
      'tee',
      'test',
      'expr',
      'true',
      'false',
      'yes',
      'seq',
    ];
    final toybox = '$_assetBinDir/toybox';
    for (final a in applets) {
      try {
        final link = Link('$_assetBinDir/$a');
        if (!await link.exists()) {
          await link.create(toybox);
        }
      } catch (_) {
        // Symlink no soportado (ej. FAT32, exFAT). Los comandos
        // usarán exec -a via bash como fallback.
      }
    }
  }

  Future<void> _extractAsset(String assetPath, String destPath) async {
    final dest = File(destPath);
    if (dest.existsSync()) return;
    try {
      final data = await rootBundle.load(assetPath);
      await dest.writeAsBytes(data.buffer.asUint8List());
    } catch (e) {
      // Log para diagnóstico: asset no encontrado en pubspec.yaml, build
      // incorrecto, o path mal escrito.
      debugPrint('[shell_executor] ERROR extrayendo asset $assetPath: $e');
      rethrow;
    }
  }

  // â”€â”€ API pública â”€â”€

  /// Entry-point real para ejecución de procesos.
  /// Android SELinux bloquea execve() desde el app data dir. Usamos
  /// /system/bin/sh como launcher (trusted path) que luego carga nuestros
  /// binarios vía PATH o exec -a.
  static const _shPath = '/system/bin/sh';

  /// Ejecuta un binario y emite su salida en tiempo real mediante [onOut]
  /// y [onErr]. Retorna el exitCode cuando el proceso termina.
  ///
  /// [onOut] recibe cada línea de stdout (sin el \n final).
  /// [onErr] recibe cada línea de stderr.
  /// [onDone] recibe el exitCode (0 = éxito).
  ///
  /// Si el proceso no se completa en [timeout] segundos, se mata.
  @override
  Future<int> stream(
    String command,
    List<String> args, {
    String? workDir,
    Map<String, String>? env,
    void Function(String line)? onOut,
    void Function(String line)? onErr,
    Duration timeout = const Duration(seconds: 30),
    String? trackTag,
  }) async {
    if (!_initialized) await init();

    final effectiveEnv = <String, String>{
      'HOME': _baseDir!,
      'PATH': '$_baseDir:/system/bin:/system/xbin',
      'TMPDIR': '$_baseDir/tmp',
      'SHELL': _shPath,
      'TERM': 'xterm-256color',
      'LANG': 'en_US.UTF-8',
      if (_rootfs.isInstalled) ..._linuxEnv(),
      ...?env,
    };

    Process? proc;
    try {
      proc = await Process.start(
        command,
        args,
        workingDirectory: workDir ?? _baseDir,
        environment: effectiveEnv.isNotEmpty ? effectiveEnv : null,
      );
      final p = proc;
      _running.add(p);
      if (trackTag != null) _tracked[trackTag] = p;

      // Leer stdout y stderr en streams paralelos
      final outSub = p.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => onOut?.call(line));

      final errSub = p.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => onErr?.call(line));

      final exitCode = await p.exitCode.timeout(
        timeout,
        onTimeout: () {
          // TER-23: NO cancelar outSub/errSub aquí — await asFuture() abajo
          // NUNCA completa tras cancel() (cancel no completa el future del
          // stream), así que stream() colgaba para siempre en todo comando
          // con timeout. SIGTERM + SIGKILL cierran los pipes del proceso y
          // eso sí dispara done → asFuture completa.
          // Fase 1: SIGTERM (permite cleanup del proceso)
          p.kill(ProcessSignal.sigterm);
          // Fase 2: tras 2s, SIGKILL forzoso para evitar zombies
          Future.delayed(const Duration(seconds: 2), () {
            try {
              p.kill(ProcessSignal.sigkill);
            } catch (_) {}
          });
          return -1;
        },
      );

      await outSub.asFuture<void>();
      await errSub.asFuture<void>();
      _running.remove(p);
      if (trackTag != null) _tracked.remove(trackTag);
      return exitCode;
    } catch (e) {
      _running.remove(proc);
      if (trackTag != null) _tracked.remove(trackTag);
      // AND-016 FIX: Fallback a probeExec nativo (sin streaming, captura completa).
      // El código de retorno -126 indica "error interno de ejecución" distinto de
      // 127 (command not found). El caller puede distinguir entre fallo del sistema
      // vs comando inexistente.
      try {
        final map = await NanoRuntimeApi.instance.probeExec(command, args);
        if (map != null) {
          final out = (map['out'] as String? ?? '');
          final err = (map['err'] as String? ?? '');
          for (final line in out.split('\n')) {
            if (line.isNotEmpty) onOut?.call(line);
          }
          for (final line in err.split('\n')) {
            if (line.isNotEmpty) onErr?.call(line);
          }
          return (map['rc'] as int?) ?? 1;
        }
      } catch (_) {}
      onErr?.call('exec bloqueado: $e');
      return -126; // código -126 = error interno, 127 = command not found
    }
  }

  @override
  bool killTracked(String tag) {
    final p = _tracked.remove(tag);
    if (p == null) return false;
    try {
      p.kill(ProcessSignal.sigterm);
    } catch (_) {}
    Future.delayed(const Duration(seconds: 2), () {
      try {
        p.kill(ProcessSignal.sigkill);
      } catch (_) {}
    });
    return true;
  }

  /// Conveniencia: ejecuta y junta toda la salida. Para comandos rápidos.
  Future<ShellResult> exec(
    String command,
    List<String> args, {
    String? workDir,
    Map<String, String>? env,
  }) async {
    final outBuf = StringBuffer();
    final errBuf = StringBuffer();
    final rc = await stream(
      command,
      args,
      workDir: workDir,
      env: env,
      onOut: (l) => outBuf.writeln(l),
      onErr: (l) => errBuf.writeln(l),
    );
    return ShellResult(
      stdout: outBuf.toString().trim(),
      stderr: errBuf.toString().trim(),
      exitCode: rc,
    );
  }

  /// Sanitiza un comando para prevenir inyección de comandos.
  /// AND-015 FIX: Usa SecurityUtils compartido en lugar de implementación duplicada.
  String _sanitizeCommand(String cmd) => SecurityUtils.sanitizeCommand(cmd);

  /// Ejecuta comando vía /system/bin/sh -c con streaming de salida en tiempo real.
  /// Usa /system/bin/sh como entry point porque SELinux bloquea execve() desde
  /// el app data dir en Android 10+ (error=13 Permission denied).
  /// /system/bin/sh está en trusted path y puede ejecutar nuestros binarios.
  /// [timeout] por defecto 120s.
  Future<int> bashStream(
    String cmd, {
    Map<String, String>? env,
    void Function(String line)? onOut,
    void Function(String line)? onErr,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (!_initialized) await init();
    if (_baseDir == null) {
      onErr?.call('bash: sin base dir');
      return 1;
    }

    // Sanitizar comando para prevenir inyección
    try {
      cmd = _sanitizeCommand(cmd);
    } catch (e) {
      onErr?.call('bash: error de sanitización: $e');
      return 126;
    }

    return stream(
      _shPath,
      ['-c', cmd],
      env: env,
      onOut: onOut,
      onErr: onErr,
      timeout: timeout,
    );
  }

  /// Ejecuta comando vía bash -c (sin streaming, captura completa).
  @override
  Future<ShellResult> bash(
    String cmd, {
    Map<String, String>? env,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    // Sanitizar comando antes de pasar a bashStream
    try {
      cmd = _sanitizeCommand(cmd);
    } catch (e) {
      return ShellResult(
        stdout: '',
        stderr: 'bash: error de sanitización: $e',
        exitCode: 126,
      );
    }

    final outBuf = StringBuffer();
    final errBuf = StringBuffer();
    final rc = await bashStream(
      cmd,
      env: env,
      timeout: timeout,
      onOut: (l) => outBuf.writeln(l),
      onErr: (l) => errBuf.writeln(l),
    );
    return ShellResult(
      stdout: outBuf.toString().trim(),
      stderr: errBuf.toString().trim(),
      exitCode: rc,
    );
  }

  /// Ejecuta un applet de BusyBox REAL via Nanoshell FFI.
  ///
  /// Nanoshell hace fork() + dlopen(libbusybox.so) + busybox_main().
  /// No usa execve() → elude SELinux en OPPO/ColorOS.
  /// Salida completamente real, capturada de pipes stdout/stderr.
  ///
  /// Fallback: si libnanoshell.so no se carga (dispositivo sin NDK-built apk),
  /// usa bash() que intenta Process.start().
  @override
  Future<ShellResult> toybox(
    List<String> args, {
    Map<String, String>? extraEnv,
    Duration? timeout,
  }) async {
    if (args.isEmpty) {
      return const ShellResult(
        stdout: '',
        stderr: 'usage: toybox <applet> [args]',
        exitCode: 1,
      );
    }
    final env = Map<String, String>.from(_defaultEnv);
    if (extraEnv != null) env.addAll(extraEnv);
    return _execBusyBox(args, env: env, timeout: timeout);
  }

  /// Entorno mínimo para comandos BusyBox via Nanoshell.
  /// Sin PATH ni HOME, busybox_main no encuentra sus applets ni archivos.
  Map<String, String> get _defaultEnv {
    final base = _baseDir ?? _fallbackBaseDir;
    return {
      'HOME': base,
      'PATH': '$base:/system/bin:/system/xbin',
      'TMPDIR': '$base/tmp',
      'SHELL': '/system/bin/sh',
      'TERM': 'xterm-256color',
      'LANG': 'en_US.UTF-8',
      'USER': 'nanoai',
    };
  }

  /// Ejecuta un binario en el worker (`:nanoshell`, sin GPU) con argv
  /// arbitrario. fork()+dlopen() en el worker es SEGURO (sin GPU → sin el
  /// MapShadow CFI crash del bionic linker 15). Devuelve null si el worker
  /// no está disponible o hace timeout (caer al in-process).
  Future<ShellResult?> _execInWorker(
    String binaryPath,
    List<String> argv, {
    Map<String, String>? env,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      final taskId = await NanoRuntimeApi.instance.workerSpawn(
        binaryPath: binaryPath,
        argv: argv,
        envp: env,
      );
      if (taskId == null) return null;
      final base = _baseDir ?? _fallbackBaseDir;
      final outF = File('$base/worker_out_$taskId');
      final errF = File('$base/worker_err_$taskId');
      final rcF = File('$base/worker_rc_$taskId');
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (rcF.existsSync()) break;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (!rcF.existsSync()) {
        try {
          await NanoRuntimeApi.instance.workerKill();
        } catch (_) {}
        return null; // timeout → caer al in-process
      }
      final rc = int.tryParse(rcF.readAsStringSync().trim()) ?? -1;
      final out = outF.existsSync() ? outF.readAsStringSync() : '';
      final err = errF.existsSync() ? errF.readAsStringSync() : '';
      try {
        outF.deleteSync();
      } catch (_) {}
      try {
        errF.deleteSync();
      } catch (_) {}
      try {
        rcF.deleteSync();
      } catch (_) {}
      return ShellResult(stdout: out, stderr: err, exitCode: rc);
    } catch (_) {
      return null; // worker no disponible
    }
  }

  /// Ejecuta un comando real vía BusyBox (Nanoshell FFI), con fallback a bash.
  ///
  /// A-28: spawnBusyBox hace fork + waitpid del hijo COMPLETO de forma
  /// síncrona. Correrlo en el UI isolate congelaba la app mientras el
  /// comando vive (tar grande, sleep). Isolate dedicado: el waitpid
  /// bloquea el isolate, no la UI. Cada isolate abre su propio handle de
  /// libnanoshell.so (los DL handles no cruzan isolates; el linker lo
  /// cachea, coste ~1ms).
  Future<ShellResult> _execBusyBox(
    List<String> args, {
    Map<String, String>? env,
    Duration? timeout,
  }) async {
    // Android 15: fork()+dlopen() en el proceso principal crashea con el CFI
    // shadow del bionic linker (linker_cfi.cpp:158 MapShadow CHECK 'p !=
    // MAP_FAILED' failed, SIGABRT). El worker (:nanoshell, sin GPU) hace
    // fork+dlopen seguro. Se ejecuta el binario toybox ELF (assets/bin/toybox,
    // extraído en init) con argv[0]="toybox" para que despache el applet.
    final toyboxPath = _assetBinDir != null ? '$_assetBinDir/toybox' : null;
    if (toyboxPath == null) {
      return const ShellResult(
        stdout: '',
        stderr: 'WorkerUnavailable: binario toybox no extraído',
        exitCode: -1,
      );
    }
    final wr = await _execInWorker(
      toyboxPath,
      ['toybox', ...args],
      env: env,
      timeout: timeout ?? const Duration(seconds: 60),
    );
    if (wr != null) return wr;
    return const ShellResult(
      stdout: '',
      stderr: 'WorkerUnavailable: el proceso :nanoshell no está disponible '
          '(fork+dlopen in-process deshabilitado en Android 15)',
      exitCode: -1,
    );
  }

  /// Verifica si BusyBox real está disponible (binario toybox extraído +
  /// worker). Ya NO usa spawnBusyBox in-process (fork+dlopen crashea en
  /// Android 15). La disponibilidad real se valida ejecutando en el worker.
  bool get busyboxRealAvailable {
    try {
      final toyboxPath = _assetBinDir != null ? '$_assetBinDir/toybox' : null;
      if (toyboxPath == null || !File(toyboxPath).existsSync()) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ejecuta un binario del rootfs en el worker (:nanoshell, sin GPU).
  /// Útil para git, curl, python, dpkg y cualquier PIE del rootfs Termux.
  ///
  /// Android 15: fork()+dlopen() en el proceso principal crashea (CFI shadow
  /// MapShadow CHECK failed). Todo binario se ejecuta en el worker; NO hay
  /// fallback in-process (nunca fork+dlopen en el proceso Flutter principal).
  @override
  Future<ShellResult> execRootfs(
    String binaryPath,
    List<String> args, {
    Map<String, String>? env,
    String? ldPreload,
    Duration? timeout,
  }) async {
    final wr = await execRootfsWorker(
      binaryPath,
      args,
      env: env,
      ldPreload: ldPreload,
      timeout: timeout ?? const Duration(seconds: 120),
    );
    if (wr != null) return wr;
    return const ShellResult(
      stdout: '',
      stderr: 'WorkerUnavailable: el proceso :nanoshell no está disponible '
          '(fork+dlopen in-process deshabilitado en Android 15)',
      exitCode: -1,
    );
  }

  /// Ejecuta un binario del rootfs en el proceso WORKER (sin GPU).
  ///
  /// fork()+dlopen() en el proceso principal de Flutter crashea con GPU
  /// activa (SIGSEGV del driver Mali al ejecutar apt/binarios pesados).
  /// El worker (`:nanoshell` process) no tiene GPU: fork seguro.
  ///
  /// Devuelve null si el worker no está disponible (se usa el in-process).
  @override
  Future<ShellResult?> execRootfsWorker(
    String binaryPath,
    List<String> args, {
    Map<String, String>? env,
    String? ldPreload,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    try {
      final effectiveEnv = Map<String, String>.from(env ?? _defaultEnv);
      if (ldPreload != null && ldPreload.isNotEmpty) {
        effectiveEnv['LD_PRELOAD'] = ldPreload;
        if (_rootfs.isInstalled && _rootfs.usrDir != null) {
          effectiveEnv['NANO_ROOTFS'] = _rootfs.usrDir!;
          effectiveEnv['LD_LIBRARY_PATH'] = '${_rootfs.usrDir}/lib';
        } else if (_baseDir != null) {
          effectiveEnv['NANO_ROOTFS'] = _baseDir!;
        }
      }
      final taskId = await NanoRuntimeApi.instance.workerSpawn(
        binaryPath: binaryPath,
        argv: [binaryPath, ...args],
        envp: effectiveEnv,
        ldPreload: ldPreload,
      );
      if (taskId == null) return null;
      // Esperar a que el worker escriba los archivos de resultado.
      final base = _baseDir ?? _fallbackBaseDir;
      final outF = File('$base/worker_out_$taskId');
      final errF = File('$base/worker_err_$taskId');
      final rcF = File('$base/worker_rc_$taskId');
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (rcF.existsSync()) break;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (!rcF.existsSync()) {
        try {
          await NanoRuntimeApi.instance.workerKill();
        } catch (_) {}
        return const ShellResult(
          stdout: '',
          stderr: 'worker timeout',
          exitCode: -1,
        );
      }
      final rc = int.tryParse(rcF.readAsStringSync().trim()) ?? -1;
      final out = outF.existsSync() ? outF.readAsStringSync() : '';
      final err = errF.existsSync() ? errF.readAsStringSync() : '';
      // Limpiar archivos temporales.
      try {
        outF.deleteSync();
      } catch (_) {}
      try {
        errF.deleteSync();
      } catch (_) {}
      try {
        rcF.deleteSync();
      } catch (_) {}
      return ShellResult(stdout: out, stderr: err, exitCode: rc);
    } catch (e) {
      return null; // worker no disponible → usar in-process
    }
  }

  /// Mata todos los procesos activos. Llamar en dispose().
  @override
  void killAll() {
    // First pass: kill all known processes
    for (final p in List.of(_running)) {
      try {
        p.kill(ProcessSignal.sigterm);
      } catch (_) {}
    }
    _running.clear();
    // Second pass: kill any processes added during first pass
    // (async callbacks could add to _running between List.of and clear)
    if (_running.isNotEmpty) {
      for (final p in List.of(_running)) {
        try {
          p.kill(ProcessSignal.sigterm);
        } catch (_) {}
      }
      _running.clear();
    }
  }

  // â”€â”€ Entorno Linux completo (compatible con Termux) â”€â”€

  /// Variables de entorno que emulan el entorno Termux estándar.
  /// Los paquetes .deb de Termux esperan estas variables para funcionar.
  Map<String, String> _linuxEnv() =>
      RootfsEnv.build(usr: _rootfs.usrDir!, base: _baseDir!, appPid: pid);
}
