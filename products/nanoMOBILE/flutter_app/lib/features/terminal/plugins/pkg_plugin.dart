import '../terminal_types.dart';
import '../terminalservices.dart';

/// Package manager commands: pkg, apt, pip, npm, cargo, gem.
class PkgPlugin {
  void register(void Function(String, CmdFn) r, TerminalServices s) {

    void execPkg(String cmd, List<String> a, void Function(String, Ln) o,
          TerminalCtx c, void Function(Duration, void Function()) af) {
      if (s.shell != null && s.shell!.initialized && s.rootfs?.isInstalled == true) {
        final binPath = '${s.rootfs!.usrDir}/bin/$cmd';
        final env = s.rootfsEnv(ldPreload: 'libnanoroot.so');
        s.shell!.execRootfsWorker(binPath, [cmd, ...a],
          env: env, ldPreload: 'libnanoroot.so').then((wr) {
          if (wr != null) {
            if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
            if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
            return;
          }
          s.shell!.execRootfs(binPath, [cmd, ...a],
            env: env, ldPreload: 'libnanoroot.so').then((wr) {
            if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
            if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
          });
        });
        return;
      }
      c.pkgs.pkg([cmd] + a, (t, ty) => o(t, Ln.values[ty]), af);
    }

    r('pkg', (a, c, o, af) => execPkg('pkg', a, o, c, af));
    r('apt', (a, c, o, af) => execPkg('apt', a, o, c, af));

    r('pip', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized && s.rootfs?.isInstalled == true) {
        final binPath = '${s.rootfs!.usrDir}/bin/pip';
        s.shell!.execRootfs(binPath, ['pip', ...a], ldPreload: 'libnanoroot.so')
            .then((wr) {
              if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
              if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
            });
        return;
      }
      c.pkgs.pkg(['pip'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    });

    r('npm', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized && s.rootfs?.isInstalled == true) {
        final binPath = '${s.rootfs!.usrDir}/bin/npm';
        s.shell!.execRootfs(binPath, ['npm', ...a], ldPreload: 'libnanoroot.so')
            .then((wr) {
              if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
              if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
            });
        return;
      }
      c.pkgs.pkg(['npm'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    });

    r('cargo', (a, c, o, af) =>
        c.pkgs.pkg(['cargo'] + a, (t, ty) => o(t, Ln.values[ty]), af));

    r('gem', (a, c, o, af) =>
        c.pkgs.pkg(['gem'] + a, (t, ty) => o(t, Ln.values[ty]), af));
  }
}
