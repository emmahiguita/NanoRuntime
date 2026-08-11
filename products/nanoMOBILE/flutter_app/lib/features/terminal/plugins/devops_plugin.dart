import '../terminal_types.dart';
import '../terminalservices.dart';
import '../../../core/services/kali_manager.dart';

/// DevOps commands: docker, kali, pty, interactive PTY commands,
/// script, crontab, watch, plugin management.
class DevOpsPlugin {
  void register(void Function(String, CmdFn) r, TerminalServices s) {

    r('docker', (a, c, o, af) {
      final d = s.docker;
      if (d == null) { o('docker: runtime no disponible', Ln.stderr); return; }
      final sub = a.isNotEmpty ? a[0] : '';
      switch (sub) {
        case 'pull':
          if (a.length < 2) { o('docker pull <imagen>', Ln.stderr); return; }
          final img = a[1];
          o('[docker] pull $img...', Ln.header);
          d.pull(img, (line) => o(line, Ln.system));
          break;
        case 'run':
          if (a.length < 2) { o('docker run <imagen> [cmd...]', Ln.stderr); return; }
          final img = a[1];
          final cmd = a.sublist(2);
          o('[docker] run $img ${cmd.join(" ")}', Ln.header);
          d.run(
            img,
            cmd,
            onOut: (l) => o(l, Ln.stdout),
            onErr: (l) => o(l, Ln.stderr),
          ).then((id) {
            if (!s.mounted) return;
            if (id != null) o('[docker] container ${id.substring(0, 12)} terminado', Ln.success);
          });
          break;
        case 'ps':
          final containers = d.ps();
          if (containers.isEmpty) {
            o('No hay contenedores activos.', Ln.info);
          } else {
            o('CONTAINER ID   IMAGE       STATUS    CREATED', Ln.header);
            for (final c in containers) {
              o('${c['id']}  ${c['image']}  ${c['status']}  ${c['created']}', Ln.stdout);
            }
          }
          break;
        case 'images':
          final imgs = d.images();
          if (imgs.isEmpty) {
            o('No hay imagenes. Usa "docker pull <imagen>".', Ln.info);
          } else {
            o('IMAGE           LAYERS', Ln.header);
            for (final i in imgs) {
              o('${i['name']}  ${i['layers']}', Ln.stdout);
            }
          }
          break;
        case 'rm':
          if (a.length < 2) { o('docker rm <id>', Ln.stderr); return; }
          d.rm(a[1]);
          o('[docker] contenedor ${a[1]} eliminado', Ln.success);
          break;
        case 'stop':
          if (a.length < 2) { o('docker stop <id>', Ln.stderr); return; }
          d.stop(a[1]);
          o('[docker] contenedor ${a[1]} detenido', Ln.success);
          break;
        default:
          o('docker pull <imagen>      — descargar imagen (ej: alpine)', Ln.info);
          o('docker run <imagen> [cmd] — ejecutar contenedor via proot', Ln.info);
          o('docker ps                 — listar contenedores', Ln.info);
          o('docker images             — listar imagenes', Ln.info);
          o('docker rm <id>            — eliminar contenedor', Ln.info);
          o('docker stop <id>          — detener contenedor', Ln.info);
      }
    });

    r('kali', (a, c, o, af) {
      final k = s.kali;
      final sub = a.isNotEmpty ? a[0] : '';
      switch (sub) {
        case 'install':
          if (k == null) { o('kali: manager no disponible', Ln.stderr); return; }
          if (k.isInstalled) { o('kali: ya instalado en ${k.kaliRoot}', Ln.success); return; }
          if (k.isDownloading) { o('kali: descarga en progreso...', Ln.info); return; }
          o('[kali] Descargando Kali Linux ARM64 (~200 MB)...', Ln.header);
          o('  URL: ${KaliManager.rootfsUrl}', Ln.info);
          k.install((stage, pct) {
            if (!s.mounted) return;
            if (stage == 'download' && pct < 100 && pct % 20 == 0) {
              o('[kali] descargando... $pct%', Ln.system);
            } else if (stage == 'extract' && pct < 100) {
              o('[kali] extrayendo rootfs...', Ln.system);
            } else if (stage == 'done') {
              o('[kali] Instalacion completa. Kali Linux ARM64 listo.', Ln.success);
              o('  Usa: kali shell  (bash dentro de Kali)', Ln.info);
              o('  Usa: kali run <cmd> (un comando en Kali)', Ln.info);
            } else if (stage == 'error') {
              o('[kali] Fallo la instalacion. Verifica conexion y espacio (~300 MB libres).', Ln.stderr);
            }
          });
          break;
        case 'shell':
          if (k == null || !k.isInstalled) { o('kali: no instalado. Ejecuta "kali install" primero.', Ln.stderr); return; }
          o('[kali] Shell interactiva (Kali ARM64 via proot)', Ln.header);
          k.shell(onOut: (l) => o(l, Ln.stdout), onErr: (l) => o(l, Ln.stderr));
          break;
        case 'run':
          if (a.length < 2) { o('kali run <comando>', Ln.stderr); return; }
          if (k == null || !k.isInstalled) { o('kali: no instalado.', Ln.stderr); return; }
          final cmd = a[1];
          final cmdArgs = a.sublist(2);
          o('[kali] $cmd ${cmdArgs.join(" ")}', Ln.system);
          k.run(cmd, cmdArgs, onOut: (l) => o(l, Ln.stdout), onErr: (l) => o(l, Ln.stderr));
          break;
        default:
          o('kali install  — descargar Kali Linux ARM64 (~200 MB)', Ln.info);
          o('kali shell    — abrir shell bash dentro de Kali', Ln.info);
          o('kali run <cmd> — ejecutar un comando en Kali', Ln.info);
          if (k != null) {
            o('  Instalado: ${k.isInstalled ? "SI" : "NO"}', k.isInstalled ? Ln.success : Ln.warn);
            o('  Rootfs: ${k.kaliRoot ?? "?"}', Ln.info);
          }
      }
    });

    r('pty', (a, c, o, af) {
      final usr = s.rootfs?.usrDir;
      if (usr == null) { o('pty: rootfs no instalado', Ln.stderr); return; }
      final bashPath = a.isNotEmpty ? a[0] : '$usr/bin/bash';
      o('pty: abriendo $bashPath...', Ln.info);
    });

    for (final inter in ['vim', 'vi', 'nano', 'python', 'python3',
                         'htop', 'less', 'more', 'man', 'mc', 'lynx']) {
      r(inter, (a, c, o, af) {
        final usr = s.rootfs?.usrDir;
        if (usr == null) { o('$inter: rootfs no instalado', Ln.stderr); return; }
        o('$inter: requiere PTY activo. Usa "pty $inter"', Ln.info);
      });
    }

    r('script', (a, c, o, af) {
      if (a.isEmpty) { o('script: uso: script cmd1; cmd2; cmd3...', Ln.stderr); return; }
      o('script: ejecutando...', Ln.info);
    });

    r('crontab', (a, c, o, af) {
      if (a.isEmpty || a[0] == '-l') {
        o('crontab: sin tareas programadas', Ln.stdout);
      } else if (a[0] == '-e') {
        o('crontab: editor no disponible en modo offline', Ln.stderr);
      } else {
        o('crontab: usa -l (listar) o -e (editar)', Ln.info);
      }
    });

    r('watch', (a, c, o, af) {
      if (a.isEmpty) { o('watch: uso: watch <comando>', Ln.stderr); return; }
      o('watch: ejecutando "${a.join(" ")}" cada 2s...', Ln.info);
    });

    r('plugin', (a, c, o, af) {
      if (a.isEmpty) { o('plugin: list, enable <plugin>, disable <plugin>', Ln.info); return; }
      if (a[0] == 'list') {
        final enabled = c.plugins.plugs.where((p) => p.enabled).toList();
        if (enabled.isEmpty) {
          o('plugin: no hay gestor de plugins', Ln.stderr);
          return;
        }
        for (final p in enabled) { o('  ${p.name}: enabled', Ln.stdout); }
        return;
      }
      o('plugin: ${a.join(" ")} — no implementado', Ln.info);
    });
  }
}
