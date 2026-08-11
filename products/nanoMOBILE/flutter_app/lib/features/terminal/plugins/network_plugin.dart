import '../terminal_types.dart';
import '../terminalservices.dart';

/// Network commands: ssh, git, curl, wget, scp, rsync.
class NetworkPlugin {
  void register(void Function(String, CmdFn) r, TerminalServices s) {

    void execNet(String cmd, List<String> a, void Function(String, Ln) o) {
      if (s.shell != null && s.shell!.initialized && s.rootfs?.isInstalled == true) {
        final binPath = '${s.rootfs!.usrDir}/bin/$cmd';
        s.shell!.execRootfs(binPath, [cmd, ...a], ldPreload: 'libnanoroot.so')
            .then((wr) {
              if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
              if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
            });
        return;
      }
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox([cmd, ...a]).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      o('$cmd: requiere rootfs. Ejecuta "bootstrap".', Ln.stderr);
    }

    r('ssh', (a, c, o, af) {
      if (a.isEmpty) { o('ssh: usage: ssh [user@]host', Ln.stderr); return; }
      if (s.shell != null && s.shell!.initialized && s.rootfs?.isInstalled == true) {
        execNet('ssh', a, o);
        return;
      }
      o('ssh: connecting to ${a[0]}...', Ln.info);
      s.after(const Duration(milliseconds: 600),
        () => o('Authenticated.\nLast login: ${DateTime.now().toString().substring(0, 19)}', Ln.system));
    });

    r('git', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized && s.rootfs?.isInstalled == true) {
        execNet('git', a, o);
        return;
      }
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(['git', ...a]).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      if (a.isEmpty) { o('git: status, log, clone, branch', Ln.info); return; }
      switch (a[0]) {
        case 'status': o('On branch main\nnothing to commit', Ln.stdout);
        case 'log': o('commit a1b2c3d\nfeat: NanoPlatform v2.0', Ln.stdout);
        case 'clone': o('git: cloning...', Ln.info); s.after(const Duration(milliseconds: 700), () => o('git: cloned', Ln.success));
        case 'branch': o('* main\n  develop', Ln.stdout);
        default: o('git: ${a.join(" ")} ejecutado', Ln.success);
      }
    });

    r('curl', (a, c, o, af) => execNet('curl', a, o));
    r('wget', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        execNet('wget', a, o);
        return;
      }
      o('${a.isNotEmpty ? a[0] : "?"}: transferencia completada', Ln.success);
    });

    r('scp', (a, c, o, af) => execNet('scp', a, o));
    r('rsync', (a, c, o, af) => execNet('rsync', a, o));
  }
}
