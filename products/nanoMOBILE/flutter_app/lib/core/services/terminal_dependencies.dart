import 'dart:async';
import 'dart:io';
import 'shell_executor.dart'; // concrete impl for factory
import 'rootfs_manager.dart';
import 'proot_manager.dart';
import 'kali_manager.dart';
import 'docker_manager.dart';
import 'rootfs_env.dart';
import 'package:flutter/foundation.dart';
import '../../features/terminal/i_bin_executor.dart';

typedef ShellFactory = IBinExecutor Function(RootfsManager rootfs);
typedef ProotFactory = ProotManager Function(IBinExecutor shell);
typedef KaliFactory =
    KaliManager Function({
      required ProotManager proot,
      required IBinExecutor shell,
    });
typedef DockerFactory =
    DockerManager Function({
      required ProotManager proot,
      required IBinExecutor shell,
    });

/// Dependency container for terminal services.
/// Ensures ordered initialization (rootfs ? shell ? proot ? kali ? docker)
/// and prevents NPE by making each step null-safe.
///
/// Shared across all tabs via static instance; per-tab PTY sessions are
/// managed separately by PtyManager.
class TerminalDependencies {
  static final TerminalDependencies instance = TerminalDependencies();

  TerminalDependencies({
    RootfsManager? rootfs,
    IBinExecutor? shell,
    ProotManager? proot,
    KaliManager? kali,
    DockerManager? docker,
    ShellFactory? shellFactory,
    ProotFactory? prootFactory,
    KaliFactory? kaliFactory,
    DockerFactory? dockerFactory,
  }) : _rootfs = rootfs,
       _shell = shell,
       _proot = proot,
       _kali = kali,
       _docker = docker,
       _shellFactory = shellFactory ?? _defaultShellFactory,
       _prootFactory = prootFactory ?? _defaultProotFactory,
       _kaliFactory = kaliFactory ?? _defaultKaliFactory,
       _dockerFactory = dockerFactory ?? _defaultDockerFactory;

  /// Solo para tests: inyecta servicios NULOS para ejercitar la terminal en
  /// modo offline honesto (comandos dart:io reales + errores sin simulación).
  /// No toca el singleton de producción ni dispara descargas del rootfs.
  @visibleForTesting
  TerminalDependencies.forTest()
    : _rootfs = null,
      _shell = null,
      _proot = null,
      _kali = null,
      _docker = null,
      _shellFactory = _defaultShellFactory,
      _prootFactory = _defaultProotFactory,
      _kaliFactory = _defaultKaliFactory,
      _dockerFactory = _defaultDockerFactory;

  RootfsManager? _rootfs;
  IBinExecutor? _shell;
  ProotManager? _proot;
  KaliManager? _kali;
  DockerManager? _docker;
  final ShellFactory _shellFactory;
  final ProotFactory _prootFactory;
  final KaliFactory _kaliFactory;
  final DockerFactory _dockerFactory;

  static IBinExecutor _defaultShellFactory(RootfsManager rootfs) =>
      ShellExecutor(rootfs: rootfs);
  static ProotManager _defaultProotFactory(IBinExecutor shell) =>
      ProotManager(shell);
  static KaliManager _defaultKaliFactory({
    required ProotManager proot,
    required IBinExecutor shell,
  }) => KaliManager(proot: proot, shell: shell);
  static DockerManager _defaultDockerFactory({
    required ProotManager proot,
    required IBinExecutor shell,
  }) => DockerManager(proot: proot, shell: shell);

  RootfsManager? get rootfs => _rootfs;
  IBinExecutor? get shell => _shell;
  ProotManager? get proot => _proot;
  KaliManager? get kali => _kali;
  DockerManager? get docker => _docker;

  bool get hasRootfs => _rootfs?.isInstalled == true;
  bool get hasShell => _shell?.initialized == true;
  String? get usrDir => _rootfs?.usrDir;
  String? get baseDir => _shell?.baseDir;

  /// Initialize rootfs manager (shared singleton, idempotent).
  Future<void> initRootfs() async {
    _rootfs ??= RootfsManager.instance;
    if (!_rootfs!.isInstalled) {
      await _rootfs!.install();
    }
  }

  /// Initialize shell executor (requires rootfs).
  Future<void> initShell() async {
    if (_rootfs == null) await initRootfs();
    _shell ??= _shellFactory(_rootfs!);
    await _shell!.init();
  }

  /// Initialize proot (requires shell).
  Future<void> initProot() async {
    if (_shell == null) await initShell();
    _proot ??= _prootFactory(_shell!);
    await _proot!.init();
  }

  /// Initialize kali (requires proot + shell).
  Future<void> initKali() async {
    if (_proot == null) await initProot();
    _kali ??= _kaliFactory(proot: _proot!, shell: _shell!);
  }

  /// Initialize docker (requires proot + shell).
  Future<void> initDocker() async {
    if (_proot == null) await initProot();
    _docker ??= _dockerFactory(proot: _proot!, shell: _shell!);
  }

  Completer<void>? _initCompleter;

  /// Full initialization (all services). Call once at app start.
  /// Deduplicates concurrent callers so only one init sequence executes.
  Future<void> initAll({void Function(String msg)? onProgress}) async {
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    final completer = Completer<void>();
    _initCompleter = completer;
    try {
      onProgress?.call('rootfs...');
      await initRootfs();
      onProgress?.call('shell...');
      await initShell();
      onProgress?.call('proot...');
      await initProot();
      onProgress?.call('kali...');
      await initKali();
      onProgress?.call('docker...');
      await initDocker();
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
      _initCompleter = null;
      rethrow;
    }
  }

  /// Entorno canónico del rootfs — delega en [RootfsEnv] (fuente única).
  /// Todas las rutas de ejecución (pkg, apt, PTY, ash, Docker) lo consumen.
  /// [extra] pisa variables previas; [ldPreload] activa redirección de rutas.
  Map<String, String> rootfsEnv({
    String? ldPreload,
    Map<String, String>? extra,
  }) {
    final usr = _rootfs?.usrDir ?? '';
    final base =
        _shell?.baseDir ?? _rootfs?.usrDir?.replaceAll('/usr', '') ?? '';
    return RootfsEnv.build(
      usr: usr,
      base: base,
      ldPreload: ldPreload,
      extra: extra,
      // PID real del proceso Dart (antes hardcodeado a '0' aquí).
      appPid: pid,
    );
  }

  void dispose() {
    _docker?.dispose();
    _shell?.killAll();
    _rootfs = null;
    _shell = null;
    _proot = null;
    _kali = null;
    _docker = null;
  }
}
