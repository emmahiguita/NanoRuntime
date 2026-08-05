import 'dart:math';

/// ── Virtual Filesystem ──
class VNode { final String name; final bool isDir; String content; final List<VNode> children; int size; VNode? parent; VNode({required this.name, this.isDir = false, this.content = '', this.children = const [], this.size = 0}); VNode? find(String n) { for (final c in children) { if (c.name == n) return c; } return null; } }

class VirtualFS {
  final VNode root;
  String cwd = '/home/nanoai';

  VirtualFS() : root = _buildRoot() { _setParents(root); }

  static VNode _buildRoot() => VNode(name: '/', isDir: true, children: [
    VNode(name: 'home', isDir: true, children: [VNode(name: 'nanoai', isDir: true, children: [
      VNode(name: 'models', isDir: true, children: [VNode(name: 'qwen2.5-1.5b.gguf', size: 1180000000), VNode(name: 'config.json', content: '{"temperature":0.7,"top_p":0.9,"context":2048}')]),
      VNode(name: 'workspace', isDir: true, children: [VNode(name: 'main.dart', content: 'void main() => runApp(NanoAIApp());'), VNode(name: 'README.md', content: '# NanoAI\nMotor LLM Local')]),
      VNode(name: 'logs', isDir: true, children: [VNode(name: 'nanortime.log', content: '[14:32:01] Boot OK\n[14:32:02] madvise 24 layers\n[14:32:15] OOM Guard: 0')]),
    ])]),
    VNode(name: 'etc', isDir: true, children: [VNode(name: 'hostname', content: 'oppo-cph2557')]),
    VNode(name: 'proc', isDir: true, children: [VNode(name: 'meminfo', content: 'MemTotal: 3812000 kB\nMemAvailable: 2860000 kB')]),
  ]);

  VNode? resolve(String path) {
    if (path.isEmpty || path == '.') { final parts = cwd == '/' ? [''] : cwd.substring(1).split('/'); var n = root; for (final p in parts) { if (p.isEmpty) continue; n = n.find(p) ?? n; } return n; }
    if (path == '..') { final parts = cwd == '/' ? [''] : cwd.substring(1).split('/'); parts.removeLast(); var n = root; for (final p in parts) { if (p.isEmpty) continue; n = n.find(p) ?? n; } return n; }
    final parts = path.startsWith('/') ? path.substring(1).split('/') : '$cwd/$path'.substring(1).split('/'); var node = root; for (final p in parts) { if (p.isEmpty || p == '.') continue; if (p == '..') { node = node.parent ?? node; continue; } node = node.find(p) ?? node; } return node;
  }

  void cd(List<String> args, void Function(String, int) out, String home) {
    if (args.isEmpty) { cwd = home; return; }
    final t = resolve(args[0]); if (t == null || !t.isDir) { out('cd: ${args[0]}: No such directory', 2); return; }
    cwd = args[0].startsWith('/') ? args[0] : args[0] == '..' ? (cwd == '/' ? '/' : cwd.substring(0, cwd.lastIndexOf('/') == 0 ? 1 : cwd.lastIndexOf('/'))) : (cwd == '/' ? '/${args[0]}' : '$cwd/${args[0]}');
    if (cwd.endsWith('/') && cwd != '/') cwd = cwd.substring(0, cwd.length - 1);
  }

  void ls(List<String> args, void Function(String, int) out) {
    final long = args.any((x) => x.contains('l')); final path = args.where((x) => !x.startsWith('-')).isEmpty ? '.' : args.where((x) => !x.startsWith('-')).first;
    final node = resolve(path); if (node == null) { out('ls: $path: No such file', 2); return; }
    if (!node.isDir) { out(node.name, 1); return; }
    if (long) out('total ${node.children.length * 4}', 3);
    for (final c in node.children) out(long ? '${c.isDir ? "d" : "-"}rwxr-xr-x nanoai nanoai ${_sz(c.size > 0 ? c.size : c.content.length).padLeft(8)} ${c.name}${c.isDir ? "/" : ""}' : '${c.name}${c.isDir ? "/" : ""}', c.isDir && !long ? 3 : 1);
  }

