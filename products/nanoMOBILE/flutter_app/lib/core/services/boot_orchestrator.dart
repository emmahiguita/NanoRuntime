import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:nanoai/core/config/app_boot_profile.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/package_service.dart';
import 'package:nanoai/core/services/rootfs_manager.dart';

/// Coordinates app startup tasks that touch native channels, disk and assets.
///
/// Kept outside widgets so the UI remains a composition layer. Startup is run
/// after the first Flutter frame to avoid blocking initial rendering.
class BootOrchestrator {
  BootOrchestrator({
    RootfsManager? rootfs,
    PackageService packageService = const PackageService(),
  }) : _rootfs = rootfs ?? RootfsManager.instance,
       _packageService = packageService;

  static const _essentialPackages = ['python', 'htop', 'git'];

  /// Librerías de runtime "completas" para que casi cualquier programa Linux
  /// funcione (multimedia, formatos, red, X11 extra, terminal, compresión,
  /// XML/DB). El DebInstaller resuelve las dependencias recursivamente, así
  /// que aquí van solo los paquetes top-level representativos.
  static const _runtimePackages = [
    // Multimedia / codecs
    'ffmpeg', 'gstreamer', 'gst-plugins-base', 'gst-plugins-good',
    'libvorbis', 'libogg', 'flac', 'opus-tools', 'libopus',
    'libx264', 'libx265', 'libvpx',
    // Formatos de imagen
    'libjpeg-turbo', 'libwebp', 'libtiff', 'librsvg',
    // Red / cripto
    'openssl', 'openssh', 'libgnutls', 'curl', 'wget', 'rsync',
    'netcat-openbsd', 'socat', 'nmap', 'tcpdump',
    // X11 extra (input, randr, composite, etc.)
    'libxcursor', 'libxrandr', 'libxinerama', 'libxfixes', 'libxcomposite',
    'libxi', 'libxtst', 'libxdamage',
    'xorg-xrandr', 'xorg-xdpyinfo', 'xdotool',
    // Terminal / texto
    'ncurses', 'readline', 'pcre', 'pcre2', 'libedit', 'less', 'man-db',
    'tmux', 'screen', 'tree', 'procps', 'util-linux', 'file', 'grep', 'sed',
    'gawk', 'findutils', 'diffutils', 'patch',
    // Compresión / archivado
    'zstd', 'xz-utils', 'p7zip', 'unzip', 'zip', 'bzip2', 'tar',
    // XML / DB
    'sqlite', 'libxml2', 'libxslt',
    // Dev / scripting — sin 'python3', 'gcc', 'g++', 'man-db' ni 'gpg':
    // el índice del rootfs embebido no los incluye y el DebInstaller ABORTA
    // la instalación completa si un solo objetivo falta (verificado en
    // dispositivo: "objetivos ausentes del índice"). Con ellos en la lista
    // el bootstrap fallaba SIEMPRE tras bloquear el hilo nativo ~15-20s.
    'python', 'perl', 'ruby', 'nodejs', 'npm', 'git', 'make', 'pkg-config',
    // Crypto / audit
    'gnupg',
    // Desktop integration
    'xdg-utils', 'xdg-user-dirs',
  ];

  final RootfsManager _rootfs;
  final PackageService _packageService;

  Future<void> run() async {
    try {
      // Handshake con el runtime nativo: verifica versión/capacidades antes
      // de que cualquier servicio toque rootfs o canales. Degrada con warning,
      // nunca bloquea el arranque.
      await NanoRuntimeApi.instance.handshake();

      // Perfil benchmark (C14-A): NO provisiona NanoLinux. La app queda
      // operativa (UI + runtime + automation); Linux se omite (no lo ejercita
      // C14-A) y el preflight lo registra como SKIPPED, no READY.
      if (AppBootProfile.current.skipsLinuxProvisioning) {
        debugPrint(
          '[boot] perfil=${AppBootProfile.current.name}: NanoLinux '
          'provisioning SKIPPED (no requerido para este perfil). '
          'Un fallo de Linux NO tumba el arranque: '
          'NanoRuntime y NanoAutomation ya están operativos.',
        );
        return;
      }

      await _ensureRootfs();
      if (!_rootfs.isInstalled) return;

      _setupBashrc();
      await _ensureEssentialPackages();
      await _ensureDesktopEnvironment();
      await _ensureRuntimeLibraries();
      await _deployDesktopEyeCandy();
    } catch (e, st) {
      debugPrint('[boot] startup failed: $e');
      debugPrint('$st');
    }
  }

