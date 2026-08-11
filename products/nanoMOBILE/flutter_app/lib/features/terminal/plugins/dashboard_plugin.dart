import '../terminal_types.dart';
import '../terminalservices.dart';

/// Dashboard and maintenance commands: dashboard, status, bootstrap,
/// dmesg, toybox, bash, man.
class DashboardPlugin {
  void register(void Function(String, CmdFn) r, TerminalServices s) {

    r('dashboard', (a, c, o, af) {
      final d = s.deviceId;
      final totalMb = ((d?['memTotalKb'] as num?)?.toDouble() ?? 0) / 1024;
      final availMb = ((d?['memAvailKb'] as num?)?.toDouble() ?? 0) / 1024;
      final usedMb = totalMb - availMb;
      final cores = d?['cpuCores'] as int? ?? 0;
      final ramStr = totalMb > 0
          ? '${usedMb.toStringAsFixed(0)}/${totalMb.toStringAsFixed(0)} MB'
          : '? MB';
      o(
        '══ Dashboard ══\n'
        'CPU: $cores cores | RAM: $ramStr\n'
        'Rootfs: ${s.rootfs?.isInstalled == true ? "INSTALADO" : "no instalado"}\n'
        'Procs: ${c.procs.procs.length} | '
        'Pkgs: ${c.pkgs.pkgs.where((p) => p.installed).length} | '
        'Containers: ${c.containers.cons.where((x) => !x.status.startsWith("Exited")).length} | '
        'Plugins: ${c.plugins.plugs.where((p) => p.enabled).length}',
        Ln.stdout,
      );
    });

    r('status', (a, c, o, af) {
      o('══ NanoPlatform Status ══', Ln.header);
      o('Shell: ${s.shell?.initialized == true ? "listo" : "no inicializado"}', Ln.info);
      o('Bin dir: ${s.shell?.binDir ?? "?"}', Ln.info);
      if (s.rootfs != null) {
        o('Rootfs: ${s.rootfs!.isInstalled ? "INSTALADO" : "no instalado"}',
          s.rootfs!.isInstalled ? Ln.success : Ln.warn);
        o('  usrDir: ${s.rootfs!.usrDir ?? "?"}', Ln.info);
        o('  Descargando: ${s.rootfs!.isDownloading}', Ln.info);
      }
      o('Env: PATH=${c.env["PATH"]}', Ln.info);
      o('Env: HOME=${c.env["HOME"]}', Ln.info);
      o('Device: ${s.deviceId?["hostname"] ?? "?"} (${s.deviceId?["uname_machine"] ?? "?"})', Ln.info);
    });

    r('bootstrap', (a, c, o, af) {
      if (s.rootfs == null) { o('bootstrap: rootfs manager no disponible', Ln.stderr); return; }
      if (s.rootfs!.isInstalled) {
        o('bootstrap: rootfs ya instalado en ${s.rootfs!.usrDir}', Ln.success);
        return;
      }
      if (s.rootfs!.isDownloading) { o('bootstrap: descarga en progreso...', Ln.info); return; }
      o('[bootstrap] Iniciando instalacion del rootfs Termux (~30 MB)...', Ln.header);
      s.rootfs!.install().then((ok) {
        if (ok) {
          o('[bootstrap] Instalacion completa. Reinicia el terminal.', Ln.success);
        } else {
          o('[bootstrap] Fallo la instalacion.', Ln.stderr);
        }
      });
    });

    r('toybox', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        s.shell!.toybox(a).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      o('toybox: shell no disponible', Ln.stderr);
    });

    r('bash', (a, c, o, af) {
      if (s.shell != null && s.shell!.initialized) {
        final shellCmd = a.isNotEmpty ? a.join(' ') : '-i';
        s.shell!.toybox(['ash', '-c', shellCmd]).then((wr) {
          if (wr.stdout.isNotEmpty) o(wr.stdout, Ln.stdout);
          if (wr.stderr.isNotEmpty) o(wr.stderr, Ln.stderr);
        });
        return;
      }
      o('bash: shell no disponible', Ln.stderr);
    });

    r('man', (a, c, o, af) {
      if (a.isEmpty) { o('man: Uso: man <pagina>', Ln.stderr); return; }
      if (s.rootfs?.isInstalled == true) {
        o('man: abriendo pagina para ${a[0]}...', Ln.info);
        return;
      }
      o('man: rootfs no instalado. Ejecuta "bootstrap".', Ln.stderr);
    });
  }
}
