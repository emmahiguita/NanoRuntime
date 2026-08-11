import 'dart:io';
import 'i_bin_executor.dart';
import '../../core/services/terminal_audit_logger.dart';
import 'terminal_types.dart';

typedef SyncProcessRunner =
    ProcessResult Function(
      String executable,
      List<String> arguments, {
      bool runInShell,
    });

/// Thin extension over the terminal's _cmds map.
///
/// Owns ONLY commands that don't exist in terminal_core's registry:
/// - device-specific: battery, wifi, weather
/// - networking: sshd, share
/// - IDE: code
///
/// All other commands (pkg, apt, pip, node, docker, kali, git, curl, etc.)
/// are owned by terminal_core._cmds ? single source of truth.
///
/// Dispatch flow: dispatcher._cmds ? terminal._cmds ? not found.
class CommandDispatcher {
  final Map<String, CmdFn> _cmds = {};
  bool _built = false;

  final IBinExecutor? shell;
  final TerminalAuditLogger? logger;
  final TerminalCtx ctx;
  final void Function(String, Ln) out;
  final String Function() getBaseDir;
  final String Function() getUsrDir;
  final Map<String, String> Function({
    String? ldPreload,
    Map<String, String>? extra,
  })
  rootfsEnv;
  final SyncProcessRunner runProcessSync;

  CommandDispatcher({
    required this.ctx,
    required this.out,
    required this.getBaseDir,
    required this.getUsrDir,
    required this.rootfsEnv,
    SyncProcessRunner? runProcessSync,
    this.shell,
    this.logger,
  }) : runProcessSync = runProcessSync ?? _defaultRunProcessSync;

