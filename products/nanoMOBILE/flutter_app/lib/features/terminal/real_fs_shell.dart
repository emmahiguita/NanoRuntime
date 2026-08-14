import 'dart:convert';
import 'dart:io';

import 'terminal_types.dart';

/// Shell de filesystem REAL — sin simulación, binarios Linux reales primero.
///
/// Orden de resolución en cada comando:
/// 1. **Binario real del host** (Linux/macOS): si existe en el PATH (o es
///    applet de busybox), se ejecuta el binario de verdad con cwd en el
///    sandbox. `sed`, `awk`, `tar`, `chmod`, `diff`... corren la lógica
///    Linux real, no una imitación. `runShell` delega pipes/redirección/
///    `&&`/`;` a `sh -c` real.
/// 2. **Fallback dart:io**: cubre el subconjunto [supported] para hosts sin
///    binarios (Windows de desarrollo/tests). Cada comando toca disco de
///    verdad; los que requieren Android (`id`, `free` sin /proc) dan error
///    honesto, nunca datos inventados.
///
/// El cwd es un path LÓGICO estilo Unix (`/`, `/sub`) mapeado al raíz real,
/// igual que el prompt `_ps1` de terminal_core. `..` no puede escapar del
/// raíz. Con binario real: los paths RELATIVOS quedan dentro del sandbox
/// (workingDirectory); los ABSOLUTOS (`/etc/...`) apuntan al host real,
/// como en un chroot parcial — real y documentado.
///
/// Nunca se usa en Android con shell activo: ahí manda el motor NanoRuntime
/// (toybox real vía Nanoshell FFI). `hostSh` es null en Android/Windows.
class RealFsShell {
  RealFsShell({required String root}) : _root = Directory(root) {
    try {
      _root.createSync(recursive: true);
    } catch (_) {}
  }

  final Directory _root;

  /// Cwd lógico (estilo Unix). Empieza en `/`.
  String cwd = '/';

  /// Shell real del host (`sh`) detectado una vez. Solo Linux/macOS: en
  /// Windows el sh de Git Bash usa rutas POSIX incompatibles con el
  /// sandbox (`C:\...`) y no debe usarse. En Android manda NanoRuntime.
  static final String? hostSh = _findHostSh();