  void cat(List<String> args, void Function(String, int) out) {
    if (args.isEmpty) { out('cat: archivo requerido', 2); return; }
    final n = resolve(args[0]); if (n == null) { out('cat: ${args[0]}: No such file', 2); return; }
    if (n.isDir) { out('cat: ${args[0]}: Is a directory', 2); return; }
    for (final l in n.content.split('\n')) out(l, 1);
  }

  void mkdir(List<String> args, void Function(String, int) out) {
    if (args.isEmpty) { out('mkdir: nombre requerido', 2); return; }
    final parent = resolve('.'); if (parent != null && parent.isDir) { parent.children.add(VNode(name: args[0], isDir: true)); out('mkdir: "${args[0]}" creado', 4); }
  }

  void rm(List<String> args, void Function(String, int) out) {
    if (args.isEmpty) { out('rm: path requerido', 2); return; }
    String path = args.last.replaceAll('-r', '').replaceAll('-f', '').trim();
    if (path.isEmpty) { out('rm: path requerido', 2); return; }
    final target = resolve(path); if (target == null) { out('rm: $path: No such file', 2); return; }
    target.parent?.children.remove(target); out('rm: "$path" eliminado', 4);
  }

  void touch(List<String> args, void Function(String, int) out) {
    if (args.isEmpty) { out('touch: nombre requerido', 2); return; }
    final parent = resolve('.'); if (parent != null && parent.isDir && parent.find(args[0]) == null) { parent.children.add(VNode(name: args[0])); out('touch: "${args[0]}" creado', 4); }
  }

  void grep(List<String> args, void Function(String, int) out) {
    if (args.length < 2) { out('grep: pattern y archivo requeridos', 2); return; }
    final n = resolve(args[1]); if (n == null || n.isDir) { out('grep: ${args[1]}: No such file', 2); return; }
    for (final l in n.content.split('\n')) { if (l.toLowerCase().contains(args[0].toLowerCase())) out(l, 1); }
  }

  void find(List<String> args, void Function(String, int) out) {
    final root = resolve(args.isNotEmpty ? args[0] : '.'); if (root == null) return;
    void w(VNode n, String p) { if (!n.isDir) { out('$p/${n.name}', 1); return; } for (final c in n.children) w(c, '$p/${n.name}'); }
    for (final c in root.children) w(c, root.name == '/' ? '' : root.name);
  }

  void diff(List<String> args, void Function(String, int) out) {
    if (args.length < 2) { out('diff: 2 archivos requeridos', 2); return; }
    final f1 = resolve(args[0]), f2 = resolve(args[1]); if (f1 == null || f2 == null) { out('diff: archivo no encontrado', 2); return; }
    final l1 = f1.content.split('\n'), l2 = f2.content.split('\n'); out('--- ${args[0]}\n+++ ${args[1]}', 1);
    for (int i = 0; i < max(l1.length, l2.length); i++) { final a1 = i < l1.length ? l1[i] : '', a2 = i < l2.length ? l2[i] : ''; if (a1 != a2) out('${i + 1}c${i + 1}\n< $a1\n---\n> $a2', 1); }
  }

  void wc(List<String> args, void Function(String, int) out) {
    if (args.isEmpty) { out('wc: archivo requerido', 2); return; }
    final n = resolve(args[0]); if (n == null || n.isDir) { out('wc: ${args[0]}: No such file', 2); return; }
    final lines = n.content.split('\n').length; final words = n.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    out('  $lines  $words  ${n.content.length} ${args[0]}', 1);
  }

  static String _sz(int b) => b > 1e9 ? '${(b / 1e9).toStringAsFixed(1)}G' : b > 1e6 ? '${(b / 1e6).toStringAsFixed(1)}M' : b > 1e3 ? '${(b / 1e3).toStringAsFixed(1)}K' : '$b';
  static void _setParents(VNode n) { for (final c in n.children) { c.parent = n; _setParents(c); } }
}

