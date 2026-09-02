/// Parser determinista de comandos Linux desde voz/texto — SIN LLM.
///
/// Convierte frases inequívocas a un ToolCall tipado (linux.list/readFile/
/// writeFile) con path y contenido extraídos del texto. Principio: la voz es
/// solo I/O del MISMO motor; el routing determinista evita gastar LLM en
/// intenciones conocidas y evita raw-shell.
///
/// Semántica de path:
///   "de la raíz"            → "/"
///   "de este directorio"/"aquí" → "/" (cwd real del rootfs; no hay cwd global)
///   "de /ruta"              → "/ruta"
///   path relativo (write/read) → "/tmp/<path>" (transitorio, verificable)
///   "léelo"                 → lastFilePath (contexto); sin contexto → null
library;

import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show ToolCall;
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart'
    show GoalExpectation;
import 'package:nanoai/features/automation/engine/execution/platform_verification.dart'
    show FileContentContains, FileExists;

/// Comando Linux tipado resuelto sin LLM.
class ParsedLinuxCommand {
  final ToolCall call;

  /// Para write: FileExists + FileContentContains (el goal NO se da por
  /// satisfecho solo con exitCode == 0).
  final GoalExpectation? expectation;
  const ParsedLinuxCommand({required this.call, this.expectation});
}

class LinuxVoiceCommandParser {
  const LinuxVoiceCommandParser();

  // "crea/escribe/guarda [un archivo llamado] X con [el texto] Y"
  static final _writeRe = RegExp(
    r'(crea|crear|escribe|escribir|guarda|guardar).*?'
    r'(?:llamad[oa]?\s+)?([\w.][\w./-]*)\s+'
    r'(?:con(?:\s+el\s+texto)?\s+)(.+)$',
    caseSensitive: false,
  );

  // "lee X" (leer archivo). "abre" NO es lectura de archivo (es navegación
  // open_system); no se incluye para no colisionar con "abre bluetooth".
  static final _readPathRe = RegExp(
    r'\b(lee|leer)\s+([\w.][\w./-]*)',
    caseSensitive: false,
  );

  // "léelo" / "muéstramelo" (contexto)
  static final _readContextRe = RegExp(
    r'^(léelo|leelo|muéstramelo|muestramelo|ábrelo|abrelo)$',
    caseSensitive: false,
  );

  static final _listRe = RegExp(
    r'\b(lista|listar|muestra|mostrar)\b.*\b(archivos?|directorios?|ficheros?|carpetas?|contenido)\b',
    caseSensitive: false,
  );
  static final _listWhatsRe = RegExp(
    r'qu[eé]\s+(?:archivos\s+)?hay',
    caseSensitive: false,
  );

  ParsedLinuxCommand? parse(String goal, {String? lastFilePath}) {
    final g = goal.trim();
    final lower = g.toLowerCase();

    final write = _parseWrite(g, lower);
    if (write != null) return write;

    final read = _parseRead(g, lower, lastFilePath);
    if (read != null) return read;

    final list = _parseList(g, lower);
    if (list != null) return list;

    return null;
  }

  ParsedLinuxCommand? _parseWrite(String g, String lower) {
    final m = _writeRe.firstMatch(lower);
    if (m == null) return null;
    final rawPath = m.group(2)!.trim();
    final content = m.group(3)!.trim();
    if (content.isEmpty) return null;
    final path = _resolvePath(rawPath);
    return ParsedLinuxCommand(
      call: ToolCall(
        tool: 'linux.writeFile',
        text: path,
        args: {'content': content},
      ),
      expectation: GoalExpectation(statePredicates: [
        FileExists(path),
        FileContentContains(path, content),
      ]),
    );
  }

  ParsedLinuxCommand? _parseRead(String g, String lower, String? lastFilePath) {
    // "léelo" → solo con contexto (no inventa target).
    if (_readContextRe.hasMatch(lower)) {
      if (lastFilePath == null || lastFilePath.isEmpty) return null;
      return ParsedLinuxCommand(
        call: ToolCall(tool: 'linux.readFile', text: lastFilePath),
      );
    }
    final m = _readPathRe.firstMatch(lower);
    if (m == null) return null;
    final path = _resolvePath(m.group(2)!.trim());
    return ParsedLinuxCommand(
      call: ToolCall(tool: 'linux.readFile', text: path),
    );
  }

  ParsedLinuxCommand? _parseList(String g, String lower) {
    final isList = _listRe.hasMatch(lower) || _listWhatsRe.hasMatch(lower);
    if (!isList) return null;
    return ParsedLinuxCommand(
      call: ToolCall(tool: 'linux.list', text: _extractListPath(g)),
    );
  }

  String _extractListPath(String g) {
    final de = RegExp(r'\bde\s+(.+)$', caseSensitive: false).firstMatch(g);
    if (de == null) return '/';
    final raw = de.group(1)!.trim();
    final lower = raw.toLowerCase();
    if (raw.startsWith('/')) return raw;
    if (lower.contains('raíz') || lower.contains('raiz')) return '/';
    // "este directorio"/"aquí"/"acá" → cwd real del rootfs.
    if (lower.contains('directorio') ||
        lower.contains('aquí') ||
        lower.contains('aqui') ||
        lower.contains('acá') ||
        lower.contains('aca')) {
      return '/';
    }
    return _resolvePath(raw);
  }

  String _resolvePath(String raw) {
    if (raw.startsWith('/')) return raw;
    return '/tmp/$raw';
  }
}