  static String? _findHostSh() {
    if (Platform.isWindows) return null;
    try {
      final r = Process.runSync('sh', const ['-c', 'command -v sh']);
      if (r.exitCode == 0 && (r.stdout as String).trim().isNotEmpty) {
        return (r.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }

  /// true si hay un sh real del host para delegar comandos completos
  /// (pipes `|`, redirección `> >> <`, `&&`, `;`).
  bool get hasRealShell => hostSh != null;

  Map<String, String> get _env => {
    'TERM': 'dumb',
    'PWD': cwd,
    ...Platform.environment,
  };

  /// Subconjunto de comandos con implementación dart:io real.
  static const supported = {
    'mkdir',
    'touch',
    'ls',
    'cat',
    'wc',
    'grep',
    'find',
    'head',
    'tail',
    'cp',
    'mv',
    'rm',
    'cd',
    'pwd',
    'echo',
    'expr',
    'seq',
    'basename',
    'dirname',
    'tree',
    'diff',
    'source',
    'id',
    'chmod',
    'df',
    'free',
  };

  bool supports(String name) => supported.contains(name);

  /// Comandos sin binario estándar del host: se resuelven SIEMPRE con el
  /// fallback dart:io (cd/pwd/source mantienen el cwd lógico del sandbox;
  /// tree no existe en la mayoría de distros base). `vi` es interactivo:
  /// sin tty emite escapes basura — va por PTY o toybox, nunca por binario.
  static const _noHostBinary = {'cd', 'pwd', 'source', 'tree', 'vi'};

  /// Ejecuta [name] con [args] y emite por [out] (stdout/stderr con [Ln]).
  Future<void> run(
    String name,
    List<String> args, {
    required void Function(String, Ln) out,
  }) async {
    void o(String t) => out(t, Ln.stdout);
    void e(String t) => out(t, Ln.stderr);

    // 1) Binario Linux real del host: sed/awk/tar/chmod/diff... reales.
    if (hasRealShell && !_noHostBinary.contains(name)) {
      final bin = await _resolveBinary(name);
      if (bin != null) {
        await _runBinary(bin, name, args, out);
        return;
      }
    }

    // 2) Fallback dart:io real (hosts sin binarios).
    try {
      switch (name) {
        case 'mkdir':
          _mkdir(args, o, e);
        case 'touch':
          _touch(args, o, e);
        case 'ls':
          _ls(args, o, e);
        case 'cat':
          _cat(args, o, e);
        case 'wc':
          _wc(args, o, e);
        case 'grep':
          _grep(args, o, e);
        case 'find':
          _find(args, o, e);
        case 'head':
          _headTail(args, o, e, head: true);
        case 'tail':
          _headTail(args, o, e, head: false);
        case 'cp':
          _cp(args, o, e);
        case 'mv':
          _mv(args, o, e);
        case 'rm':
          _rm(args, o, e);
        case 'cd':
          _cd(args, o, e);
        case 'pwd':
          o(cwd);
        case 'echo':
          o(args.join(' '));
        case 'expr':
          _expr(args, o, e);
        case 'seq':
          _seq(args, o, e);
        case 'basename':
          _basenameDirname(args, o, e, base: true);
        case 'dirname':
          _basenameDirname(args, o, e, base: false);
        case 'tree':
          _tree(args, o, e);
        case 'diff':
          _diff(args, o, e);
        case 'source':
          await _source(args, o, e);
        case 'id':
          e('id: identidad del dispositivo no disponible');
        case 'chmod':
          e('chmod: requiere rootfs (sin binarios en este host)');
        case 'df':
          _df(o, e);
        case 'free':
          _free(o, e);
        default:
          e('$name: no disponible (fallback dart:io no lo soporta)');
      }
    } catch (err) {
      e('$name: $err');
    }
  }

  /// Ejecuta [cmd] completo con `sh -c` real del host: pipes `|`,
  /// redirección `> >> <`, `&&`, `||`, `;` — la semántica Linux de verdad
  /// sobre el sandbox. Sin sh del host → error honesto.
  Future<void> runShell(
    String cmd, {
    required void Function(String, Ln) out,
  }) async {
    final sh = hostSh;
    if (sh == null) {
      out('sh: no disponible en este host', Ln.stderr);
      return;
    }
    Process process;
    try {
      process = await Process.start(
        sh,
        ['-c', cmd],
        workingDirectory: resolve('.'),
        environment: _env,
      );
    } catch (err) {
      out('sh: $err', Ln.stderr);
      return;
    }
    await _pump(process, out);
  }

  /// Resuelve el binario del host para [name]: primero el binario nativo
  /// del PATH (coreutils/GNU reales), luego busybox si existe (applets).
  Future<String?> _resolveBinary(String name) async {
    final sh = hostSh;
    if (sh == null) return null;
    final cached = _binCache[name];
    if (cached == true) return name;
    if (cached == false) return await _resolveBusybox();
    try {
      final r = await Process.run(sh, ['-c', r'command -v "$1"', 'sh', name]);
      final ok = r.exitCode == 0 && (r.stdout as String).trim().isNotEmpty;
      _binCache[name] = ok;
      if (ok) return name;
    } catch (_) {
      _binCache[name] = false;
    }
    return await _resolveBusybox();
  }

  static final Map<String, bool> _binCache = {};
  static bool? _haveBusybox;

  Future<String?> _resolveBusybox() async {
    final sh = hostSh;
    if (sh == null) return null;
    if (_haveBusybox == true) return 'busybox';
    if (_haveBusybox == false) return null;
    try {
      final r = await Process.run(sh, ['-c', 'command -v busybox']);
      final ok = r.exitCode == 0 && (r.stdout as String).trim().isNotEmpty;
      _haveBusybox = ok;
      return ok ? 'busybox' : null;
    } catch (_) {
      _haveBusybox = false;
      return null;
    }
  }

  /// Lanza [bin] real ([name] como applet si es busybox) con cwd en el
  /// sandbox y vuelca stdout/stderr por [out].
  Future<void> _runBinary(
    String bin,
    String name,
    List<String> args,
    void Function(String, Ln) out,
  ) async {
    Process process;
    try {
      process = await Process.start(
        bin,
        bin == 'busybox' ? [name, ...args] : args,
        workingDirectory: resolve('.'),
        environment: _env,
      );
    } catch (err) {
      out('$name: $err', Ln.stderr);
      return;
    }
    await _pump(process, out);
  }

  /// Vuelca stdout/stderr de [process] línea a línea por [out] y espera el
  /// exit code. Sin salida y con rc != 0 no se inventa nada: un shell real
  /// también vuelve en silencio (p. ej. `grep` sin coincidencias).
  Future<void> _pump(Process process, void Function(String, Ln) out) async {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((l) => out(l, Ln.stdout));
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((l) => out(l, Ln.stderr));
    await process.exitCode;
  }

  // ── resolución de paths ──

  /// Path virtual (lógico) → path real bajo el raíz. `..` no escapa del raíz.
  String resolve(String p) {
    var parts = cwd == '/'
        ? <String>[]
        : cwd.split('/').where((s) => s.isNotEmpty).toList();
    if (p.startsWith('/')) parts = [];
    for (final seg in p.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (parts.isNotEmpty) parts.removeLast();
        continue;
      }
      parts.add(seg);
    }
    final rel = parts.join('/');
    return rel.isEmpty ? _root.path : '${_root.path}/$rel';
  }

  /// Path real → path lógico relativo al cwd actual (para find/ls -l).
  /// Normaliza separadores: los paths reales del host (Windows `\`) se
  /// comparan contra el raíz normalizado a `/`.
  String logical(String real) {
    final rootNorm = _root.path.replaceAll('\\', '/');
    final realNorm = real.replaceAll('\\', '/');
    final rel = realNorm.startsWith('$rootNorm/')
        ? realNorm.substring(rootNorm.length + 1)
        : realNorm;
    if (cwd == '/') return '/$rel';
    final c = cwd.endsWith('/') ? cwd : '$cwd/';
    return rel.startsWith(c.substring(1))
        ? rel.substring(c.length - 1)
        : '/$rel';
  }

  // ── comandos FS ──

  void _mkdir(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    if (args.isEmpty) {
      e('mkdir: falta operando');
      return;
    }
    for (final a in args) {
      Directory(resolve(a)).createSync(recursive: true);
    }
  }

  void _touch(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    if (args.isEmpty) {
      e('touch: falta operando');
      return;
    }
    for (final a in args) {
      File(resolve(a)).createSync(recursive: true);
    }
  }

  void _ls(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    final target = args.isEmpty ? cwd : args.first;
    final d = Directory(resolve(target));
    if (!d.existsSync()) {
      e('ls: $target: No such file or directory');
      return;
    }
    final entries = d.listSync().map((x) => x.uri.pathSegments.last).toList()
      ..sort();
    for (final n in entries) {
      o(n);
    }
  }

  void _cat(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    if (args.isEmpty) {
      e('cat: falta operando');
      return;
    }
    for (final a in args) {
      final f = File(resolve(a));
      if (!f.existsSync()) {
        e('cat: $a: No such file or directory');
        continue;
      }
      final content = f.readAsStringSync();
      for (final line in content.split('\n')) {
        if (line.isNotEmpty) o(line);
      }
    }
  }

  void _wc(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    if (args.isEmpty) {
      e('wc: falta operando');
      return;
    }
    final f = File(resolve(args.last));
    if (!f.existsSync()) {
      e('wc: ${args.last}: No such file or directory');
      return;
    }
    final lines = f.readAsStringSync().split('\n').length - 1;
    o('$lines ${args.last}');
  }

  void _grep(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    if (args.length < 2) {
      e('usage: grep [-i] PATRON ARCHIVO');
      return;
    }
    var ignoreCase = false;
    var i = 0;
    if (args[i] == '-i') {
      ignoreCase = true;
      i++;
    }
    final pattern = ignoreCase ? args[i].toLowerCase() : args[i];
    final file = File(resolve(args[i + 1]));
    if (!file.existsSync()) {
      e('grep: ${args[i + 1]}: No such file or directory');
      return;
    }
    for (final line in file.readAsStringSync().split('\n')) {
      final hay = ignoreCase ? line.toLowerCase() : line;
      if (hay.contains(pattern)) o(line);
    }
  }

  void _find(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    final target = args.isEmpty ? cwd : args.first;
    final d = Directory(resolve(target));
    if (!d.existsSync()) {
      e('find: $target: No such file or directory');
      return;
    }
    void walk(Directory dir) {
      final entries = dir.listSync().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final x in entries) {
        o(logical(x.path));
        if (x is Directory) walk(x);
      }
    }

    o(logical(d.path));
    walk(d);
  }

  void _headTail(
    List<String> args,
    void Function(String) o,
    void Function(String) e, {
    required bool head,
  }) {
    var n = 10;
    var fileArg = '';
    var i = 0;
    while (i < args.length) {
      if (args[i] == '-n' && i + 1 < args.length) {
        n = int.tryParse(args[i + 1]) ?? n;
        i += 2;
      } else {
        fileArg = args[i];
        i++;
      }
    }
    if (fileArg.isEmpty) {
      e('${head ? "head" : "tail"}: falta operando');
      return;
    }
    final f = File(resolve(fileArg));
    if (!f.existsSync()) {
      e('${head ? "head" : "tail"}: $fileArg: No such file or directory');
      return;
    }
    final lines = f.readAsStringSync().split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    final pick = head
        ? lines.take(n)
        : lines.skip(lines.length - n < 0 ? 0 : lines.length - n);
    for (final l in pick) {
      o(l);
    }
  }

  void _cp(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    if (args.length < 2) {
      e('cp: faltan operandos');
      return;
    }
    final src = args[0];
    final dst = args[1];
    final s = FileSystemEntity.typeSync(resolve(src), followLinks: true);
    if (s == FileSystemEntityType.notFound) {
      e('cp: $src: No such file or directory');
      return;
    }
    if (s == FileSystemEntityType.directory) {
      Directory(resolve(dst)).createSync(recursive: true);
      for (final x in Directory(resolve(src)).listSync(recursive: true)) {
        final rel = x.path.substring(resolve(src).length).replaceAll('\\', '/');
        final dest = '${resolve(dst)}$rel';
        if (x is File) {
          File(dest).parent.createSync(recursive: true);
          x.copySync(dest);
        } else if (x is Directory) {
          Directory(dest).createSync(recursive: true);
        }
      }
    } else {
      File(resolve(dst)).parent.createSync(recursive: true);
      File(resolve(src)).copySync(resolve(dst));
    }
  }

  void _mv(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    if (args.length < 2) {
      e('mv: faltan operandos');
      return;
    }
    final src = resolve(args[0]);
    final dst = resolve(args[1]);
    final type = FileSystemEntity.typeSync(src, followLinks: true);
    if (type == FileSystemEntityType.notFound) {
      e('mv: ${args[0]}: No such file or directory');
      return;
    }
    // Basename lógico (el sandbox usa rutas Unix): `a/b/c` → `c`.
    final segs = args[0].split('/').where((s) => s.isNotEmpty).toList();
    final base = segs.isEmpty ? '' : segs.last;
    // Si el destino es un directorio, mover dentro de él conservando el nombre.
    final dstType = FileSystemEntity.typeSync(dst, followLinks: false);
    final dest = dstType == FileSystemEntityType.directory ? '$dst/$base' : dst;
    // File.renameSync falla con directorios; se resuelve por tipo real, no por
    // toString().contains('notFound') (frágil, dependía del texto del enum).
    if (type == FileSystemEntityType.directory) {
      Directory(src).renameSync(dest);
    } else {
      File(src).renameSync(dest);
    }
  }

  void _rm(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    if (args.isEmpty) {
      e('rm: falta operando');
      return;
    }
    var recursive = false;
    final targets = <String>[];
    for (final a in args) {
      if (a == '-r' || a == '-rf' || a == '-f') {
        recursive = true;
      } else {
        targets.add(a);
      }
    }
    for (final t in targets) {
      final p = resolve(t);
      final type = FileSystemEntity.typeSync(p, followLinks: true);
      if (type == FileSystemEntityType.notFound) continue;
      if (type == FileSystemEntityType.directory) {
        if (!recursive) {
          e('rm: $t: es un directorio (usa -r)');
          continue;
        }
        Directory(p).deleteSync(recursive: true);
      } else {
        File(p).deleteSync();
      }
    }
  }

  void _cd(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    final target = args.isEmpty ? '/' : args.first;
    final real = resolve(target);
    if (!Directory(real).existsSync()) {
      e('cd: $target: No such file or directory');
      return;
    }
    // Reconstruye el cwd lógico desde el path real (normaliza `..` y `.`).
    final rootNorm = _root.path.replaceAll('\\', '/');
    final realNorm = real.replaceAll('\\', '/');
    final rel = realNorm.startsWith('$rootNorm/')
        ? realNorm.substring(rootNorm.length + 1)
        : '';
    cwd = rel.isEmpty ? '/' : '/$rel';
  }

  // ── comandos de lógica ──

  void _expr(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    if (args.length != 3) {
      e('usage: expr A OP B');
      return;
    }
    final a = int.tryParse(args[0]);
    final b = int.tryParse(args[2]);
    if (a == null || b == null) {
      e('expr: operando no numérico');
      return;
    }
    switch (args[1]) {
      case '+':
        o('${a + b}');
      case '-':
        o('${a - b}');
      case '*':
        o('${a * b}');
      case '/':
        o(b == 0 ? 'expr: division by zero' : '${a ~/ b}');
      default:
        e('expr: operador no soportado: ${args[1]}');
    }
  }

  void _seq(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    int? first, last, step = 1;
    if (args.length == 1) {
      last = int.tryParse(args[0]);
    } else if (args.length >= 2) {
      first = int.tryParse(args[0]);
      last = int.tryParse(args[1]);
      if (args.length >= 3) step = int.tryParse(args[2]);
    }
    if (last == null || step == null || step == 0) {
      e('usage: seq [PRIMERO] ULTIMO [PASO]');
      return;
    }
    final start = first ?? 1;
    for (var v = start; (step > 0) ? v <= last : v >= last; v += step) {
      o('$v');
    }
  }

  void _basenameDirname(
    List<String> args,
    void Function(String) o,
    void Function(String) e, {
    required bool base,
  }) {
    if (args.isEmpty) {
      e('${base ? "basename" : "dirname"}: falta operando');
      return;
    }
    final p = args[0];
    final parts = p.split('/').where((s) => s.isNotEmpty).toList();
    if (base) {
      o(parts.isEmpty ? '/' : parts.last);
    } else {
      if (p.startsWith('/')) {
        o(
          parts.length <= 1
              ? '/'
              : '/${parts.sublist(0, parts.length - 1).join("/")}',
        );
      } else {
        o(
          parts.length <= 1
              ? '.'
              : parts.sublist(0, parts.length - 1).join('/'),
        );
      }
    }
  }

  // ── tree / diff / source ──

  void _tree(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    final target = args.isEmpty ? cwd : args.first;
    final d = Directory(resolve(target));
    if (!d.existsSync()) {
      e('tree: $target: No such file or directory');
      return;
    }
    var dirs = 0;
    var files = 0;
    void walk(Directory dir, String prefix, String label) {
      o('$prefix$label');
      final entries = dir.listSync().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (var i = 0; i < entries.length; i++) {
        final x = entries[i];
        final last = i == entries.length - 1;
        final name = x.uri.pathSegments.last;
        final branch = last ? '└── ' : '├── ';
        if (x is Directory) {
          dirs++;
          walk(x, '$prefix${last ? "    " : "│   "}$branch', '$name/');
        } else {
          files++;
          o('$prefix$branch$name');
        }
      }
    }

    o(target);
    walk(d, '', '');
    o('');
    o('directorios: $dirs, archivos: $files');
  }

  /// Diff línea a línea con LCS básico. Marca `-` quitadas y `+` añadidas.
  void _diff(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) {
    if (args.length < 2) {
      e('usage: diff ARCHIVO1 ARCHIVO2');
      return;
    }
    final f1 = File(resolve(args[0]));
    final f2 = File(resolve(args[1]));
    if (!f1.existsSync() || !f2.existsSync()) {
      e('diff: archivo no encontrado');
      return;
    }
    final a = f1.readAsStringSync().split('\n');
    final b = f2.readAsStringSync().split('\n');
    if (a.isNotEmpty && a.last.isEmpty) a.removeLast();
    if (b.isNotEmpty && b.last.isEmpty) b.removeLast();

    // LCS sobre líneas (tamaños de archivos de terminal: pequeño).
    final lcs = List.generate(
      a.length + 1,
      (_) => List.filled(b.length + 1, 0),
    );
    for (var i = a.length - 1; i >= 0; i--) {
      for (var j = b.length - 1; j >= 0; j--) {
        lcs[i][j] = a[i] == b[j]
            ? lcs[i + 1][j + 1] + 1
            : (lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
      }
    }
    o('--- ${args[0]}');
    o('+++ ${args[1]}');
    var i = 0;
    var j = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        o('-${a[i]}');
        i++;
      } else {
        o('+${b[j]}');
        j++;
      }
    }
    while (i < a.length) {
      o('-${a[i]}');
      i++;
    }
    while (j < b.length) {
      o('+${b[j]}');
      j++;
    }
  }

