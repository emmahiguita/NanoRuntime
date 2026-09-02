import '../terminal_types.dart';
import '../terminalservices.dart';

/// System commands: help, clear, date, whoami, uname, hostname, uptime,
/// id, env, export, alias, source, which/type, true, false, sleep.
class SystemPlugin {
  void register(void Function(String, CmdFn) r, TerminalServices s) {
    r('help', (a, c, o, af) {
      o('Comandos disponibles:', Ln.header);
      final groups = <String, List<String>>{
        'Sistema': [
          'help',
          'clear',
          'status',
          'dashboard',
          'date',
          'whoami',
          'uname',
          'hostname',
          'uptime',
          'id',
          'env',
          'export',
          'alias',
          'source',
          'which',
          'true',
          'false',
          'sleep',
          'desktop',
        ],
        'Archivos': [
          'ls',
          'cat',
          'cd',
          'pwd',
          'cp',
          'mv',
          'rm',
          'mkdir',
          'touch',
          'chmod',
          'chown',
          'ln',
          'echo',
          'wc',
          'grep',
          'find',
          'head',
          'tail',
          'sort',
          'uniq',
          'cut',
          'tr',
          'du',
          'stat',
          'basename',
          'dirname',
          'nl',
          'tree',
          'diff',
        ],
        'Procesos': ['ps', 'kill', 'htop', 'pstree', 'jobs', 'sudo', '!'],
        'Red': [
          'ssh',
          'git',
          'curl',
          'wget',
          'scp',
          'rsync',
          'sshd',
          'wifi',
          'share',
          'host',
          'battery',
        ],
        'Paquetes': ['pkg', 'apt', 'pip', 'npm', 'cargo', 'gem'],
        'Monitor': [
          'free',
          'df',
          'top',
          'netstat',
          'ss',
          'lsof',
          'vmstat',
          'iotop',
          'dmesg',
          'battery',
        ],
        'IA': ['ai', 'infer', 'tune', 'gpu', 'nvtop'],
        'DevOps': [
          'docker',
          'kali',
          'bootstrap',
          'script',
          'crontab',
          'watch',
          'plugin',
        ],
        'Terminal': [
          'pty',
          'bash',
          'toybox',
          'vim',
          'nano',
          'python',
          'htop',
          'man',
          'clear',
        ],
        'Extras': ['weather', 'code'],
      };
      for (final g in groups.entries) {
        o('  ${g.key}:', Ln.info);
        o('    ${g.value.join(", ")}', Ln.stdout);
      }
      o('', Ln.stdout);
      o('Prefijo !: ash -c con BusyBox real (Nanoshell FFI)', Ln.info);
      o('bootstrap: instala rootfs Termux', Ln.info);
    });

    r('clear', (a, c, o, af) => s.onClear());
    r('desktop', (a, c, o, af) {
      if (s.mounted) s.onNavigate('/desktop');
    });

    r(
      'date',
      (a, c, o, af) => o(
        a.contains('--utc')
            ? DateTime.now().toUtc().toIso8601String().substring(0, 19)
            : DateTime.now().toString().substring(0, 19),
        Ln.stdout,
      ),
    );

    r('whoami', (a, c, o, af) {
      final uid = s.deviceId?['uid'] as int?;
      o(uid != null ? 'u0_a$uid' : (c.env['USER'] ?? 'nanoai'), Ln.stdout);
    });

    r('uname', (a, c, o, af) {
      final d = s.deviceId;
      // Sin identity real del device: error honesto, nunca "Linux aarch64"
      // inventado (falso en desktop o en hardware distinto).
      if (d == null) {
        o('uname: identidad del dispositivo no disponible', Ln.stderr);
        return;
      }
      final sys = d['uname_sysname'] as String? ?? 'Linux';
      final host = d['hostname'] as String? ?? 'localhost';
      final rel = d['uname_release'] as String? ?? 'unknown';
      final arch = d['uname_machine'] as String? ?? 'unknown';
      if (a.contains('-a')) {
        o('$sys $host $rel $arch GNU/Linux', Ln.stdout);
      } else if (a.contains('-r')) {
        o(rel, Ln.stdout);
      } else if (a.contains('-m')) {
        o(arch, Ln.stdout);
      } else if (a.contains('-n')) {
        o(host, Ln.stdout);
      } else {
        o(sys, Ln.stdout);
      }
    });

    r(
      'hostname',
      (a, c, o, af) =>
          o((s.deviceId?['hostname'] as String?) ?? 'localhost', Ln.stdout),
    );

    r('uptime', (a, c, o, af) {
      final sec = s.deviceId?['uptimeSec'] as double?;
      if (sec == null) {
        o('uptime: no disponible (sin identity del device)', Ln.stderr);
        return;
      }
      final d = (sec / 86400).floor();
      final h = ((sec % 86400) / 3600).floor();
      final m = ((sec % 3600) / 60).floor();
      o(
        'up ${d > 0 ? '$d days, ' : ''}$h:${m.toString().padLeft(2, '0')}',
        Ln.stdout,
      );
    });

    r('id', (a, c, o, af) {
      final d = s.deviceId;
      final uid = d?['uid'] as int?;
      if (uid == null) {
        o('id: identidad del dispositivo no disponible', Ln.stderr);
        return;
      }
      final gid = d?['gid'] as int?;
      final groups = d?['groups'] as String?;
      final gidStr = gid != null ? ' gid=$gid(u0_a$gid)' : '';
      final groupsStr = groups != null && groups.isNotEmpty
          ? ' groups=$groups'
          : '';
      o('uid=$uid(u0_a$uid)$gidStr$groupsStr', Ln.stdout);
    });

    r(
      'env',
      (a, c, o, af) => a.isEmpty
          ? c.env.forEach((k, v) => o('$k=$v', Ln.stdout))
          : o('${a[0]}=${c.env[a[0]] ?? ""}', Ln.stdout),
    );

    r('export', (a, c, o, af) {
      if (a.isNotEmpty) {
        final kv = a.join(' ').split('=');
        if (kv.length == 2) {
          c.env[kv[0]] = kv[1];
          o('${kv[0]}=${kv[1]}', Ln.success);
        }
      }
    });

    r('alias', (a, c, o, af) {
      if (a.isEmpty) {
        c.aliases.forEach((k, v) => o('$k=$v', Ln.stdout));
      } else {
        final kv = a.join(' ').split('=');
        if (kv.length == 2) {
          c.aliases[kv[0]] = kv[1];
          o('$kv[0]=$kv[1]', Ln.success);
        }
      }
    });

    // 'source' is handled directly in terminal_core._buildRegistry()
    // because it needs _execCmd to dispatch each script line.

    r('which', (a, c, o, af) {}); // delegated to realCommands (BusyBox)

    // P2: `type` NO está en realCommands (solo `which` lo está), así que el
    // handler vacío era el único registro y el comando moría en silencio.
    r('type', (a, c, o, af) {
      if (a.isEmpty) {
        o('type: uso: type <comando>', Ln.stderr);
        return;
      }
      final name = a[0];
      if (realCommands.contains(name)) {
        o('$name es un comando real (BusyBox/rootfs)', Ln.stdout);
      } else if (c.aliases.containsKey(name)) {
        o('$name es un alias de ${c.aliases[name]}', Ln.stdout);
      } else if (c.env.containsKey(name)) {
        o('$name es una variable de entorno', Ln.stdout);
      } else {
        o('type: $name no encontrado', Ln.stderr);
      }
    });

    r('sleep', (a, c, o, af) {
      final sec = double.tryParse(a.isNotEmpty ? a[0] : '0') ?? 0;
      s.after(Duration(milliseconds: (sec * 1000).round()), () {});
    });

    r('true', (a, c, o, af) {});
    r('false', (a, c, o, af) => o('', Ln.stderr));
  }
}
