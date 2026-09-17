import '../../../executors/linux/linux_automation_port.dart';
import '../tool_call.dart';

/// Manejador de herramientas semánticas Linux para el orquestador de Nano.
///
/// Ejecuta operaciones estructuradas de alto nivel (FS, Archive, Process, Git)
/// a través del puerto ILinuxAutomationExecutor, evitando exponer comandos bash
/// crudos al modelo de lenguaje y devolviendo evidencia compacta y verificada.
class SemanticLinuxToolHandler {
  final ILinuxAutomationExecutor? _executor;

  const SemanticLinuxToolHandler({ILinuxAutomationExecutor? executor})
      : _executor = executor;

  bool get isAvailable => _executor?.isAvailable ?? false;

  /// Ejecuta una llamada a herramienta con prefijo `nano.linux.*`.
  Future<String> handleToolCall(ToolCall call) async {
    final exec = _executor;
    if (exec == null || !exec.isAvailable) {
      return '[linuxOff] El subsistema Linux/Nanoshell no está disponible en este dispositivo.';
    }

    final tool = call.tool.toLowerCase().trim();
    final args = call.args ?? const <String, dynamic>{};

    switch (tool) {
      // ── FS ──
      case 'nano.linux.fs.list':
        final path = _extractString(args, ['path', 'dir']) ?? '/';
        final recursive = args['recursive'] as bool? ?? false;
        final res = await exec.listFiles(path, recursive: recursive);
        if (!res.ok) return '[linuxFail] list "$path": ${res.verification.details}';
        final count = res.data?.length ?? 0;
        final sample = res.data?.take(5).map((e) => e.name).join(', ') ?? '';
        return 'SUCCESS: $count items en "$path" ($sample${count > 5 ? '…' : ''})';

      case 'nano.linux.fs.read':
        final path = _extractString(args, ['path', 'file']);
        if (path == null) return '[toolError] Se requiere parámetro "path"';
        final maxBytes = (args['maxBytes'] as num?)?.toInt() ?? 4096;
        final res = await exec.readFile(path, maxBytes: maxBytes);
        if (!res.ok) return '[linuxFail] read "$path": ${res.verification.details}';
        final content = res.data ?? '';
        final truncated = content.length > 500 ? '${content.substring(0, 500)}…' : content;
        return 'SUCCESS: lectura de "$path" (${content.length} bytes):\n$truncated';

      case 'nano.linux.fs.write':
        final path = _extractString(args, ['path', 'file']);
        final content = _extractString(args, ['content', 'text']) ?? '';
        if (path == null) return '[toolError] Se requiere parámetro "path"';
        final res = await exec.writeFile(path, content);
        if (!res.ok) return '[linuxFail] write "$path": ${res.verification.details}';
        return 'SUCCESS: archivo "$path" escrito y verificado en disco (${content.length} bytes).';

      case 'nano.linux.fs.remove':
        final path = _extractString(args, ['path', 'target']);
        if (path == null) return '[toolError] Se requiere parámetro "path"';
        final recursive = args['recursive'] as bool? ?? false;
        final res = await exec.removePath(path, recursive: recursive);
        if (!res.ok) return '[linuxFail] remove "$path": ${res.verification.details}';
        return 'SUCCESS: "$path" eliminado y confirmado inexistente en disco.';

      case 'nano.linux.fs.copy':
        final src = _extractString(args, ['source', 'src', 'from']);
        final dst = _extractString(args, ['destination', 'dst', 'to']);
        if (src == null || dst == null) return '[toolError] Requiere "source" y "destination"';
        final res = await exec.copyPath(src, dst);
        if (!res.ok) return '[linuxFail] copy: ${res.verification.details}';
        return 'SUCCESS: copiado de "$src" a "$dst" verificado.';

      case 'nano.linux.fs.move':
        final src = _extractString(args, ['source', 'src', 'from']);
        final dst = _extractString(args, ['destination', 'dst', 'to']);
        if (src == null || dst == null) return '[toolError] Requiere "source" y "destination"';
        final res = await exec.movePath(src, dst);
        if (!res.ok) return '[linuxFail] move: ${res.verification.details}';
        return 'SUCCESS: movimiento de "$src" a "$dst" verificado.';

      case 'nano.linux.fs.stat':
        final path = _extractString(args, ['path', 'target']);
        if (path == null) return '[toolError] Se requiere parámetro "path"';
        final res = await exec.statPath(path);
        if (!res.ok) return '[linuxFail] stat "$path": ${res.verification.details}';
        final entry = res.data;
        return 'SUCCESS: stat "$path" type=${entry?.type.name} size=${entry?.sizeBytes}b perms=${entry?.permissions}';

      // ── Archive ──
      case 'nano.linux.archive.create':
        final src = _extractString(args, ['sourcePath', 'source', 'src']);
        final tar = _extractString(args, ['tarPath', 'destination', 'tar']);
        if (src == null || tar == null) return '[toolError] Requiere "sourcePath" y "tarPath"';
        final gzip = args['gzip'] as bool? ?? true;
        final res = await exec.createTar(src, tar, gzip: gzip);
        if (!res.ok) return '[linuxFail] archive.create: ${res.verification.details}';
        return 'SUCCESS: archivo comprimido "$tar" creado con integridad verificada.';

      case 'nano.linux.archive.extract':
        final tar = _extractString(args, ['tarPath', 'tar', 'file']);
        final target = _extractString(args, ['targetDir', 'dest', 'dir']);
        if (tar == null || target == null) return '[toolError] Requiere "tarPath" y "targetDir"';
        final gzip = args['gzip'] as bool? ?? true;
        final res = await exec.extractTar(tar, target, gzip: gzip);
        if (!res.ok) return '[linuxFail] archive.extract: ${res.verification.details}';
        return 'SUCCESS: archivo "$tar" extraído correctamente en "$target".';

      // ── Process ──
      case 'nano.linux.process.list':
        final res = await exec.listProcesses();
        if (!res.ok) return '[linuxFail] process.list: ${res.verification.details}';
        final procs = res.data ?? [];
        final sample = procs.take(6).map((p) => '${p.pid}:${p.command}').join(', ');
        return 'SUCCESS: ${procs.length} procesos activos ($sample${procs.length > 6 ? '…' : ''})';

      case 'nano.linux.process.start':
        final cmd = _extractString(args, ['command', 'cmd', 'bin']);
        final tag = _extractString(args, ['trackTag', 'tag']) ?? 'proc-${DateTime.now().millisecondsSinceEpoch}';
        if (cmd == null) return '[toolError] Se requiere parámetro "command"';
        final cmdArgs = _extractList(args, ['args', 'arguments']);
        final res = await exec.startTracked(cmd, cmdArgs, trackTag: tag);
        if (!res.ok) return '[linuxFail] process.start: ${res.verification.details}';
        return 'SUCCESS: proceso "$cmd" iniciado en segundo plano bajo tag "$tag".';

      case 'nano.linux.process.stop':
        final tag = _extractString(args, ['trackTag', 'tag']);
        if (tag == null) return '[toolError] Se requiere parámetro "trackTag"';
        final res = await exec.stopTracked(tag);
        if (!res.ok) return '[linuxFail] process.stop "$tag": ${res.verification.details}';
        return 'SUCCESS: proceso con tag "$tag" detenido satisfactoriamente.';

      // ── Git ──
      case 'nano.linux.git.status':
        final repo = _extractString(args, ['repoPath', 'path', 'repo']) ?? '.';
        final res = await exec.gitStatus(repo);
        if (!res.ok) return '[linuxFail] git status: ${res.verification.details}';
        final out = (res.data ?? '').trim();
        return 'SUCCESS: git status ($repo):\n${out.isEmpty ? 'clean working tree' : out}';

      case 'nano.linux.git.diff':
        final repo = _extractString(args, ['repoPath', 'path', 'repo']) ?? '.';
        final res = await exec.gitDiff(repo);
        if (!res.ok) return '[linuxFail] git diff: ${res.verification.details}';
        final diff = (res.data ?? '').trim();
        final preview = diff.length > 400 ? '${diff.substring(0, 400)}…' : diff;
        return 'SUCCESS: git diff ($repo):\n${preview.isEmpty ? 'sin cambios' : preview}';

      case 'nano.linux.git.log':
        final repo = _extractString(args, ['repoPath', 'path', 'repo']) ?? '.';
        final limit = (args['limit'] as num?)?.toInt() ?? 5;
        final res = await exec.gitLog(repo, limit: limit);
        if (!res.ok) return '[linuxFail] git log: ${res.verification.details}';
        return 'SUCCESS: git log ($repo):\n${res.data ?? ''}';

      // ── Structured Exec Escape Hatch ──
      case 'nano.linux.exec.structured':
        final exe = _extractString(args, ['executable', 'command', 'cmd']);
        if (exe == null) return '[toolError] Se requiere parámetro "executable"';
        final cmdArgs = _extractList(args, ['args', 'arguments']);
        final cwd = _extractString(args, ['cwd', 'workDir']);
        final res = await exec.executeStructured(exe, cmdArgs, cwd: cwd);
        if (!res.ok) return '[linuxFail] exec "$exe": ${res.verification.details}';
        final out = (res.data ?? '').trim();
        final tail = out.length > 500 ? '${out.substring(0, 500)}…' : out;
        return 'SUCCESS: exec "$exe" exitCode=0:\n${tail.isEmpty ? '(sin salida)' : tail}';

      default:
        return '[toolUnknown] Herramienta semántica Linux desconocida: ${call.tool}';
    }
  }

  String? _extractString(Map<String, dynamic> args, List<String> keys) {
    for (final k in keys) {
      final v = args[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  List<String> _extractList(Map<String, dynamic> args, List<String> keys) {
    for (final k in keys) {
      final v = args[k];
      if (v is List) return v.map((e) => '$e').toList();
    }
    return const [];
  }
}
