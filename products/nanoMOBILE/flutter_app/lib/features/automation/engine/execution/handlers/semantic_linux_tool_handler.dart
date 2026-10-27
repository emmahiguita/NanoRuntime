import '../../../executors/linux/linux_automation_port.dart';
import '../tool_call.dart';
part 'semantic_linux_remaining.dart';

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
        if (!res.ok) {
          return '[linuxFail] list "$path": ${res.verification.details}';
        }
        final count = res.data?.length ?? 0;
        final sample = res.data?.take(5).map((e) => e.name).join(', ') ?? '';
        return 'SUCCESS: $count items en "$path" ($sample${count > 5 ? '…' : ''})';

      case 'nano.linux.fs.read':
        final path = _extractString(args, ['path', 'file']);
        if (path == null) return '[toolError] Se requiere parámetro "path"';
        final maxBytes = (args['maxBytes'] as num?)?.toInt() ?? 4096;
        final res = await exec.readFile(path, maxBytes: maxBytes);
        if (!res.ok) {
          return '[linuxFail] read "$path": ${res.verification.details}';
        }
        final content = res.data ?? '';
        final truncated = content.length > 500
            ? '${content.substring(0, 500)}…'
            : content;
        return 'SUCCESS: lectura de "$path" (${content.length} bytes):\n$truncated';

      case 'nano.linux.fs.write':
        final path = _extractString(args, ['path', 'file']);
        final rawContent = args['content'] ?? args['text'];
        if (rawContent is! String) {
          return '[toolError] Se requiere contenido de texto explícito.';
        }
        final content = rawContent;
        if (path == null) return '[toolError] Se requiere parámetro "path"';
        final res = await exec.writeFile(path, content);
        if (!res.ok) {
          return '[linuxFail] write "$path": ${res.verification.details}';
        }
        return 'SUCCESS: archivo "$path" escrito y verificado en disco (${content.length} bytes).';

      case 'nano.linux.fs.remove':
        final path = _extractString(args, ['path', 'target']);
        if (path == null) return '[toolError] Se requiere parámetro "path"';
        final recursive = args['recursive'] as bool? ?? false;
        final res = await exec.removePath(path, recursive: recursive);
        if (!res.ok) {
          return '[linuxFail] remove "$path": ${res.verification.details}';
        }
        return 'SUCCESS: "$path" eliminado y confirmado inexistente en disco.';

      case 'nano.linux.fs.copy':
        final src = _extractString(args, ['source', 'src', 'from']);
        final dst = _extractString(args, ['destination', 'dst', 'to']);
        if (src == null || dst == null) {
          return '[toolError] Requiere "source" y "destination"';
        }
        final res = await exec.copyPath(src, dst);
        if (!res.ok) return '[linuxFail] copy: ${res.verification.details}';
        return 'SUCCESS: copiado de "$src" a "$dst" verificado.';

      case 'nano.linux.fs.move':
        final src = _extractString(args, ['source', 'src', 'from']);
        final dst = _extractString(args, ['destination', 'dst', 'to']);
        if (src == null || dst == null) {
          return '[toolError] Requiere "source" y "destination"';
        }
        final res = await exec.movePath(src, dst);
        if (!res.ok) return '[linuxFail] move: ${res.verification.details}';
        return 'SUCCESS: movimiento de "$src" a "$dst" verificado.';

      case 'nano.linux.fs.stat':
        final path = _extractString(args, ['path', 'target']);
        if (path == null) return '[toolError] Se requiere parámetro "path"';
        final res = await exec.statPath(path);
        if (!res.ok) {
          return '[linuxFail] stat "$path": ${res.verification.details}';
        }
        final entry = res.data;
        return 'SUCCESS: stat "$path" type=${entry?.type.name} size=${entry?.sizeBytes}b perms=${entry?.permissions}';

      default:
        return _handleRemaining(call, exec, args);
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