  Future<void> _ensureRootfs() async {
    final installed = await _rootfs.checkInstalled();
    if (installed) {
      debugPrint('[boot] rootfs already installed at ${_rootfs.usrDir}');
      return;
    }

    debugPrint('[boot] rootfs missing; starting background bootstrap...');
    await _rootfs.install();
    debugPrint(
      '[boot] auto-bootstrap: ${_rootfs.isInstalled ? "OK" : "FAILED"}',
    );
  }

  Future<void> _ensureEssentialPackages() async {
    final usr = _rootfs.usrDir;
    if (usr == null) return;

    final missing = <String>[];
    for (final package in _essentialPackages) {
      if (!File('$usr/bin/$package').existsSync()) missing.add(package);
    }

    if (missing.isEmpty) {
      debugPrint('[boot] essential packages already installed');
      return;
    }

    debugPrint('[boot] installing packages: ${missing.join(", ")}...');
    final ok = await _packageService.installPackages(missing);
    debugPrint('[boot] essential package install: ${ok ? "OK" : "FAILED"}');
  }

  Future<void> _ensureDesktopEnvironment() async {
    if (_isDesktopReady()) {
      debugPrint('[boot] desktop already installed');
      await _prepareVncEnvironment();
      debugPrint('[boot] desktop ready; VNC starts from Desktop shortcut');
      return;
    }

    debugPrint('[boot] installing VNC desktop...');
    final ok = await _packageService.installGraphical();
    debugPrint('[boot] desktop install: ${ok ? "OK" : "FAILED"}');
    if (!ok) return;

    await _prepareVncEnvironment();
    debugPrint(
      '[boot] desktop installed and ready; VNC starts from Desktop shortcut',
    );
  }

  bool _isDesktopReady() {
    final usr = _rootfs.usrDir;
    if (usr == null) return false;

    final libDir = Directory('$usr/lib');
    final evdevFile = File('$usr/share/X11/xkb/rules/evdev');

    final hasXcb =
        libDir.existsSync() &&
        libDir.listSync().any(
          (entry) => entry.path.split('/').last.startsWith('libxcb.so'),
        );

    return File('$usr/bin/Xvnc').existsSync() &&
        File('$usr/bin/openbox').existsSync() &&
        File('${libDir.path}/libpng16.so').existsSync() &&
        File('${libDir.path}/libbrotlidec.so').existsSync() &&
        File('${libDir.path}/libandroid-support.so').existsSync() &&
        hasXcb &&
        _existsAny([
          '${libDir.path}/libexpat.so.1',
          '${libDir.path}/libexpat.so',
        ]) &&
        _existsAny([
          '${libDir.path}/libfontconfig.so.1',
          '${libDir.path}/libfontconfig.so',
        ]) &&
        _existsAny([
          '${libDir.path}/libXfont2.so.2',
          '${libDir.path}/libXfont2.so',
          '${libDir.path}/libxfont2.so.2',
          '${libDir.path}/libxfont2.so',
        ]) &&
        evdevFile.existsSync() &&
        evdevFile.lengthSync() > 200;
  }

  bool _existsAny(List<String> paths) =>
      paths.any((path) => File(path).existsSync());

  /// Instala las librerías de runtime "completas" (multimedia, formatos, red,
  /// X11 extra, terminal, compresión). Idempotente: usa el binario ffmpeg como
  /// marcador (si ya está, el conjunto se instaló en un boot previo).
  Future<void> _ensureRuntimeLibraries() async {
    final usr = _rootfs.usrDir;
    if (usr == null) return;

    if (File('$usr/bin/ffmpeg').existsSync()) {
      debugPrint('[boot] runtime libraries already installed');
      return;
    }

    // Anti-ANR: si un intento previo ya falló, no reintentar en cada
    // arranque — la instalación completa corre en el hilo nativo y lo
    // bloquea ~15-20s (verificado: ANR "Input dispatching timed out" al
    // arrancar con el sistema bajo presión). Reintento manual disponible
    // en la pantalla Desktop Audit.
    final attempted = File('$usr/.runtime-libs-attempted');
    if (attempted.existsSync()) {
      debugPrint(
        '[boot] runtime libraries install: SKIPPED (intento previo falló)',
      );
      return;
    }

    debugPrint(
      '[boot] installing runtime libraries (${_runtimePackages.length} packages)...',
    );
    final ok = await _packageService.installPackages(_runtimePackages);
    if (!ok) {
      try {
        attempted.writeAsStringSync('1');
      } catch (_) {
        // Best effort: sin marcador, el próximo arranque reintentará.
      }
    }
    debugPrint('[boot] runtime libraries install: ${ok ? "OK" : "FAILED"}');
  }

