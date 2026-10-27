import 'dart:convert';
import 'tool_call.dart';
import 'tool_registry.dart';
import 'agent_json_payload.dart';

/// Lee llamadas completas del modelo; nunca fabrica campos de JSON truncado.
abstract final class AgentToolProtocol {
  static Map<String, dynamic> jsonDecodeTolerant(String source) =>
      (jsonDecode(source) as Map).cast<String, dynamic>();

  static ToolCall? extractToolCall(String text) {
    final calls = extractToolCalls(text);
    return calls.length == 1 ? calls.single : null;
  }

  /// Conserva contenido literal (código, llaves y escapes) y orden de un array.
  static List<ToolCall> extractToolCalls(String text) {
    final payload = AgentJsonPayload.extract(text);
    if (payload == null) return const [];
    try {
      final decoded = jsonDecode(payload);
      final values = decoded is List ? decoded : [decoded];
      final calls = <ToolCall>[];
      for (final value in values) {
        final call = _parseToolObject(value);
        // Un plan parcialmente malformado no ejecuta solo su parte válida.
        if (call == null) return const [];
        calls.add(call);
      }
      return calls;
    } on Object {
      return const [];
    }
  }

  static ToolCall? _parseToolObject(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final rawTool = value['tool'];
    if (rawTool is! String || rawTool.trim().isEmpty) return null;
    final args = <String, Object?>{};
    final rawArgs = value['args'];
    if (rawArgs is Map<String, dynamic>) {
      args.addAll(rawArgs);
    } else if (rawArgs is List) {
      args['arguments'] = rawArgs;
      args['args'] = rawArgs;
    } else if (rawArgs != null) {
      return null;
    }
    for (final entry in value.entries) {
      if (!const {'tool', 'args', 'expect'}.contains(entry.key)) {
        args.putIfAbsent(entry.key, () => entry.value);
      }
    }
    String? text(String key) =>
        value[key] is String ? value[key] as String : null;
    return ToolCall(
      tool: ToolRegistry.builtin.canonicalName(rawTool),
      selector: text('selector') ?? text('path'),
      text: text('text') ?? text('command') ?? text('path'),
      key: text('key'),
      expect: value['expect'] is Map<String, dynamic>
          ? value['expect'] as Map<String, dynamic>
          : null,
      args: args.isEmpty ? null : args,
    );
  }
}
