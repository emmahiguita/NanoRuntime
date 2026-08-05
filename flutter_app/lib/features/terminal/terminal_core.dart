import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/design_tokens.dart';
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
  final int sessionId; final String initialCwd;
  const NanoTerminal({super.key, this.sessionId = 0, this.initialCwd = '/home/nanoai'});
  @override State<NanoTerminal> createState() => _TermState();
}

class _TermState extends State<NanoTerminal> {
  final _in = TextEditingController(), _sc = ScrollController(), _fn = FocusNode();
  final _lines = <TL>[], _hist = <String>[], _timers = <Timer>[];
  final _ctx = TerminalCtx();
  int _hIdx = -1; bool _ctrl = false, _alive = true;
  final _cmds = <String, CmdFn>{};

  // ── DRY: PS1 prompt getter ──
  String get _ps1 => 'nanoai@oppo:${_ctx.fs.cwd == '/home/nanoai' ? '~' : _ctx.fs.cwd.split('/').last}\$ ';

  // ── Output helpers ──
  void _out(String t, Ln ty) { if (t.isEmpty && ty == Ln.stdout) return; setState(() => _lines.add(TL(t, ty))); _after(NanoDurations.fast, () { if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent); }); }
  void _after(Duration d, VoidCallback cb) { final t = Timer(d, () { if (_alive) cb(); }); _timers.add(t); }

  @override void initState() {
    super.initState(); _ctx.fs.cwd = widget.initialCwd; _buildRegistry();
    _out('NanoPlatform CLI v2.0 — ${_ctx.procs.procs.length} procs | ${_ctx.pkgs.pkgs.where((p) => p.installed).length} pkgs | ${_ctx.containers.cons.length} containers', Ln.header);
    _out('Type "help" or "ai <pregunta>".', Ln.info); _out('', Ln.stdout);
    _loadHistory(); HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override void dispose() { _saveHistory(); _alive = false; for (final t in _timers) t.cancel(); _in.dispose(); _sc.dispose(); _fn.dispose(); HardwareKeyboard.instance.removeHandler(_onKey); super.dispose(); }

  // ── Command Registry (OCP: add new commands without touching _exec) ──
  void _buildRegistry() {
    // System
    _cmds['help'] = (a, c, o, af) => _help(a, o);
    _cmds['clear'] = (a, c, o, af) => setState(() => _lines.clear());
    _cmds['date'] = (a, c, o, af) => o(a.contains('--utc') ? DateTime.now().toUtc().toIso8601String().substring(0, 19) : DateTime.now().toString().substring(0, 19), Ln.stdout);
    _cmds['whoami'] = (a, c, o, af) => o(c.env['USER']!, Ln.stdout);
    _cmds['uname'] = (a, c, o, af) => o(a.contains('-a') ? 'Linux oppo-cph2557 5.4.0 aarch64 GNU/Linux' : 'Linux', Ln.stdout);
    _cmds['hostname'] = (a, c, o, af) => o('oppo-cph2557', Ln.stdout);
    _cmds['uptime'] = (a, c, o, af) => o('up 3 days, 14:22, 1 user', Ln.stdout);
    _cmds['env'] = (a, c, o, af) => a.isEmpty ? c.env.forEach((k, v) => o('$k=$v', Ln.stdout)) : o('${a[0]}=${c.env[a[0]] ?? ""}', Ln.stdout);
    _cmds['export'] = (a, c, o, af) { if (a.isNotEmpty) { final kv = a.join(' ').split('='); if (kv.length == 2) { c.env[kv[0]] = kv[1]; o('${kv[0]}=${kv[1]}', Ln.success); } } };
    _cmds['alias'] = (a, c, o, af) { if (a.isEmpty) { c.aliases.forEach((k, v) => o('$k=$v', Ln.stdout)); } else { final kv = a.join(' ').split('='); if (kv.length == 2) { c.aliases[kv[0]] = kv[1]; o('$kv[0]=$kv[1]', Ln.success); } } };
    _cmds['source'] = (a, c, o, af) => o('sourced ${a.isNotEmpty ? a[0] : ".bashrc"}', Ln.success);
    _cmds['which'] = _cmds['type'] = (a, c, o, af) => o(a.isNotEmpty ? '/usr/bin/${a[0]}' : 'which: argumento requerido', a.isNotEmpty ? Ln.stdout : Ln.stderr);
    // FS
    _cmds['ls'] = (a, c, o, af) => c.fs.ls(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['cd'] = (a, c, o, af) => c.fs.cd(a, (t, ty) => o(t, Ln.values[ty]), c.env['HOME']!);
    _cmds['pwd'] = (a, c, o, af) => o(c.fs.cwd, Ln.stdout);
    _cmds['cat'] = (a, c, o, af) => c.fs.cat(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['mkdir'] = (a, c, o, af) => c.fs.mkdir(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['rm'] = (a, c, o, af) => c.fs.rm(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['touch'] = (a, c, o, af) => c.fs.touch(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['echo'] = (a, c, o, af) => o(a.join(' '), Ln.stdout);
    _cmds['grep'] = (a, c, o, af) => c.fs.grep(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['find'] = (a, c, o, af) => c.fs.find(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['diff'] = (a, c, o, af) => c.fs.diff(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['wc'] = (a, c, o, af) => c.fs.wc(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['chmod'] = _cmds['chown'] = _cmds['ln'] = (a, c, o, af) => o('${a.isNotEmpty ? a[0] : "?"}: operación completada', Ln.success);
    // Procs
    _cmds['ps'] = (a, c, o, af) => c.procs.ps((t, ty) => o(t, Ln.values[ty]));
    _cmds['kill'] = (a, c, o, af) => c.procs.kill(a, (t, ty) => o(t, Ln.values[ty]));
    _cmds['htop'] = (a, c, o, af) => c.procs.htop((t, ty) => o(t, Ln.values[ty]));
    _cmds['pstree'] = (a, c, o, af) => c.procs.pstree((t, ty) => o(t, Ln.values[ty]));
    _cmds['jobs'] = (a, c, o, af) => o('[1] + running nanortime-core', Ln.stdout);
    // Pkgs
    _cmds['pkg'] = (a, c, o, af) => c.pkgs.pkg(a, (t, ty) => o(t, Ln.values[ty]), af);
    _cmds['apt'] = (a, c, o, af) => c.pkgs.pkg(['search'] + a, (t, ty) => o(t, Ln.values[ty]), af);
    _cmds['pip'] = (a, c, o, af) { for (final p in c.pkgs.byManager('pip')) o('${p.name} ${p.ver} ${p.installed ? "(installed)" : ""}', Ln.stdout); };
    _cmds['npm'] = (a, c, o, af) { for (final p in c.pkgs.byManager('npm')) o('${p.name} ${p.ver}', Ln.stdout); };
    _cmds['cargo'] = (a, c, o, af) { for (final p in c.pkgs.byManager('cargo')) o('${p.name} ${p.ver}', Ln.stdout); };
    _cmds['gem'] = (a, c, o, af) { for (final p in c.pkgs.byManager('gem')) o('${p.name} ${p.ver}', Ln.stdout); };
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
    _cmds['stat'] = (a, c, o, af) { final all = a.contains('--all'), mem = all || a.contains('--memory'), cpu = all || a.contains('--cpu'); o('══ NanoRuntime Status ══', Ln.header); if (mem) o('RAM: 3.72 GB | Used: 2.80 GB (75%) | Free: 0.92 GB\nModel: 920 MB | KV: 180 MB | PageCache: 210 MB', Ln.stdout); if (cpu) o('CPU: Snapdragon 778G | Temp: ${(37 + c.rng.nextDouble() * 6).toStringAsFixed(1)}°C | Procs: ${c.procs.procs.length}', Ln.stdout); };
    _cmds['infer'] = (a, c, o, af) { if (a.isEmpty) { o('infer: prompt requerido', Ln.stderr); return; } o('[NanoRuntime] Model: qwen2.5-1.5b', Ln.system); af(const Duration(milliseconds: 800), () => o('Response: "${a.join(" ")}" → ${c.rng.nextInt(300) + 80}ms @ ${c.rng.nextInt(10) + 12} tok/s', Ln.success)); };
    _cmds['ai'] = (a, c, o, af) { if (a.isEmpty) { o('ai: escribe un prompt. Ej: ai ¿cómo optimizar RAM?', Ln.stderr); return; } final prompt = a.join(' '); o('[NanoAI] Procesando: "$prompt"', Ln.info); af(const Duration(milliseconds: 600), () { o('Respuesta: Para "$prompt", recomiendo:', Ln.success); o('  • madvise(DONTNEED) para liberar capas\n  • htop para monitorear procesos\n  • Ajustar OOM Guard: export OOM_THRESHOLD=150', Ln.stdout); o('Completado en ${c.rng.nextInt(300) + 80}ms | ${c.rng.nextInt(10) + 12} tok/s', Ln.info); }); };
    _cmds['tune'] = (a, c, o, af) { o('Auto-tuning...', Ln.info); af(const Duration(milliseconds: 1200), () => o('✓ Optimized. ${c.rng.nextInt(15) + 5}% improvement.', Ln.info)); };
    _cmds['gpu'] = (a, c, o, af) => o('GPU: Adreno 642L | Freq: 490 MHz | Temp: ${(38 + c.rng.nextDouble() * 5).toStringAsFixed(1)}°C\n  Efficiency (0-3): ${c.rng.nextInt(30) + 10}% @ ${c.rng.nextInt(15) + 30}°C\n  Performance (4-7): ${c.rng.nextInt(50) + 5}% @ ${c.rng.nextInt(20) + 35}°C', Ln.stdout);
    _cmds['nvtop'] = (a, c, o, af) { for (final l in ['╔══ nvtop ══╗', '║ GPU: Adreno ║', '║ Mem: 920M  ║', '╚═══════════╝']) o(l, Ln.header); };
    _cmds['dashboard'] = (a, c, o, af) => o('══ Dashboard ══\nCPU:${c.rng.nextInt(30) + 10}% RAM:2.80/3.72 GB\nProcs:${c.procs.procs.length} Pkgs:${c.pkgs.pkgs.where((p) => p.installed).length} Containers:${c.containers.cons.where((x) => !x.status.startsWith("Exited")).length} Plugins:${c.plugins.plugs.where((p) => p.enabled).length}', Ln.stdout);
    // Monitor
    _cmds['dmesg'] = (a, c, o, af) { for (final l in ['Booting NanoPlatform', 'CPU: Snapdragon 778G', 'Memory: 3812000K', 'Docker: initialized', 'sshd: listening', 'NanoPlatform: ready']) o(l, Ln.system); };
    _cmds['free'] = (a, c, o, af) => o('Mem: 3.72G total, 920M used, 2.80G free', Ln.stdout);
    _cmds['df'] = (a, c, o, af) => o('/dev/sda1 128G 52G 76G 41%', Ln.stdout);
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
    for (final s in [['Sistema', 'help clear date whoami uname hostname uptime env export alias source which type'], ['FS', 'ls cd pwd cat grep find diff wc mkdir rm touch echo chmod chown ln'], ['Procesos', 'ps kill jobs htop pstree'], ['Pkgs', 'pkg apt pip npm cargo gem'], ['Containers', 'docker'], ['Remote', 'ssh git adb curl scp wget'], ['Plugins', 'plugin'], ['IA', 'ai infer stat tune gpu nvtop dashboard'], ['Monitor', 'dmesg free df top netstat ss lsof vmstat iotop']])
      o('  ${s[0]}: ${s[1]}', Ln.info);
  }

  // ── Execution ──
  List<String> _tok(String c) { final t = <String>[], b = StringBuffer(); bool sq = false, dq = false; for (int i = 0; i < c.length; i++) { final ch = c[i]; if (ch == "'" && !dq) { sq = !sq; continue; } if (ch == '"' && !sq) { dq = !dq; continue; } if (ch == ' ' && !sq && !dq) { if (b.isNotEmpty) { t.add(b.toString()); b.clear(); } continue; } b.write(ch); } if (b.isNotEmpty) t.add(b.toString()); return t; }

  void _exec(String raw) {
    _out(_ps1 + raw, Ln.prompt); final cmd = raw.trim(); if (cmd.isEmpty) return;
    _hist.add(cmd); _hIdx = -1; _in.clear();
    var parts = _tok(cmd); if (parts.isNotEmpty && _ctx.aliases.containsKey(parts[0])) parts = _tok(_ctx.aliases[parts[0]]!);
    if (parts.isEmpty) return;
    final name = parts[0], args = parts.sublist(1);
    // Pipe
    if (raw.contains('|') && !raw.startsWith('|')) { _pipe(parts, raw); return; }
    // Dispatch via registry
    final handler = _cmds[name];
    if (handler != null) { handler(args, _ctx, _out, _after); } else { _out('$name: comando no encontrado. "help" para ver todos.', Ln.stderr); }
  }

  void _pipe(List<String> left, String raw) {
    final buf = <String>[], name = left[0];
    if (name == 'ps') { for (final p in _ctx.procs.procs) { buf.add('${p.pid} ${p.name}'); } } else if (name == 'ls') { _ctx.fs.resolve('.')?.children.forEach((c) => buf.add(c.name)); } else if (name == 'cat' && left.length > 1) { final n = _ctx.fs.resolve(left[1]); if (n != null) buf.addAll(n.content.split('\n')); }
    final search = raw.split('|').last.trim().replaceFirst(RegExp(r'grep\s*', caseSensitive: false), '').trim();
    final matches = buf.where((l) => l.toLowerCase().contains(search.toLowerCase())).toList();
    for (final m in matches) _out(m, Ln.stdout);
    if (matches.isEmpty) _out('(sin coincidencias)', Ln.info);
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