  Future<void> _prepareVncEnvironment() async {
    final usr = _rootfs.usrDir;
    if (usr == null || !File('$usr/bin/Xvnc').existsSync()) return;

    try {
      debugPrint('[boot] preparing VNC environment...');
      _ensureCompatibilityLinks(usr);
      _ensureXkbSymlinks(usr);
      await _installXkbcompWrapper(usr);
      await _installShmemShim(usr);
      debugPrint('[boot] VNC environment ready (xkbcomp wrapper + shmem)');
    } catch (e) {
      debugPrint('[boot] VNC setup error: $e');
    }
  }

  void _ensureCompatibilityLinks(String usr) {
    void ensureLink(String path) {
      try {
        final link = Link(path);
        if (!link.existsSync()) link.createSync(usr, recursive: false);
      } catch (_) {
        // Best effort: compatibility links may be denied on some Android builds.
      }
    }

    ensureLink('/data/data/dev.nanoai.mobile/f');
    try {
      final canonicalAppDir = Directory(usr).parent.parent.parent.path;
      ensureLink('$canonicalAppDir/f');
    } catch (_) {}
  }

  void _ensureXkbSymlinks(String usr) {
    _forceRelativeLink('$usr/share/X11/xkb', '../xkeyboard-config-2');

    for (final dir in [
      'compat',
      'geometry',
      'keycodes',
      'rules',
      'symbols',
      'types',
    ]) {
      _forceRelativeLink('$usr/$dir', 'share/xkeyboard-config-2/$dir');
    }
  }

  /// Crea o corrige un symlink relativo en [linkPath] apuntando a
  /// [expectedTarget].
  ///
  /// Termux empaqueta xkeyboard-config con su propio symlink en
  /// share/X11/xkb que apunta a una ruta ABSOLUTA hardcodeada de
  /// com.termux (/data/data/com.termux/files/usr/share/xkeyboard-config-2).
  /// Ese symlink sobrevive intacto a la extraccion del .deb dentro de
  /// nuestro propio rootfs, y como ya "existe" al llegar aqui, el chequeo
  /// antiguo (solo crear si falta) nunca lo corregia: Xvnc terminaba
  /// siguiendo un symlink roto y fallaba con "Failed to activate virtual
  /// core keyboard". Por eso hay que comparar el target real contra el
  /// esperado y sobreescribir el symlink si no coincide, no solo crearlo
  /// cuando falta.
  void _forceRelativeLink(String linkPath, String expectedTarget) {
    try {
      final link = Link(linkPath);
      if (link.existsSync()) {
        String? current;
        try {
          current = link.targetSync();
        } catch (_) {
          current = null;
        }
        if (current == expectedTarget) return;
        link.deleteSync();
      } else {
        final type = FileSystemEntity.typeSync(linkPath, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          Directory(linkPath).deleteSync(recursive: true);
        } else if (type == FileSystemEntityType.file) {
          File(linkPath).deleteSync();
        }
      }
      link.createSync(expectedTarget, recursive: false);
    } catch (_) {
      // Best effort: algunos builds de Android niegan symlinks.
    }
  }

