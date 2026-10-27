part of 'semantic_linux_tool_handler.dart';

/// Archivo, procesos y Git: conserva argumentos y devuelve estados observados.
extension _RemainingLinuxTools on SemanticLinuxToolHandler {
  Future<String> _handleRemaining(
    ToolCall call,
    ILinuxAutomationExecutor exec,
    Map<String, dynamic> args,
  ) async {
    switch (call.tool.toLowerCase().trim()) {
      // ── Archive ──
      case 'nano.linux.archive.create':
        final src = _extractString(args, ['sourcePath', 'source', 'src']);
        final tar = _extractString(args, ['tarPath', 'destination', 'tar']);
        if (src == null || tar == null) {
          return '[toolError] Requiere "sourcePath" y "tarPath"';
        }
        final gzip = args['gzip'] as bool? ?? true;
        final res = await exec.createTar(src, tar, gzip: gzip);
        if (!res.ok) {
          return '[linuxFail] archive.create: ${res.verification.details}';
        }
        return 'SUCCESS: archivo comprimido "$tar" creado con integridad verificada.';

      case 'nano.linux.archive.extract':
        final tar = _extractString(args, ['tarPath', 'tar', 'file']);
        final target = _extractString(args, ['targetDir', 'dest', 'dir']);
        if (tar == null || target == null) {
          return '[toolError] Requiere "tarPath" y "targetDir"';
        }
        final gzip = args['gzip'] as bool? ?? true;
        final res = await exec.extractTar(tar, target, gzip: gzip);
        if (!res.ok) {
          return '[linuxFail] archive.extract: ${res.verification.details}';
        }
        return 'SUCCESS: archivo "$tar" extraído correctamente en "$target".';

      // ── Process ──
      case 'nano.linux.process.list':
        final res = await exec.listProcesses();
        if (!res.ok) {
          return '[linuxFail] process.list: ${res.verification.details}';
        }
        final procs = res.data ?? [];
        final sample = procs
            .take(6)
            .map((p) => '${p.pid}:${p.command}')
            .join(', ');
        return 'SUCCESS: ${procs.length} procesos activos ($sample${procs.length > 6 ? '…' : ''})';

      case 'nano.linux.process.start':
        final cmd = _extractString(args, ['command', 'cmd', 'bin']);
        final tag =
            _extractString(args, ['trackTag', 'tag']) ??
            'proc-${DateTime.now().millisecondsSinceEpoch}';
        if (cmd == null) return '[toolError] Se requiere parámetro "command"';
        final cmdArgs = _extractList(args, ['args', 'arguments']);
        final res = await exec.startTracked(cmd, cmdArgs, trackTag: tag);
        if (!res.executedOk) {
          return '[linuxFail] process.start: ${res.verification.details}';
        }
        if (!res.isVerified) {
          return '[completedUnverified] ${res.verification.details} Tag: $tag.';
        }
        return 'SUCCESS: proceso "$cmd" iniciado en segundo plano bajo tag "$tag".';

      case 'nano.linux.process.stop':
        final tag = _extractString(args, ['trackTag', 'tag']);
        if (tag == null) return '[toolError] Se requiere parámetro "trackTag"';
        final res = await exec.stopTracked(tag);
        if (res.executedOk && !res.isVerified) {
          return '[completedUnverified] ${res.verification.details}';
        }
        if (!res.ok) {
          return '[linuxFail] process.stop "$tag": ${res.verification.details}';
        }
        return 'SUCCESS: proceso con tag "$tag" detenido satisfactoriamente.';

      // ── Git ──
      case 'nano.linux.git.status':
        final repo = _extractString(args, ['repoPath', 'path', 'repo']) ?? '.';
        final res = await exec.gitStatus(repo);
        if (!res.ok) {
          return '[linuxFail] git status: ${res.verification.details}';
        }
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
        if (exe == null) {
          return '[toolError] Se requiere parámetro "executable"';
        }
        final cmdArgs = _extractList(args, ['args', 'arguments']);
        final cwd = _extractString(args, ['cwd', 'workDir']);
        final res = await exec.executeStructured(exe, cmdArgs, cwd: cwd);
        if (!res.ok) {
          return '[linuxFail] exec "$exe": ${res.verification.details}';
        }
        final out = (res.data ?? '').trim();
        final tail = out.length > 500 ? '${out.substring(0, 500)}…' : out;
        return 'SUCCESS: exec "$exe" exitCode=0:\n${tail.isEmpty ? '(sin salida)' : tail}';

      default:
        return '[toolUnknown] Herramienta Linux desconocida: ${call.tool}';
    }
  }
}