/// ── Process Manager ──
class Proc { int pid, ppid; String name, state; double cpu, mem; Proc(this.pid, this.ppid, this.name, this.cpu, this.mem, {this.state = 'R'}); }

class ProcessManager {
  final List<Proc> procs = [];
  ProcessManager() {
    procs.addAll([Proc(1, 0, 'init', 0, 0.1, state: 'S'), Proc(1024, 1, 'nanortime-core', 4.2, 30.2), Proc(1028, 1, 'oom_guard', 0.5, 0.8, state: 'S'), Proc(1032, 1, 'thermal_ctrl', 0.2, 0.4, state: 'S'), Proc(1040, 1, 'nano_shell', 1.1, 5.2), Proc(1044, 1, 'pkg_daemon', 0.3, 2.1, state: 'S'), Proc(1050, 1, 'docker_engine', 1.8, 12.5, state: 'S'), Proc(1060, 1, 'sshd', 0.1, 1.2, state: 'S')]);
  }

  void ps(void Function(String, int) out) {
    out('PID   PPID  %CPU  %MEM  S  COMMAND', 3);
    for (final p in procs) out('${p.pid.toString().padLeft(5)} ${p.ppid.toString().padLeft(4)}  ${p.cpu.toStringAsFixed(1).padLeft(4)} ${p.mem.toStringAsFixed(1).padLeft(5)}  ${p.state.padRight(3)} ${p.name}', 1);
  }

  void kill(List<String> args, void Function(String, int) out) {
    if (args.isEmpty) { out('kill: PID requerido', 2); return; }
    final pid = int.tryParse(args.last.replaceAll(RegExp(r'[^0-9]'), '')); if (pid == null || !procs.any((p) => p.pid == pid)) { out('kill: PID $pid no encontrado', 2); return; }
    procs.removeWhere((p) => p.pid == pid); out('kill: proceso $pid terminado', 4);
  }

  void htop(void Function(String, int) out) {
    out('══ htop ══', 7); out('PID   USER   PRI  NI  VIRT   RES   S  CPU%  MEM%  Command', 3);
    for (final p in procs) out('${p.pid.toString().padLeft(5)} nanoai  20   0  ${(p.mem * 38).toInt()}M  ${(p.mem * 32).toInt()}M  ${p.state}  ${p.cpu.toStringAsFixed(1).padLeft(4)} ${p.mem.toStringAsFixed(1).padLeft(5)}  ${p.name}', 1);
  }

  void pstree(void Function(String, int) out) {
    final byPpid = <int, List<Proc>>{}; for (final p in procs) { byPpid.putIfAbsent(p.ppid, () => []).add(p); }
    void pt(int ppid, String pre) { final ch = byPpid[ppid] ?? []; for (int i = 0; i < ch.length; i++) { final c = ch[i]; final last = i == ch.length - 1; out('$pre${last ? "└─" : "├─"} ${c.name}(${c.pid})', 1); pt(c.pid, '$pre${last ? "   " : "│  "}'); } }
    pt(0, '');
  }
}

/// ── Package Registry ──
class Pkg { final String name, ver, desc, manager, category; final int sizeMb; bool installed; Pkg({required this.name, required this.ver, required this.desc, required this.manager, required this.category, this.sizeMb = 1, this.installed = false}); }

