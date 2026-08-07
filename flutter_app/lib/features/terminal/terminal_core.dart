import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/services/llm_engine_client.dart';
import '../../core/services/shell_executor.dart';
import '../../core/services/rootfs_manager.dart';
import '../../core/services/proot_manager.dart';
import '../../core/services/kali_manager.dart';
import '../../core/services/docker_manager.dart';
import '../../core/services/proc_fs.dart';
import '../../core/services/pty_shell.dart';
import '../../core/services/terminal_dependencies.dart';
import 'terminal_subsystems.dart';
import 'noar_panel.dart';
import 'ansi_terminal.dart';
import 'command_dispatcher.dart';
import 'pty_manager.dart';
import 'terminal_types.dart';

/* ================================================================
   NanoTerminal Core — SOLID architecture
   Types in terminal_types.dart | Commands in command_dispatcher.dart
   ================================================================ */

class NanoTerminal extends StatefulWidget {
  final int sessionId; final String initialCwd; final LLMEngineClient? engine;
  final void Function(String title)? onTitle;
  final TerminalDependencies? deps; // optional override for testing
  const NanoTerminal({super.key, this.sessionId = 0, this.initialCwd = '/home/nanoai', this.engine, this.onTitle, this.deps});
  @override State<NanoTerminal> createState() => _TermState();
}

class _TermState extends State<NanoTerminal> {
  // ── Injected dependencies (via TerminalDependencies) ──
  TerminalDependencies get _deps => widget.deps ?? TerminalDependencies.instance;
  ShellExecutor? get _shell => _deps.shell;
  RootfsManager? get _rootfs => _deps.rootfs;
  ProotManager? get _proot => _deps.proot;
  KaliManager? get _kali => _deps.kali;
  DockerManager? get _docker => _deps.docker;

  // ── UI state ──
  final _in = TextEditingController(), _sc = ScrollController(), _fn = FocusNode();
  final _lines = <TL>[], _hist = <String>[], _timers = <Timer>[];
  final _cronJobs = <_CronJob>[];
  final _ctx = TerminalCtx();
  int _hIdx = -1; bool _ctrl = false, _alive = true;
  LLMEngineClient? _engine;
  // SesiÃ³n PTY activa: terminal interactivo (vim, htop, python REPL, bash -i).
  // Cuando no es null, ^ el input del usuario va a la sesiÃ³n PTY, no al parser.
  PtySession? _pty;
  final _ptyLines = <String>[]; // buffer acumulado del output PTY
  // Buffer ANSI/VT100 del PTY activo: cuando _pty no es null, el Ã¡rea de
  // salida se renderiza con AnsiTerminalView (parsea colores/cursor) en vez
  // de las lÃ­neas de texto plano.
  AnsiTerminal? _ansi;
  final _cmds = <String, CmdFn>{};
  CommandDispatcher? _dispatcher;
  PtyManager? _ptyManager;

  // ── Rootfs helpers (single source of truth) ──
  String get _baseDir {
    final usr = _shell?.usrDir ?? _rootfs?.usrDir ?? '';
    return usr.endsWith('/usr') ? usr.substring(0, usr.length - 4) : usr;
  }

  String get _usrDir => _shell?.usrDir ?? _rootfs?.usrDir ?? '';

  /// Mapa de entorno canónico del rootfs. Todas las ejecuciones (pkg, apt,
  /// PTY, ash) usan este método como base. Parámetros opcionales para
  /// LD_PRELOAD y overrides específicos.
  Map<String, String> _rootfsEnv({String? ldPreload, Map<String, String>? extra}) {
    final usr = _usrDir;
    final base = _baseDir;
    return {
      'HOME': '$base/home',
      'PREFIX': usr,
      'PATH': '$usr/bin:$usr/bin/applets:/system/bin:/system/xbin',
      'LD_LIBRARY_PATH': '$usr/lib',
      'TMPDIR': '$usr/tmp',
      'SHELL': '$usr/bin/bash',
      'TERM': 'xterm-256color',
      'LANG': 'en_US.UTF-8',
      'TERMUX': 'true',
      'TERMUX_PREFIX': usr,       // apt & pkg require this
      'TERMUX_HOME': '$base/home', // apt config path
      'ANDROID_DATA': '/data',
      'ANDROID_ROOT': '/system',
      if (ldPreload != null && ldPreload.isNotEmpty) 'LD_PRELOAD': ldPreload,
      if (ldPreload != null && ldPreload.isNotEmpty) 'NANO_ROOTFS': usr,
      if (extra != null) for (final e in extra.entries) e.key: e.value,
    };
  }

  // â”€â”€ FAB draggable â”€â”€
  Offset _fabOffset = Offset.zero;
  bool _fabInit = false;
  static const double _fabSize = 40;

  // â”€â”€ REAL EXECUTION: operaciones reales sobre el filesystem del device â”€â”€
  // Hay DOS filesystems:
  //   1. _realRoot (systemTemp/nano_real_root/): FS virtual para dart:io
  //      (ls, cat, mkdir, etc.). Sandbox aislado, no toca el rootfs.
  //   2. Termux rootfs (files/nano/usr/): binarios reales ARM64 ejecutados
  //      vÃ­a bash/toybox. Gestionado por RootfsManager + ShellExecutor.
  // Estos dos FS son independientes. El prompt muestra el _realRoot cwd;
  // los comandos con ! o pipes usan el rootfs Termux.
  late final Directory _realRoot;
  late Directory _realCwd;
  // Track del cwd dentro del rootfs Termux (aproximado, se actualiza con !cd).
  String _bashCwd = '/';
  // Comandos con implementaciÃ³n REAL (dart:io + MethodChannel).
  // No dependen de execve â€” usan llamadas directas al sistema.
  /// Comandos que se ejecutan REAL vÃ­a BusyBox (Nanoshell FFI).
  /// Estos 80+ comandos cubren ~95% del uso cotidiano de terminal.
  /// El resto (simulados/dart:io) se usan como fallback si BusyBox falla.
  static const _realCmds = {
    // â”€â”€ filesystem â”€â”€
    'ls', 'cat', 'echo', 'mkdir', 'touch', 'rm', 'cp', 'mv',
    'wc', 'grep', 'find', 'pwd', 'cd',
    'head', 'tail', 'sort', 'uniq', 'cut', 'tr',
    'stat', 'file', 'which', 'xargs', 'tee', 'ln', 'readlink',
    'realpath', 'dirname', 'basename', 'chmod', 'chown', 'chgrp',
    'rmdir', 'du', 'df', 'sync',

    // â”€â”€ shell builtins â”€â”€
    'test', 'expr', 'true', 'false', 'yes', 'seq', 'sleep',
    'clear', 'reset', 'env', 'printenv', 'printf', 'id', 'whoami',
    'uname', 'hostname', 'uptime', 'date', 'cal', 'dmesg',
    'watch',

    // â”€â”€ process â”€â”€
    'ps', 'kill', 'pgrep', 'pkill', 'pidof', 'top', 'free',
    'vmstat', 'iotop',

    // â”€â”€ network â”€â”€
    'wget', 'ping', 'netstat', 'nslookup', 'ifconfig', 'route',
    'arp', 'nc',

    // â”€â”€ archive/compress â”€â”€
    'tar', 'gzip', 'gunzip', 'bzip2', 'bunzip2', 'xz', 'unxz',
    'unzip', 'zip',

    // â”€â”€ text editing â”€â”€
    'vi', 'sed', 'awk', 'diff', 'patch', 'cmp',
  };

  // Identidad real del device (uid, uname, hostname, meminfo...).
  // Se puebla async en initState; los handlers de comando la consultan
  // en runtime. Si aÃºn no estÃ¡ disponible, usan fallback razonable.
  Map<String, dynamic>? _devId;

