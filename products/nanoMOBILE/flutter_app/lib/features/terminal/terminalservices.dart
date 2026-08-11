import 'i_bin_executor.dart';
import '../../core/services/rootfs_manager.dart';
import '../../core/services/docker_manager.dart';
import '../../core/services/kali_manager.dart';
import '../../core/services/proot_manager.dart';
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
  final IBinExecutor? shell;
  final RootfsManager? rootfs;

  // Device identity (populated async)
  final Map<String, dynamic>? deviceId;

  // Container runtimes
  final DockerManager? docker;
  final KaliManager? kali;
  final ProotManager? proot;

  // UI callbacks (thin: plugins shouldn't know about setState)
  final void Function() onClear;
  final void Function(String route) onNavigate;

  // Package managers
  final Map<String, String> Function({
    String? ldPreload,
    Map<String, String>? extra,
  }) rootfsEnv;

  // LLM engine (lazy, may be null)
  final Object? Function() getEngine;

  // Audit
  final void Function(String, String, String) audit;

  // Help text (registered by plugins)
  final Map<String, String> helpTexts;

  final bool mounted;

  TerminalServices({
    required this.ctx,
    required this.out,
    required this.after,
    required this.rootfsEnv,
    required this.getEngine,
    required this.audit,
    this.shell,
    this.rootfs,
    this.deviceId,
    this.docker,
    this.kali,
    this.proot,
    void Function()? onClear,
    void Function(String)? onNavigate,
    this.mounted = true,
    Map<String, String>? helpTexts,
  })  : onClear = onClear ?? _noop,
        onNavigate = onNavigate ?? _noopStr,
        helpTexts = helpTexts ?? {};

  static void _noop() {}
  static void _noopStr(String _) {}
}
