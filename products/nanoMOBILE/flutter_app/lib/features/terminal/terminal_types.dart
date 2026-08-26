// ignore_for_file: deprecated_member_use

/// Terminal output types — shared between terminal_core and command_dispatcher.
enum Ln { prompt, stdout, stderr, success, info, warn, system, header }

class TL {
  final String text;
  final Ln type;
  const TL(this.text, this.type);
}

/// Command handler signature
typedef CmdFn =
    dynamic Function(
      List<String> args,
      TerminalCtx ctx,
      void Function(String, Ln) out,
      void Function(Duration, void Function()) after,
    );

/// Canonical set of commands with real (non-simulated) implementations.
/// Single source of truth shared by terminal_core and CommandDispatcher.
/// Both modules use this constant for O(1) membership checks.
const realCommands = {
  'ls',
  'cat',
  'echo',
  'mkdir',
  'touch',
  'rm',
  'cp',
  'mv',
  'wc',
  'grep',
  'find',
  'pwd',
  'cd',
  'head',
  'tail',
  'sort',
  'uniq',
  'cut',
  'tr',
  'stat',
  'file',
  'which',
  'xargs',
  'tee',
  'ln',
  'readlink',
  'realpath',
  'dirname',
  'basename',
  'chmod',
  'chown',
  'chgrp',
  'rmdir',
  'du',
  'df',
  'sync',
  'test',
  'expr',
  'true',
  'false',
  'yes',
  'seq',
  'sleep',
  'clear',
  'reset',
  'env',
  'printenv',
  'printf',
  'id',
  'whoami',
  'uname',
  'hostname',
  'uptime',
  'date',
  'cal',
  'dmesg',
  'watch',
  'ps',
  'kill',
  'pgrep',
  'pkill',
  'pidof',
  'top',
  'free',
  'vmstat',
  'iotop',
  'wget',
  'ping',
  'netstat',
  'nslookup',
  'ifconfig',
  'route',
  'arp',
  'nc',
  'tar',
  'gzip',
  'gunzip',
  'bzip2',
  'bunzip2',
  'xz',
  'unxz',
  'unzip',
  'zip',
  'vi',
  'sed',
  'awk',
  'diff',
  'patch',
  'cmp',
};

/// Minimal stubs replacing the deleted terminal_subsystems.dart simulation layer.
/// All execution is real (Nanoshell FFI, rootfs, /proc). These stubs exist
/// only for backward compat with fallback code paths that reference ctx.procs,
/// ctx.pkgs, etc. when shell is not active.

class StubProc {
  String name = '?';
  int pid = 0;
  String state = 'S';
}

typedef StubOut = void Function(String, int);

class ProcessManager {
  final List<StubProc> procs = [];
  void ps(StubOut o) {
    o('ps: rootfs no instalado', Ln.stderr.index);
  }

  void kill(List<String> a, StubOut o) {
    o('kill: rootfs no instalado', Ln.stderr.index);
  }

  void htop(StubOut o) {
    o('htop: rootfs no instalado', Ln.stderr.index);
  }

  void pstree(StubOut o) {
    o('pstree: rootfs no instalado', Ln.stderr.index);
  }
}

class StubPkg {
  bool installed = false;
  String name = '';
}

class PackageRegistry {
  final List<StubPkg> pkgs = [];
  void pkg(
    List<String> a,
    StubOut o, [
    void Function(Duration, void Function())? af,
  ]) {
    o(
      'pkg: rootfs no instalado. Ejecuta "bootstrap" primero.',
      Ln.stderr.index,
    );
  }
}

class StubContainer {
  String id = '';
  String image = '';
  String status = 'Exited';
}

class ContainerRegistry {
  final List<StubContainer> cons = [];
}

class PluginRegistry {
  final List<StubPlugin> plugs = [];
  void plugin(List<String> a, StubOut o) {
    o(
      'plugin: no hay gestor de plugins activo (simulación eliminada).',
      Ln.stderr.index,
    );
  }
}

class StubPlugin {
  bool enabled = false;
  String name = '';
}

/// Dependency container — entorno, aliases y cwd.
class TerminalCtx {
  // Minimal stubs for backward compat (real commands use CommandDispatcher).
  final ProcessManager procs = ProcessManager();
  final PackageRegistry pkgs = PackageRegistry();
  final ContainerRegistry containers = ContainerRegistry();
  final PluginRegistry plugins = PluginRegistry();

  final Map<String, String> env = {
    'HOME': '/home/nanoai',
    'USER': 'nanoai',
    'PATH': '/usr/bin:/bin:/system/bin:/system/xbin',
    'SHELL': '/bin/nanosh',
    'LANG': 'en_US.UTF-8',
    'ANDROID_ROOT': '/system',
    'ANDROID_DATA': '/data',
  };
  final Map<String, String> aliases = {
    'll': 'ls -la',
    'gs': 'git status',
    'gp': 'git push',
    '..': 'cd ..',
  };
  String cwd = '/home/nanoai';
}

/// Result of a shell command execution. Shared between ShellExecutor,
/// IBinExecutor, and all consumers. Immutable value type.
class ShellResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  const ShellResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
}