  // â”€â”€ DRY: PS1 prompt getter â”€â”€
  String get _ps1 {
    final h = _devId?['hostname'] as String? ?? 'oppo';
    final rootP = _realRoot.path.replaceAll(r'\', '/');
    final cwdP = _realCwd.path.replaceAll(r'\', '/');
    String home;
    if (cwdP == rootP) {
      home = '~';
    } else if (cwdP.startsWith(rootP)) {
      home = cwdP.substring(rootP.length);
      if (home.isEmpty) home = '/';
    } else {
      home = cwdP; // fuera del root: mostrar path real completo
    }
    return 'nanoai@$h:$home\$ ';
  }

  // â”€â”€ Output helpers â”€â”€
  static const int _maxLines = 10000;
  bool _scrollPending = false;

  void _out(String t, Ln ty) {
    if (t.isEmpty && ty == Ln.stdout) return;
    setState(() {
      _lines.add(TL(t, ty));
      if (_lines.length > _maxLines) _lines.removeRange(0, _lines.length - _maxLines);
    });
    if (!_scrollPending) {
      _scrollPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollPending = false;
        if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent);
      });
    }
  }
  void _after(Duration d, VoidCallback cb) { final t = Timer(d, () { if (_alive) cb(); }); _timers.add(t); }

  @override void initState() {
    super.initState(); _engine = widget.engine ?? LLMEngineClient(); _ctx.fs.cwd = widget.initialCwd;
    _buildRegistry(); // terminal-specific commands (ai, gpu, docker, kali, etc.)
    _initRealRoot(); // sÃ­ncrono: garantiza _realCwd antes del primer prompt
    _fetchDeviceIdentity(); // async: uid, uname, hostname reales del device
    _initShell(); // async: extrae bash/toybox + verifica rootfs (crea ShellExecutor + RootfsManager compartidos)
    _loadNoar(); // async: carga librerÃ­a de comandos guardados
    // Init FAB position after first frame so MediaQuery is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_fabInit && mounted) {
        final sz = MediaQuery.of(context).size;
        setState(() {
          _fabOffset = Offset(sz.width - _fabSize - 12, sz.height * 0.35);
          _fabInit = true;
        });
      }
    });
    _out('NanoTerminal — rootfs ARM64', Ln.header);
    _out('Modo: auto-PTY (bash interactivo real)', Ln.info);
    _out('', Ln.stdout);
    _loadHistory(); HardwareKeyboard.instance.addHandler(_onKey);
  }

  /// Crea el dir raÃ­z del FS real y siembra archivos demo. Usa systemTemp
  /// como base (no requiere MethodChannel, disponible en test y device).
  void _initRealRoot() {
    _realRoot = Directory('${Directory.systemTemp.path}/nano_real_root');
    if (!_realRoot.existsSync()) _realRoot.createSync(recursive: true);
    _realCwd = _realRoot;
    final here = _realRoot.path.replaceAll(r'\', '/');
    // Siembra inicial del FS real.
    for (final d in ['models', 'workspace', 'logs']) {
      final dd = Directory('$here/$d');
      if (!dd.existsSync()) dd.createSync(recursive: true);
    }
    final w = File('$here/workspace/main.dart'); if (!w.existsSync()) w.writeAsStringSync('void main() => runApp(NanoAIApp());\n');
    final r = File('$here/workspace/README.md'); if (!r.existsSync()) r.writeAsStringSync('# NanoAI\nMotor LLM Local\n');
    final q = File('$here/models/qwen2.5-1.5b.gguf'); if (!q.existsSync()) q.writeAsStringSync('');
    final cfg = File('$here/models/config.json'); if (!cfg.existsSync()) cfg.writeAsStringSync('{"temperature":0.7,"top_p":0.9,"context":2048}');
    final lg = File('$here/logs/nanortime.log'); if (!lg.existsSync()) lg.writeAsStringSync('[14:32:01] Boot OK\n[14:32:02] madvise 24 layers\n[14:32:15] OOM Guard: 0');
  }

  /// Obtiene identidad real del device (uid, uname, hostname, meminfo...)
  /// desde la plataforma. Los comandos usan estos datos para devolver info
  /// autÃ©ntica sin depender de execve() (bloqueado por SELinux en este device).
  Future<void> _fetchDeviceIdentity() async {
    try {
      const ch = MethodChannel('com.nanoai/device_metrics');
      _devId = Map<String, dynamic>.from(
        await ch.invokeMethod('getDeviceIdentity') as Map? ?? {},
      );
    } catch (e) {
      _devId = null; // handlers usan fallbacks hardcodeados
    }
  }

  /// Lee temperatura del CPU desde thermal_zones del kernel Linux.
  /// Prueba varias rutas comunes en Android (Snapdragon, Mediatek, Exynos).
  /// Retorna Â°C o null si ninguna ruta es legible.
  double? _readCpuTemp() {
    const paths = [
      '/sys/class/thermal/thermal_zone0/temp',
      '/sys/class/thermal/thermal_zone1/temp',
      '/sys/devices/virtual/thermal/thermal_zone0/temp',
      '/sys/class/hwmon/hwmon0/temp1_input',
    ];
    for (final p in paths) {
      try {
        final raw = File(p).readAsStringSync().trim();
        final v = double.tryParse(raw);
        if (v == null) continue;
        // > 200 probablemente es millidegrees (ej: 38500 = 38.5Â°C)
        return v > 200 ? v / 1000.0 : v;
      } catch (_) {}
    }
    return null;
  }

  /// Lee informaciÃ³n de GPU desde /sys/class/kgsl/kgsl-3d0/ (Adreno)
  /// o /sys/kernel/gpu/ (Mali). Retorna Map con name, freqMhz, tempC,
  /// gpuLoad, gpuMemMb. Campos ausentes si la ruta no existe en el device.
  Map<String, dynamic> _readGpuInfo() {
    final info = <String, dynamic>{};
    // Adreno (Qualcomm Snapdragon)
    const kgslBase = '/sys/class/kgsl/kgsl-3d0';
    try {
      final gpuclk = File('$kgslBase/gpuclk').readAsStringSync().trim();
      final hz = int.tryParse(gpuclk);
      if (hz != null) info['freqMhz'] = (hz / 1000000).round();
    } catch (_) {}
    try {
      final gpuBusy = File('$kgslBase/gpubusy').readAsStringSync().trim();
      // Formato: "busy_time total_time"
      final parts = gpuBusy.split(RegExp(r'\s+'));
      if (parts.length == 2) {
        final busy = double.tryParse(parts[0]);
        final total = double.tryParse(parts[1]);
        if (busy != null && total != null && total > 0) {
          info['gpuLoad'] = (busy / total * 100).roundToDouble();
        }
      }
    } catch (_) {}
    try {
      final devfreq = File('$kgslBase/devfreq/cur_freq').readAsStringSync().trim();
      final hz = int.tryParse(devfreq);
      if (hz != null && !info.containsKey('freqMhz')) {
        info['freqMhz'] = (hz / 1000000).round();
      }
    } catch (_) {}
    // GPU temperature (thermal_zone varies by device)
    const tempZones = [
      '/sys/class/kgsl/kgsl-3d0/temp',
      '/sys/class/thermal/thermal_zone2/temp',
      '/sys/class/thermal/thermal_zone5/temp',
    ];
    for (final p in tempZones) {
      try {
        final raw = File(p).readAsStringSync().trim();
        final v = double.tryParse(raw);
        if (v != null) {
          info['tempC'] = v > 200 ? v / 1000.0 : v;
          break;
        }
      } catch (_) {}
    }
    // GPU name from dtb/model or fallback to SoC
    try {
      final nameFile = File('$kgslBase/name');
      if (nameFile.existsSync()) {
        info['name'] = nameFile.readAsStringSync().trim();
      }
    } catch (_) {}
    // Legacy Mali GPU path
    if (!info.containsKey('name')) {
      try {
        final mali = File('/sys/kernel/gpu/gpu_model');
        if (mali.existsSync()) info['name'] = mali.readAsStringSync().trim();
      } catch (_) {}
    }
    // Fallback: detectar del cpuHardware
    if (!info.containsKey('name')) {
      final hw = _devId?['cpuHardware'] as String? ?? '';
      if (hw.contains('SDM') || hw.contains('SM') || hw.contains('SC')) {
        info['name'] = 'Adreno';
      } else if (hw.contains('MT')) {
        info['name'] = 'Mali';
      } else if (hw.contains('Exynos')) {
        info['name'] = 'Mali';
      }
    }
    // GPU dedicated memory size (Adreno)
    try {
      final memDesc = File('$kgslBase/mem_desc');
      if (memDesc.existsSync()) {
        info['gpuMemMb'] = 512; // Most mid-range Adreno: 512MB carve-out
      }
    } catch (_) {}
    return info;
  }

  /// Extrae bash y toybox de assets/bin/ al dir privado de la app y los
  /// marca ejecutables. Luego verifica/instala el rootfs Termux completo.
  ///
  /// Â¡IMPORTANTE! ShellExecutor y terminal_core comparten la MISMA instancia
  /// de RootfsManager para que el estado de instalaciÃ³n estÃ© sincronizado.
  Future<void> _initShell() async {
    // ── TerminalDependencies: init ordenado, compartido entre tabs ──
    if (_deps.rootfs == null) {
      await _deps.initAll(onProgress: (msg) => _out('[init] $msg', Ln.system));
    }
    // ── Create injected classes with services ready ──
    _dispatcher = CommandDispatcher(
      shell: _shell, rootfs: _rootfs,
      ctx: _ctx, out: _out, ptyOpen: (a) => _ptyOpen(a),
      getBaseDir: () => _baseDir, getUsrDir: () => _usrDir,
      rootfsEnv: _rootfsEnv,
    );
    _dispatcher!.buildRegistry();
    _ptyManager = PtyManager(
      shell: _shell, rootfs: _rootfs,
      rootfsEnv: _rootfsEnv, onTitle: widget.onTitle,
    );

    if (_shell?.initialized == true) {
      _out('[shell] bash + toybox listos en ${_shell!.binDir}', Ln.system);
    }

    final installed = _rootfs?.isInstalled == true;
    if (installed) {
      _out('[rootfs] detectado en ${_rootfs!.usrDir}', Ln.success);
      _applyRootfsEnv();
      _after(const Duration(milliseconds: 500), () => _ptyOpen(['bash']));
    } else {
      _out('[rootfs] no instalado. Ejecuta "bootstrap".', Ln.info);
    }

    if (_proot != null && _proot!.isReady) {
      _out('[proot] listo — chroot sin root disponible', Ln.system);
    } else {
      _out('[proot] no disponible (ptrace bloqueado por SELinux?)', Ln.warn);
    }

    // Kali + Docker: via container
    // Services are now accessed via _deps getter — no local fields to sync
    if (_kali != null) {
      await _kali!.checkInstalled();
      if (_kali!.isInstalled) _out('[kali] detectado en ${_kali!.kaliRoot}', Ln.success);
    }
    if (_docker != null) {
      _out('[docker] runtime listo', Ln.system);
    }
  }

  /// Aplica las variables de entorno reales del rootfs al TerminalCtx.
  /// Crea HOME y TMPDIR para que bash no falle al escribir archivos de sesiÃ³n.
  /// Incluye variables de identidad Termux que los paquetes .deb esperan.
  void _applyRootfsEnv() {
    if (_shell == null || _shell!.usrDir == null || _shell!.baseDir == null) return;
    final usr = _shell!.usrDir!;
    final base = _shell!.baseDir!;
    // â”€â”€ Paths â”€â”€
    _ctx.env['HOME'] = '$base/home';
    _ctx.env['PREFIX'] = usr;
    _ctx.env['PATH'] = '$usr/bin:$usr/bin/applets:/system/bin:/system/xbin';
    _ctx.env['SHELL'] = '$usr/bin/bash';
    _ctx.env['TMPDIR'] = '$usr/tmp';
    _ctx.env['LD_LIBRARY_PATH'] = '$usr/lib';
    // â”€â”€ Termux identity â”€â”€
    _ctx.env['TERMUX'] = 'true';
    _ctx.env['TERMUX_VERSION'] = '0.118.0';
    _ctx.env['TERMUX_APP__PID'] = '${pid}';
    _ctx.env['TERMUX_APK_RELEASE'] = 'F_DROID';
    _ctx.env['TERMUX_APP__IS_DEBUGGABLE'] = 'false';
    _ctx.env['ANDROID_DATA'] = '/data';
    _ctx.env['ANDROID_ROOT'] = '/system';
    _ctx.env['LANG'] = 'en_US.UTF-8';
    // â”€â”€ Sincronizar bash cwd con HOME del rootfs â”€â”€
    _bashCwd = '$base/home';
    // â”€â”€ Crear directorios necesarios â”€â”€
    try { Directory('$base/home').createSync(recursive: true); } catch (_) {}
    try { Directory('$usr/tmp').createSync(recursive: true); } catch (_) {}
    try { Directory('$usr/var/lib/dpkg').createSync(recursive: true); } catch (_) {}
    try { Directory('$usr/var/log').createSync(recursive: true); } catch (_) {}
  }

  // â”€â”€ REAL ENGINE: operaciones con dart:io (sin execve) â”€â”€

  /// Convierte un path virtual (estilo /home/nanoai/...) a path real en el
  /// filesystem del device. Paths absolutos parten de _realRoot; relativos
  /// parten de _realCwd.
  String _toReal(String virt) {
    final clean = virt.replaceAll(r'\', '/');
    if (clean.isEmpty || clean == '.') return _realCwd.path;
    if (clean.startsWith('/')) return '${_realRoot.path}/${clean.substring(1)}';
    return '${_realCwd.path}/$clean';
  }

  /// Ejecuta un comando real usando dart:io directamente (sin execve).
  /// Retorna (stdout, stderr, exitCode) o null si el comando no estÃ¡
  /// implementado en el motor real (â†’ fallback al simulador).
  (String, String, int)? _runRealSync(String cmd, List<String> args) {
    if (!_realCmds.contains(cmd)) return null;
    try {
      switch (cmd) {
        case 'ls':     return _realLs(args);
        case 'cat':    return _realCat(args);
        case 'echo':   final out = args.join(' '); return (out, '', 0);
        case 'pwd':    return _realPwd();
        case 'cd':     return _realCd(args);
        case 'mkdir':  return _realMkdir(args);
        case 'touch':  return _realTouch(args);
        case 'rm':     return _realRm(args);
        case 'cp':     return _realCp(args);
        case 'mv':     return _realMv(args);
        case 'wc':     return _realWc(args);
        case 'grep':   return _realGrep(args);
        case 'find':   return _realFind(args);
        case 'head':   return _realHead(args);
        case 'tail':   return _realTail(args);
        default:       return null;
      }
    } catch (e) {
      return ('', '$e', 1);
    }
  }

  // â”€â”€ Implementaciones reales â”€â”€

  (String, String, int) _realLs(List<String> args) {
    final long = args.any((a) => a.startsWith('-') && a.contains('l'));
    final all = args.any((a) => a.startsWith('-') && a.contains('a'));
    final pathArg = args.where((a) => !a.startsWith('-')).isEmpty
        ? _realCwd.path : _toReal(args.firstWhere((a) => !a.startsWith('-')));
    final dir = Directory(pathArg);
    if (!dir.existsSync()) return ('', 'ls: ${args.lastWhere((a) => !a.startsWith('-'), orElse: () => '.')}: No such file or directory', 2);
    final entries = dir.listSync();
    final buf = StringBuffer();
    if (long) buf.writeln('total ${entries.length}');
    for (final e in entries) {
      final name = e.uri.pathSegments.last;
      if (!all && name.startsWith('.')) continue;
      final stat = e.statSync();
      final type = stat.type == FileSystemEntityType.directory ? 'd' : '-';
      final perms = 'rwxr-xr-x';
      final size = stat.size;
      if (long) {
        buf.writeln('$type$perms nanoai nanoai ${size.toString().padLeft(8)} $name${type == 'd' ? '/' : ''}');
      } else {
        buf.writeln('$name${type == 'd' ? '/' : ''}');
      }
    }
    return (buf.toString().trimRight(), '', 0);
  }

  (String, String, int) _realCat(List<String> args) {
    if (args.isEmpty) return ('', 'cat: falta archivo', 1);
    final path = _toReal(args[0]);
    final f = File(path);
    if (!f.existsSync()) return ('', 'cat: ${args[0]}: No such file or directory', 1);
    return (f.readAsStringSync(), '', 0);
  }

  (String, String, int) _realPwd() {
    final virt = _realCwd.path.replaceAll(r'\', '/');
    final root = _realRoot.path.replaceAll(r'\', '/');
    if (virt == root) return ('/', '', 0);
    if (virt.startsWith(root)) {
      final rel = virt.substring(root.length);
      return (rel.isEmpty ? '/' : rel, '', 0);
    }
    // cd .. fue mÃ¡s allÃ¡ del root â€” mostrar el path real completo
    return (virt, '', 0);
  }

  (String, String, int) _realCd(List<String> args) {
    final target = args.isEmpty ? _realRoot.path : _toReal(args[0]);
    final dir = Directory(target);
    if (!dir.existsSync()) return ('', 'cd: ${args[0]}: No such directory', 1);
    _realCwd = dir.absolute;
    return ('', '', 0);
  }

  (String, String, int) _realMkdir(List<String> args) {
    if (args.isEmpty) return ('', 'mkdir: falta nombre', 1);
    final path = _toReal(args[0]);
    Directory(path).createSync(recursive: true);
    return ('', '', 0);
  }

  (String, String, int) _realTouch(List<String> args) {
    if (args.isEmpty) return ('', 'touch: falta nombre', 1);
    final path = _toReal(args[0]);
    final f = File(path);
    if (f.existsSync()) {
      f.setLastModifiedSync(DateTime.now());
    } else {
      f.createSync(recursive: true);
    }
    return ('', '', 0);
  }

  (String, String, int) _realRm(List<String> args) {
    final recursive = args.contains('-r') || args.contains('-rf');
    final paths = args.where((a) => !a.startsWith('-')).toList();
    if (paths.isEmpty) return ('', 'rm: falta path', 1);
    for (final p in paths) {
      final path = _toReal(p);
      final entity = FileSystemEntity.typeSync(path);
      if (entity == FileSystemEntityType.notFound) {
        return ('', 'rm: $p: No such file or directory', 1);
      }
      if (entity == FileSystemEntityType.directory) {
        if (recursive) Directory(path).deleteSync(recursive: true);
        else return ('', 'rm: $p: is a directory', 1);
      } else {
        File(path).deleteSync();
      }
    }
    return ('', '', 0);
  }

  (String, String, int) _realCp(List<String> args) {
    if (args.length < 2) return ('', 'cp: origen y destino requeridos', 1);
    final src = _toReal(args[0]);
    final dst = _toReal(args[1]);
    if (FileSystemEntity.typeSync(src, followLinks: false) == FileSystemEntityType.notFound) return ('', 'cp: ${args[0]}: No such file', 1);
    if (FileSystemEntity.typeSync(src) == FileSystemEntityType.directory) {
      _copyDir(Directory(src), Directory(dst));
    } else {
      File(dst).parent.createSync(recursive: true);
      File(src).copySync(dst);
    }
    return ('', '', 0);
  }

  void _copyDir(Directory src, Directory dst) {
    dst.createSync(recursive: true);
    for (final e in src.listSync()) {
      final name = e.uri.pathSegments.last;
      if (e is Directory) {
        _copyDir(e, Directory('${dst.path}/$name'));
      } else if (e is File) {
        e.copySync('${dst.path}/$name');
      }
    }
  }

  (String, String, int) _realMv(List<String> args) {
    if (args.length < 2) return ('', 'mv: origen y destino requeridos', 1);
    final src = _toReal(args[0]);
    final dst = _toReal(args[1]);
    FileSystemEntity entity = File(src);
    if (!entity.existsSync()) return ('', 'mv: ${args[0]}: No such file', 1);
    entity.renameSync(dst);
    return ('', '', 0);
  }

  (String, String, int) _realWc(List<String> args) {
    if (args.isEmpty) return ('', 'wc: falta archivo', 1);
    final path = _toReal(args.last);
    final f = File(path);
    if (!f.existsSync()) return ('', 'wc: ${args.last}: No such file', 1);
    final content = f.readAsStringSync();
    final lines = content.split('\n').length;
    final words = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = content.length;
    var out = '$lines $words $chars';
    if (args.length > 1) out += ' ${args.last}';
    return (out, '', 0);
  }

  (String, String, int) _realGrep(List<String> args) {
    if (args.length < 2) return ('', 'grep: pattern y archivo requeridos', 1);
    final pattern = args[0];
    final ignoreCase = args.any((a) => a == '-i');
    final file = _toReal(args.last);
    final f = File(file);
    if (!f.existsSync()) return ('', 'grep: ${args.last}: No such file', 1);
    final lines = f.readAsLinesSync();
    final buf = StringBuffer();
    for (final line in lines) {
      final match = ignoreCase
          ? line.toLowerCase().contains(pattern.toLowerCase())
          : line.contains(pattern);
      if (match) buf.writeln(line);
    }
    final out = buf.toString().trimRight();
    if (out.isEmpty) return ('', '', 1);
    return (out, '', 0);
  }

  (String, String, int) _realFind(List<String> args) {
    final start = args.isEmpty ? _realCwd.path : _toReal(args[0]);
    final dir = Directory(start);
    if (!dir.existsSync()) return ('', 'find: ${args.isNotEmpty ? args[0] : '.'}: No such file', 1);
    final buf = StringBuffer();
    void walk(Directory d, String prefix) {
      for (final e in d.listSync()) {
        final name = e.uri.pathSegments.last;
        final full = '$prefix/$name';
        buf.writeln(full);
        if (e is Directory) walk(e, full);
      }
    }
    walk(dir, start == _realRoot.path ? '' : start);
    return (buf.toString().trimRight(), '', 0);
  }

  (String, String, int) _realHead(List<String> args) {
    final n = int.tryParse(args.firstWhere((a) => a.startsWith('-n'), orElse: () => '-n10').replaceAll(RegExp(r'-n=?'), '')) ?? 10;
    final file = args.lastWhere((a) => !a.startsWith('-'));
    final path = _toReal(file);
    final f = File(path);
    if (!f.existsSync()) return ('', 'head: $file: No such file', 1);
    final lines = f.readAsLinesSync().take(n).join('\n');
    return (lines, '', 0);
  }

  (String, String, int) _realTail(List<String> args) {
    final n = int.tryParse(args.firstWhere((a) => a.startsWith('-n'), orElse: () => '-n10').replaceAll(RegExp(r'-n=?'), '')) ?? 10;
    final file = args.lastWhere((a) => !a.startsWith('-'));
    final path = _toReal(file);
    final f = File(path);
    if (!f.existsSync()) return ('', 'tail: $file: No such file', 1);
    final lines = f.readAsLinesSync();
    final out = lines.skip(lines.length - n).join('\n');
    return (out, '', 0);
  }

  Widget _modifierRow(Color fg, Color chrome) {
    final style = TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11, color: fg.withValues(alpha: 0.7));
    Widget key(String label, VoidCallback onTap, {String? longLabel}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: fg.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
          child: Text(longLabel ?? label, style: style),
        ),
      );
    }
    return Container(
      color: chrome,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        key('Esc', () => _pty?.writeBytes([0x1b])),
        key('Ctrl', () { _ctrl = !_ctrl; setState(() {}); }, longLabel: _ctrl ? 'Ctrl ON' : 'Ctrl'),
        key('Tab', () => _pty?.writeBytes([0x09])),
        const SizedBox(width: 8),
        key('<', () => _pty?.writeBytes([0x1b, 0x5b, 0x44])),
        key('v', () => _pty?.writeBytes([0x1b, 0x5b, 0x42])),
        key('^', () => _pty?.writeBytes([0x1b, 0x5b, 0x41])),
        key('>', () => _pty?.writeBytes([0x1b, 0x5b, 0x43])),
        const SizedBox(width: 8),
        key('Paste', () async { final data = await Clipboard.getData(Clipboard.kTextPlain); final text = data?.text; if (text != null && _pty != null) { _pty!.write('\x1b[200~'); _pty!.writeBytes(utf8.encode(text)); _pty!.write('\x1b[201~'); } }),
        key('/', () => _pty?.writeBytes([0x2f])),
        key('-', () => _pty?.writeBytes([0x2d])),
        key('|', () => _pty?.writeBytes([0x7c])),
      ])),
    );
  }


  @override void dispose() { _saveHistory(); _alive = false; _ptyClose(); for (final t in _timers) t.cancel(); _timers.clear(); _engine?.dispose(); _shell?.killAll(); _docker?.dispose(); _in.dispose(); _sc.dispose(); _fn.dispose(); HardwareKeyboard.instance.removeHandler(_onKey); super.dispose(); }

  // â”€â”€ Command Registry (OCP: add new commands without touching _exec) â”€â”€
  /// Builds the legacy command registry. Common Linux commands (ls, cat, etc.)
  /// are handled by CommandDispatcher. This registry only adds terminal-specific
  /// commands (ai, gpu, docker, kali, help, noar, etc.) and simulated fallbacks.
  void _buildRegistry() {
    // CommandDispatcher covers: realCmds(80+), pkg, apt, pip3, node/npm, which,
    // host, interactive PTY, pty, bootstrap, vmstat, crontab.
    // This method only registers terminal-specific commands NOT in dispatcher.

    // System
    _cmds['help'] = (a, c, o, af) => _help(a, o);
    _cmds['clear'] = (a, c, o, af) => setState(() => _lines.clear());
    _cmds['date'] = (a, c, o, af) => o(a.contains('--utc') ? DateTime.now().toUtc().toIso8601String().substring(0, 19) : DateTime.now().toString().substring(0, 19), Ln.stdout);
    _cmds['whoami'] = (a, c, o, af) {
      final uid = _devId?['uid'] as int?;
      o(uid != null ? 'u0_a$uid' : c.env['USER']!, Ln.stdout);
    };
    _cmds['uname'] = (a, c, o, af) {
      final d = _devId;
      final sys = d?['uname_sysname'] as String? ?? 'Linux';
      final host = d?['hostname'] as String? ?? 'localhost';
      final rel = d?['uname_release'] as String? ?? 'unknown';
      final arch = d?['uname_machine'] as String? ?? 'aarch64';
      if (a.contains('-a')) {
        o('$sys $host $rel $arch GNU/Linux', Ln.stdout);
      } else if (a.contains('-r')) {
        o(rel, Ln.stdout);
      } else if (a.contains('-m')) {
        o(arch, Ln.stdout);
      } else if (a.contains('-n')) {
        o(host, Ln.stdout);
      } else {
        o(sys, Ln.stdout);
      }
    };
    _cmds['hostname'] = (a, c, o, af) => o((_devId?['hostname'] as String?) ?? 'localhost', Ln.stdout);
    _cmds['uptime'] = (a, c, o, af) {
      final sec = _devId?['uptimeSec'] as double?;
      if (sec == null) { o('up ??:??, 0 users', Ln.stdout); return; }
      final d = (sec / 86400).floor();
      final h = ((sec % 86400) / 3600).floor();
      final m = ((sec % 3600) / 60).floor();
      o('up ${d > 0 ? '$d days, ' : ''}$h:${m.toString().padLeft(2, '0')}, 1 user', Ln.stdout);
    };
    _cmds['id'] = (a, c, o, af) {
      final d = _devId;
      final uid = d?['uid'] as int?;
      final gid = d?['gid'] as int?;
      final groups = d?['groups'] as String?;
      if (uid == null) {
        o('uid=0(root) gid=0(root) groups=0(root)', Ln.stdout);
        return;
      }
      final gidStr = gid != null ? ' gid=$gid(u0_a$gid)' : '';
      final groupsStr = groups != null && groups.isNotEmpty ? ' groups=$groups' : '';
      o('uid=$uid(u0_a$uid)$gidStr$groupsStr', Ln.stdout);
    };
    _cmds['env'] = (a, c, o, af) => a.isEmpty ? c.env.forEach((k, v) => o('$k=$v', Ln.stdout)) : o('${a[0]}=${c.env[a[0]] ?? ""}', Ln.stdout);
    _cmds['export'] = (a, c, o, af) { if (a.isNotEmpty) { final kv = a.join(' ').split('='); if (kv.length == 2) { c.env[kv[0]] = kv[1]; o('${kv[0]}=${kv[1]}', Ln.success); } } };
    _cmds['alias'] = (a, c, o, af) { if (a.isEmpty) { c.aliases.forEach((k, v) => o('$k=$v', Ln.stdout)); } else { final kv = a.join(' ').split('='); if (kv.length == 2) { c.aliases[kv[0]] = kv[1]; o('$kv[0]=$kv[1]', Ln.success); } } };
    _cmds['source'] = (a, c, o, af) => o('sourced ${a.isNotEmpty ? a[0] : ".bashrc"}', Ln.success);
    _cmds['which'] = _cmds['type'] = (a, c, o, af) => _delegateToReal('which', a, o);
    // â”€â”€ utilidades (real via _runRealSync o datos de _devId) â”€â”€
    _cmds['sleep'] = (a, c, o, af) { final sec = double.tryParse(a.isNotEmpty ? a[0] : '0') ?? 0; af(Duration(milliseconds: (sec * 1000).round()), () {}); };
    _cmds['true'] = (a, c, o, af) {}; // exit 0, no output
    _cmds['false'] = (a, c, o, af) => o('', Ln.stderr); // exit 1
    _cmds['basename'] = (a, c, o, af) { if (a.isEmpty) { o('basename: falta argumento', Ln.stderr); return; } final p = a[0]; final slash = p.lastIndexOf('/'); o(slash >= 0 ? p.substring(slash + 1) : p, Ln.stdout); };
    _cmds['dirname'] = (a, c, o, af) { if (a.isEmpty) { o('dirname: falta argumento', Ln.stderr); return; } final p = a[0]; final slash = p.lastIndexOf('/'); o(slash > 0 ? p.substring(0, slash) : (slash == 0 ? '/' : '.'), Ln.stdout); };
    _cmds['expr'] = (a, c, o, af) { try { final expr = a.join(' '); final val = _evalExpr(expr); o('$val', Ln.stdout); } catch (e) { o('expr: error de sintaxis', Ln.stderr); } };
    _cmds['seq'] = (a, c, o, af) { if (a.isEmpty) { o('seq: falta argumento', Ln.stderr); return; } final last = int.tryParse(a.last) ?? 10; final first = a.length > 1 ? (int.tryParse(a[0]) ?? 1) : 1; for (var i = first; i <= last; i++) o('$i', Ln.stdout); };
    _cmds['host'] = (a, c, o, af) => _delegateToReal('host', a, o);
    _cmds['nl'] = (a, c, o, af) {
      final file = a.firstOrNull; if (file == null) { o('nl: falta archivo', Ln.stderr); return; }
      final path = _toReal(file); final f = File(path);
      if (!f.existsSync()) { o('nl: $file: No such file', Ln.stderr); return; }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) o('${(i + 1).toString().padLeft(6)}\t${lines[i]}', Ln.stdout);
    };
    _cmds['tree'] = (a, c, o, af) {
      final start = a.isNotEmpty ? _toReal(a[0]) : _realCwd.path;
      final dir = Directory(start);
      if (!dir.existsSync()) { o('tree: ${a.isNotEmpty ? a[0] : "."}: No such directory', Ln.stderr); return; }
      o(a.isNotEmpty ? a[0] : '.', Ln.stdout); var files = 0, dirs = 0;
      void walk(Directory d, String prefix) {
        final entries = d.listSync().toList();
        for (var i = 0; i < entries.length; i++) {
          final e = entries[i]; final name = e.uri.pathSegments.last; final last = i == entries.length - 1;
          if (e is Directory) { dirs++; o('$prefix${last ? "â””â”€â”€ " : "â”œâ”€â”€ "}$name/', Ln.info); walk(e, '$prefix${last ? "    " : "â”‚   "}'); }
          else if (e is File) { files++; o('$prefix${last ? "â””â”€â”€ " : "â”œâ”€â”€ "}$name', Ln.stdout); }
        }
      }
      walk(dir, ''); o('', Ln.stdout); o('$dirs directorios, $files archivos', Ln.info);
    };
    _cmds['diff'] = (a, c, o, af) {
      if (a.length < 2) { o('diff: 2 archivos requeridos', Ln.stderr); return; }
      final p1 = _toReal(a[0]), p2 = _toReal(a[1]); final f1 = File(p1), f2 = File(p2);
      if (!f1.existsSync()) { o('diff: ${a[0]}: No such file', Ln.stderr); return; }
      if (!f2.existsSync()) { o('diff: ${a[1]}: No such file', Ln.stderr); return; }
      final l1 = f1.readAsLinesSync(), l2 = f2.readAsLinesSync();
      o('--- ${a[0]}\n+++ ${a[1]}', Ln.stdout);
      final n = l1.length > l2.length ? l1.length : l2.length;
      for (var i = 0; i < n; i++) {
        final s1 = i < l1.length ? l1[i] : '', s2 = i < l2.length ? l2[i] : '';
        if (s1 != s2) o('${i + 1}c${i + 1}\n< $s1\n---\n> $s2', Ln.stdout);
      }
    };
    _cmds['chmod'] = _cmds['chown'] = _cmds['ln'] = (a, c, o, af) => o('${a.isNotEmpty ? a[0] : "?"}: operaciÃ³n completada', Ln.success);
    // Procs â€” si hay shell real, usar toybox ps; si no, simulado.
    _cmds['ps'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) {
        _delegateToReal('ps', a, o); return;
      }
      c.procs.ps((t, ty) => o(t, Ln.values[ty]));
    };
    _cmds['kill'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) {
        _delegateToReal('kill', a, o); return;
      }
      c.procs.kill(a, (t, ty) => o(t, Ln.values[ty]));
    };
    _cmds['htop'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) {
        _delegateToReal('htop', a, o); return;
      }
      c.procs.htop((t, ty) => o(t, Ln.values[ty]));
    };
    _cmds['pstree'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) {
        _delegateToReal('pstree', a, o); return;
      }
      c.procs.pstree((t, ty) => o(t, Ln.values[ty]));
    };
    _cmds['jobs'] = (a, c, o, af) {
      // Mostrar procesos reales del app desde /proc
      final ownPid = pid;
      final ownStat = ProcFs.pidStat(ownPid);
      final ownPpid = ownStat['ppid'] as int? ?? 0;
      o('JOBS (procesos del grupo actual):', Ln.header);
      int jobNum = 1;
      for (final pid in ProcFs.listPids()) {
        final stat = ProcFs.pidStat(pid);
        final ppid = stat['ppid'] as int? ?? 0;
        // Mostrar procesos del mismo parent o hijos directos
        if (ppid == ownPpid || ppid == ownPid) {
          final name = stat['name'] as String? ?? '?';
          final state = stat['state'] as String? ?? '?';
          o('[$jobNum] $state  $pid  $name', Ln.stdout);
          jobNum++;
        }
      }
      if (jobNum == 1) o('  (sin procesos background)', Ln.info);
    };
    // Pkgs â€” si el rootfs Termux estÃ¡ instalado, apt/pip/npm delegan al
    // binario real. Si no, usan el PackageRegistry simulado como fallback.
    _cmds['pkg'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized && _rootfs?.isInstalled == true) {
        final binPath = '${_rootfs!.usrDir}/bin/pkg';
        final env = _rootfsEnv(ldPreload: 'libnanoroot.so');
        _shell!.execRootfsWorker(binPath, ['pkg', ...a],
            env: env, ldPreload: 'libnanoroot.so').then((wr) {
          if (wr != null) { _shellOut(wr); return; }
          _shell!.execRootfs(binPath, ['pkg', ...a],
            env: env, ldPreload: 'libnanoroot.so').then(_shellOut);
        });
        return;
      }
      c.pkgs.pkg(a, (t, ty) => o(t, Ln.values[ty]), af);
    };
    _cmds['apt'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized && _rootfs?.isInstalled == true) {
        final binPath = '${_rootfs!.usrDir}/bin/apt';
        final env = _rootfsEnv(ldPreload: 'libnanoroot.so');
        // Worker primero (sin GPU, fork seguro); fallback in-process.
        _shell!.execRootfsWorker(binPath, ['apt', ...a],
            env: env, ldPreload: 'libnanoroot.so').then((wr) {
          if (wr != null) { _shellOut(wr); return; }
          _shell!.execRootfs(binPath, ['apt', ...a],
            env: env, ldPreload: 'libnanoroot.so').then(_shellOut);
        });
        return;
      }
      c.pkgs.pkg(['apt'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    };
    _cmds['pip'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized && _rootfs?.isInstalled == true) {
        final binPath = '${_rootfs!.usrDir}/bin/pip';
        _shell!.execRootfs(binPath, ['pip', ...a],
          ldPreload: 'libnanoroot.so').then(_shellOut);
        return;
      }
      c.pkgs.pkg(['pip'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    };
    _cmds['npm'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized && _rootfs?.isInstalled == true) {
        final binPath = '${_rootfs!.usrDir}/bin/npm';
        _shell!.execRootfs(binPath, ['npm', ...a],
          ldPreload: 'libnanoroot.so').then(_shellOut);
        return;
      }
      c.pkgs.pkg(['npm'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    };
    _cmds['cargo'] = (a, c, o, af) => c.pkgs.pkg(['cargo'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    _cmds['gem'] = (a, c, o, af) => c.pkgs.pkg(['gem'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    // sudo: passthrough al comando real (Linux espera privilegio para instalar).
    _cmds['sudo'] = (a, c, o, af) { if (a.isEmpty) { o('sudo: uso: sudo <comando>', Ln.stderr); return; } o('sudo: ejecutando "${a.join(" ")}"', Ln.info); final handler = _cmds[a.first]; if (handler != null) handler(a.sublist(1), c, o, af); else o('sudo: ${a.first}: comando no encontrado', Ln.stderr); };
    // Containers
    _cmds['docker'] = (a, c, o, af) => _dockerCmd(a, o);
    _cmds['kali'] = (a, c, o, af) => _kaliCmd(a, o);
    // Terminal interactiva (PTY): abre bash real del rootfs en modo interactivo.
    _cmds['pty'] = (a, c, o, af) {
      final usr = _rootfs?.usrDir;
      if (usr == null) { o('pty: rootfs no instalado', Ln.stderr); return; }
      final bashPath = a.isNotEmpty ? a[0] : '$usr/bin/bash';
      _ptyOpen([bashPath, '-i'], o: o);
    };
    // Comandos interactivos â†’ PTY con el binario real del rootfs.
    // AsignaciÃ³n directa (NO ??=): pisa mocks previos de htop/top/man/nvtop
    // que usaban captura de pipes sin tty. Los interactivos requieren PTY.
    for (final inter in ['vim', 'vi', 'nano', 'python', 'python3', 'htop',
                         'less', 'more', 'man', 'mc', 'lynx']) {
      _cmds[inter] = (a, c, o, af) {
        final usr = _rootfs?.usrDir;
        if (usr == null) { o('$inter: rootfs no instalado', Ln.stderr); return; }
        final bin = '$usr/bin/$inter';
        _ptyOpen([bin, ...a], o: o);
      };
    }
    // Remote â€” con rootfs instalado, git/curl/wget/ssh ejecutan binarios reales.
    _cmds['ssh'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized && _rootfs?.isInstalled == true) {
        final binPath = '${_rootfs!.usrDir}/bin/ssh';
        _shell!.execRootfs(binPath, ['ssh', ...a],
          ldPreload: 'libnanoroot.so').then(_shellOut);
        return;
      }
      if (a.isEmpty) { o('ssh: usage: ssh [user@]host', Ln.stderr); return; }
      o('ssh: connecting to ${a[0]}...', Ln.info); af(const Duration(milliseconds: 600), () => o('Authenticated.\nLast login: ${DateTime.now().toString().substring(0, 19)}', Ln.system));
    };
    _cmds['git'] = (a, c, o, af) {
      // Prioridad 1: binario real del rootfs vÃ­a execRootfs
      if (_shell != null && _shell!.initialized && _rootfs?.isInstalled == true) {
        final binPath = '${_rootfs!.usrDir}/bin/git';
        _shell!.execRootfs(binPath, ['git', ...a],
          ldPreload: 'libnanoroot.so').then(_shellOut);
        return;
      }
      // Fallback: BusyBox (no tiene git â†’ simulaciÃ³n)
      if (_shell != null && _shell!.initialized) {
        _delegateToReal('git', a, o); return;
      }
      if (a.isEmpty) { o('git: status, log, clone, branch', Ln.info); return; } switch (a[0]) { case 'status': o('On branch main\nnothing to commit', Ln.stdout); case 'log': o('commit a1b2c3d\nfeat: NanoPlatform v2.0', Ln.stdout); case 'clone': o('git: cloning...', Ln.info); af(const Duration(milliseconds: 700), () => o('git: cloned', Ln.success)); case 'branch': o('* main\n  develop', Ln.stdout); default: o('git: ${a.join(" ")} ejecutado', Ln.success); }
    };
    _cmds['curl'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized && _rootfs?.isInstalled == true) {
        final binPath = '${_rootfs!.usrDir}/bin/curl';
        _shell!.execRootfs(binPath, ['curl', ...a],
          ldPreload: 'libnanoroot.so').then(_shellOut);
        return;
      }
      if (_shell != null && _shell!.initialized) {
        _delegateToReal('curl', a, o); return;
      }
      o('curl: ${a.isNotEmpty ? a.last : "URL"} â†’ 200 OK', Ln.success);
    };
    _cmds['wget'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) {
        _delegateToReal('wget', a, o); return;
      }
      o('${a.isNotEmpty ? a[0] : "?"}: transferencia completada', Ln.success);
    };
    _cmds['scp'] = _cmds['rsync'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized && _rootfs?.isInstalled == true) {
        final bin = a.isNotEmpty ? a[0] : 'scp';
        final binPath = '${_rootfs!.usrDir}/bin/$bin';
        _shell!.execRootfs(binPath, a,
          ldPreload: 'libnanoroot.so').then(_shellOut);
        return;
      }
      if (_shell != null && _shell!.initialized) {
        _delegateToReal(a.isNotEmpty ? a[0] : 'scp', a, o); return;
      }
      o('${a.isNotEmpty ? a[0] : "?"}: transferencia completada', Ln.success);
    };
    // Automation
    _cmds['script'] = (a, c, o, af) async {
      if (a.isEmpty) {
        o('script: uso: script cmd1; cmd2; cmd3...', Ln.stderr);
        o('  Ejecuta cada comando secuencialmente como si los escribieras en la terminal.', Ln.info);
        return;
      }
      // Split por ; y ejecutar secuencialmente
      final commands = a.join(' ').split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (commands.isEmpty) return;
      o('[script] ${commands.length} comandos a ejecutar...', Ln.header);
      for (int i = 0; i < commands.length; i++) {
        final cmd = commands[i];
        o('\$ $cmd', Ln.info);
        // Ejecutar a travÃ©s del pipeline normal de comandos
        await _execCmd(cmd);
        if (!_alive || !mounted) return;
      }
      o('[script] finalizado.', Ln.success);
    };
    _cmds['crontab'] = (a, c, o, af) {
      if (a.isEmpty) { o('crontab: uso: crontab -l | -e "<min> <cmd>" | -r <num>', Ln.stderr); return; }
      switch (a[0]) {
        case '-l':
          if (_cronJobs.isEmpty) { o('crontab: sin tareas programadas', Ln.info); return; }
          o('CRON JOBS:', Ln.header);
          for (int i = 0; i < _cronJobs.length; i++) {
            final job = _cronJobs[i];
            o('  [$i] */${job.intervalMin} * * * *  ${job.command}', Ln.stdout);
          }
          break;
        case '-e':
          if (a.length < 2) { o('crontab -e: uso: crontab -e "<minutos>" "<comando>"', Ln.stderr); return; }
          final interval = int.tryParse(a[1]);
          if (interval == null || interval < 1) { o('crontab: intervalo invÃ¡lido (debe ser >= 1 minuto)', Ln.stderr); return; }
          final command = a.sublist(2).join(' ');
          if (command.isEmpty) { o('crontab: comando requerido', Ln.stderr); return; }
          final job = _CronJob(
            intervalMin: interval,
            command: command,
            timer: Timer.periodic(Duration(minutes: interval), (_) {
              if (!_alive || !mounted) return;
              _execCmd(command);
            }),
          );
          _cronJobs.add(job);
          _timers.add(job.timer);
          o('crontab: agendado #${_cronJobs.length - 1} â€” */$interval * * * *  $command', Ln.success);
          break;
        case '-r':
          if (a.length < 2) { o('crontab -r: uso: crontab -r <num>', Ln.stderr); return; }
          final idx = int.tryParse(a[1]);
          if (idx == null || idx < 0 || idx >= _cronJobs.length) {
            o('crontab: Ã­ndice invÃ¡lido. Usa crontab -l para ver la lista.', Ln.stderr);
            return;
          }
          final removed = _cronJobs.removeAt(idx);
          removed.timer.cancel();
          _timers.remove(removed.timer);
          o('crontab: tarea #$idx eliminada.', Ln.success);
          break;
        default:
          o('crontab: flag desconocido "${a[0]}". Usa -l, -e, -r.', Ln.stderr);
      }
    };
    _cmds['watch'] = (a, c, o, af) {
      if (a.length < 2) { o('watch: uso: watch <segundos> <comando>', Ln.stderr); return; }
      final sec = int.tryParse(a[0]);
      if (sec == null || sec < 1) { o('watch: segundos invÃ¡lidos', Ln.stderr); return; }
      final command = a.sublist(1).join(' ');
      o('watch: ejecutando "$command" cada ${sec}s. Ctrl+C para detener.', Ln.info);
      // Una iteraciÃ³n inmediata
      _execCmd(command);
      // Programar repeticiones
      final timer = Timer.periodic(Duration(seconds: sec), (_) {
        if (!_alive || !mounted) return;
        _execCmd(command);
      });
      _timers.add(timer);
    };
    // Plugins
    _cmds['plugin'] = (a, c, o, af) => c.plugins.plugin(a, (t, ty) => o(t, Ln.values[ty]));
    // AI
    _cmds['stat'] = (a, c, o, af) {
      final all = a.contains('--all'), mem = all || a.contains('--memory'), cpu = all || a.contains('--cpu');
      o('â•â• NanoRuntime Status â•â•', Ln.header);
      if (mem) {
        final d = _devId;
        final double totalKb = (d?['memTotalKb'] as num?)?.toDouble() ?? 0.0;
        final double availKb = (d?['memAvailKb'] as num?)?.toDouble() ?? 0.0;
        final double usedKb = totalKb > 0 ? totalKb - availKb : 0.0;
        String fmt(double kb) => kb >= 1048576 ? '${(kb / 1048576).toStringAsFixed(2)} GB' : '${(kb / 1024).toStringAsFixed(0)} MB';
        if (totalKb > 0) {
          final pct = totalKb > 0 ? (usedKb / totalKb * 100).round() : 0;
          o('RAM: ${fmt(totalKb)} | Used: ${fmt(usedKb)} ($pct%) | Free: ${fmt(availKb)}', Ln.stdout);
        } else {
          o('RAM: (leyendo /proc/meminfo...)', Ln.stdout);
        }
        o('Model: 920 MB | KV: 180 MB | PageCache: 210 MB', Ln.stdout);
      }
      if (cpu) {
        final cores = _devId?['cpuCores'] as int? ?? Platform.numberOfProcessors;
        final hw = _devId?['cpuHardware'] as String?;
        final tempC = _readCpuTemp();
        final tempStr = tempC != null ? ' | Temp: ${tempC.toStringAsFixed(1)}Â°C' : '';
        o('CPU: $cores cores${hw != null ? ' ($hw)' : ''}$tempStr | Procs: ${c.procs.procs.length}', Ln.stdout);
      }
    };
    _cmds['infer'] = (a, c, o, af) {
      if (a.isEmpty) { o('infer: prompt requerido', Ln.stderr); return; }
      final prompt = a.join(' ');
      final engine = _engine;
      if (engine == null) { o('infer: motor LLM no disponible', Ln.stderr); return; }
      o('[NanoRuntime] Enviando a ${engine.baseUrl}...', Ln.system);
      final start = DateTime.now();
      engine.generate(prompt: prompt, maxTokens: 128).then((res) {
        if (!_alive || !mounted) return;
        final ms = DateTime.now().difference(start).inMilliseconds;
        for (final line in res.text.split('\n')) { if (line.isNotEmpty) o(line, Ln.success); }
        o('${ms}ms @ ${res.tps?.toStringAsFixed(1) ?? "?"} tok/s', Ln.info);
      }).catchError((e) {
        if (!_alive || !mounted) return;
        o('infer: el motor no respondiÃ³ â€” $e', Ln.stderr);
      });
    };
    _cmds['ai'] = (a, c, o, af) {
      if (a.isEmpty) { o('ai: escribe un prompt. Ej: ai Â¿cÃ³mo optimizar RAM?', Ln.stderr); return; }
      final prompt = a.join(' ');
      final engine = _engine;
      if (engine == null) { o('ai: motor LLM no disponible', Ln.stderr); return; }
      o('[NanoAI] Pensando... (${engine.baseUrl})', Ln.info);
      engine.generate(prompt: prompt, maxTokens: 512).then((res) {
        if (!_alive || !mounted) return;
        for (final line in res.text.split('\n')) { if (line.isNotEmpty) o(line, Ln.stdout); }
        if (res.tps != null) o('${res.tps!.toStringAsFixed(1)} tok/s', Ln.info);
      }).catchError((e) {
        if (!_alive || !mounted) return;
        o('ai: el motor no respondiÃ³. Â¿EstÃ¡ corriendo llama.cpp en 127.0.0.1:8080?', Ln.stderr);
        o('  $e', Ln.stderr);
      });
    };
    _cmds['tune'] = (a, c, o, af) async {
      o('â•â• NanoAI Auto-Tune â•â•', Ln.header);
      // 1. Device diagnostics
      final mem = ProcFs.meminfo();
      final totalMb = (mem['MemTotal'] ?? 0) ~/ 1024;
      final availMb = (mem['MemAvailable'] ?? mem['MemFree'] ?? 0) ~/ 1024;
      final cores = _devId?['cpuCores'] as int? ?? Platform.numberOfProcessors;
      final tempC = _readCpuTemp();
      o('Device: ${totalMb}MB RAM, ${availMb}MB libre, $cores cores'
          '${tempC != null ? ', ${tempC.toStringAsFixed(1)}Â°C' : ''}',
          Ln.info);

      // 2. Engine health check
      final engine = _engine;
      if (engine == null) {
        o('Motor LLM: no configurado (sin engine client)', Ln.warn);
        o('Sugerencias: instala llama.cpp en 127.0.0.1:8080', Ln.info);
        return;
      }
      o('Motor URL: ${engine.baseUrl}', Ln.info);
      final online = await engine.isOnline();
      if (!online) {
        o('Motor: OFFLINE (no responde en ${engine.baseUrl})', Ln.warn);
        o('Sugerencia: lanza llama.cpp con --server --port 8080', Ln.info);
        return;
      }
      o('Motor: ONLINE', Ln.success);

      // 3. Benchmark rÃ¡pido: medir tokens por segundo real
      o('Benchmark TPS... (prompt de prueba)', Ln.info);
      try {
        final res = await engine.generate(
          prompt: 'Hello',
          maxTokens: 10,
          temperature: 0.0,
        );
        o('Respuesta: "${res.text.length > 40 ? '${res.text.substring(0, 40)}...' : res.text}"', Ln.stdout);
        if (res.tps != null) {
          o('Velocidad: ${res.tps!.toStringAsFixed(1)} tok/s', Ln.success);
          // Sugerencias basadas en TPS real
          if (res.tps! < 5) {
            o('âš  TPS bajo. Considera:', Ln.warn);
            o('  - Usar un modelo mÃ¡s pequeÃ±o (Qwen 0.5B en vez de 1.5B)', Ln.info);
            o('  - Reducir context window (--ctx-size 512)', Ln.info);
            o('  - Deshabilitar GPU layers si tenÃ©s poca RAM', Ln.info);
          } else if (res.tps! < 20) {
            o('TPS aceptable. Optimizaciones:', Ln.info);
            o('  - Subir --threads a $cores para mejor rendimiento', Ln.info);
            o('  - Aumentar --batch-size a 512 si tenÃ©s RAM', Ln.info);
          } else {
            o('TPS excelente. Sugerencias:', Ln.info);
            o('  - PodÃ©s usar modelos mÃ¡s grandes (Qwen 3B, 7B)', Ln.info);
            o('  - Aumentar --ctx-size a 4096 para prompts largos', Ln.info);
          }
        }
        // RAM-based suggestions
        if (availMb < 500) {
          o('âš  RAM baja (${availMb}MB libre). Riesgo de OOM con modelos grandes.', Ln.warn);
        } else if (availMb > 2000) {
          o('RAM suficiente para modelos de hasta ~2B parÃ¡metros (Qwen-1.5B, Gemma-2B).', Ln.info);
        } else {
          o('RAM adecuada para modelos de ~1B parÃ¡metros.', Ln.info);
        }
      } on LLMEngineException catch (e) {
        o('Benchmark fallÃ³: ${e.message}', Ln.stderr);
      }
    };
    _cmds['gpu'] = (a, c, o, af) {
      final info = _readGpuInfo();
      final name = info['name'] ?? 'Adreno';
      final freq = info['freqMhz'];
      final temp = info['tempC'];
      final freqStr = freq != null ? ' | Freq: $freq MHz' : '';
      final tempStr = temp != null ? ' | Temp: ${temp.toStringAsFixed(1)}Â°C' : '';
      o('GPU: $name$freqStr$tempStr', Ln.stdout);
      final load = info['gpuLoad'];
      if (load != null) {
        o('  Load: ${load.toStringAsFixed(1)}%', Ln.stdout);
      }
      if (freq == null && temp == null) {
        // Fallback: el kernel no expone kgsl. Mostrar SoC del cpuinfo.
        final hw = _devId?['cpuHardware'] as String?;
        if (hw != null) o('  SoC: $hw (GPU info via /sys/class/kgsl/ no disponible)', Ln.info);
      }
    };
    _cmds['nvtop'] = (a, c, o, af) {
      final info = _readGpuInfo();
      final name = (info['name'] as String?) ?? 'GPU';
      final freq = info['freqMhz'];
      final mem = info['gpuMemMb'];
      o('â•”â•â• nvtop â•â•â•—', Ln.header);
      o('â•‘ GPU: $name ${" ".padLeft(15 - name.length)}â•‘', Ln.header);
      if (freq != null) o('â•‘ Freq: $freq MHz ${" ".padLeft(8)}â•‘', Ln.header);
      if (mem != null) o('â•‘ Mem: ${mem}M ${" ".padLeft(14)}â•‘', Ln.header);
      o('â•šâ•â•â•â•â•â•â•â•â•â•â•â•', Ln.header);
    };
    _cmds['dashboard'] = (a, c, o, af) {
      final d = _devId;
      final totalMb = ((d?['memTotalKb'] as num?)?.toDouble() ?? 0) / 1024;
      final availMb = ((d?['memAvailKb'] as num?)?.toDouble() ?? 0) / 1024;
      final usedMb = totalMb - availMb;
      final cores = d?['cpuCores'] as int? ?? Platform.numberOfProcessors;
      final ramStr = totalMb > 0
          ? '${usedMb.toStringAsFixed(0)}/${totalMb.toStringAsFixed(0)} MB'
          : '? MB';
      o('â•â• Dashboard â•â•\n'
          'CPU: $cores cores | RAM: $ramStr\n'
          'Procs: ${c.procs.procs.length} | '
          'Pkgs: ${c.pkgs.pkgs.where((p) => p.installed).length} | '
          'Containers: ${c.containers.cons.where((x) => !x.status.startsWith("Exited")).length} | '
          'Plugins: ${c.plugins.plugs.where((p) => p.enabled).length}',
          Ln.stdout);
    };
    // Rootfs bootstrap
    _cmds['bootstrap'] = (a, c, o, af) {
      final rootfs = _rootfs;
      if (rootfs == null) { o('bootstrap: rootfs manager no disponible', Ln.stderr); return; }
      if (rootfs.isInstalled) { o('bootstrap: rootfs ya instalado en ${rootfs.usrDir}', Ln.success); return; }
      if (rootfs.isDownloading) { o('bootstrap: descarga en progreso...', Ln.info); return; }
      o('[bootstrap] Iniciando instalaciÃ³n del rootfs Termux (~30 MB)...', Ln.header);
      o('  URL: ${RootfsManager.bootstrapUrl}', Ln.info);
      // ExtracciÃ³n con el extractor Kotlin (ZipFile + SYMLINKS.txt + symlinks).
      rootfs.install().then((ok) {
        if (!_alive || !mounted) return;
        if (ok) {
          _applyRootfsEnv();
          o('[bootstrap] InstalaciÃ³n completa. PATH, HOME y binarios actualizados.', Ln.success);
          o('  PATH=${_ctx.env["PATH"]}', Ln.info);
          o('  HOME=${_ctx.env["HOME"]}', Ln.info);
          o('  PREFIX=${_ctx.env["PREFIX"]}', Ln.info);
          o('  Prueba: !ls -la /usr/bin | head -5', Ln.info);
        } else {
          o('[bootstrap] FallÃ³ la instalaciÃ³n. Verifica:', Ln.stderr);
          o('  1. ConexiÃ³n a internet (WiFi o datos mÃ³viles)', Ln.stderr);
          o('  2. Espacio libre en almacenamiento (~50 MB necesarios)', Ln.stderr);
          o('  3. Permiso INTERNET en AndroidManifest.xml', Ln.stderr);
          o('  Reintenta con: bootstrap', Ln.info);
        }
      });
    };
    _cmds['status'] = (a, c, o, af) {
      o('â•â• NanoPlatform Status â•â•', Ln.header);
      final shellReady = _shell?.initialized ?? false;
      o('Shell: ${shellReady ? "listo" : "no inicializado"}', Ln.info);
      o('Bin dir: ${_shell?.binDir ?? "?"}', Ln.info);
      final rf = _rootfs;
      if (rf != null) {
        o('Rootfs: ${rf.isInstalled ? "INSTALADO" : "no instalado"}', rf.isInstalled ? Ln.success : Ln.warn);
        o('  usrDir: ${rf.usrDir ?? "?"}', Ln.info);
        o('  Descargando: ${rf.isDownloading}', Ln.info);
      }
      o('Env: PATH=${c.env["PATH"]}', Ln.info);
      o('Env: HOME=${c.env["HOME"]}', Ln.info);
      o('Env: SHELL=${c.env["SHELL"]}', Ln.info);
      o('Engine: ${_engine?.baseUrl ?? "?"}', Ln.info);
      o('Device: ${_devId?["hostname"] ?? "?"} (${_devId?["uname_machine"] ?? "?"})', Ln.info);
    };
    // Monitor â€” con shell real, delegan a toybox/bash.
    _cmds['dmesg'] = (a, c, o, af) {
      // Prioridad 1: BusyBox dmesg (kernel ring buffer real)
      if (_shell != null && _shell!.initialized) { _delegateToReal('dmesg', a, o); return; }
      // Fallback: leer /proc/kmsg via dart:io
      final log = ProcFs.dmesg(maxLines: 40);
      if (log != null && log.isNotEmpty) {
        for (final line in log.split('\n')) {
          // Formato tÃ­pico: "prio,timestamp,message"
          final trimmed = line.replaceFirst(RegExp(r'^\d+,\d+,\d+,'), '');
          o(trimmed, Ln.system);
        }
      } else {
        o('dmesg: /proc/kmsg no disponible (requiere root en este device)', Ln.warn);
      }
    };
    _cmds['free'] = (a, c, o, af) {
      final d = _devId;
      final totalKb = (d?['memTotalKb'] as num?)?.toDouble() ?? 3812000.0;
      final availKb = (d?['memAvailKb'] as num?)?.toDouble() ?? 2000000.0;
      final usedKb = totalKb - availKb;
      final swapTotal = (d?['swapTotalKb'] as num?)?.toDouble() ?? 0.0;
      final swapFree = (d?['swapFreeKb'] as num?)?.toDouble() ?? 0.0;
      String fmt(double kb) => kb >= 1048576 ? '${(kb / 1048576).toStringAsFixed(1)}G' : '${(kb / 1024).toStringAsFixed(0)}M';
      final buf = StringBuffer();
      buf.writeln('              total        used        free');
      buf.writeln('Mem:   ${fmt(totalKb).padLeft(6)}   ${fmt(usedKb).padLeft(6)}   ${fmt(availKb).padLeft(6)}');
      if (swapTotal > 0) buf.writeln('Swap:  ${fmt(swapTotal).padLeft(6)}   ${fmt(swapTotal - swapFree).padLeft(6)}   ${fmt(swapFree).padLeft(6)}');
      o(buf.toString().trimRight(), Ln.stdout);
    };
    _cmds['df'] = (a, c, o, af) {
      final d = _devId;
      final blockSize = (d?['storageBlockSize'] as num?)?.toDouble() ?? 4096.0;
      final totalBlocks = (d?['storageTotalBlocks'] as num?)?.toDouble() ?? 0.0;
      final availBlocks = (d?['storageAvailBlocks'] as num?)?.toDouble() ?? 0.0;
      final usedBlocks = totalBlocks - availBlocks;
      final pct = totalBlocks > 0 ? (usedBlocks / totalBlocks * 100).round() : 0;
      String fmt(double blocks) {
        final bytes = blocks * blockSize;
        if (bytes >= 1e12) return '${(bytes / 1e12).toStringAsFixed(1)}T';
        if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(1)}G';
        if (bytes >= 1e6) return '${(bytes / 1e6).toStringAsFixed(0)}M';
        return '${(bytes / 1e3).toStringAsFixed(0)}K';
      }
      if (totalBlocks <= 0) {
        o('Filesystem      Size  Used Avail Use% Mounted on\n/dev/sda1       128G   52G   76G  41% /data', Ln.stdout);
        return;
      }
      o('Filesystem      Size  Used Avail Use% Mounted on\n/data           ${fmt(totalBlocks).padLeft(4)} ${fmt(usedBlocks).padLeft(4)} ${fmt(availBlocks).padLeft(4)}  ${pct.toString().padLeft(3)}% /data', Ln.stdout);
    };
    _cmds['top'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) { _delegateToReal('top', a, o); return; }
      // Datos reales de /proc/stat + /proc/loadavg
      final load = ProcFs.loadavg();
      final mem = ProcFs.meminfo();
      final totalKb = mem['MemTotal'] ?? 0;
      final availKb = mem['MemAvailable'] ?? mem['MemFree'] ?? 0;
      final usedPct = totalKb > 0 ? ((totalKb - availKb) / totalKb * 100).round() : 0;
      final (running, _) = ProcFs.procsRunning();
      final uptime = ProcFs.uptimeSec();
      final hours = (uptime ~/ 3600);
      final mins = ((uptime % 3600) ~/ 60);
      o('top - ${DateTime.now().toString().substring(11, 19)} '
          'up ${hours}h${mins}m, '
          'load avg: ${load.$1.toStringAsFixed(2)} ${load.$2.toStringAsFixed(2)} ${load.$3.toStringAsFixed(2)}\n'
          'Tasks: $running running | '
          'MEM: $usedPct% used (${(availKb ~/ 1024)}M free / ${(totalKb ~/ 1024)}M total)',
          Ln.stdout);
    };
    _cmds['netstat'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) { _delegateToReal('netstat', a, o); return; }
      // Leer sockets TCP reales desde /proc/net/tcp
      final sockets = ProcFs.netTcp();
      if (sockets.isEmpty) {
        o('tcp 0.0.0.0:8080 LISTEN\ntcp 192.168.0.5:44221 github.com:443 ESTABLISHED', Ln.stdout);
        return;
      }
      for (final sock in sockets) {
        final state = sock['state'] as String? ?? '??';
        final local = '${sock['localAddr']}:${sock['localPort']}';
        final remote = '${sock['remoteAddr']}:${sock['remotePort']}';
        o('tcp  $local  $remote  $state', Ln.stdout);
      }
    };
    _cmds['ss'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) { _delegateToReal('ss', a, o); return; }
      // Leer sockets TCP reales desde /proc/net/tcp
      final showAll = a.contains('-a') || a.contains('--all');
      final showListen = a.contains('-l') || a.contains('--listen') || !showAll;
      o('Netid State      Recv-Q Send-Q Local Address:Port  Peer Address:Port Process', Ln.header);
      for (final sock in ProcFs.netTcp()) {
        final state = sock['state'] as String? ?? '??';
        if (showListen && state != 'LISTEN' && state != 'ESTABLISHED') continue;
        if (!showAll && !showListen && state != 'ESTABLISHED') continue;
        final local = '${sock['localAddr']}:${sock['localPort']}';
        final remote = '${sock['remoteAddr']}:${sock['remotePort']}';
        o('tcp   ${state.padRight(10)} 0      0      ${local.padRight(21)} ${remote.padRight(21)}', Ln.stdout);
      }
      if (ProcFs.netTcp().isEmpty) {
        o('tcp   LISTEN     0      128    0.0.0.0:8080          0.0.0.0:*', Ln.stdout);
      }
    };
    _cmds['lsof'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) { _delegateToReal('lsof', a, o); return; }
      // Leer file descriptors reales del proceso actual
      final ownPid = pid;
      o('COMMAND     PID  USER   FD   TYPE DEVICE SIZE/OFF NODE NAME', Ln.header);
      final status = ProcFs.pidStatus(ownPid);
      final name = status['Name'] ?? 'nanoai';
      final uid = status['Uid'] ?? '?';
      final user = ProcFs.uidToName(int.tryParse(uid.split('\t')[0]) ?? 0);
      for (final fd in ProcFs.pidFds(ownPid)) {
        final fdStr = fd['fd'].toString();
        final target = fd['target'] as String? ?? '?';
        // Clasificar tipo
        String type = 'REG';
        if (target.startsWith('/dev/')) type = 'CHR';
        else if (target.startsWith('/proc/')) type = 'unknown';
        else if (target.startsWith('socket:')) type = 'sock';
        else if (target.startsWith('pipe:')) type = 'FIFO';
        else if (target.startsWith('anon_inode:')) type = 'unknown';
        o('$name ${ownPid.toString().padLeft(5)}  $user  ${fdStr.padLeft(4)}  $type  ${target}', Ln.stdout);
      }
    };
    _cmds['vmstat'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) { _delegateToReal('vmstat', a, o); return; }
      // Fallback: datos reales de /proc/vmstat, /proc/meminfo, /proc/stat
      final mem = ProcFs.meminfo();
      final vmst = ProcFs.vmstat();
      final cpu = ProcFs.cpuTimes();
      final (running, blocked) = ProcFs.procsRunning();
      final freeMem = (mem['MemFree'] ?? 0) ~/ 1024;
      final buffMem = (mem['Buffers'] ?? 0) ~/ 1024;
      final cacheMem = ((mem['Cached'] ?? 0) + (mem['SReclaimable'] ?? 0)) ~/ 1024;
      final swapTotal = (mem['SwapTotal'] ?? 0) ~/ 1024;
      final si = vmst['pswpin'] ?? 0;
      final so = vmst['pswpout'] ?? 0;
      final bi = (vmst['pgpgin'] ?? 0) ~/ 100; // Aproximado
      final bo = (vmst['pgpgout'] ?? 0) ~/ 100;
      final intr = vmst['intr'] ?? 0;
      final ctx = vmst['ctxt'] ?? 0;
      // CPU % (diferencia no calculable sin snapshot previo)
      final cpuUser = 8; final cpuSys = 3; final cpuIdle = 88; final cpuWait = 1;
      o('procs -----------memory---------- ---swap-- -----io---- -system-- ----cpu----\n'
          ' r  b   swpd   free   buff   cache   si   so    bi    bo   in   cs us sy id wa\n'
          ' $running  $blocked  ${swapTotal.toString().padLeft(4)} ${freeMem.toString().padLeft(5)} ${buffMem.toString().padLeft(5)} ${cacheMem.toString().padLeft(5)}'
          '  ${si.toString().padLeft(4)} ${so.toString().padLeft(4)} ${bi.toString().padLeft(5)} ${bo.toString().padLeft(5)}'
          ' ${intr.toString().padLeft(4)} ${ctx.toString().padLeft(4)}  $cpuUser  $cpuSys $cpuIdle  $cpuWait',
          Ln.stdout);
    };
    _cmds['iotop'] = (a, c, o, af) {
      if (_shell != null && _shell!.initialized) { _delegateToReal('iotop', a, o); return; }
      // Leer I/O real de los procesos desde /proc/[pid]/io
      o('Total DISK READ:  ? B/s | Total DISK WRITE:  ? B/s', Ln.header);
      o('  TID  PRIO  USER     DISK READ  DISK WRITE  SWAPIN    IO>    COMMAND', Ln.stdout);
      final pids = ProcFs.listPids().take(20); // Limitar a 20 PIDs
      for (final pid in pids) {
        final stat = ProcFs.pidStat(pid);
        final io = ProcFs.pidIo(pid);
        final status = ProcFs.pidStatus(pid);
        final name = stat['name'] as String? ?? status['Name'] ?? '?';
        if (name == '?') continue;
        final uidStr = status['Uid']?.split('\t')[0].trim();
        final uid = int.tryParse(uidStr ?? '') ?? 0;
        final user = ProcFs.uidToName(uid);
        final readBytes = io['read_bytes'] ?? 0;
        final writeBytes = io['write_bytes'] ?? 0;
        String fmt(int bytes) {
          if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(2)} G';
          if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(2)} M';
          if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(2)} K';
          return '$bytes B';
        }
        o('$pid be/4 ${user.padRight(9)} ${fmt(readBytes).padLeft(9)}  ${fmt(writeBytes).padLeft(9)}   0.00 %  0.00 % $name',
           Ln.stdout);
      }
    };
    _cmds['man'] = (a, c, o, af) => o('${a.isNotEmpty ? a[0].toUpperCase() : "?"}(1)    NanoPlatform Manual\nNAME    ${a.isNotEmpty ? a[0] : "?"}\nSYNOPSIS  ${a.isNotEmpty ? a[0] : "?"} [options]\nDESCRIPTION  Integrated command.', Ln.info);
  }

  void _help(List<String> a, void Function(String, Ln) o) {
    if (a.isNotEmpty) { _cmds['man']!(a, _ctx, o, _after); return; }
    o('â•â• Comandos â•â•', Ln.header);
    for (final s in [['Sistema', 'help clear date whoami uname hostname uptime id env export alias source which type sleep true false status'], ['FS', 'ls cd pwd cat grep find diff wc mkdir rm cp mv touch echo chmod chown ln head tail basename dirname wc nl'], ['Shell real', 'bash toybox ! (prefijo: !ls -la â†’ bash -c)'], ['Rootfs', 'bootstrap (instalar Termux rootfs ~30MB)'], ['Proot/Distro', 'kali install|shell|run (Kali Linux ARM64 ~200MB)'], ['Containers', 'docker pull|run|ps|images|rm|stop (runtime proot)'], ['Procesos', 'ps kill jobs htop pstree'], ['Pkgs', 'pkg apt pip npm cargo gem'], ['Remote', 'ssh git adb curl scp wget'], ['Plugins', 'plugin'], ['IA', 'ai infer stat tune gpu nvtop dashboard'], ['Monitor', 'dmesg free df top netstat ss lsof vmstat iotop']])
      o('  ${s[0]}: ${s[1]}', Ln.info);
  }

  // â”€â”€ Kali Linux â”€â”€

  void _kaliCmd(List<String> args, void Function(String, Ln) o) {
    final sub = args.isNotEmpty ? args[0] : '';
    switch (sub) {
      case 'install':
        final kali = _kali;
        if (kali == null) { o('kali: manager no disponible', Ln.stderr); return; }
        if (kali.isInstalled) { o('kali: ya instalado en ${kali.kaliRoot}', Ln.success); return; }
        if (kali.isDownloading) { o('kali: descarga en progreso...', Ln.info); return; }
        o('[kali] Descargando Kali Linux ARM64 (~200 MB)...', Ln.header);
        o('  URL: ${KaliManager.rootfsUrl}', Ln.info);
        kali.install((stage, pct) {
          if (!_alive || !mounted) return;
          if (stage == 'download' && pct < 100 && pct % 20 == 0) {
            o('[kali] descargando... $pct%', Ln.system);
          } else if (stage == 'extract' && pct < 100) {
            o('[kali] extrayendo rootfs...', Ln.system);
          } else if (stage == 'done') {
            o('[kali] InstalaciÃ³n completa. Kali Linux ARM64 listo.', Ln.success);
            o('  Usa: kali shell  (bash dentro de Kali)', Ln.info);
            o('  Usa: kali run <cmd> (un comando en Kali)', Ln.info);
          } else if (stage == 'error') {
            o('[kali] FallÃ³ la instalaciÃ³n. Verifica conexiÃ³n y espacio (~300 MB libres).', Ln.stderr);
          }
        });
        break;

      case 'shell':
        if (_kali == null || !_kali!.isInstalled) {
          o('kali: no instalado. Ejecuta "kali install" primero.', Ln.stderr); return;
        }
        o('[kali] Shell interactiva (Kali ARM64 vÃ­a proot)', Ln.header);
        _kali!.shell(
          onOut: (l) => o(l, Ln.stdout),
          onErr: (l) => o(l, Ln.stderr),
        );
        break;

      case 'run':
        if (args.length < 2) { o('kali run <comando>', Ln.stderr); return; }
        final cmd = args[1];
        final cmdArgs = args.sublist(2);
        if (_kali == null || !_kali!.isInstalled) {
          o('kali: no instalado.', Ln.stderr); return;
        }
        o('[kali] $cmd ${cmdArgs.join(" ")}', Ln.system);
        _kali!.run(cmd, cmdArgs,
          onOut: (l) => o(l, Ln.stdout),
          onErr: (l) => o(l, Ln.stderr),
        );
        break;

      default:
        o('kali install  â€” descargar Kali Linux ARM64 (~200 MB)', Ln.info);
        o('kali shell    â€” abrir shell bash dentro de Kali', Ln.info);
        o('kali run <cmd> â€” ejecutar un comando en Kali', Ln.info);
        o('kali status   â€” verificar instalaciÃ³n', Ln.info);
        if (_kali != null) {
          o('  Instalado: ${_kali!.isInstalled ? "SÃ" : "NO"}', _kali!.isInstalled ? Ln.success : Ln.warn);
          o('  Rootfs: ${_kali!.kaliRoot ?? "?"}', Ln.info);
        }
    }
  }

  // â”€â”€ Docker runtime (proot-based) â”€â”€

  void _dockerCmd(List<String> args, void Function(String, Ln) o) {
    final sub = args.isNotEmpty ? args[0] : '';
    switch (sub) {
      case 'pull':
        if (args.length < 2) { o('docker pull <imagen>', Ln.stderr); return; }
        final img = args[1];
        o('[docker] pull $img...', Ln.header);
        _docker?.pull(img, (line) => o(line, Ln.system));
        break;

      case 'run':
        if (args.length < 2) { o('docker run <imagen> [cmd...]', Ln.stderr); return; }
        final img = args[1];
        final cmd = args.sublist(2);
        o('[docker] run $img ${cmd.join(" ")}', Ln.header);
        _docker?.run(img, cmd,
          onOut: (l) => o(l, Ln.stdout),
          onErr: (l) => o(l, Ln.stderr),
        ).then((id) {
          if (!_alive || !mounted) return;
          if (id != null) o('[docker] container ${id.substring(0, 12)} terminado', Ln.success);
        });
        break;

      case 'ps':
        final containers = _docker?.ps() ?? [];
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
        final imgs = _docker?.images() ?? [];
        if (imgs.isEmpty) {
          o('No hay imÃ¡genes. Usa "docker pull <imagen>".', Ln.info);
        } else {
          o('IMAGE           LAYERS', Ln.header);
          for (final i in imgs) {
            o('${i['name']}  ${i['layers']}', Ln.stdout);
          }
        }
        break;

      case 'rm':
        if (args.length < 2) { o('docker rm <id>', Ln.stderr); return; }
        _docker?.rm(args[1]);
        o('[docker] contenedor ${args[1]} eliminado', Ln.success);
        break;

      case 'stop':
        if (args.length < 2) { o('docker stop <id>', Ln.stderr); return; }
        _docker?.stop(args[1]);
        o('[docker] contenedor ${args[1]} detenido', Ln.success);
        break;

      default:
        o('docker pull <imagen>      â€” descargar imagen (ej: alpine)', Ln.info);
        o('docker run <imagen> [cmd] â€” ejecutar contenedor vÃ­a proot', Ln.info);
        o('docker ps                 â€” listar contenedores', Ln.info);
        o('docker images             â€” listar imÃ¡genes', Ln.info);
        o('docker rm <id>            â€” eliminar contenedor', Ln.info);
        o('docker stop <id>          â€” detener contenedor', Ln.info);
    }
  }

  /// Evaluador aritmÃ©tico simple para `expr`. Soporta + - * / y parÃ©ntesis.
  int _evalExpr(String expr) {
    final s = expr.replaceAll(' ', '');
    // Solo nÃºmeros y operadores bÃ¡sicos
    if (RegExp(r'^[\d\+\-\*/\(\)]+$').hasMatch(s)) {
      return _evalSimple(s);
    }
    // Fallback: sumar si es "X + Y"
    final add = RegExp(r'(\d+)\s*\+\s*(\d+)').firstMatch(expr);
    if (add != null) return int.parse(add.group(1)!) + int.parse(add.group(2)!);
    final sub = RegExp(r'(\d+)\s*\-\s*(\d+)').firstMatch(expr);
    if (sub != null) return int.parse(sub.group(1)!) - int.parse(sub.group(2)!);
    final mul = RegExp(r'(\d+)\s*\*\s*(\d+)').firstMatch(expr);
    if (mul != null) return int.parse(mul.group(1)!) * int.parse(mul.group(2)!);
    final div = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(expr);
    if (div != null) return int.parse(div.group(1)!) ~/ int.parse(div.group(2)!);
    return 0;
  }

  // Parser aritmÃ©tico para expr. Soporta + - * / y parÃ©ntesis via
  // recursive-descent con mÃ©todos privados (evita el problema de
  // forward-reference de local functions en Dart).
  int _pos = 0;
  String _exprSrc = '';

  int _evalSimple(String s) {
    _pos = 0; _exprSrc = s; return _parseExpr();
  }
  int _parseExpr() {
    var v = _parseFactor();
    while (_pos < _exprSrc.length && (_exprSrc[_pos] == '+' || _exprSrc[_pos] == '-')) {
      final op = _exprSrc[_pos]; _pos++;
      final r = _parseFactor();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }
  int _parseFactor() {
    var v = _parseTerm();
    while (_pos < _exprSrc.length && (_exprSrc[_pos] == '*' || _exprSrc[_pos] == '/')) {
      final op = _exprSrc[_pos]; _pos++;
      final r = _parseTerm();
      v = op == '*' ? v * r : v ~/ r;
    }
    return v;
  }
  int _parseTerm() {
    if (_pos < _exprSrc.length && _exprSrc[_pos] == '(') { _pos++; final v = _parseExpr(); _pos++; return v; }
    final start = _pos;
    while (_pos < _exprSrc.length && RegExp(r'[0-9]').hasMatch(_exprSrc[_pos])) _pos++;
    return int.parse(_exprSrc.substring(start, _pos));
  }

  // â”€â”€ Execution â”€â”€
  List<String> _tok(String c) { final t = <String>[], b = StringBuffer(); bool sq = false, dq = false; for (int i = 0; i < c.length; i++) { final ch = c[i]; if (ch == "'" && !dq) { sq = !sq; continue; } if (ch == '"' && !sq) { dq = !dq; continue; } if (ch == ' ' && !sq && !dq) { if (b.isNotEmpty) { t.add(b.toString()); b.clear(); } continue; } b.write(ch); } if (b.isNotEmpty) t.add(b.toString()); return t; }

  /// Detecta operadores de shell (| > < >> && || ;) fuera de comillas.
  /// Si estÃ¡n presentes, el comando debe delegarse a bash -c.
  bool _hasShellOps(String cmd) {
    bool sq = false, dq = false;
    for (int i = 0; i < cmd.length; i++) {
      final ch = cmd[i];
      if (ch == "'" && !dq) { sq = !sq; continue; }
      if (ch == '"' && !sq) { dq = !dq; continue; }
      if (sq || dq) continue;
      if (ch == '|') return true;
      if (ch == '>' || ch == '<') return true;
      if (ch == '&' && i + 1 < cmd.length && cmd[i + 1] == '&') return true;
      if (ch == '|' && i + 1 < cmd.length && cmd[i + 1] == '|') return true;
      if (ch == ';') return true;
    }
    return false;
  }

  void _exec(String raw) { _execAsync(raw); } // puente syncâ†’async para onSubmitted

  /// Ejecuta un comando raw (string) pasÃ¡ndolo por el pipeline completo.
  /// Usado por script, crontab, y watch para ejecuciÃ³n programada.
  Future<void> _execCmd(String raw) async {
    // Simular que el usuario escribiÃ³ el comando
    _out('\$ $raw', Ln.info);
    await _execAsync(raw);
  }

  /// Delega un comando a ejecuciÃ³n real vÃ­a BusyBox (Nanoshell FFI).
  /// Nanoshell hace fork()+dlopen(libbusybox.so)+busybox_main().
  /// Elude SELinux â€” no usa execve(). Salida 100% real.
  void _delegateToReal(String bin, List<String> args, void Function(String, Ln) o) {
    final cmd = '$bin ${args.join(" ")}';
    o('[real] $cmd', Ln.system);
    _shell!.toybox([bin, ...args]).then((r) {
      _shellOut(r);
    });
  }

  // â”€â”€ PTY: terminal interactivo (vim, htop, python, bash -i) â”€â”€

  bool get _ptyActive => _pty != null && !_pty!.isClosed;

  // Ãšltimo tamaÃ±o (rows x cols) aplicado al PTY y al buffer ANSI. Evita
  // re-resize en cada build con LayoutBuilder.
  int _ptyRows = 24, _ptyCols = 80;

  /// Aplica el tamaÃ±o del Ã¡rea visible al PTY y al buffer ANSI.
  /// Los apps fullscreen (vim/htop) consultan TIOCGWINSZ en cada redibujo;
  /// sin resize real dibujan en 24x80 aunque la pantalla sea mayor.
  /// Se difiere a post-frame porque toca ChangeNotifier (evita rebuild en build).
  void _applyPtySize(double w, double h) {
    if (_pty == null || !_ptyActive || _ansi == null) return;
    // MÃ©tricas aproximadas: fuente JetBrains Mono 12.5 â†’ ~7.6px/car, altura
    // de lÃ­nea ~20px (1.6 * 12.5).
    final rows = (h / 20).floor().clamp(1, 200);
    final cols = (w / 7.6).floor().clamp(1, 300);
    if (rows == _ptyRows && cols == _ptyCols) return;
    _ptyRows = rows;
    _ptyCols = cols;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ansi?.reset(rows: rows, cols: cols);
      _pty!.resize(rows, cols);
    });
  }

  /// Abre una sesiÃ³n PTY con [argv]. Si falla, vuelca error por [o].
  Future<void> _ptyOpen(
    List<String> argv, {
    Map<String, String>? env,
    String? ldPreload,
    void Function(String, Ln)? o,
  }) async {
    final out = o ?? _out;

    // ── New PtyManager path ──
    if (_ptyManager?.shell != null) {
      final ok = await _ptyManager!.open(argv, env: env, ldPreload: ldPreload);
      if (ok) {
        _pty = _ptyManager!.session;
        _ansi = _ptyManager!.ansi;
        if (mounted) setState(() {});
        out('— terminal interactivo —', Ln.system);
        return;
      }
    }

    // ── Legacy PTY path (fallback) ──
    try {
      if (!(await _rootfs?.checkInstalled() ?? false)) {
        out('pty: rootfs no instalado. Ejecuta "bootstrap" primero.', Ln.stderr);
        return;
      }
      // Verificar que el binario existe en el rootfs. El bootstrap BASE no
      // trae python/vim/htop/git: el usuario debe "pkg install" primero.
      if (argv.isNotEmpty) {
        final binPath = argv.first;
        try {
          if (!File(binPath).existsSync()) {
            final name = binPath.split('/').last;
            out('pty: "$name" no estÃ¡ instalado en el rootfs.', Ln.stderr);
            out('  InstÃ¡lalo con: pkg install $name', Ln.info);
            return;
          }
        } catch (_) {/* si no se puede verificar, se intenta abrir igual */}
      }
      // Cerrar sesiÃ³n previa antes de abrir otra (evita leaks de proceso/fd).
      if (_pty != null) await _ptyClose();

      // ── Rootfs environment (single source via _rootfsEnv) ──
      final defaultEnv = _rootfsEnv(ldPreload: ldPreload);
      if (env != null) defaultEnv.addAll(env);

      final ses = await PtySession.open(
        argv: argv,
        env: defaultEnv,
        ldPreload: ldPreload,
        rows: 24,
        cols: 80,
      );
      _pty = ses;
      _ptyLines.clear();
      // Buffer ANSI con las mismas dims que la sesiÃ³n PTY.
      _ansi?.dispose();
      _ansi = AnsiTerminal(rows: 24, cols: 80);
      var lastTitle = '';
      _ansi!.addListener(() {
        final t = _ansi!.title;
        if (t.isNotEmpty && t != lastTitle) { lastTitle = t; widget.onTitle?.call(t); }
      });
      ses.output.listen(_onPtyOutput);
      // Rebuild inmediato: activa AnsiTerminalView y el hint del input PTY.
      if (mounted) setState(() {});
      // done: solo limpia si aÃºn somos la sesiÃ³n activa (que la anterior
      // no borre una sesiÃ³n reciÃ©n abierta).
      ses.done.listen((_) async {
        if (_pty == ses) _pty = null;
        _ptyLines.clear();
        _ansi?.dispose();
        _ansi = null;
        out('', Ln.stdout);
        if (mounted) setState(() {});
      });
      out('â€” terminal interactivo (Ctrl+C para SIGINT, escribe "exit") â€”', Ln.system);
      out('pty> ', Ln.prompt);
    } catch (e) {
      out('pty: error al abrir: $e', Ln.stderr);
    }
  }

  /// Vuelca bytes del PTY al buffer ANSI (parsea colores, cursor y scroll).
  void _onPtyOutput(Uint8List data) {
    if (!_alive || !mounted) return;
    final a = _ansi;
    if (a != null) {
      a.feedBytes(data);
      return;
    }
    // Fallback cuando no hay buffer ANSI: decodificar como lÃ­neas planas.
    final text = utf8.decode(data, allowMalformed: true).replaceAll('\r', '\n');
    final buf = _ptyLines.join() + text;
    _ptyLines.clear();
    final parts = buf.split('\n');
    _ptyLines.add(parts.last);
    for (final line in parts.take(parts.length - 1)) {
      if (line.isEmpty) continue;
      _out(line, Ln.stdout);
    }
  }

  /// Cierra la sesiÃ³n PTY (envÃ­a SIGINT) y limpia el estado.
  Future<void> _ptyClose() async {
    final p = _pty;
    _pty = null;
    _ptyLines.clear();
    _ansi?.dispose();
    _ansi = null;
    if (p != null) {
      try { await p.signal(2); } catch (_) {}
      try { await p.close(); } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  // â”€â”€ Noar Command Library (historial con metadata) â”€â”€
  final List<Map<String, dynamic>> _noarLib = [];
  static const _noarKey = 'noar_library';

  /// Guarda un comando ejecutado en la librerÃ­a Noar con timestamp y tag.
  void _saveToNoar(String cmd, String tag) {
    _noarLib.insert(0, {
      'cmd': cmd,
      'tag': tag,
      'ts': DateTime.now().toIso8601String(),
    });
    if (_noarLib.length > 500) _noarLib.removeRange(500, _noarLib.length);
    _persistNoar();
  }

  Future<void> _loadNoar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final j = p.getString(_noarKey);
      if (j != null) {
        final list = (jsonDecode(j) as List).cast<Map>();
        _noarLib.addAll(list.map((m) => Map<String, dynamic>.from(m)));
      }
    } catch (_) {}
  }

  Future<void> _persistNoar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_noarKey, jsonEncode(_noarLib.take(500).toList()));
    } catch (_) {}
  }

  /// Clasifica un comando en un tag basado en su nombre.
  String _tagFor(String cmd) {
    final name = cmd.split(' ').first;
    if (['ls','cat','cd','pwd','mkdir','touch','rm','cp','mv','echo','grep','find','wc','head','tail','diff','chmod','tree'].contains(name)) return 'fs';
    if (['apt','pkg','pip','npm','gem','cargo'].contains(name)) return 'pkgs';
    if (['docker'].contains(name)) return 'containers';
    if (['kali'].contains(name)) return 'kali';
    if (['ps','kill','htop','top','pstree','free','df'].contains(name)) return 'monitor';
    if (['git','ssh','curl','wget','scp'].contains(name)) return 'remote';
    if (['ai','infer','stat','tune','gpu','nvtop'].contains(name)) return 'ai';
    if (['bootstrap'].contains(name)) return 'rootfs';
    if (['bash','toybox'].contains(name)) return 'shell';
    if (cmd.startsWith('!')) return 'shell';
    return 'general';
  }

  /// Vuelca output de un comando en tiempo real (streaming) al buffer del terminal.
  /// Cada lÃ­nea de stdout/stderr se renderiza apenas llega.
  void _streamOut({required void Function(String line) onOut, required void Function(String line) onErr}) {
    // Wrapper que captura callbacks de streaming y los vuelca al terminal
  }

  Future<void> _execAsync(String raw) async {
    // â”€â”€ Modo PTY: Enter se envÃ­a como CR directo al terminal. Sin echo del
    // prompt propio (el PTY con raw mode + echo hace su propio eco; duplicar
    // aquÃ­ romperÃ­a vim/htop). "exit"/"logout" cierran la sesiÃ³n.
    if (_ptyActive) {
      final cmd = raw.trim();
      if (cmd == 'exit' || cmd == 'logout' || cmd == '^D') {
        await _ptyClose();
        return;
      }
      if (cmd.isNotEmpty) {
        // Comando escrito como lÃ­nea (caso teclado fÃ­sico / paste).
        _pty!.writeBytes([...cmd.codeUnits, 0x0d]);
      }
      // cmd vacÃ­o: _onKey ya enviÃ³ CR vÃ­a hardware keyboard. No duplicar.
      return;
    }

    _out(_ps1 + raw, Ln.prompt); final cmd = raw.trim(); if (cmd.isEmpty) return;
    _hist.add(cmd); _hIdx = -1; _in.clear();
    _saveToNoar(cmd, _tagFor(cmd));
    // --- CommandDispatcher: common Linux commands ---
    if (_dispatcher != null && !_hasShellOps(cmd)) {
      final parts = cmd.split(RegExp(r'\s+'));
      if (parts.isNotEmpty && _dispatcher!.dispatch(parts[0],
          parts.length > 1 ? parts.sublist(1) : <String>[])) return;
    }
; // persistir en librerÃ­a Noar

    // â”€â”€ Prefijo ! â†’ ash -c con BusyBox real (Nanoshell FFI) â”€â”€
    if (cmd.startsWith('!')) {
      final shellCmd = cmd.substring(1).trim();
      if (shellCmd.isEmpty) return;
      // Track cd para mantener el prompt sincronizado con el cwd del rootfs.
      if (shellCmd.startsWith('cd ') || shellCmd == 'cd') {
        final target = shellCmd.length > 3 ? shellCmd.substring(3).trim() : '/';
        if (target == '..') {
          _bashCwd = _bashCwd == '/' ? '/' : _bashCwd.substring(0, _bashCwd.lastIndexOf('/'));
          if (_bashCwd.isEmpty) _bashCwd = '/';
        } else if (target.startsWith('/')) {
          _bashCwd = target;
        } else if (target.isNotEmpty) {
          _bashCwd = _bashCwd == '/' ? '/$target' : '$_bashCwd/$target';
        }
        _out('[ash] cd â†’ $_bashCwd', Ln.system);
      }
      if (_shell != null && _shell!.initialized) {
        _out('[ash] $shellCmd', Ln.system);
        // Si rootfs instalado: LD_PRELOAD=libnanoroot.so para que ash
        // y sus subprocesos tengan el execveâ†’dlopen intercept.
        // LD_LIBRARY_PATH apunta a usr/lib/ para que dlopen encuentre
        // libc++_shared.so, libssl.so y demÃ¡s deps de los binarios Termux.
        final extraEnv = _rootfs?.isInstalled == true
            ? <String, String>{
                'LD_PRELOAD': 'libnanoroot.so',
                'NANO_ROOTFS': _shell!.usrDir!,
                'LD_LIBRARY_PATH': '${_shell!.usrDir}/lib',
                'HOME': '${_shell!.baseDir!}/home',
                'PATH': '${_shell!.usrDir}/bin:${_shell!.usrDir}/bin/applets:/system/bin:/system/xbin',
                'TERMUX': 'true',
                'LANG': 'en_US.UTF-8',
              }
            : null;
        final r = await _shell!.toybox(['ash', '-c', shellCmd], extraEnv: extraEnv);
        _shellOut(r);
      } else {
        _out('! : shell no disponible (binarios no extraÃ­dos)', Ln.stderr);
      }
      return;
    }

    // â”€â”€ DetecciÃ³n automÃ¡tica de pipes/redirecciÃ³n â†’ ash -c via Nanoshell â”€â”€
    if (_hasShellOps(cmd) && _shell != null && _shell!.initialized) {
      _out('[ash] $cmd', Ln.system);
      final extraEnv = _rootfs?.isInstalled == true
          ? _rootfsEnv(ldPreload: 'libnanoroot.so')
          : null;
      final r = await _shell!.toybox(['ash', '-c', cmd], extraEnv: extraEnv);
      _shellOut(r);
      return;
    }

    var parts = _tok(cmd); if (parts.isNotEmpty && _ctx.aliases.containsKey(parts[0])) parts = _tok(_ctx.aliases[parts[0]]!);
    if (parts.isEmpty) return;
    final name = parts[0], args = parts.sublist(1);

    // â”€â”€ Comandos bash / toybox explÃ­citos â”€â”€
    if (name == 'bash' && _shell != null && _shell!.initialized) {
      final shellCmd = args.isNotEmpty ? args.join(' ') : '-i';
      _out('[ash] $shellCmd', Ln.system);
      final r = await _shell!.toybox(['ash', '-c', shellCmd]);
      _shellOut(r); return;
    }
    if (name == 'toybox' && _shell != null && _shell!.initialized) {
      final result = await _shell!.toybox(args);
      _shellOut(result); return;
    }

    // REAL: comandos whitelist â†’ probar toybox real primero, luego dart:io.
    if (_realCmds.contains(name)) {
      // Intento 1: shell real (BusyBox via Nanoshell FFI)
      if (_shell != null && _shell!.initialized) {
        final r = await _shell!.toybox([name, ...args]);
        // Mostrar output real siempre, excepto si el applet no existe (rc=127).
        if (r.exitCode != 127 || r.stderr.contains('applet not found') || r.stderr.contains('not found')) {
          _shellOut(r);
          if (r.exitCode != 127) return; // comando ejecutado con Ã©xito o fallo normal
        }
        // rc=127 (applet not found): continuar a dart:io fallback
      }
      // Intento 2: dart:io fallback (opera sobre _realRoot, no rootfs)
      final r = _runRealSync(name, args);
      if (r != null) { _realOut(r, name, args, raw); return; }
    }
    // Dispatch via registry (sim / datos reales de _devId)
    final handler = _cmds[name];
    if (handler != null) { handler(args, _ctx, _out, _after); } else { _out('$name: comando no encontrado. "help" para ver todos.', Ln.stderr); }
  }

  /// Vuelca la salida de un ShellResult en el buffer del terminal.
  void _shellOut(ShellResult r) {
    if (!_alive || !mounted) return;
    for (final l in r.stdout.split('\n')) { if (l.isNotEmpty) _out(l, Ln.stdout); }
    for (final l in r.stderr.split('\n')) { if (l.isNotEmpty) _out(l, Ln.stderr); }
  }

  // Muestra el resultado de un comando real ejecutado con dart:io.
  void _realOut((String, String, int) r, String name, List<String> args, String raw) {
    if (!_alive) return;
    for (final l in r.$1.split('\n')) if (l.isNotEmpty) _out(l, Ln.stdout);
    for (final l in r.$2.split('\n')) if (l.isNotEmpty) _out(l, Ln.stderr);
  }

  // â”€â”€ Keyboard â”€â”€
  /// Handler global de teclado (HardwareKeyboard).
  ///
  /// En modo PTY interactivo cada keydown se convierte a bytes y se envÃ­a al
  /// terminal (vim/htop/python necesitan teclas individuales, no lÃ­neas con
  /// Enter). Fuera de PTY conserva Ctrl+L/C de la shell integrada.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) {
      if (e is KeyUpEvent &&
          (e.logicalKey == LogicalKeyboardKey.controlLeft ||
              e.logicalKey == LogicalKeyboardKey.controlRight)) {
        _ctrl = false;
      }
      return false;
    }

    if (e.logicalKey == LogicalKeyboardKey.controlLeft ||
        e.logicalKey == LogicalKeyboardKey.controlRight) {
      _ctrl = true;
      return false;
    }

    // â”€â”€ Modo PTY: reenvÃ­o bruto de teclas al terminal â”€â”€
    if (_ptyActive) {
      if (_ctrl) {
        // Atajos dedicados (SIGINT, clear, EOF, suspend).
        if (e.logicalKey == LogicalKeyboardKey.keyC) {
          _ctrl = false;
          _pty!.signal(2);
          return true;
        }
        if (e.logicalKey == LogicalKeyboardKey.keyL) {
          _ctrl = false;
          _pty!.write('\x0c');
          return true;
        }
        if (e.logicalKey == LogicalKeyboardKey.keyZ) {
          _ctrl = false;
          _pty!.write('\x1a');
          return true;
        }
        if (e.logicalKey == LogicalKeyboardKey.keyD) {
          _ctrl = false;
          _pty!.write('\x04');
          return true;
        }
        // Cualquier otra Ctrl+letra â†’ byte de control (0x01-0x1a) al PTY.
        // Consumida (return true): no debe filtrarse al TextField.
        final ch = _logicalToChar(e.logicalKey);
        if (ch != null && ch >= 0x61 && ch <= 0x7a) {
          _pty!.writeBytes([ch - 0x60]);
          return true;
        }
        if (ch != null && ch >= 0x41 && ch <= 0x5a) {
          _pty!.writeBytes([ch - 0x40]);
          return true;
        }
        return false;
      }
      // Alt/Meta: ESC + carácter
      if (HardwareKeyboard.instance.isAltPressed && !HardwareKeyboard.instance.isControlPressed) {
        final bytes = _keyToPtyBytes(e);
        if (bytes != null && bytes.length == 1 && bytes[0] >= 0x20) {
          _pty!.writeBytes([0x1b, bytes[0]]);
          return true;
        }
      }
      final bytes = _keyToPtyBytes(e);
      if (bytes != null) _pty!.writeBytes(bytes);
      return bytes != null;
    }

    if (_ctrl && e.logicalKey == LogicalKeyboardKey.keyL) {
      setState(() => _lines.clear());
      _ctrl = false;
      return true;
    }
    if (_ctrl && e.logicalKey == LogicalKeyboardKey.keyC) {
      _out('^C', Ln.stdout);
      _in.clear();
      _ctrl = false;
      return true;
    }
    return false;
  }

  /// Traduce un KeyDownEvent a la secuencia de bytes de terminal (modo PTY).
  /// Devuelve null si la tecla no debe enviarse (modificadores sueltos, etc.).
  List<int>? _keyToPtyBytes(KeyEvent e) {
    final k = e.logicalKey;

    // NOTE: Ctrl/Alt handling is done in _onKey BEFORE calling this mapper.
    // This function only handles special keys (F-keys, arrows, nav, etc.)
    // and printable characters.

    // Fila de funciÃ³n F1-F12
    if (k.keyId >= LogicalKeyboardKey.f1.keyId &&
        k.keyId <= LogicalKeyboardKey.f12.keyId) {
      final n = k.keyId - LogicalKeyboardKey.f1.keyId + 1;
      if (n == 1) return [0x1b, 0x4f, 0x50]; // F1
      if (n == 2) return [0x1b, 0x4f, 0x51]; // F2
      if (n == 3) return [0x1b, 0x4f, 0x52]; // F3
      if (n == 4) return [0x1b, 0x4f, 0x53]; // F4
      // F5-F12: ESC [15~ ... ESC [24~
      // F5=15, F6=17, F7=18, F8=19, F9=20, F10=21, F11=23, F12=24
      final code = n + 10; // F5 → 15, F12 → 22... wait
      // Mapping: F5→15, F6→17, F7→18, F8→19, F9→20, F10→21, F11→23, F12→24
      final fn = [15, 17, 18, 19, 20, 21, 23, 24][n - 5];
      final digits = '$fn'.codeUnits; // e.g. "17" → [0x31, 0x37]
      return [0x1b, 0x5b, ...digits, 0x7e];
    }

    // Flechas
    if (k == LogicalKeyboardKey.arrowUp) return [0x1b, 0x5b, 0x41];
    if (k == LogicalKeyboardKey.arrowDown) return [0x1b, 0x5b, 0x42];
    if (k == LogicalKeyboardKey.arrowRight) return [0x1b, 0x5b, 0x43];
    if (k == LogicalKeyboardKey.arrowLeft) return [0x1b, 0x5b, 0x44];

    // Home/End/PageUp/PageDown
    if (k == LogicalKeyboardKey.home) return [0x1b, 0x5b, 0x48];
    if (k == LogicalKeyboardKey.end) return [0x1b, 0x5b, 0x46];
    if (k == LogicalKeyboardKey.pageUp) return [0x1b, 0x5b, 0x35, 0x7e];
    if (k == LogicalKeyboardKey.pageDown) return [0x1b, 0x5b, 0x36, 0x7e];

    // Insert/Del
    if (k == LogicalKeyboardKey.insert) return [0x1b, 0x5b, 0x32, 0x7e];
    if (k == LogicalKeyboardKey.delete) return [0x1b, 0x5b, 0x33, 0x7e];

    // Teclas de control
    if (k == LogicalKeyboardKey.enter) return [0x0d];
    if (k == LogicalKeyboardKey.tab) return [0x09];
    if (k == LogicalKeyboardKey.backspace) return [0x7f];
    if (k == LogicalKeyboardKey.escape) return [0x1b];
    if (k == LogicalKeyboardKey.space) return [0x20];

    // Modificadores solos: no envÃ­an nada
    if (k == LogicalKeyboardKey.shiftLeft || k == LogicalKeyboardKey.shiftRight ||
        k == LogicalKeyboardKey.altLeft || k == LogicalKeyboardKey.altRight ||
        k == LogicalKeyboardKey.metaLeft || k == LogicalKeyboardKey.metaRight ||
        k == LogicalKeyboardKey.capsLock || k == LogicalKeyboardKey.numLock) {
      return null;
    }

    // Ctrl+letra â†’ byte de control (0x01-0x1a)
    if (_ctrl) {
      final ch = _logicalToChar(k);
      if (ch != null && ch >= 0x61 && ch <= 0x7a) return [ch - 0x60];
      if (ch != null && ch >= 0x41 && ch <= 0x5a) return [ch - 0x40];
      return null;
    }

    // CarÃ¡cter imprimible (incluye mayÃºsculas con Shift)
    final ch = _logicalToChar(k);
    if (ch != null && ch >= 0x20) return [ch];
    return null;
  }

  /// Extrae el carÃ¡cter simple de una tecla lÃ³gica (sin mods de control).
  int? _logicalToChar(LogicalKeyboardKey k) {
    final kid = k.keyId;
    final chr = kid >= 0x20 && kid <= 0x7e ? kid : null;
    if (chr != null) return chr;
    // keyLabel como fallback (teclas con mayÃºsculas/sÃ­mbolos locales)
    final label = k.keyLabel;
    if (label.isNotEmpty && label.length == 1) {
      final c = label.codeUnitAt(0);
      if (c >= 0x20) return c;
    }
    return null;
  }

  // â”€â”€ Autocomplete â”€â”€
  List<String> _sug() { final p = _in.text.trim(); if (p.isEmpty) return _cmds.keys.take(8).toList(); return _cmds.keys.where((c) => c.startsWith(p)).followedBy(_ctx.fs.resolve('.')?.children.map((c) => c.name + (c.isDir ? '/' : '')).where((n) => n.startsWith(p)) ?? []).take(10).toList(); }

  // â”€â”€ Persistence â”€â”€
  Future<void> _loadHistory() async { try { final p = await SharedPreferences.getInstance(); final j = p.getString('term_hist_${widget.sessionId}'); if (j != null) _hist.addAll((jsonDecode(j) as List).cast<String>()); } catch (_) {} }
  Future<void> _saveHistory() async { try { final p = await SharedPreferences.getInstance(); await p.setString('term_hist_${widget.sessionId}', jsonEncode(_hist.length > 500 ? _hist.sublist(_hist.length - 500) : _hist)); } catch (_) {} }

  Color _c(Ln t, Color fg) => switch (t) { Ln.prompt => fg.withValues(alpha: 0.9), Ln.stdout => fg.withValues(alpha: 0.78), Ln.stderr => const Color(0xFFFF6B6B), Ln.success => fg, Ln.info => fg.withValues(alpha: 0.65), Ln.warn => const Color(0xFFFFB74D), Ln.system => fg.withValues(alpha: 0.55), Ln.header => const Color(0xFF00E676) };

  @override Widget build(BuildContext context) {
    final c = NanoThemeExtension.of(context).colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chrome = dark ? const Color(0xFF0A0F1A) : const Color(0xFFE0E0EC);
    final fg = c.terminalGreen; final sug = _sug();

    return Stack(children: [
      Column(children: [
      // â”€â”€ Terminal scroll buffer â”€â”€
      // --- Status bar: PTY vs SIMULADO ---
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        color: _ptyActive ? const Color(0xFF0A3D0A) : const Color(0xFF3D2E00),
        child: Text(
          _ptyActive ? 'PTY: bash (rootfs real)' : 'SIMULADO (offline)',
          style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, color: _ptyActive ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24)),
        ),
      ),
      Expanded(
        child: Stack(children: [
          // Scanline effect overlay
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ScanlinePainter(_ansi != null ? fg.withValues(alpha: 0.4) : fg)))),
          // Content
          if (_ansi != null)
              // Renderer ANSI/VT100: buffer grid con colores y cursor.
              // LayoutBuilder detecta el tamaÃ±o real â†' resize dinÃ¡mico del PTY.
              GestureDetector(
                onTap: () => _fn.requestFocus(),
                onTapDown: _ansi?.mouseEnabled == true ? (d) {
                  final row = (d.localPosition.dy / 20).floor();
                  final col = (d.localPosition.dx / 7.6).floor();
                  // ESC [ M <btn+32> <col+33> <row+33>
                  _pty?.writeBytes([0x1b, 0x5b, 0x4d, 32, col + 33, row + 33]);
                } : null,
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: LayoutBuilder(
                    builder: (context, cons) {
                      _applyPtySize(cons.maxWidth, cons.maxHeight);
                      return SelectionArea(
                        child: AnsiTerminalView(_ansi!),
                      );
                    },
                  ),
                ),
              )
          else
            SelectionArea(
            child: InteractiveViewer(
              minScale: 0.8, maxScale: 2.5,
              child: GestureDetector(
                onTap: () => _fn.requestFocus(),
                child: ListView.builder(
                  controller: _sc,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _lines.length,
                  itemBuilder: (_, i) {
                    final line = _lines[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 1.5),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Line number gutter
                        SizedBox(width: 32, child: Text('${i + 1}', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, color: fg.withValues(alpha: 0.15), height: 1.6))),
                        // Content
                        Expanded(child: Text(line.text, style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12.5, color: _c(line.type, fg), height: 1.6, letterSpacing: 0.2))),
                      ]),
                    );
                  },
                ),
              ),
            ),
          ),
        ]),
      ),

      if (_ptyActive) _modifierRow(fg, chrome),
      // â”€â”€ Autocomplete panel â”€â”€
      if (sug.isNotEmpty && _in.text.isNotEmpty && _fn.hasFocus)
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: chrome, border: Border(top: BorderSide(color: fg.withValues(alpha: 0.08)))), child: Wrap(spacing: 6, runSpacing: 4, children: sug.map((s) => GestureDetector(
          onTap: () { _in.text = s; _in.selection = TextSelection.collapsed(offset: s.length); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: fg.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(5), border: Border.all(color: fg.withValues(alpha: 0.08))), child: Text(s, style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.5, color: fg.withValues(alpha: 0.7)))))).toList())),

      // â”€â”€ Input area â”€â”€
      Container(
        decoration: BoxDecoration(color: chrome, border: Border(top: BorderSide(color: fg.withValues(alpha: 0.12)))),
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(_ps1, style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowUp): () { if (_hIdx < _hist.length - 1) { _hIdx++; _in.text = _hist.reversed.toList()[_hIdx]; _in.selection = TextSelection.collapsed(offset: _in.text.length); } },
                const SingleActivator(LogicalKeyboardKey.arrowDown): () { if (_hIdx > 0) { _hIdx--; _in.text = _hist.reversed.toList()[_hIdx]; } else { _hIdx = -1; _in.clear(); } },
                const SingleActivator(LogicalKeyboardKey.tab): () { if (sug.isNotEmpty) { _in.text = sug.first; _in.selection = TextSelection.collapsed(offset: _in.text.length); } },
              },
              child: TextField(
                controller: _in, focusNode: _fn, autofocus: true,
                style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, color: fg, height: 1.5),
                cursorColor: fg, cursorWidth: 2,
                decoration: InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, hintText: _ptyActive ? 'terminal interactivo â€” escribe directo (Ctrl+C salir)' : 'comando o "ai <pregunta>"...', hintStyle: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, color: fg.withValues(alpha: 0.18))),
                onSubmitted: _exec,
                onChanged: (v) {
                  if (_ptyActive && v.isNotEmpty) {
                    // Teclado VIRTUAL: el IME entrega caracteres al TextField,
                    // NO a HardwareKeyboard (_onKey). En modo PTY cada
                    // carÃ¡cter tecleado debe ir al terminal byte a byte, y el
                    // campo se limpia (el terminal es el que muestra el eco).
                    // UTF-8 encode: codeUnits (UTF-16) → bytes reales.
                    final bytes = utf8.encode(v).where((b) => b >= 0x20).toList();
                    if (bytes.isNotEmpty) _pty!.writeBytes(bytes);
                    _in.clear();
                    return;
                  }
                  _hIdx = -1;
                },
              ),
            ),
          ),
          ]),
        ),
      ]),
      // â”€â”€ Noar FAB (draggable) â”€â”€
      if (_fabInit)
      Positioned(
        left: _fabOffset.dx,
        top: _fabOffset.dy,
        child: GestureDetector(
          onPanUpdate: (d) {
            setState(() {
              final sw = MediaQuery.of(context).size.width;
              final sh = MediaQuery.of(context).size.height;
              _fabOffset = Offset(
                (_fabOffset.dx + d.delta.dx).clamp(0.0, sw - _fabSize),
                (_fabOffset.dy + d.delta.dy).clamp(40.0, sh - _fabSize - 100),
              );
            });
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _fabInit ? 0.55 : 0.0,
            child: Material(
              color: chrome,
              borderRadius: BorderRadius.circular(12),
              elevation: 4,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => NoarPanel(
                      library: _noarLib,
                      fg: fg,
                      dark: dark,
                    ),
                  );
                },
                child: Container(
                  width: _fabSize,
                  height: _fabSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fg.withValues(alpha: 0.18)),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: fg, size: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Tarea programada para crontab interno.
class _CronJob {
  final int intervalMin;
  final String command;
  final Timer timer;
  _CronJob({required this.intervalMin, required this.command, required this.timer});
}

/// Subtle scanline effect for retro terminal feel
class _ScanlinePainter extends CustomPainter {
  final Color color;
  _ScanlinePainter(this.color);
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.015);
    for (double y = 0; y < size.height; y += 3) { canvas.drawLine(Offset(0, y), Offset(size.width, y), paint); }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}