  /// Ejecuta cada línea no vacía y no comentada del archivo como comando
  /// soportado por este fallback (recursivo).
  Future<void> _source(
    List<String> args,
    void Function(String) o,
    void Function(String) e,
  ) async {
    if (args.isEmpty) {
      e('source: falta archivo');
      return;
    }
    final f = File(resolve(args[0]));
    if (!f.existsSync()) {
      e('source: ${args[0]}: No such file or directory');
      return;
    }
    for (final raw in f.readAsStringSync().split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split(RegExp(r'\s+'));
      final name = parts[0];
      final rest = parts.length > 1 ? parts.sublist(1) : <String>[];
      if (!supports(name)) {
        e('source: $name: no disponible');
        continue;
      }
      // await: sin él las líneas se lanzan concurrentes y el orden de
      // salida (y cualquier `cd`) se intercala — un script source debe
      // ejecutarse secuencialmente.
      await run(
        name,
        rest,
        out: (t, ty) {
          if (ty == Ln.stdout) {
            o(t);
          } else {
            e(t);
          }
        },
      );
    }
  }

  // ── comandos honestos de sistema ──

  /// df requiere device identity del runtime Android (stats de /proc/mounts
  /// del device). En este host no hay identity → error honesto, nunca
  /// inventa cifras ni muestra el disco del PC de desarrollo.
  void _df(void Function(String) o, void Function(String) e) {
    e('df: almacenamiento no disponible');
  }

  /// free real: lee /proc/meminfo si existe (Linux). Sin /proc → error honesto.
  void _free(void Function(String) o, void Function(String) e) {
    try {
      final raw = File('/proc/meminfo').readAsStringSync();
      final total = _meminfoKb(raw, 'MemTotal');
      final free = _meminfoKb(raw, 'MemFree');
      final avail = _meminfoKb(raw, 'MemAvailable');
      if (total == null) {
        e('free: memoria no disponible');
        return;
      }
      final used = total - (avail ?? free ?? 0);
      String fmt(int kb) => '${(kb / 1024).toStringAsFixed(0)} MB';
      o(
        'Mem: total ${fmt(total)}, usada ${fmt(used)}, libre ${fmt(avail ?? free ?? 0)}',
      );
    } catch (_) {
      e('free: memoria no disponible');
    }
  }

  int? _meminfoKb(String raw, String key) {
    for (final line in raw.split('\n')) {
      if (!line.startsWith('$key:')) continue;
      final v = RegExp(r'(\d+)').firstMatch(line.split(':')[1]);
      return int.tryParse(v?.group(1) ?? '');
    }
    return null;
  }
}
