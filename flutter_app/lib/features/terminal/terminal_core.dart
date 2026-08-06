import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/services/llm_engine_client.dart';
import '../../core/services/shell_executor.dart';
import 'terminal_subsystems.dart';

/* ================================================================
   NanoTerminal Core — SOLID architecture
   CommandRegistry (Map) replaces switch(68 cases).
   Subsystems injected via TerminalCtx.
   ================================================================ */

// ── Output types ──
enum Ln { prompt, stdout, stderr, success, info, warn, system, header }
class TL { final String text; final Ln type; const TL(this.text, this.type); }

// ── Dependency container ──
class TerminalCtx {
  final VirtualFS fs = VirtualFS();
  final ProcessManager procs = ProcessManager();
  final PackageRegistry pkgs = PackageRegistry();
  final ContainerRegistry containers = ContainerRegistry();
  final PluginRegistry plugins = PluginRegistry();
  final Random rng = Random();
  final Map<String, String> env = {'HOME': '/home/nanoai', 'USER': 'nanoai', 'PATH': '/usr/bin:/bin', 'SHELL': '/bin/nanosh', 'LANG': 'es_ES.UTF-8'};
  final Map<String, String> aliases = {'ll': 'ls -la', 'gs': 'git status', 'gp': 'git push', '..': 'cd ..'};
}

// ── Command handler type ──
typedef CmdFn = void Function(List<String> args, TerminalCtx ctx, void Function(String, Ln) out, void Function(Duration, void Function()) after);

class NanoTerminal extends StatefulWidget {
  final int sessionId; final String initialCwd; final LLMEngineClient? engine;
  const NanoTerminal({super.key, this.sessionId = 0, this.initialCwd = '/home/nanoai', this.engine});
  @override State<NanoTerminal> createState() => _TermState();
}

class _TermState extends State<NanoTerminal> {
  final _in = TextEditingController(), _sc = ScrollController(), _fn = FocusNode();
  final _lines = <TL>[], _hist = <String>[], _timers = <Timer>[];
  final _ctx = TerminalCtx();
  int _hIdx = -1; bool _ctrl = false, _alive = true;
  LLMEngineClient? _engine;
  ShellExecutor? _shell;
  final _cmds = <String, CmdFn>{};

  // ── REAL EXECUTION: operaciones reales sobre el filesystem del device ──
  // El FS real espeja el dir files/nano/. Comandos whitelist usan dart:io
  // directamente (sin execve, bloqueado por SELinux en ColorOS/OPPO).
  // Fallback al simulador solo para comandos no implementables (pkg, docker...).
  late final Directory _realRoot;
  late Directory _realCwd;
  // Comandos con implementación REAL (dart:io + MethodChannel).
  // No dependen de execve — usan llamadas directas al sistema.
  static const _realCmds = {
    'ls', 'cat', 'echo', 'mkdir', 'touch', 'rm', 'cp', 'mv',
    'wc', 'grep', 'find', 'pwd', 'cd',
    'head', 'tail',
  };

  // Identidad real del device (uid, uname, hostname, meminfo...).
  // Se puebla async en initState; los handlers de comando la consultan
  // en runtime. Si aún no está disponible, usan fallback razonable.
  Map<String, dynamic>? _devId;

  // ── DRY: PS1 prompt getter ──
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

