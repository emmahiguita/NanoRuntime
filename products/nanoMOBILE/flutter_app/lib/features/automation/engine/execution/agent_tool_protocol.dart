import 'dart:convert';

import 'tool_call.dart';

/// Parseo tolerante del bloque JSON de herramientas en texto generado.
abstract final class AgentToolProtocol {
  /// Localiza y decodifica el objeto JSON con clave "tool" si la respuesta
  /// es una llamada a herramienta del agente.
  ///
  /// Tolerancia: el modelo puede rodear el JSON de markdown (` ```json `).
  /// Si el texto es una explicación conversacional larga con texto sustancial
  /// antes del JSON, se considera respuesta normal de texto y no tool call.
  static ToolCall? extractToolCall(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Normalizar si viene envuelto en bloque de código markdown ```json ... ```
    var cleaned = trimmed;
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7).trim();
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3).trim();
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    }

    final startMatch = RegExp(r'\{[^{}\n]*"tool"\s*:').firstMatch(cleaned);
    if (startMatch == null) return null;

    // Si hay más de 50 caracteres de prosa explicativa antes del primer {,
    // es una respuesta conversacional que cita JSON, no un tool call directo.
    if (startMatch.start > 50) return null;

    final start = startMatch.start;
    var depth = 0;
    var end = -1;
    for (var i = start; i < cleaned.length; i++) {
      final c = cleaned[i];
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    final candidate = end >= 0
        ? cleaned.substring(start, end + 1)
        : cleaned.substring(start);
    return _parseToolObject(candidate);
  }

  static Map<String, dynamic> jsonDecodeTolerant(String s) =>
      (jsonDecode(s) as Map).cast<String, dynamic>();

  /// Extrae TODAS las llamadas a herramienta de la respuesta: un array JSON
  /// (`[{"tool":"tap",...},{"tool":"back"}]`) o un objeto único. Devuelve la
  /// lista vacía si no hay ninguna. Mantiene el contrato single de
  /// [extractToolCall] (este método devuelve esa misma llamada como lista).
  static List<ToolCall> extractToolCalls(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    var cleaned = trimmed;
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7).trim();
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3).trim();
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    }

    // ¿Array JSON de tools?
    final arrayStart = cleaned.indexOf('[');
    if (arrayStart >= 0) {
      // No interpretar prosa con un [ fuera de contexto: el array debe
      // contener "tool" como primera clave de un objeto.
      final probe = cleaned.substring(arrayStart);
      if (RegExp(r'\[[^\[\]]*"tool"\s*:').hasMatch(probe)) {
        final arrayEnd = _findBalanced(cleaned, arrayStart, '[', ']');
        if (arrayEnd > arrayStart) {
          final inner = cleaned.substring(arrayStart + 1, arrayEnd);
          final calls = <ToolCall>[];
          for (final part in _splitTopLevel(inner)) {
            final call = _parseToolObject(part);
            if (call != null) calls.add(call);
          }
          if (calls.isNotEmpty) return calls;
        }
      }
    }

    // Fallback: objeto único (contrato original).
    final single = extractToolCall(text);
    return single == null ? const [] : [single];
  }

  /// Parsea un objeto JSON de herramienta a [ToolCall]; null si no tiene
  /// clave "tool" válida.
  static ToolCall? _parseToolObject(String candidate) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) return null;
    try {
      final map = jsonDecodeTolerant(trimmed);
      final tool = map['tool'] as String?;
      if (tool == null || tool.isEmpty) return null;

      final argsMap = <String, Object?>{};
      if (map['args'] is Map) {
        argsMap.addAll((map['args'] as Map).cast<String, Object?>());
      } else if (map['args'] is List) {
        final list = (map['args'] as List).map((e) => '$e').toList();
        argsMap['arguments'] = list;
        argsMap['args'] = list;
      }

      // Preserva claves top-level para no descartar path, command, content,
      // cwd, timeout, etc. anunciadas en ToolDefinition (ToolRegistry).
      for (final entry in map.entries) {
        if (entry.key != 'tool' &&
            entry.key != 'args' &&
            entry.key != 'expect' &&
            !argsMap.containsKey(entry.key)) {
          argsMap[entry.key] = entry.value;
        }
      }

      final selector = (map['selector'] as String?) ?? (map['path'] as String?);
      final text = (map['text'] as String?) ??
          (map['command'] as String?) ??
          (map['path'] as String?);

      final rawTool = tool.trim();
      final canonicalTool = switch (rawTool.toLowerCase()) {
        'linux.readfile' => 'linux.readFile',
        'linux.writefile' => 'linux.writeFile',
        final other => other,
      };

      return ToolCall(
        tool: canonicalTool,
        selector: selector,
        text: text,
        key: map['key'] as String?,
        expect: map['expect'] is Map
            ? (map['expect'] as Map).cast<String, dynamic>()
            : null,
        args: argsMap.isNotEmpty ? argsMap : null,
      );
    } catch (_) {
      final rawTool = _field(trimmed, 'tool');
      if (rawTool == null) return null;
      final canonicalTool = switch (rawTool.trim().toLowerCase()) {
        'linux.readfile' => 'linux.readFile',
        'linux.writefile' => 'linux.writeFile',
        final other => other,
      };
      final command = _field(trimmed, 'command');
      final path = _field(trimmed, 'path');
      final content = _field(trimmed, 'content');
      final selector = _field(trimmed, 'selector') ?? path;
      final text = _field(trimmed, 'text') ?? command ?? path;
      final key = _field(trimmed, 'key');
      final argsMap = <String, Object?>{};
      if (command != null) argsMap['command'] = command;
      if (path != null) argsMap['path'] = path;
      if (content != null) argsMap['content'] = content;
      return ToolCall(
        tool: canonicalTool,
        selector: selector,
        text: text,
        key: key,
        args: argsMap.isNotEmpty ? argsMap : null,
      );
    }
  }

  /// Encuentra el índice del cierre balanceado de [open]/[close] a partir de
  /// [start] (que apunta al carácter abierto). -1 si no cierra.
  static int _findBalanced(String s, int start, String open, String close) {
    var depth = 0;
    for (var i = start; i < s.length; i++) {
      final c = s[i];
      if (c == open) {
        depth++;
      } else if (c == close) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// Divide el interior de un array JSON en sus objetos top-level.
  static List<String> _splitTopLevel(String inner) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < inner.length; i++) {
      final c = inner[i];
      if (c == '{') depth++;
      if (c == '}') depth--;
      if (c == ',' && depth == 0) {
        parts.add(inner.substring(start, i));
        start = i + 1;
      }
    }
    final tail = inner.substring(start).trim();
    if (tail.isNotEmpty) parts.add(tail);
    return parts;
  }

  static String? _field(String s, String key) {
    final m = RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(s);
    return m?.group(1)?.replaceAll(r'\"', '"');
  }
}
