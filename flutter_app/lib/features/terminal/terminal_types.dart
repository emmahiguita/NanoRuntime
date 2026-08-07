// ignore_for_file: deprecated_member_use
import 'terminal_subsystems.dart';

/// Terminal output types — shared between terminal_core and command_dispatcher.
enum Ln { prompt, stdout, stderr, success, info, warn, system, header }
class TL { final String text; final Ln type; const TL(this.text, this.type); }

/// Command handler signature
typedef CmdFn = dynamic Function(List<String> args, TerminalCtx ctx, void Function(String, Ln) out, void Function(Duration, void Function()) after);

/// Dependency container.
/// Legacy simulated subsystems (fs, procs, pkgs, containers, plugins) kept
/// for backward compat with old _cmds registry. New code uses CommandDispatcher.
class TerminalCtx {
  // @deprecated — use CommandDispatcher + shell.toybox() instead
  final VirtualFS fs = VirtualFS();
  // @deprecated
  final ProcessManager procs = ProcessManager();
  // @deprecated
  final PackageRegistry pkgs = PackageRegistry();
  // @deprecated
  final ContainerRegistry containers = ContainerRegistry();
  // @deprecated
  final PluginRegistry plugins = PluginRegistry();
  final Map<String, String> env = {'HOME': '/home/nanoai', 'USER': 'nanoai', 'PATH': '/usr/bin:/bin:/system/bin:/system/xbin', 'SHELL': '/bin/nanosh', 'LANG': 'en_US.UTF-8', 'ANDROID_ROOT': '/system', 'ANDROID_DATA': '/data'};
  final Map<String, String> aliases = {'ll': 'ls -la', 'gs': 'git status', 'gp': 'git push', '..': 'cd ..'};
  String cwd = '/home/nanoai';
}
