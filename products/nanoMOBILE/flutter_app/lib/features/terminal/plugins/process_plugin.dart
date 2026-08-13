import 'dart:io';
import '../../../core/services/proc_fs.dart';
import '../terminal_types.dart';
import '../terminalservices.dart';

/// Process commands: ps, kill, htop, pstree, jobs, sudo.
class ProcessPlugin {
  void register(void Function(String, CmdFn) r, TerminalServices s) {

    r('ps', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['ps', ...a]).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      c.procs.ps((t, ty) => o(t, Ln.values[ty]));
    });

    r('kill', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['kill', ...a]).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      c.procs.kill(a, (t, ty) => o(t, Ln.values[ty]));
    });

    r('htop', (a, c, o, af) {
      // Interactive: open PTY if rootfs installed. Fallback to offline proc list.
      final usr = s.rootfs?.usrDir;
      if (usr != null && s.rootfs?.isInstalled == true) {
        // PTY command will override this registration in _buildRegistry.
        // This fallback handles offline mode.
        c.procs.htop((t, ty) => o(t, Ln.values[ty]));
        return;
      }
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['htop']).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      c.procs.htop((t, ty) => o(t, Ln.values[ty]));
    });

    r('pstree', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['pstree', ...a]).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      c.procs.pstree((t, ty) => o(t, Ln.values[ty]));
    });

    r('jobs', (a, c, o, af) {
      final ownPid = pid;
      final ownStat = ProcFs.pidStat(ownPid);
      final ownPpid = ownStat['ppid'] as int? ?? 0;
      o('JOBS (procesos del grupo actual):', Ln.header);
      int jobNum = 1;
      for (final pid in ProcFs.listPids()) {
        final stat = ProcFs.pidStat(pid);
        final ppid = stat['ppid'] as int? ?? 0;
        if (ppid == ownPpid || ppid == ownPid) {
          final name = stat['name'] as String? ?? '?';
          final state = stat['state'] as String? ?? '?';
          o('[$jobNum] $state  $pid  $name', Ln.stdout);
          jobNum++;
        }
      }
      if (jobNum == 1) o('  (sin procesos background)', Ln.info);
    });

    r('sudo', (a, c, o, af) {
      if (a.isEmpty) { o('sudo: uso: sudo <comando>', Ln.stderr); return; }
      // Sin root no hay sudo: no se finge ejecución, se indica la vía real.
      o('sudo: sin root real. Usa "! ${a.join(" ")}" para ejecución real.', Ln.stderr);
    });
  }
}
