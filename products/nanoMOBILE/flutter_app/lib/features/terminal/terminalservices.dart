import 'i_bin_executor.dart';
import '../../core/services/rootfs_manager.dart';
import '../../core/services/docker_manager.dart';
import '../../core/services/kali_manager.dart';
import '../../core/services/proot_manager.dart';
import '../../core/linux/linux_distribution.dart';
import 'terminal_types.dart';

/// Dependency container for command plugins.
///
/// Plugins receive exactly what they need -- no more. This avoids
/// coupling every plugin to every service (ISP applied).
class TerminalServices {
  final TerminalCtx ctx;
  final void Function(String, Ln) out;
  final void Function(Duration, void Function()) after;

  // Infrastructure
  final IBinExecutor? Function()? _getShell;
  final RootfsManager? Function()? _getRootfs;
  final IBinExecutor? _shell;
  final RootfsManager? _rootfs;

  IBinExecutor? get shell => _getShell?.call() ?? _shell;
  RootfsManager? get rootfs => _getRootfs?.call() ?? _rootfs;

  // Device identity (populated async)
  final Map<String, dynamic>? deviceId;

  // Container runtimes
  final DockerManager? Function()? _getDocker;
  final KaliManager? Function()? _getKali;
  final ProotManager? Function()? _getProot;
  final DockerManager? _docker;
  final KaliManager? _kali;
  final ProotManager? _proot;

  DockerManager? get docker => _getDocker?.call() ?? _docker;
  KaliManager? get kali => _getKali?.call() ?? _kali;
  ProotManager? get proot => _getProot?.call() ?? _proot;

  // Distros Linux (UBUNTU-EXEC-02): ubuntu es UbuntuDistribution concreto;
  // el resto de distros del registry expone run/shell por su propia vía.
  final LinuxDistribution? Function()? _getUbuntu;
  final LinuxDistribution? _ubuntu;

  LinuxDistribution? get ubuntu => _getUbuntu?.call() ?? _ubuntu;

  // UI callbacks (thin: plugins shouldn't know about setState)
  final void Function() onClear;
  final void Function(String route) onNavigate;

  // Package managers
  final Map<String, String> Function({
    String? ldPreload,
    Map<String, String>? extra,
  })
  rootfsEnv;

  // LLM engine (lazy, may be null)
  final Object? Function() getEngine;

  // Audit
  final void Function(String, String, String) audit;

  // Help text (registered by plugins)
  final Map<String, String> helpTexts;

  final bool mounted;

  /// Abre una sesión interactiva PTY con los argumentos dados.
  final Future<void> Function(
    List<String> argv, {
    Map<String, String>? env,
    String? ldPreload,
  })?
  openPty;

  TerminalServices({
    required this.ctx,
    required this.out,
    required this.after,
    required this.rootfsEnv,
    required this.getEngine,
    required this.audit,
    IBinExecutor? shell,
    RootfsManager? rootfs,
    this.deviceId,
    DockerManager? docker,
    KaliManager? kali,
    ProotManager? proot,
    LinuxDistribution? ubuntu,
    IBinExecutor? Function()? getShell,
    RootfsManager? Function()? getRootfs,
    DockerManager? Function()? getDocker,
    KaliManager? Function()? getKali,
    ProotManager? Function()? getProot,
    LinuxDistribution? Function()? getUbuntu,
    this.openPty,
    void Function()? onClear,
    void Function(String)? onNavigate,
    this.mounted = true,
    Map<String, String>? helpTexts,
  }) : _shell = shell,
       _rootfs = rootfs,
       _docker = docker,
       _kali = kali,
       _proot = proot,
       _ubuntu = ubuntu,
       _getShell = getShell,
       _getRootfs = getRootfs,
       _getDocker = getDocker,
       _getKali = getKali,
       _getProot = getProot,
       _getUbuntu = getUbuntu,
       onClear = onClear ?? _noop,
       onNavigate = onNavigate ?? _noopStr,
       helpTexts = helpTexts ?? {};

  static void _noop() {}
  static void _noopStr(String _) {}
}
