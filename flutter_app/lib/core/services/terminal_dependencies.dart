import 'shell_executor.dart';
import 'rootfs_manager.dart';
import 'proot_manager.dart';
import 'kali_manager.dart';
import 'docker_manager.dart';

/// Dependency container for terminal services.
/// Ensures ordered initialization (rootfs → shell → proot → kali → docker)
/// and prevents NPE by making each step null-safe.
///
/// Shared across all tabs via static instance; per-tab PTY sessions are
/// managed separately by PtyManager.
class TerminalDependencies {
  static final TerminalDependencies instance = TerminalDependencies._();

  TerminalDependencies._();

  RootfsManager? _rootfs;
  ShellExecutor? _shell;
  ProotManager? _proot;
  KaliManager? _kali;
  DockerManager? _docker;

  RootfsManager? get rootfs => _rootfs;
  ShellExecutor? get shell => _shell;
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
    _shell ??= ShellExecutor(rootfs: _rootfs!);
    await _shell!.init();
  }

  /// Initialize proot (requires shell).
  Future<void> initProot() async {
    if (_shell == null) await initShell();
    _proot ??= ProotManager(_shell!);
    await _proot!.init();
  }

  /// Initialize kali (requires proot + shell).
  Future<void> initKali() async {
    if (_proot == null) await initProot();
    _kali ??= KaliManager(proot: _proot!, shell: _shell!);
  }

  /// Initialize docker (requires proot + shell).
  Future<void> initDocker() async {
    if (_proot == null) await initProot();
    _docker ??= DockerManager(proot: _proot!, shell: _shell!);
  }

  /// Full initialization (all services). Call once at app start.
  Future<void> initAll({void Function(String msg)? onProgress}) async {
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
