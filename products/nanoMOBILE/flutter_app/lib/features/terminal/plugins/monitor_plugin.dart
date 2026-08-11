import 'dart:io';
import '../../../core/services/proc_fs.dart';
import '../terminal_types.dart';
import '../terminalservices.dart';

/// Monitor commands: free, df, top, netstat, ss, lsof, vmstat, iotop, dmesg.
class MonitorPlugin {
  void register(void Function(String, CmdFn) r, TerminalServices s) {

    r('free', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['free', ...a]).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      final m = ProcFs.meminfo();
      final total = (m['MemTotal'] ?? 0) ~/ 1024;
      if (total == 0) {
        o('free: memoria no disponible', Ln.stderr);
        return;
      }
      final avail = (m['MemAvailable'] ?? 0) ~/ 1024;
      final used = total - avail;
      o('              total        used        free', Ln.header);
      o('Mem:    ${total.toString().padLeft(10)} ${used.toString().padLeft(10)} ${avail.toString().padLeft(10)}', Ln.stdout);
    });

    r('df', (a, c, o, af) {
      final d = s.deviceId;
      if (d != null && d.containsKey('diskTotalKb')) {
        final total = (d['diskTotalKb'] as num) ~/ 1024;
        final avail = (d['diskAvailKb'] as num) ~/ 1024;
        final used = total - avail;
        o('Filesystem     1M-blocks   Used Available Use% Mounted on', Ln.header);
        o('/dev/root     ${total.toString().padLeft(9)} ${used.toString().padLeft(6)} ${avail.toString().padLeft(8)}   ${total > 0 ? ((used * 100) ~/ total) : 0}% /', Ln.stdout);
        return;
      }
      o('df: almacenamiento no disponible', Ln.stderr);
    });

    r('top', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['top', '-b', '-n', '1']).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      o('PID   USER   %CPU %MEM   VSZ   RSS TTY  STAT START   TIME COMMAND', Ln.header);
      final pids = ProcFs.listPids();
      int count = 0;
      for (final pid in pids) {
        if (count++ >= 20) break;
        final stat = ProcFs.pidStat(pid);
        final name = stat['name'] as String? ?? '?';
        final rss = (stat['rssPages'] as int? ?? 0) * 4 ~/ 1024;
        o('${pid.toString().padLeft(5)} nanoai  0.0  $rss  0   $rss ?    S    00:00   0:00 $name', Ln.stdout);
      }
    });

    r('netstat', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['netstat', ...a]).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      o('netstat: requiere rootfs o shell real', Ln.stderr);
    });

    r('ss', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['ss', ...a]).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      o('ss: requiere rootfs o shell real', Ln.stderr);
    });

    r('lsof', (a, c, o, af) {
      o('lsof (PID  $pid):', Ln.header);
      final pids = ProcFs.listPids();
      int count = 0;
      for (final pid in pids) {
        if (count++ >= 30) break;
        final stat = ProcFs.pidStat(pid);
        final name = stat['name'] as String? ?? '?';
        o('$pid  nanoai  ${pid}u   REG  0,0  0  /data/data/$name', Ln.stdout);
      }
      o('lsof: muestra los 30 procesos activos del app', Ln.info);
    });

    r('vmstat', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['vmstat', ...a]).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      final m = ProcFs.meminfo();
      o('procs -----------memory----------', Ln.header);
      o(' 0  0  ${(m['MemFree'] ?? 0) ~/ 1024}  ${(m['Buffers'] ?? 0) ~/ 1024}  ${((m['Cached'] ?? 0) + (m['SReclaimable'] ?? 0)) ~/ 1024}', Ln.stdout);
    });

    r('iotop', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['iotop', '-b', '-n', '1']).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      o('iotop: requiere rootfs o shell real', Ln.stderr);
    });

    r('dmesg', (a, c, o, af) {
      final d = s.deviceId;
      if (d != null && d.containsKey('dmesg')) {
        o(d['dmesg'] as String, Ln.stdout);
        return;
      }
      o('[dmesg] kernel log no disponible en este dispositivo', Ln.info);
    });
  }
}
