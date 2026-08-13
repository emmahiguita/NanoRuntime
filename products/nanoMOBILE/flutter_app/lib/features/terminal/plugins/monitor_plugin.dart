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
      // Sin shell: solo columnas que /proc/[pid]/stat expone de verdad.
      // Sin %CPU/%MEM (requieren muestreo de /proc/stat) ni tiempos
      // inventados — un campo desconocido se marca '?', nunca un número.
      final pids = ProcFs.listPids();
      if (pids.isEmpty) {
        o('top: procfs no disponible en este host', Ln.stderr);
        return;
      }
      o('PID   S   RSS(KB)   VSZ(KB)   COMMAND', Ln.header);
      int count = 0;
      for (final pid in pids) {
        if (count++ >= 20) break;
        final stat = ProcFs.pidStat(pid);
        final name = stat['name'] as String? ?? '?';
        final state = stat['state'] as String? ?? '?';
        final rssKb = (stat['rss'] as int? ?? 0) * 4; // páginas × 4 KB
        final vszKb = (stat['vsize'] as int? ?? 0) ~/ 1024;
        o(
          '${pid.toString().padLeft(5)}   $state  ${rssKb.toString().padLeft(6)}  ${vszKb.toString().padLeft(7)}   $name',
          Ln.stdout,
        );
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
      // FDs reales de /proc/[pid]/fd (target del symlink incluido). Nunca
      // filas REG fabricadas: si el kernel no expone un fd, no se muestra.
      final pids = ProcFs.listPids();
      if (pids.isEmpty) {
        o('lsof: procfs no disponible en este host', Ln.stderr);
        return;
      }
      o('PID   COMMAND   FD   TARGET', Ln.header);
      int shown = 0;
      for (final pid in pids) {
        if (shown >= 30) break;
        final name = ProcFs.pidStat(pid)['name'] as String? ?? '?';
        for (final fd in ProcFs.pidFds(pid)) {
          o('$pid   $name   ${fd['fd']}   ${fd['target']}', Ln.stdout);
          if (++shown >= 30) break;
        }
      }
      o('lsof: primeros 30 fds reales de /proc', Ln.info);
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
