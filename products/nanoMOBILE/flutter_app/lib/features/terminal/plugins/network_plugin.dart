import '../terminal_types.dart';
import '../terminalservices.dart';

/// Network commands: ssh, git, curl, wget, scp, rsync.
class NetworkPlugin {
  void register(void Function(String, CmdFn) r, TerminalServices s) {

    /// Sanitiza argumentos de comandos de red para prevenir inyección
    bool sanitizeNetworkArgs(List<String> args) {
      for (final arg in args) {
        // Bloquear caracteres peligrosos
        if (arg.contains('\n') || arg.contains('\r') || arg.contains('\0')) {
          return false;
        }
        // Bloquear intentos de command chaining
        if (arg.contains(';') || arg.contains('|') || arg.contains('&') || arg.contains('`')) {
          return false;
        }
        // Bloquear redirecciones de shell
        if (arg.contains('>') || arg.contains('<')) {
          return false;
        }
        // Bloquear subshells
        if (arg.contains(r'$(') || arg.contains(r'${')) {
          return false;
        }
      }
      return true;
    }

    void execNet(String cmd, List<String> a, void Function(String, Ln) o) {
      // Sanitizar argumentos antes de ejecutar
      if (!sanitizeNetworkArgs(a)) {
        o('$cmd: argumentos inválidos detectados', Ln.stderr);
        return;
      }

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
      // Sin rootfs no hay ssh real: error honesto, nunca un login fingido.
      o('ssh: requiere rootfs o shell real. Ejecuta "bootstrap".', Ln.stderr);
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
      // Sin git real: error honesto, nunca commits/branches inventados.
      o('git: requiere rootfs o shell real. Ejecuta "bootstrap".', Ln.stderr);
    });

    r('curl', (a, c, o, af) => execNet('curl', a, o));
    r('wget', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        execNet('wget', a, o);
        return;
      }
      // Sin wget real: error honesto, nunca "transferencia completada" falsa.
      o('wget: requiere rootfs o shell real. Ejecuta "bootstrap".', Ln.stderr);
    });

    r('scp', (a, c, o, af) => execNet('scp', a, o));
    r('rsync', (a, c, o, af) => execNet('rsync', a, o));
  }
}
