import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'rootfs_manager.dart';
import 'nanoshell_ffi.dart';
import 'rootfs_env.dart';
import '../../features/terminal/terminal_types.dart';
import '../../features/terminal/i_bin_executor.dart';

/// Ejecuta comandos reales con streaming de salida.
///
/// Dos fases:
///   Fase 1 (pre-bootstrap): extrae bash + toybox de assets/bin/ como bootstrap
///     loader mÃ­nimo. Permite comandos bÃ¡sicos mientras se descarga el rootfs.
///   Fase 2 (post-bootstrap): usa el rootfs Termux completo en
///     files/nano/usr/ con bash real, coreutils, apt, dpkg, etc.
///
/// La transiciÃ³n es automÃ¡tica: si RootfsManager.isInstalled == true,
/// los paths de binarios apuntan a files/nano/usr/bin/. Si no, a files/nano/.
///
/// DIFERENCIA CLAVE vs Termux: no usamos PTY (requiere JNI + forkpty).
/// En su lugar usamos Process.start con stdout/stderr pipeados. Esto
/// significa que los programas interactivos (vim, htop, python REPL)
/// no funcionarÃ¡n â€” pero todo lo demÃ¡s (compiladores, curl, git, pip,
/// compilaciones largas) emite output en tiempo real.
class ShellExecutor implements IBinExecutor {
  static const _channel = MethodChannel('com.nanoai/exec_bin');

  final RootfsManager _rootfs;

  String? _baseDir; // files/nano/
  String? _assetBinDir; // files/nano/ (binarios de assets)
  bool _initialized = false;
  @override
  bool get initialized => _initialized;