  static ProcessResult _defaultRunProcessSync(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
  }) => Process.runSync(executable, arguments, runInShell: runInShell);

  void registerCommand(String name, CmdFn fn) {
    _cmds[name] = fn;
  }

  void buildRegistry() {
    if (_built) return;
    _built = true;

    registerCommand('battery', (a, c, o, af) {
      o('=== Bateria ===', Ln.header);
      _printFileValue(o, '  Nivel: ', const [
        '/sys/class/power_supply/battery/capacity',
        '/sys/class/power_supply/BAT0/capacity',
        '/sys/class/power_supply/bms/capacity',
      ], suffix: '%');
      _printFileValue(o, '  Temp: ', const [
        '/sys/class/power_supply/battery/temp',
        '/sys/class/power_supply/BAT0/temp',
        '/sys/class/power_supply/bms/temp',
      ], mapValue: (value) => '${(int.tryParse(value) ?? 0) ~/ 10}C');
      _printFileValue(o, '  Estado: ', const [
        '/sys/class/power_supply/battery/status',
        '/sys/class/power_supply/BAT0/status',
        '/sys/class/power_supply/bms/status',
      ]);
    });

    registerCommand('wifi', (a, c, o, af) {
      o('=== WiFi ===', Ln.header);
      _emitIp(o);
      try {
        final result = runProcessSync('dumpsys', ['wifi'], runInShell: true);
        if (result.exitCode == 0) {
          final text = result.stdout.toString();
          final ssid = RegExp(r'SSID: "(.+?)"').firstMatch(text);
          final rssi = RegExp(r'RSSI: (-?\d+)').firstMatch(text);
          if (ssid != null) o('  SSID: ${ssid.group(1)}', Ln.info);
          if (rssi != null) o('  Senal: ${rssi.group(1)} dBm', Ln.info);
        }
      } catch (_) {}
    });

    registerCommand('weather', (a, c, o, af) {
      final city = a.isNotEmpty ? a.join('+') : '';
      try {
        final result = runProcessSync('curl', [
          '-s',
          'wttr.in/$city?format=%l:+%c+%t+%w+%h',
        ], runInShell: true);
        if (result.exitCode == 0 &&
            result.stdout.toString().trim().isNotEmpty) {
          o(result.stdout.toString().trim(), Ln.success);
          return;
        }
      } catch (_) {}
      o('curl no disponible. pkg install curl', Ln.info);
    });

    registerCommand('share', (a, c, o, af) {
      final usr = getUsrDir();
      final port = int.tryParse(a.firstOrNull ?? '') ?? 8080;
      final cwd = c.cwd.isNotEmpty ? c.cwd : getBaseDir();
      o('Iniciando HTTP server en puerto $port...', Ln.info);
      final env = rootfsEnv(ldPreload: 'libnanoroot.so');
      shell?.execRootfsWorker(
        '$usr/bin/python3',
        ['-m', 'http.server', '$port', '--directory', cwd],
        env: env,
        ldPreload: 'libnanoroot.so',
      );
      _getIp().then((ip) {
        if (ip != null) {
          o('  http://$ip:$port', Ln.success);
          o('  Ctrl+C para detener.', Ln.info);
        }
      });
    });

    registerCommand('sshd', (a, c, o, af) {
      final usr = getUsrDir();
      if (a.contains('start')) {
        o('Iniciando sshd en puerto 8022...', Ln.info);
        shell?.execRootfsWorker(
          '$usr/bin/sshd',
          ['-D', '-p', '8022'],
          env: rootfsEnv(ldPreload: 'libnanoroot.so'),
          ldPreload: 'libnanoroot.so',
        );
        _getIp().then((ip) {
          if (ip != null) o('  ssh root@$ip -p 8022', Ln.success);
        });
        return;
      }
      o('=== SSH Server ===', Ln.header);
      o('  1. pkg install openssh', Ln.info);
      o('  2. passwd', Ln.info);
      o('  3. ssh-keygen -A', Ln.info);
      o('  4. sshd start  (puerto 8022)', Ln.info);
    });

    registerCommand('code', (a, c, o, af) {
      o('=== VS Code Server ===', Ln.header);
      o('  pkg install code-server', Ln.info);
      o('  code-server --bind-addr 0.0.0.0:8080', Ln.info);
    });
  }

  bool dispatch(String cmd, List<String> args, {String? traceId}) {
    logger?.event(
      'dispatch.start',
      layer: 'dispatcher',
      traceId: traceId,
      command: cmd,
      argv: [cmd, ...args],
    );
    final fn = _cmds[cmd];
    if (fn != null) {
      return _invoke(
        fn,
        cmd,
        args,
        traceId: traceId,
        owner: 'CommandDispatcher',
      );
    }
    logger?.event(
      'dispatch.miss',
      layer: 'dispatcher',
      traceId: traceId,
      command: cmd,
    );
    return false;
  }

  bool _invoke(
    CmdFn fn,
    String cmd,
    List<String> args, {
    String? traceId,
    required String owner,
  }) {
    try {
      fn(args, ctx, out, (d, cb) {});
      logger?.event(
        'dispatch.ok',
        layer: 'dispatcher',
        traceId: traceId,
        command: cmd,
        data: {'owner': owner},
      );
      return true;
    } catch (e, st) {
      logger?.event(
        'dispatch.error',
        layer: 'dispatcher',
        traceId: traceId,
        command: cmd,
        error: e,
        stackTrace: st,
        data: {'owner': owner},
      );
      rethrow;
    }
  }

  void _emitIp(
    void Function(String, Ln) writer, {
    String successPrefix = '  IP: ',
    String successSuffix = '',
  }) {
    _getIp().then((ip) {
      if (ip != null) writer('$successPrefix$ip$successSuffix', Ln.info);
    });
  }

  void _printFileValue(
    void Function(String, Ln) writer,
    String prefix,
    List<String> paths, {
    String suffix = '',
    String Function(String value)? mapValue,
  }) {
    for (final path in paths) {
      try {
        final file = File(path);
        if (!file.existsSync()) continue;
        final raw = file.readAsStringSync().trim();
        final value = mapValue == null ? raw : mapValue(raw);
        writer('$prefix$value$suffix', Ln.info);
        return;
      } catch (_) {}
    }
  }

  Future<String?> _getIp() async {
    try {
      for (final iface in await NetworkInterface.list()) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
