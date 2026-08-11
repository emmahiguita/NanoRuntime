import 'dart:io';
import 'package:flutter/services.dart';
import '../../features/terminal/i_bin_executor.dart';

/// Ejecuta comandos dentro de un rootfs aislado usando proot (chroot sin root).
///
/// proot usa ptrace para interceptar syscalls y traducir paths, permitiendo
/// ejecutar cualquier distro ARM64 Linux (Kali, Ubuntu, Debian...) sin permisos
/// de superusuario.
///
/// Requisitos:
///   - proot binary extraído en files/nano/proot
///   - Rootfs de la distro en files/nano/distros/<name>/
///   - Kernel con ptrace habilitado (varía por fabricante)
///
/// Comando proot equivalente:
///   proot -r <rootfs> -b /dev -b /proc -b /sys -b /data/data/<app>/files/nano/usr:/usr/termux \
///     -w /root /usr/bin/env -i HOME=/root PATH=/usr/bin:/bin /bin/bash -c "<cmd>"
class ProotManager {
  static const _channel = MethodChannel('com.nanoai/exec_bin');

  final IBinExecutor _shell;
  String? _prootPath;
  bool _ready = false;
  bool get isReady => _ready;

  ProotManager(this._shell);

  /// Extrae proot de assets y lo marca ejecutable.
  Future<void> init() async {
    if (_ready) return;
    try {
      final binDir = await _channel.invokeMethod<String>('getFilesDir');
      if (binDir == null || binDir.isEmpty) return;

      final dest = '$binDir/proot';
      final f = File(dest);
      if (!f.existsSync()) {
        final data = await rootBundle.load('assets/bin/proot');
        await f.writeAsBytes(data.buffer.asUint8List());
      }
      await _channel.invokeMethod('makeExecutable', dest);
      _prootPath = dest;
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Ejecuta un comando dentro de un rootfs vía proot, con streaming de output.
  ///
  /// [rootfs] es el path absoluto al rootfs (ej: files/nano/distros/kali)
  /// [command] y [args] son el binario a ejecutar dentro del rootfs.
  /// [env] variables de entorno para el proceso hijo dentro del jail.
  /// [bindMounts] paths extra a bind-ear (formato: 'host:guest').
  Future<int> exec({
    required String rootfs,
    required String command,
    List<String> args = const [],
    Map<String, String>? env,
    List<String> bindMounts = const [],
    String workDir = '/root',
    void Function(String line)? onOut,
    void Function(String line)? onErr,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (!_ready) await init();
    if (!_ready) {
      onErr?.call('proot: no disponible');
      return 127;
    }

    // Bind mounts estándar para que el rootfs tenga acceso a dispositivos
    // y al filesystem del host. Solo bindeamos paths que existen realmente
    // para evitar errores silenciosos de proot en Android (donde /dev/pts
    // y /dev/shm frecuentemente no existen).
    final defaultBinds = <String>[
      '/dev',
      '/proc',
      '/sys',
    ];
    // Añadir paths opcionales solo si existen en el host
    for (final opt in ['/dev/pts', '/dev/shm']) {
      if (Directory(opt).existsSync()) defaultBinds.add(opt);
    }

    // Si el rootfs Termux está instalado, bind-ear su /usr como /usr/termux
    // para que el rootfs Kali/Ubuntu pueda usar los binarios de Termux.
    if (_shell.usrDir != null) {
      defaultBinds.add('${_shell.usrDir}:/usr/termux');
    }

    // Si hay un directorio home en el rootfs, bind-earlo también
    final homeDir = '$rootfs/root';
    if (Directory(homeDir).existsSync()) {
      // Asegurar que /root existe dentro del rootfs
    }

    final allBinds = [...defaultBinds, ...bindMounts];

    // Validate bind mounts: only allow mounting from app data dir or
    // standard system paths (/dev, /proc, /sys, /data/data/<app>).
    // Block arbitrary host paths to prevent sandbox escape.
    for (final bind in allBinds) {
      final src = bind.split(':').first;
      if (src.startsWith('/dev') || src.startsWith('/proc') ||
          src.startsWith('/sys') || src.startsWith('/data/data/')) {
        continue; // allowed
      }
      // Also allow app-specific paths resolved at runtime
      if (_shell.usrDir != null && src.startsWith(_shell.usrDir!)) continue;
      if (src == _shell.baseDir) continue;
      onErr?.call('Security: bind mount "$src" is not allowed');
      return 127;
    }

    // Construir argumentos de proot
    final prootArgs = <String>[];
    prootArgs.add('-r');
    prootArgs.add(rootfs);
    prootArgs.add('-w');
    prootArgs.add(workDir);

    // Añadir bind mounts
    for (final bind in allBinds) {
      prootArgs.add('-b');
      prootArgs.add(bind);
    }

    // Añadir variables de entorno
    final effectiveEnv = <String, String>{
      'HOME': '/root',
      'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      'TERM': 'xterm-256color',
      'LANG': 'en_US.UTF-8',
      ...?env,
    };
    for (final entry in effectiveEnv.entries) {
      prootArgs.add('-i');
      prootArgs.add('${entry.key}=${entry.value}');
    }

    // Comando a ejecutar dentro del rootfs
    prootArgs.add(command);
    prootArgs.addAll(args);

    return _shell.stream(
      _prootPath!,
      prootArgs,
      env: {},
      onOut: onOut,
      onErr: onErr,
      timeout: timeout,
    );
  }

  /// Ejecuta bash interactivo dentro del rootfs.
  Future<int> shell({
    required String rootfs,
    Map<String, String>? env,
    List<String> bindMounts = const [],
    void Function(String line)? onOut,
    void Function(String line)? onErr,
  }) {
    return exec(
      rootfs: rootfs,
      command: '/bin/bash',
      args: const ['-c', 'bash --norc'],
      env: env,
      bindMounts: bindMounts,
      onOut: onOut,
      onErr: onErr,
    );
  }
}