  Future<void> _installXkbcompWrapper(String usr) async {
    try {
      const assetPath = 'assets/exe/xkbcomp';
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      if (bytes.length < 50000) {
        debugPrint('[boot] invalid xkbcomp asset (${bytes.length} bytes)');
        return;
      }

      for (final loc in ['$usr/xkbcomp.real', '$usr/xkbcomp']) {
        final file = File(loc);
        if (file.existsSync() && file.lengthSync() >= 50000) continue;
        file.writeAsBytesSync(bytes);
        _chmodExecutable(loc);
        debugPrint('[boot] xkbcomp deployed at $loc (${bytes.length} bytes)');
      }

      final wrapper = File('$usr/bin/xkbcomp');
      wrapper.writeAsStringSync(r'''#!/system/bin/sh
PREFIX=/data/user/0/dev.nanoai.mobile/files/nano/usr
IN="$PREFIX/tmp/xkbcomp-$$.stdin"
LOG="$PREFIX/tmp/xkbcomp.log"
export LD_LIBRARY_PATH="$PREFIX/lib:/system/lib64"
export XKB_CONFIG_ROOT="$PREFIX/share/X11/xkb"
export NANO_ROOTFS="$PREFIX"
echo "--- xkbcomp call ---" >> "$LOG"
echo "args: $@" >> "$LOG"
cat > "$IN"
/system/bin/linker64 "$PREFIX/xkbcomp.real" "$@" < "$IN" >> "$LOG" 2>&1
RC=$?
echo "rc=$RC" >> "$LOG"
rm -f "$IN"
exit $RC
''');
      _chmodExecutable(wrapper.path);
      debugPrint('[boot] xkbcomp wrapper deployed at ${wrapper.path}');
    } catch (e) {
      debugPrint('[boot] xkbcomp wrapper error: $e');
    }
  }

  Future<void> _installShmemShim(String usr) async {
    try {
      const assetPath = 'assets/exe/libandroid-shmem.so';
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      if (bytes.length < 1000) {
        debugPrint(
          '[boot] invalid libandroid-shmem asset (${bytes.length} bytes)',
        );
        return;
      }

      final loc = '$usr/lib/libandroid-shmem.so';
      File(loc).writeAsBytesSync(bytes);
      debugPrint(
        '[boot] libandroid-shmem shim deployed at $loc (${bytes.length} bytes)',
      );
    } catch (e) {
      debugPrint('[boot] libandroid-shmem asset error: $e');
    }
  }

  /// Despliega el HUD de bienvenida (hud.py) al home del rootfs.
  /// Idempotente y no destructivo: escribe solo si faltan o cambió el tamaño.
  /// DESKTOP-POLISH-01: fuera el wallpaper PNG — el fondo es la galaxia
  /// procedural que DesktopSessionManager genera a la resolución del fb.
  /// Lo consume lxterminal -e (banner de bienvenida).
  Future<void> _deployDesktopEyeCandy() async {
    final usr = _rootfs.usrDir;
    if (usr == null) return;

    final homeDir = Directory('${File(usr).parent.path}/home');
    if (!homeDir.existsSync()) return;

    for (final entry in const [
      ('assets/exe/hud.py', '.hud.py'),
    ]) {
      try {
        final data = await rootBundle.load(entry.$1);
        final bytes = data.buffer.asUint8List();
        if (bytes.length < 500) continue;
        final target = File('${homeDir.path}/${entry.$2}');
        if (target.existsSync() && target.lengthSync() == bytes.length) {
          continue;
        }
        target.writeAsBytesSync(bytes);
        debugPrint(
          '[boot] eye candy desplegado: ${entry.$2} '
          '(${bytes.length} bytes)',
        );
      } catch (e) {
        debugPrint('[boot] eye candy ${entry.$2}: $e');
      }
    }
  }

  void _setupBashrc() {
    final usr = _rootfs.usrDir;
    if (usr == null) return;

    final homeDir = Directory('${File(usr).parent.path}/home');
    if (!homeDir.existsSync()) homeDir.createSync(recursive: true);

    final bashrc = File('${homeDir.path}/.bashrc');
    if (bashrc.existsSync()) return;

    bashrc.writeAsStringSync(r'''
# NanoAI Terminal .bashrc
export PS1='\[\e[32m\]\u@nano\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'
alias free='free -h'
alias pkg='apt'
alias py='python3'
alias nv='nvtop'
export TERM=xterm-256color
export PAGER=less
export EDITOR=vim
''');
    debugPrint('[boot] .bashrc created at ${homeDir.path}');
  }

  void _chmodExecutable(String path) {
    try {
      Process.runSync('chmod', ['755', path]);
    } catch (_) {}
  }
}
