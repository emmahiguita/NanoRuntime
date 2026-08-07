import 'dart:io';
import 'dart:convert';
import 'dart:math';
import '../../core/services/shell_executor.dart';
import '../../core/services/rootfs_manager.dart';
import '../../core/services/proc_fs.dart';
import 'terminal_subsystems.dart';
import 'terminal_types.dart';

/// Single-responsibility: owns the command registry and dispatches execution.
class CommandDispatcher {
  final Map<String, CmdFn> _cmds = {};
  bool _built = false;

  final ShellExecutor? shell;
  final RootfsManager? rootfs;
  final TerminalCtx ctx;
  final void Function(String, Ln) out;
  final Future<void> Function(List<String>) ptyOpen;
  final String Function() getBaseDir;
  final String Function() getUsrDir;
  final Map<String, String> Function({String? ldPreload, Map<String, String>? extra}) rootfsEnv;

  CommandDispatcher({
    required this.ctx, required this.out, required this.ptyOpen,
    required this.getBaseDir, required this.getUsrDir,
    required this.rootfsEnv, this.shell, this.rootfs,
  });

  void buildRegistry() {
    if (_built) return; _built = true;

    final realCmds = ['ls','cat','cp','mv','rm','mkdir','rmdir','touch','chmod','chown',
      'echo','pwd','cd','date','whoami','uname','env','printenv','id','groups','passwd','su','sudo','dmesg','clear','reset','tty',
      'grep','find','wc','head','tail','sort','uniq','cut','tr','du','df','stat','file','xargs','tee','readlink','realpath','basename',
      'dirname','printf','yes','test','cal','sleep','seq','expr','nl','tree','diff','cmp','patch','tar','gzip','gunzip','bzip2','bunzip2',
      'xz','unxz','unzip','zip','lz4','zstd','sha256sum','md5sum','ps','kill','pgrep','pkill','pidof','top','free',
      'ping','wget','curl','netstat','ss','nslookup','ifconfig','route','arp','nc','ssh','scp','rsync','git',
    ];
    for (final cmd in realCmds) {
      _cmds[cmd] = (a, c, o, af) {
        if (shell != null && shell!.initialized) { _runReal(cmd, a, o); }
        else if (cmd == 'pwd') { o(getBaseDir(), Ln.stdout); }
        else if (cmd == 'echo') { o(a.join(' '), Ln.stdout); }
        else if (cmd == 'cd') { o('cd: sin rootfs — usa "bootstrap"', Ln.stderr); }
        else { o('$cmd: comando no disponible sin rootfs', Ln.stderr); }
      };
    }

    _cmds['which'] = _cmds['type'] = (a, c, o, af) => _runReal('which', a, o);
    _cmds['host'] = (a, c, o, af) => _runReal('host', a, o);

    _cmds['pkg'] = (a, c, o, af) {
      if (shell != null && shell!.initialized && rootfs?.isInstalled == true) {
        final binPath = '${rootfs!.usrDir}/bin/pkg';
        final env = rootfsEnv(ldPreload: 'libnanoroot.so');
        shell!.execRootfsWorker(binPath, ['pkg', ...a], env: env, ldPreload: 'libnanoroot.so').then((wr) {
          if (wr != null) { _shellOut(wr); return; }
          shell!.execRootfs(binPath, ['pkg', ...a], env: env, ldPreload: 'libnanoroot.so').then(_shellOut);
        });
        return;
      }
      c.pkgs.pkg(a, (t, ty) => o(t, Ln.values[ty]), af);
    };

    _cmds['apt'] = (a, c, o, af) {
      if (shell != null && shell!.initialized && rootfs?.isInstalled == true) {
        final binPath = '${rootfs!.usrDir}/bin/apt';
        final env = rootfsEnv(ldPreload: 'libnanoroot.so');
        shell!.execRootfsWorker(binPath, ['apt', ...a], env: env, ldPreload: 'libnanoroot.so').then((wr) {
          if (wr != null) { _shellOut(wr); return; }
          shell!.execRootfs(binPath, ['apt', ...a], env: env, ldPreload: 'libnanoroot.so').then(_shellOut);
        });
        return;
      }
      c.pkgs.pkg(['apt'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    };

    _cmds['pip3'] = _cmds['pip'] = (a, c, o, af) {
      if (shell != null && shell!.initialized && rootfs?.isInstalled == true) {
        final binPath = '${rootfs!.usrDir}/bin/pip3';
        final env = rootfsEnv(ldPreload: 'libnanoroot.so');
        shell!.execRootfsWorker(binPath, ['pip3', ...a], env: env, ldPreload: 'libnanoroot.so').then((wr) {
          if (wr != null) { _shellOut(wr); return; }
          shell!.execRootfs(binPath, ['pip3', ...a], env: env, ldPreload: 'libnanoroot.so').then(_shellOut);
        });
        return;
      }
      o('pip3: rootfs no instalado.', Ln.stderr);
    };

    for (final cmd in ['node', 'npm', 'npx']) {
      _cmds[cmd] = (a, c, o, af) {
        if (shell != null && shell!.initialized && rootfs?.isInstalled == true) {
          final binPath = '${rootfs!.usrDir}/bin/$cmd';
          final env = rootfsEnv(ldPreload: 'libnanoroot.so');
          shell!.execRootfsWorker(binPath, [cmd, ...a], env: env, ldPreload: 'libnanoroot.so').then((wr) {
            if (wr != null) { _shellOut(wr); return; }
            shell!.execRootfs(binPath, [cmd, ...a], env: env, ldPreload: 'libnanoroot.so').then(_shellOut);
          });
          return;
        }
        o('$cmd: rootfs no instalado.', Ln.stderr);
      };
    }

    for (final inter in ['vim','vi','nano','python','python3','htop','less','more','man','mc','lynx']) {
      _cmds[inter] = (a, c, o, af) => ptyOpen([inter, ...a]);
    }
    _cmds['pty'] = (a, c, o, af) => ptyOpen(a);
    _cmds['bootstrap'] = (a, c, o, af) {
      if (rootfs == null) { o('rootfs manager no disponible', Ln.stderr); return; }
      o('Instalando rootfs Termux...', Ln.info);
      rootfs!.install().then((ok) {
        if (ok) { o('Rootfs instalado. Reinicia el terminal.', Ln.success); }
        else { o('Fallo en la instalación.', Ln.stderr); }
      });
    };

    _cmds['vmstat'] = (a, c, o, af) {
      if (shell != null && shell!.initialized) { _runReal('vmstat', a, o); return; }
      final mem = ProcFs.meminfo();
      o('procs -----------memory----------', Ln.header);
      o(' 0  0  ${(mem['MemFree']??0)~/1024}  ${(mem['Buffers']??0)~/1024}  ${((mem['Cached']??0)+(mem['SReclaimable']??0))~/1024}', Ln.stdout);
    };

    _cmds['crontab'] = (a, c, o, af) => o('crontab: usa "crontab -l" o "crontab -e"', Ln.info);

    // ── share: HTTP file server ──
    _cmds['share'] = (a, c, o, af) {
      final usr = getUsrDir();
      final port = int.tryParse(a.firstOrNull ?? '') ?? 8080;
      final cwd = c.cwd.isNotEmpty ? c.cwd : getBaseDir();
      o('Iniciando HTTP server en puerto $port...', Ln.info);
      final env = rootfsEnv(ldPreload: 'libnanoroot.so');
      shell?.execRootfsWorker('$usr/bin/python3', ['-m','http.server','$port','--directory',cwd], env: env, ldPreload: 'libnanoroot.so');
      _getIp().then((ip) {
        if (ip != null) { o('  http://$ip:$port', Ln.success); o('  Ctrl+C para detener.', Ln.info); }
      });
    };

    // ── sshd ──
    _cmds['sshd'] = (a, c, o, af) {
      final usr = getUsrDir();
      if (a.contains('start')) {
        o('Iniciando sshd en puerto 8022...', Ln.info);
        shell?.execRootfsWorker('$usr/bin/sshd', ['-D','-p','8022'], env: rootfsEnv(ldPreload:'libnanoroot.so'), ldPreload:'libnanoroot.so');
        _getIp().then((ip) { if (ip != null) o('  ssh root@$ip -p 8022', Ln.success); });
        return;
      }
      o('=== SSH Server ===', Ln.header);
      o('  1. pkg install openssh', Ln.info);
      o('  2. passwd', Ln.info);
      o('  3. ssh-keygen -A', Ln.info);
      o('  4. sshd start  (puerto 8022)', Ln.info);
    };

    // ── code: VS Code server ──
    _cmds['code'] = (a, c, o, af) {
      o('=== VS Code Server ===', Ln.header);
      o('  pkg install code-server', Ln.info);
      o('  code-server --bind-addr 0.0.0.0:8080', Ln.info);
    };

    // ── battery ──
    _cmds['battery'] = (a, c, o, af) {
      o('=== Bateria ===', Ln.header);
      for (final path in ['/sys/class/power_supply/battery/capacity','/sys/class/power_supply/BAT0/capacity','/sys/class/power_supply/bms/capacity']) {
        try { final f = File(path); if (f.existsSync()) { o('  Nivel: ${f.readAsStringSync().trim()}%', Ln.info); break; } } catch (_) {}
      }
      for (final path in ['/sys/class/power_supply/battery/temp','/sys/class/power_supply/BAT0/temp','/sys/class/power_supply/bms/temp']) {
        try { final f = File(path); if (f.existsSync()) { final t = (int.tryParse(f.readAsStringSync().trim())??0)~/10; o('  Temp: ${t}C', Ln.info); break; } } catch (_) {}
      }
      for (final path in ['/sys/class/power_supply/battery/status','/sys/class/power_supply/BAT0/status','/sys/class/power_supply/bms/status']) {
        try { final f = File(path); if (f.existsSync()) { o('  Estado: ${f.readAsStringSync().trim()}', Ln.info); break; } } catch (_) {}
      }
    };

    // ── wifi ──
    _cmds['wifi'] = (a, c, o, af) {
      o('=== WiFi ===', Ln.header);
      _getIp().then((ip) { if (ip != null) o('  IP: $ip', Ln.info); });
      try {
        final r = Process.runSync('dumpsys', ['wifi'], runInShell: true);
        if (r.exitCode == 0) {
          final out = r.stdout.toString();
          final ssid = RegExp(r'SSID: "(.+?)"').firstMatch(out);
          final rssi = RegExp(r'RSSI: (-?\d+)').firstMatch(out);
          if (ssid != null) o('  SSID: ${ssid.group(1)}', Ln.info);
          if (rssi != null) o('  Senal: ${rssi.group(1)} dBm', Ln.info);
        }
      } catch (_) {}
    };

    // ── weather ──
    _cmds['weather'] = (a, c, o, af) {
      final city = a.isNotEmpty ? a.join('+') : '';
      try {
        final r = Process.runSync('curl', ['-s', "wttr.in/$city?format=%l:+%c+%t+%w+%h"], runInShell: true);
        if (r.exitCode == 0 && r.stdout.toString().trim().isNotEmpty) { o(r.stdout.toString().trim(), Ln.success); return; }
      } catch (_) {}
      o('curl no disponible. pkg install curl', Ln.info);
    };
  }

  bool dispatch(String cmd, List<String> args) {
    final fn = _cmds[cmd];
    if (fn == null) return false;
    fn(args, ctx, out, (d, cb) {});
    return true;
  }

  bool hasShellOps(String cmd) => cmd.contains('|') || cmd.contains('>') || cmd.contains('<') || cmd.contains('&&');

  Future<String?> _getIp() async {
    try {
      for (final iface in await NetworkInterface.list()) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _runReal(String cmd, List<String> args, void Function(String, Ln) out) async {
    if (shell == null || !shell!.initialized) return;
    final r = await shell!.toybox([cmd, ...args]);
    if (r != null) _shellOut(r);
  }

  void _shellOut(ShellResult r) {
    if (r.stdout.isNotEmpty) out(r.stdout, Ln.stdout);
    if (r.stderr.isNotEmpty) out(r.stderr, Ln.stderr);
  }
}