class PackageRegistry {
  final List<Pkg> pkgs = [];
  PackageRegistry() { pkgs.addAll(_defaults()); }
  static List<Pkg> _defaults() => [Pkg(name: 'python', ver: '3.12.3', desc: 'Python', manager: 'apt', category: 'lang', sizeMb: 45, installed: true), Pkg(name: 'nodejs', ver: '20.11.0', desc: 'Node.js', manager: 'apt', category: 'lang', sizeMb: 32), Pkg(name: 'rustc', ver: '1.77.0', desc: 'Rust', manager: 'apt', category: 'lang', sizeMb: 180), Pkg(name: 'git', ver: '2.44.0', desc: 'Git', manager: 'apt', category: 'tools', sizeMb: 12, installed: true), Pkg(name: 'docker', ver: '26.0.0', desc: 'Docker', manager: 'apt', category: 'containers', sizeMb: 85, installed: true), Pkg(name: 'openssh', ver: '9.6p1', desc: 'SSH', manager: 'apt', category: 'tools', sizeMb: 8, installed: true), Pkg(name: 'vim', ver: '9.1', desc: 'Vim', manager: 'apt', category: 'tools', sizeMb: 15, installed: true), Pkg(name: 'numpy', ver: '1.26.4', desc: 'NumPy', manager: 'pip', category: 'python', sizeMb: 18, installed: true), Pkg(name: 'torch', ver: '2.2.0', desc: 'PyTorch', manager: 'pip', category: 'python', sizeMb: 850), Pkg(name: 'transformers', ver: '4.38.0', desc: 'Transformers', manager: 'pip', category: 'python', sizeMb: 320), Pkg(name: 'express', ver: '4.19.0', desc: 'Express', manager: 'npm', category: 'web', sizeMb: 2), Pkg(name: 'react', ver: '18.2.0', desc: 'React', manager: 'npm', category: 'web', sizeMb: 6), Pkg(name: 'serde', ver: '1.0.197', desc: 'Serde', manager: 'cargo', category: 'rust', sizeMb: 1), Pkg(name: 'tokio', ver: '1.36.0', desc: 'Tokio', manager: 'cargo', category: 'rust', sizeMb: 4), Pkg(name: 'rails', ver: '7.1.3', desc: 'Rails', manager: 'gem', category: 'web', sizeMb: 22)];

  void pkg(List<String> args, void Function(String, int) out, void Function(Duration, void Function()) after) {
    if (args.isEmpty) { out('pkg: search, install, remove, list, update, info', 3); return; }
    switch (args[0]) {
      case 'search': final q = args.length > 1 ? args[1] : ''; for (final p in pkgs.where((x) => x.name.contains(q))) out('${p.name.padRight(20)} ${p.ver.padRight(10)} [${p.manager}] ${p.installed ? "(installed)" : ""}', 1); break;
      case 'install': final n = args.length > 1 ? args[1] : ''; final p = pkgs.firstWhere((x) => x.name == n, orElse: () => Pkg(name: '', ver: '', desc: '', manager: '', category: '')); if (p.name.isEmpty) { out('pkg: "$n" not found', 2); return; } out('pkg: installing $n...', 3); after(const Duration(milliseconds: 600), () { p.installed = true; out('pkg: $n installed (${p.sizeMb} MB)', 4); }); break;
      case 'remove': final n = args.length > 1 ? args[1] : ''; final p = pkgs.where((x) => x.name == n).firstOrNull; if (p != null) { p.installed = false; out('pkg: $n removed', 4); } break;
      case 'list': for (final p in pkgs.where((x) => x.installed)) out('${p.name} ${p.ver} [${p.manager}]', 1); break;
      case 'update': out('pkg: updating...', 3); after(const Duration(milliseconds: 400), () => out('pkg: 342 packages. 3 updates pending.', 4)); break;
    }
  }

  List<Pkg> byManager(String m) => pkgs.where((x) => x.manager == m).toList();
}

/// ── Container Registry ──
class DockerContainer { String id, image, name, status; final List<String> ports; DockerContainer({required this.id, required this.image, required this.name, required this.status, this.ports = const []}); }

class ContainerRegistry {
  final List<DockerContainer> cons = [];
  final _rng = Random();
  ContainerRegistry() { cons.addAll([DockerContainer(id: 'a1b2', image: 'ubuntu:22.04', name: 'dev-env', status: 'Up 3h', ports: ['8080:80', '2222:22']), DockerContainer(id: 'c3d4', image: 'python:3.12-slim', name: 'ml-worker', status: 'Exited'), DockerContainer(id: 'e5f6', image: 'nginx:alpine', name: 'web-proxy', status: 'Up 5h', ports: ['443:443'])]); }