  /// Procesos activos. Se limpian en dispose() para no dejar zombies.
  final List<Process> _running = [];

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
      _baseDir = await _channel.invokeMethod<String>('getFilesDir');
    } catch (_) {
      // Fallback: sin channel (tests, desktop). Nanoshell aÃºn puede funcionar
      // si conocemos el path del app sandbox.
      _baseDir = '/data/data/dev.nanoai.mobile/files/nano';
    }
    if (_baseDir == null || _baseDir!.isEmpty) {
      _baseDir = '/data/data/dev.nanoai.mobile/files/nano';
    }
    _assetBinDir = _baseDir;

    // 2. NanoShell: cargar libnanoshell.so para ejecuciÃ³n real vÃ­a BusyBox.
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
    //    Si falla, no bloquea â€” Nanoshell ya cubre la ejecuciÃ³n real.
    try {
      await _extractAsset('assets/bin/bash', '$_assetBinDir/bash');
      await _extractAsset('assets/bin/toybox', '$_assetBinDir/toybox');
      await _channel.invokeMethod('makeExecutable', '$_assetBinDir/bash');
      await _channel.invokeMethod('makeExecutable', '$_assetBinDir/toybox');
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

  /// Crea symlinks para los applets mÃ¡s comunes de BusyBox en el dir base.
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
        // usarÃ¡n exec -a via bash como fallback.
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
      // Log para diagnÃ³stico: asset no encontrado en pubspec.yaml, build
      // incorrecto, o path mal escrito.
      debugPrint('[shell_executor] ERROR extrayendo asset $assetPath: $e');
      rethrow;
    }
  }

  // â”€â”€ API pÃºblica â”€â”€

  /// Entry-point real para ejecuciÃ³n de procesos.
  /// Android SELinux bloquea execve() desde el app data dir. Usamos
  /// /system/bin/sh como launcher (trusted path) que luego carga nuestros
  /// binarios vÃ­a PATH o exec -a.
  static const _shPath = '/system/bin/sh';

  /// Ejecuta un binario y emite su salida en tiempo real mediante [onOut]
  /// y [onErr]. Retorna el exitCode cuando el proceso termina.
  ///
  /// [onOut] recibe cada lÃ­nea de stdout (sin el \n final).
  /// [onErr] recibe cada lÃ­nea de stderr.
  /// [onDone] recibe el exitCode (0 = Ã©xito).
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
          // Fase 1: SIGTERM (permite cleanup del proceso)
          p.kill(ProcessSignal.sigterm);
          outSub.cancel();
          errSub.cancel();
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
      return exitCode;
    } catch (e) {
      _running.remove(proc);
      // Fallback a probeExec nativo (sin streaming, captura completa)
      try {
        final map =
            await _channel.invokeMethod('probeExec', {
                  'path': command,
                  'args': args,
                })
                as Map?;
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
      return -126; // cÃ³digo distinto de 127 (command not found) para que el
      // caller pueda distinguir "error interno" de "fallo real"
    }
  }

  /// Conveniencia: ejecuta y junta toda la salida. Para comandos rÃ¡pidos.
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

  /// Ejecuta comando vÃ­a /system/bin/sh -c con streaming de salida en tiempo real.
  /// Usa /system/bin/sh como entry point porque SELinux bloquea execve() desde
  /// el app data dir en Android 10+ (error=13 Permission denied).
  /// /system/bin/sh estÃ¡ en trusted path y puede ejecutar nuestros binarios.
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
    return stream(
      _shPath,
      ['-c', cmd],
      env: env,
      onOut: onOut,
      onErr: onErr,
      timeout: timeout,
    );
  }

  /// Ejecuta comando vÃ­a bash -c (sin streaming, captura completa).
  @override
  Future<ShellResult> bash(
    String cmd, {
    Map<String, String>? env,
    Duration timeout = const Duration(seconds: 120),
  }) async {
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
  /// No usa execve() â†’ elude SELinux en OPPO/ColorOS.
  /// Salida completamente real, capturada de pipes stdout/stderr.
  ///
  /// Fallback: si libnanoshell.so no se carga (dispositivo sin NDK-built apk),
  /// usa bash() que intenta Process.start().
  @override
  Future<ShellResult> toybox(
    List<String> args, {
    Map<String, String>? extraEnv,
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
    return _execBusyBox(args, env: env);
  }

  /// Entorno mÃ­nimo para comandos BusyBox via Nanoshell.
  /// Sin PATH ni HOME, busybox_main no encuentra sus applets ni archivos.
  Map<String, String> get _defaultEnv {
    final base = _baseDir ?? '/data/data/dev.nanoai.mobile/files/nano';
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

  /// Ejecuta un comando real vÃ­a BusyBox (Nanoshell FFI), con fallback a bash.
  Future<ShellResult> _execBusyBox(
    List<String> args, {
    Map<String, String>? env,
  }) async {
    try {
      final ns = Nanoshell.instance;
      if (!ns.isLoaded) {
        try {
          ns.load();
        } catch (_) {
          // libnanoshell.so no disponible (build sin NDK, o dispositivo
          // que no extrajo jniLibs). Fallback a bash.
          return _execBusyBoxFallback(args, env: env);
        }
      }

      final result = ns.spawnBusyBox(args, env: env);

      if (result.exitCode == -1) {
        // Error interno de nanoshell (fork/pipe/dlopen fallÃ³).
        // Intentar fallback.
        final errMsg = ns.lastError;
        if (errMsg.contains('dlopen')) {
          // libbusybox.so o sus deps no encontradas en jniLibs.
          return _execBusyBoxFallback(args, env: env);
        }
        return ShellResult(
          stdout: result.stdout,
          stderr: 'nanoshell error: $errMsg\n${result.stderr}',
          exitCode: result.exitCode,
        );
      }

      return ShellResult(
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      );
    } catch (e) {
      return _execBusyBoxFallback(args, env: env);
    }
  }

  /// Fallback: ejecuciÃ³n vÃ­a bash/sh (Process.start). Solo funciona en
  /// dispositivos con SELinux permisivo (no OPPO/ColorOS).
  Future<ShellResult> _execBusyBoxFallback(
    List<String> args, {
    Map<String, String>? env,
  }) async {
    String esc(String s) => "'${s.replaceAll("'", "'\\''")}'";
    final cmd = args.map(esc).join(' ');
    return bash(cmd, env: env);
  }

  /// Verifica si BusyBox real estÃ¡ disponible vÃ­a Nanoshell.
  bool get busyboxRealAvailable {
    try {
      if (!Nanoshell.instance.isLoaded) Nanoshell.instance.load();
      final result = Nanoshell.instance.spawnBusyBox(['true']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Ejecuta un binario genÃ©rico del rootfs vÃ­a nanoshell_spawn_generic.
  /// Ãštil para git, curl, python, dpkg y cualquier PIE del rootfs Termux.
  ///
  /// [binaryPath] debe ser path absoluto al binario (ej. /data/.../usr/bin/curl).
  /// [ldPreload] opcional: si se pasa "libnanoroot.so", activa fakechroot.
  @override
  Future<ShellResult> execRootfs(
    String binaryPath,
    List<String> args, {
    Map<String, String>? env,
    String? ldPreload,
  }) async {
    try {
      final ns = Nanoshell.instance;
      if (!ns.isLoaded) ns.load();

      // Construir env con NANO_ROOTFS y LD_LIBRARY_PATH si se usa ldPreload.
      // Sin esto, libnanoroot.so se carga pero no sabe dÃ³nde estÃ¡ el rootfs.
      // OJO: nanoroot.c mapea /usr/X â†’ {NANO_ROOTFS}/X, asÃ­ que NANO_ROOTFS
      // DEBE ser .../files/nano/usr (NO el baseDir). /etc â†’ {parent}/etc.
      final effectiveEnv = Map<String, String>.from(env ?? _defaultEnv);
      if (ldPreload != null && ldPreload.isNotEmpty) {
        effectiveEnv['LD_PRELOAD'] = ldPreload;
        if (_rootfs.isInstalled && _rootfs.usrDir != null) {
          effectiveEnv['NANO_ROOTFS'] = _rootfs.usrDir!;
          effectiveEnv['LD_LIBRARY_PATH'] = '${_rootfs.usrDir}/lib';
        } else if (_baseDir != null) {
          // Sin rootfs: fallback al baseDir (los binarios viven en baseDir/).
          effectiveEnv['NANO_ROOTFS'] = _baseDir!;
        }
      }

      final result = ns.spawnGeneric(
        binaryPath,
        args,
        env: effectiveEnv,
        ldPreload: ldPreload,
      );

      return ShellResult(
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      );
    } catch (e) {
      return ShellResult(
        stdout: '',
        stderr: 'execRootfs error: $e',
        exitCode: -1,
      );
    }
  }

  /// Ejecuta un binario del rootfs en el proceso WORKER (sin GPU).
  ///
  /// fork()+dlopen() en el proceso principal de Flutter crashea con GPU
  /// activa (SIGSEGV del driver Mali al ejecutar apt/binarios pesados).
  /// El worker (`:nanoshell` process) no tiene GPU: fork seguro.
  ///
  /// Devuelve null si el worker no estÃ¡ disponible (se usa el in-process).
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
      final resp = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'workerSpawn',
        {
          'binaryPath': binaryPath,
          'argv': [binaryPath, ...args],
          'envp': effectiveEnv,
          'ldPreload': ldPreload,
        },
      );
      final taskId = resp?['taskId'] as String?;
      if (taskId == null) return null;
      // Esperar a que el worker escriba los archivos de resultado.
      final base = _baseDir ?? '/data/data/dev.nanoai.mobile/files/nano';
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
          await _channel.invokeMethod('workerKill');
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
      return null; // worker no disponible â†’ usar in-process
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

  /// Variables de entorno que emulan el entorno Termux estÃ¡ndar.
  /// Los paquetes .deb de Termux esperan estas variables para funcionar.
  Map<String, String> _linuxEnv() => RootfsEnv.build(
    usr: _rootfs.usrDir!,
    base: _baseDir!,
    appPid: pid,
  );
}