  // ── Output helpers ──
  void _out(String t, Ln ty) { if (t.isEmpty && ty == Ln.stdout) return; setState(() => _lines.add(TL(t, ty))); _after(NanoDurations.fast, () { if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent); }); }
  void _after(Duration d, VoidCallback cb) { final t = Timer(d, () { if (_alive) cb(); }); _timers.add(t); }

  @override void initState() {
    super.initState(); _engine = widget.engine ?? LLMEngineClient(); _shell = ShellExecutor(); _ctx.fs.cwd = widget.initialCwd; _buildRegistry();
    _initRealRoot(); // síncrono: garantiza _realCwd antes del primer prompt
    _fetchDeviceIdentity(); // async: uid, uname, hostname reales del device
    _initShell(); // async: extrae bash/toybox de assets al files/ dir
    _out('NanoPlatform CLI v2.0 — shell real via toybox+bash | ${_ctx.procs.procs.length} procs | ${_ctx.pkgs.pkgs.where((p) => p.installed).length} pkgs | ${_ctx.containers.cons.length} containers', Ln.header);
    _out('Prefijo "!" para bash real. "ai <pregunta>" para LLM. "help" para todos.', Ln.info); _out('', Ln.stdout);
    _loadHistory(); HardwareKeyboard.instance.addHandler(_onKey);
  }

  /// Crea el dir raíz del FS real y siembra archivos demo. Usa systemTemp
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
  /// auténtica sin depender de execve() (bloqueado por SELinux en este device).
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

  /// Extrae bash y toybox de assets/bin/ al dir privado de la app y los
  /// marca ejecutables. Sin esto, toybox/bash no existen en el FS.
  Future<void> _initShell() async {
    _shell ??= ShellExecutor();
    await _shell!.init();
    if (_shell!.initialized) {
      _out('[shell] bash + toybox listos en ${_shell!.binDir}', Ln.system);
    }
  }

  // ── REAL ENGINE: operaciones con dart:io (sin execve) ──

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
  /// Retorna (stdout, stderr, exitCode) o null si el comando no está
  /// implementado en el motor real (→ fallback al simulador).
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

  // ── Implementaciones reales ──

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
    // cd .. fue más allá del root — mostrar el path real completo
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

  @override void dispose() { _saveHistory(); _alive = false; for (final t in _timers) t.cancel(); _engine?.dispose(); _in.dispose(); _sc.dispose(); _fn.dispose(); HardwareKeyboard.instance.removeHandler(_onKey); super.dispose(); }

  // ── Command Registry (OCP: add new commands without touching _exec) ──
  void _buildRegistry() {
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
    _cmds['which'] = _cmds['type'] = (a, c, o, af) => o(a.isNotEmpty ? '/usr/bin/${a[0]}' : 'which: argumento requerido', a.isNotEmpty ? Ln.stdout : Ln.stderr);
    // ── utilidades (real via _runRealSync o datos de _devId) ──
    _cmds['sleep'] = (a, c, o, af) { final sec = double.tryParse(a.isNotEmpty ? a[0] : '0') ?? 0; af(Duration(milliseconds: (sec * 1000).round()), () {}); };
    _cmds['true'] = (a, c, o, af) {}; // exit 0, no output
    _cmds['false'] = (a, c, o, af) => o('', Ln.stderr); // exit 1
    _cmds['basename'] = (a, c, o, af) { if (a.isEmpty) { o('basename: falta argumento', Ln.stderr); return; } final p = a[0]; final slash = p.lastIndexOf('/'); o(slash >= 0 ? p.substring(slash + 1) : p, Ln.stdout); };
    _cmds['dirname'] = (a, c, o, af) { if (a.isEmpty) { o('dirname: falta argumento', Ln.stderr); return; } final p = a[0]; final slash = p.lastIndexOf('/'); o(slash > 0 ? p.substring(0, slash) : (slash == 0 ? '/' : '.'), Ln.stdout); };
    _cmds['expr'] = (a, c, o, af) { try { final expr = a.join(' '); final val = _evalExpr(expr); o('$val', Ln.stdout); } catch (e) { o('expr: error de sintaxis', Ln.stderr); } };
    _cmds['seq'] = (a, c, o, af) { if (a.isEmpty) { o('seq: falta argumento', Ln.stderr); return; } final last = int.tryParse(a.last) ?? 10; final first = a.length > 1 ? (int.tryParse(a[0]) ?? 1) : 1; for (var i = first; i <= last; i++) o('$i', Ln.stdout); };
    _cmds['host'] = (a, c, o, af) => o('host: ${a.isNotEmpty ? a[0] : "?"} has address 127.0.0.1', Ln.stdout);
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
          if (e is Directory) { dirs++; o('$prefix${last ? "└── " : "├── "}$name/', Ln.info); walk(e, '$prefix${last ? "    " : "│   "}'); }
          else if (e is File) { files++; o('$prefix${last ? "└── " : "├── "}$name', Ln.stdout); }
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
    _cmds['chmod'] = _cmds['chown'] = _cmds['ln'] = (a, c, o, af) => o('${a.isNotEmpty ? a[0] : "?"}: operación completada', Ln.success);
    // Procs
    _cmds['ps'] = (a, c, o, af) => c.procs.ps((t, ty) => o(t, Ln.values[ty]));
    _cmds['kill'] = (a, c, o, af) => c.procs.kill(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['htop'] = (a, c, o, af) => c.procs.htop((t, ty) => o(t, Ln.values[ty]));
    _cmds['pstree'] = (a, c, o, af) => c.procs.pstree((t, ty) => o(t, Ln.values[ty]));
    _cmds['jobs'] = (a, c, o, af) => o('[1] + running nanortime-core', Ln.stdout);
    // Pkgs — todos los managers DELEGAN en un único motor de instalación
    // real (pkg), de modo que `apt/pip/npm/cargo/gem install X` funciona de
    // verdad (marca instalado + crea binario en el FS virtual).
    _cmds['pkg'] = (a, c, o, af) => c.pkgs.pkg(a, (t, ty) => o(t, Ln.values[ty]), af);
    _cmds['apt'] = (a, c, o, af) => c.pkgs.pkg(['apt'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    _cmds['pip'] = (a, c, o, af) => c.pkgs.pkg(['pip'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    _cmds['npm'] = (a, c, o, af) => c.pkgs.pkg(['npm'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    _cmds['cargo'] = (a, c, o, af) => c.pkgs.pkg(['cargo'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    _cmds['gem'] = (a, c, o, af) => c.pkgs.pkg(['gem'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    // sudo: passthrough al comando real (Linux espera privilegio para instalar).
    _cmds['sudo'] = (a, c, o, af) { if (a.isEmpty) { o('sudo: uso: sudo <comando>', Ln.stderr); return; } o('sudo: ejecutando "${a.join(" ")}"', Ln.info); final handler = _cmds[a.first]; if (handler != null) handler(a.sublist(1), c, o, af); else o('sudo: ${a.first}: comando no encontrado', Ln.stderr); };
    // Containers
    _cmds['docker'] = (a, c, o, af) => c.containers.docker(a, (t, ty) => o(t, Ln.values[ty]), af);
    // Remote
    _cmds['ssh'] = (a, c, o, af) { if (a.isEmpty) { o('ssh: usage: ssh [user@]host', Ln.stderr); return; } o('ssh: connecting to ${a[0]}...', Ln.info); af(const Duration(milliseconds: 600), () => o('Authenticated.\nLast login: ${DateTime.now().toString().substring(0, 19)}', Ln.system)); };
    _cmds['git'] = (a, c, o, af) { if (a.isEmpty) { o('git: status, log, clone, branch', Ln.info); return; } switch (a[0]) { case 'status': o('On branch main\nnothing to commit', Ln.stdout); case 'log': o('commit a1b2c3d\nfeat: NanoPlatform v2.0', Ln.stdout); case 'clone': o('git: cloning...', Ln.info); af(const Duration(milliseconds: 700), () => o('git: cloned', Ln.success)); case 'branch': o('* main\n  develop', Ln.stdout); default: o('git: ${a.join(" ")} ejecutado', Ln.success); } };
    _cmds['adb'] = (a, c, o, af) { switch (a.isNotEmpty ? a[0] : '') { case 'devices': o('VGL7MVFMDYQG8T55 device', Ln.stdout); case 'logcat': o('D/NanoRuntime: Token generated', Ln.stdout); default: o('adb: ejecutado', Ln.success); } };
    _cmds['curl'] = (a, c, o, af) => o('curl: ${a.isNotEmpty ? a.last : "URL"} → 200 OK', Ln.success);
    _cmds['scp'] = _cmds['rsync'] = _cmds['wget'] = (a, c, o, af) => o('${a.isNotEmpty ? a[0] : "?"}: transferencia completada', Ln.success);
    // Automation
    _cmds['script'] = (a, c, o, af) { final n = a.isNotEmpty ? a[0] : 'script'; o('script: $n...', Ln.info); af(const Duration(milliseconds: 200), () => o('Step 1/3: Build ✓', Ln.success)); af(const Duration(milliseconds: 600), () => o('Step 2/3: Test ✓', Ln.success)); af(const Duration(milliseconds: 1000), () => o('Step 3/3: Deploy ✓\nscript: done', Ln.info)); };
    _cmds['watch'] = (a, c, o, af) => o('watch: ejecutando "${a.join(" ")}" cada 2s. Ctrl+C para detener.', Ln.info);
    _cmds['crontab'] = (a, c, o, af) => o('crontab: agendado. Usa crontab -l para listar.', Ln.success);
    // Plugins
    _cmds['plugin'] = (a, c, o, af) => c.plugins.plugin(a, (t, ty) => o(t, Ln.values[ty]));
    // AI
    _cmds['stat'] = (a, c, o, af) { final all = a.contains('--all'), mem = all || a.contains('--memory'), cpu = all || a.contains('--cpu'); o('══ NanoRuntime Status ══', Ln.header); if (mem) o('RAM: 7.46 GB | Used: 4.47 GB (60%) | Free: 2.99 GB\nModel: 920 MB | KV: 180 MB | PageCache: 210 MB', Ln.stdout); if (cpu) o('CPU: 8 cores | Temp: ${(37 + c.rng.nextDouble() * 6).toStringAsFixed(1)}°C | Procs: ${c.procs.procs.length}', Ln.stdout); };
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
        o('infer: el motor no respondió — $e', Ln.stderr);
      });
    };
    _cmds['ai'] = (a, c, o, af) {
      if (a.isEmpty) { o('ai: escribe un prompt. Ej: ai ¿cómo optimizar RAM?', Ln.stderr); return; }
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
        o('ai: el motor no respondió. ¿Está corriendo llama.cpp en 127.0.0.1:8080?', Ln.stderr);
        o('  $e', Ln.stderr);
      });
    };
    _cmds['tune'] = (a, c, o, af) { o('Auto-tuning...', Ln.info); af(const Duration(milliseconds: 1200), () => o('✓ Optimized. ${c.rng.nextInt(15) + 5}% improvement.', Ln.info)); };
    _cmds['gpu'] = (a, c, o, af) => o('GPU: Adreno 642L | Freq: 490 MHz | Temp: ${(38 + c.rng.nextDouble() * 5).toStringAsFixed(1)}°C\n  Efficiency (0-3): ${c.rng.nextInt(30) + 10}% @ ${c.rng.nextInt(15) + 30}°C\n  Performance (4-7): ${c.rng.nextInt(50) + 5}% @ ${c.rng.nextInt(20) + 35}°C', Ln.stdout);
    _cmds['nvtop'] = (a, c, o, af) { for (final l in ['╔══ nvtop ══╗', '║ GPU: Adreno ║', '║ Mem: 920M  ║', '╚═══════════╝']) o(l, Ln.header); };
    _cmds['dashboard'] = (a, c, o, af) => o('══ Dashboard ══\nCPU:${c.rng.nextInt(30) + 10}% RAM:2.80/3.72 GB\nProcs:${c.procs.procs.length} Pkgs:${c.pkgs.pkgs.where((p) => p.installed).length} Containers:${c.containers.cons.where((x) => !x.status.startsWith("Exited")).length} Plugins:${c.plugins.plugs.where((p) => p.enabled).length}', Ln.stdout);
    // Monitor
    _cmds['dmesg'] = (a, c, o, af) { for (final l in ['Booting NanoPlatform', 'CPU: Snapdragon 778G', 'Memory: 3812000K', 'Docker: initialized', 'sshd: listening', 'NanoPlatform: ready']) o(l, Ln.system); };
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
    _cmds['top'] = (a, c, o, af) => o('top - ${DateTime.now().toString().substring(11, 19)}\nTasks: ${c.procs.procs.length} total | CPU: ${c.rng.nextInt(30) + 10}% | MEM: ${c.rng.nextInt(20) + 70}%', Ln.stdout);
    _cmds['netstat'] = (a, c, o, af) => o('tcp 0.0.0.0:8080 LISTEN\ntcp 192.168.0.8:44220 github.com:443 ESTABLISHED', Ln.stdout);
    _cmds['ss'] = (a, c, o, af) => o('tcp LISTEN 0 128 0.0.0.0:8080 0.0.0.0:*', Ln.stdout);
    _cmds['lsof'] = (a, c, o, af) => o('nanortime 1024 nanoai mem REG /models/qwen.gguf', Ln.stdout);
    _cmds['vmstat'] = (a, c, o, af) => o('1 0 0 2860M 120M 390M 0 0 12 28 420 680 8 3 88 1', Ln.stdout);
    _cmds['iotop'] = (a, c, o, af) => o('1040 be/4 nanoai 0.00 B/s 2.4 K/s nano_shell', Ln.stdout);
    _cmds['man'] = (a, c, o, af) => o('${a.isNotEmpty ? a[0].toUpperCase() : "?"}(1)    NanoPlatform Manual\nNAME    ${a.isNotEmpty ? a[0] : "?"}\nSYNOPSIS  ${a.isNotEmpty ? a[0] : "?"} [options]\nDESCRIPTION  Integrated command.', Ln.info);
  }

  void _help(List<String> a, void Function(String, Ln) o) {
    if (a.isNotEmpty) { _cmds['man']!(a, _ctx, o, _after); return; }
    o('══ Comandos ══', Ln.header);
    for (final s in [['Sistema', 'help clear date whoami uname hostname uptime id env export alias source which type sleep true false'], ['FS', 'ls cd pwd cat grep find diff wc mkdir rm cp mv touch echo chmod chown ln head tail basename dirname wc nl'], ['Shell real', 'bash toybox ! (prefijo: !ls -la → bash -c)'], ['Procesos', 'ps kill jobs htop pstree'], ['Pkgs', 'pkg apt pip npm cargo gem'], ['Containers', 'docker'], ['Remote', 'ssh git adb curl scp wget'], ['Plugins', 'plugin'], ['IA', 'ai infer stat tune gpu nvtop dashboard'], ['Monitor', 'dmesg free df top netstat ss lsof vmstat iotop']])
      o('  ${s[0]}: ${s[1]}', Ln.info);
  }

  /// Evaluador aritmético simple para `expr`. Soporta + - * / y paréntesis.
  int _evalExpr(String expr) {
    final s = expr.replaceAll(' ', '');
    // Solo números y operadores básicos
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

  // Parser aritmético para expr. Soporta + - * / y paréntesis via
  // recursive-descent con métodos privados (evita el problema de
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

  // ── Execution ──
  List<String> _tok(String c) { final t = <String>[], b = StringBuffer(); bool sq = false, dq = false; for (int i = 0; i < c.length; i++) { final ch = c[i]; if (ch == "'" && !dq) { sq = !sq; continue; } if (ch == '"' && !sq) { dq = !dq; continue; } if (ch == ' ' && !sq && !dq) { if (b.isNotEmpty) { t.add(b.toString()); b.clear(); } continue; } b.write(ch); } if (b.isNotEmpty) t.add(b.toString()); return t; }

  /// Detecta operadores de shell (| > < >> && || ;) fuera de comillas.
  /// Si están presentes, el comando debe delegarse a bash -c.
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

  void _exec(String raw) { _execAsync(raw); } // puente sync→async para onSubmitted

  Future<void> _execAsync(String raw) async {
    _out(_ps1 + raw, Ln.prompt); final cmd = raw.trim(); if (cmd.isEmpty) return;
    _hist.add(cmd); _hIdx = -1; _in.clear();

    // ── Prefijo ! → bash -c real ──
    if (cmd.startsWith('!')) {
      final shellCmd = cmd.substring(1).trim();
      if (shellCmd.isEmpty) return;
      if (_shell != null && _shell!.initialized) {
        o('[bash] $shellCmd', Ln.system);
        final result = await _shell!.bash(shellCmd);
        _shellOut(result);
      } else {
        _out('! : shell no disponible (binarios no extraídos)', Ln.stderr);
      }
      return;
    }

    // ── Detección automática de pipes/redirección → bash -c real ──
    if (_hasShellOps(cmd) && _shell != null && _shell!.initialized) {
      o('[bash] $cmd', Ln.system);
      final result = await _shell!.bash(cmd);
      _shellOut(result);
      return;
    }

    var parts = _tok(cmd); if (parts.isNotEmpty && _ctx.aliases.containsKey(parts[0])) parts = _tok(_ctx.aliases[parts[0]]!);
    if (parts.isEmpty) return;
    final name = parts[0], args = parts.sublist(1);

    // ── Comandos bash / toybox explícitos ──
    if (name == 'bash' && _shell != null && _shell!.initialized) {
      final shellCmd = args.join(' ');
      final result = await _shell!.bash(shellCmd.isNotEmpty ? shellCmd : '-i');
      _shellOut(result); return;
    }
    if (name == 'toybox' && _shell != null && _shell!.initialized) {
      final result = await _shell!.toybox(args);
      _shellOut(result); return;
    }

    // REAL: comandos whitelist → probar toybox real primero, luego dart:io.
    if (_realCmds.contains(name)) {
      // Intento 1: shell real (toybox)
      if (_shell != null && _shell!.initialized) {
        final r = await _shell!.toybox([name, ...args]);
        if (r.exitCode == 0 && r.stdout.isNotEmpty || r.exitCode == 0) {
          _shellOut(r); return;
        }
        // Si toybox falla (exitCode != 0), cae en dart:io.
      }
      // Intento 2: dart:io fallback
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

  // ── Keyboard ──
  bool _onKey(KeyEvent e) { if (e is KeyDownEvent) { if (e.logicalKey == LogicalKeyboardKey.controlLeft || e.logicalKey == LogicalKeyboardKey.controlRight) { _ctrl = true; return false; } if (_ctrl && e.logicalKey == LogicalKeyboardKey.keyL) { setState(() => _lines.clear()); _ctrl = false; return true; } if (_ctrl && e.logicalKey == LogicalKeyboardKey.keyC) { _out('^C', Ln.stdout); _in.clear(); _ctrl = false; return true; } } if (e is KeyUpEvent && (e.logicalKey == LogicalKeyboardKey.controlLeft || e.logicalKey == LogicalKeyboardKey.controlRight)) _ctrl = false; return false; }

  // ── Autocomplete ──
  List<String> _sug() { final p = _in.text.trim(); if (p.isEmpty) return _cmds.keys.take(8).toList(); return _cmds.keys.where((c) => c.startsWith(p)).followedBy(_ctx.fs.resolve('.')?.children.map((c) => c.name + (c.isDir ? '/' : '')).where((n) => n.startsWith(p)) ?? []).take(10).toList(); }

  // ── Persistence ──
  Future<void> _loadHistory() async { try { final p = await SharedPreferences.getInstance(); final j = p.getString('term_hist_${widget.sessionId}'); if (j != null) _hist.addAll((jsonDecode(j) as List).cast<String>()); } catch (_) {} }
  Future<void> _saveHistory() async { try { final p = await SharedPreferences.getInstance(); await p.setString('term_hist_${widget.sessionId}', jsonEncode(_hist.length > 500 ? _hist.sublist(_hist.length - 500) : _hist)); } catch (_) {} }

  Color _c(Ln t, Color fg) => switch (t) { Ln.prompt => fg.withValues(alpha: 0.9), Ln.stdout => fg.withValues(alpha: 0.78), Ln.stderr => const Color(0xFFFF6B6B), Ln.success => fg, Ln.info => fg.withValues(alpha: 0.65), Ln.warn => const Color(0xFFFFB74D), Ln.system => fg.withValues(alpha: 0.55), Ln.header => const Color(0xFF00E676) };

  @override Widget build(BuildContext context) {
    final c = NanoThemeExtension.of(context).colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chrome = dark ? const Color(0xFF0A0F1A) : const Color(0xFFE0E0EC);
    final fg = c.terminalGreen; final sug = _sug();

    return Column(children: [
      // ── Terminal scroll buffer ──
      Expanded(
        child: Stack(children: [
          // Scanline effect overlay
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ScanlinePainter(fg)))),
          // Content
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
                        SizedBox(width: 32, child: Text('${i + 1}', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: fg.withValues(alpha: 0.15), height: 1.6))),
                        // Content
                        Expanded(child: Text(line.text, style: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: _c(line.type, fg), height: 1.6, letterSpacing: 0.2))),
                      ]),
                    );
                  },
                ),
              ),
            ),
          ),
        ]),
      ),

      // ── Autocomplete panel ──
      if (sug.isNotEmpty && _in.text.isNotEmpty && _fn.hasFocus)
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: chrome, border: Border(top: BorderSide(color: fg.withValues(alpha: 0.08)))), child: Wrap(spacing: 6, runSpacing: 4, children: sug.map((s) => GestureDetector(
          onTap: () { _in.text = s; _in.selection = TextSelection.collapsed(offset: s.length); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: fg.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(5), border: Border.all(color: fg.withValues(alpha: 0.08))), child: Text(s, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: fg.withValues(alpha: 0.7)))))).toList())),

      // ── Input area ──
      Container(
        decoration: BoxDecoration(color: chrome, border: Border(top: BorderSide(color: fg.withValues(alpha: 0.12)))),
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(_ps1, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowUp): () { if (_hIdx < _hist.length - 1) { _hIdx++; _in.text = _hist.reversed.toList()[_hIdx]; _in.selection = TextSelection.collapsed(offset: _in.text.length); } },
                const SingleActivator(LogicalKeyboardKey.arrowDown): () { if (_hIdx > 0) { _hIdx--; _in.text = _hist.reversed.toList()[_hIdx]; } else { _hIdx = -1; _in.clear(); } },
                const SingleActivator(LogicalKeyboardKey.tab): () { if (sug.isNotEmpty) { _in.text = sug.first; _in.selection = TextSelection.collapsed(offset: _in.text.length); } },
              },
              child: TextField(
                controller: _in, focusNode: _fn, autofocus: true,
                style: GoogleFonts.jetBrainsMono(fontSize: 13, color: fg, height: 1.5),
                cursorColor: fg, cursorWidth: 2,
                decoration: InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, hintText: 'comando o "ai <pregunta>"...', hintStyle: GoogleFonts.jetBrainsMono(fontSize: 13, color: fg.withValues(alpha: 0.18))),
                onSubmitted: _exec, onChanged: (_) => _hIdx = -1,
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
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