  void docker(List<String> args, void Function(String, int) out, void Function(Duration, void Function()) after) {
    if (args.isEmpty) { out('docker: ps, pull, run, stop, rm, logs, images, info', 3); return; }
    switch (args[0]) {
      case 'ps': final all = args.contains('-a'); final list = all ? cons : cons.where((c) => !c.status.startsWith('Exited')).toList(); out('CONTAINER ID  IMAGE       STATUS    NAME', 3); for (final c in list) out('${c.id.padRight(13)} ${c.image.padRight(10)} ${c.status.padRight(8)} ${c.name}', 1); break;
      case 'pull': out('docker: pulling ${args.length > 1 ? args[1] : "image"}...', 3); after(const Duration(milliseconds: 800), () => out('docker: pulled', 4)); break;
      case 'run': final id = _rng.nextInt(9999).toRadixString(16); cons.add(DockerContainer(id: id, image: args.length > 1 ? args[1] : 'image', name: 'ctr_$id', status: 'Up 5s')); out('docker: $id started', 4); break;
      case 'stop': final c = _find(args); if (c != null) { c.status = 'Exited (0)'; out('docker: ${c.id} stopped', 4); } break;
      case 'rm': cons.removeWhere((x) => x.id == (args.length > 1 ? args[1] : '') || x.name == (args.length > 1 ? args[1] : '')); out('docker: removed', 4); break;
      case 'logs': out('[INFO] Server listening\n[INFO] Connected', 1); break;
    }
  }

  DockerContainer? _find(List<String> args) => cons.where((x) => x.id == (args.length > 1 ? args[1] : '') || x.name == (args.length > 1 ? args[1] : '')).firstOrNull;
}

/// ── Plugin Registry ──
class Plugin { final String name, ver, desc, author; bool enabled; Plugin({required this.name, required this.ver, required this.desc, required this.author, this.enabled = false}); }

class PluginRegistry {
  final List<Plugin> plugs = [];
  PluginRegistry() { plugs.addAll([Plugin(name: 'syntax-highlight', ver: '2.1.0', desc: 'Syntax highlighting', author: 'nanoai', enabled: true), Plugin(name: 'git-integration', ver: '1.4.2', desc: 'Git integration', author: 'nanoai', enabled: true), Plugin(name: 'ai-autocomplete', ver: '3.0.0', desc: 'AI autocomplete', author: 'nanoai', enabled: true), Plugin(name: 'docker-dashboard', ver: '1.0.1', desc: 'Container dashboard', author: 'community'), Plugin(name: 'theme-manager', ver: '0.9.0', desc: 'Theme manager', author: 'community', enabled: true)]); }

  void plugin(List<String> args, void Function(String, int) out) {
    if (args.isEmpty) { out('plugin: list,search,install,remove,enable,disable', 3); return; }
    switch (args[0]) {
      case 'list': for (final p in plugs) out('${p.name.padRight(22)} v${p.ver} ${p.enabled ? "[enabled]" : "[disabled]"}', 1); break;
      case 'install': final n = args.length > 1 ? args[1] : ''; if (!plugs.any((p) => p.name == n)) { plugs.add(Plugin(name: n, ver: '1.0.0', desc: n, author: 'user', enabled: true)); out('plugin: "$n" installed', 4); } break;
      case 'remove': plugs.removeWhere((p) => p.name == (args.length > 1 ? args[1] : '')); out('plugin: removed', 4); break;
      case 'enable': final p = plugs.where((x) => x.name == (args.length > 1 ? args[1] : '')).firstOrNull; if (p != null) { p.enabled = true; out('plugin: enabled', 4); } break;
      case 'disable': final p = plugs.where((x) => x.name == (args.length > 1 ? args[1] : '')).firstOrNull; if (p != null) { p.enabled = false; out('plugin: disabled', 4); } break;
    }
  }
}
