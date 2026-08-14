/// AgentToolDispatcher — herramientas de UI para el chat.
///
/// Dos vías de entrada, una sola ejecución segura ([NanoAgentExecutor]):
///
/// 1. Comandos `@` deterministas escritos por el usuario (sin LLM, funcionan
///    con el motor degradado): `@tap text=Bluetooth`, `@pantalla`, `@back`.
/// 2. Tool-calling del LLM: el modelo responde un JSON de una línea
///    `{"tool":"tap","selector":"..."}` y [AgentToolProtocol] lo extrae del
///    texto generado con parseo tolerante (los GGUF 1B-7B no tienen
///    function calling fiable: puede añadir texto alrededor del JSON).
///
/// Invariante: todo fallo degrada a texto legible en español — jamás lanza.
library;

import 'dart:convert';

import '../services/nano_runtime_api.dart';
import 'agent_executor.dart';
import 'nano_selector.dart';

/// Llamada a herramienta extraída de una respuesta del LLM.
class ToolCall {
  final String tool;
  final String? selector;
  final String? text;
  const ToolCall({required this.tool, this.selector, this.text});
}

/// Parseo tolerante del bloque JSON de herramientas en texto generado.
abstract final class AgentToolProtocol {
  /// Localiza y decodifica el primer objeto JSON con clave "tool".
  ///
  /// Tolerancia: el modelo puede rodear el JSON de markdown o prosa. Se
  /// localiza el `{` inicial por regex, se recorta hasta el `}` balanceado y
  /// se intenta `jsonDecode`; si falla, se extraen los campos por regex.
  /// Devuelve null si no hay llamada reconocible (respuesta normal de texto).
  static ToolCall? extractToolCall(String text) {
    final startMatch = RegExp(r'\{[^{}\n]*"tool"\s*:').firstMatch(text);
    if (startMatch == null) return null;
    final start = startMatch.start;
    var depth = 0;
    var end = -1;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    final candidate =
        end >= 0 ? text.substring(start, end + 1) : text.substring(start);
    try {
      final map = jsonDecodeTolerant(candidate);
      final tool = map['tool'] as String?;
      if (tool == null || tool.isEmpty) return null;
      return ToolCall(
        tool: tool.trim().toLowerCase(),
        selector: map['selector'] as String?,
        text: map['text'] as String?,
      );
    } catch (_) {
      // Fallback por regex campo a campo.
      final tool = _field(candidate, 'tool');
      if (tool == null) return null;
      return ToolCall(
        tool: tool.toLowerCase(),
        selector: _field(candidate, 'selector'),
        text: _field(candidate, 'text'),
      );
    }
  }

  static Map<String, dynamic> jsonDecodeTolerant(String s) =>
      (jsonDecode(s) as Map).cast<String, dynamic>();

  static String? _field(String s, String key) {
    final m = RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(s);
    return m?.group(1)?.replaceAll(r'\"', '"');
  }
}

/// Ejecutor de comandos `@` y de [ToolCall] del LLM.
class AgentToolDispatcher {
  AgentToolDispatcher({NanoAgentExecutor? executor})
      : _executor = executor ?? NanoAgentExecutor();

  final NanoAgentExecutor _executor;

  /// True si [text] es un comando de herramienta del usuario (`@comando`).
  /// `@@` escapa: permite enviar texto literal que empiece con @.
  static bool isToolCommand(String text) {
    final t = text.trim();
    return t.startsWith('@') && !t.startsWith('@@');
  }

  // ── Comandos @ ────────────────────────────────────────────────────────────

  /// Ejecuta un comando `@` del usuario y devuelve el feedback para el chat.
  Future<String> runCommand(String command) async {
    final t = command.trim();
    if (t.startsWith('@@')) return t.substring(1);

    final space = t.indexOf(RegExp(r'\s'));
    final verb = (space < 0 ? t : t.substring(0, space)).substring(1);
    final rest = space < 0 ? '' : t.substring(space + 1).trim();

    switch (verb) {
      case 'pantalla':
      case 'screen':
        return _describeScreen();
      case 'resolver':
      case 'resolve':
        return _resolve(rest);
      case 'tap':
      case 'tocar':
        return _tap(rest);
      case 'escribir':
      case 'write':
        return _write(rest);
      case 'back':
      case 'atras':
      case 'atrás':
        return _back();
      default:
        return '❌ Comando desconocido "@$verb". Disponibles: @pantalla, '
            '@resolver <selector>, @tap <selector>, '
            '@escribir <texto> | <selector>, @back.';
    }
  }

  // ── Tool-calling LLM ──────────────────────────────────────────────────────

  /// Ejecuta un [ToolCall] del LLM. [tool] desconocida degrada a error
  /// legible que el modelo puede usar para corregirse.
  Future<String> runTool(ToolCall call) async {
    switch (call.tool) {
      case 'screen':
        return _describeScreen();
      case 'tap':
        if (call.selector == null || call.selector!.isEmpty) {
          return '❌ [tool] tap requiere "selector".';
        }
        return _tap(call.selector!);
      case 'write':
        if (call.selector == null || call.selector!.isEmpty) {
          return '❌ [tool] write requiere "selector".';
        }
        return _write('${call.text ?? ''} | ${call.selector}');
      case 'back':
        return _back();
      default:
        return '❌ [tool] Herramienta desconocida "${call.tool}". Disponibles: '
            'screen, tap, write, back.';
    }
  }

  // ── Implementaciones ──────────────────────────────────────────────────────

  Future<String> _describeScreen() async {
    final snap = await _executor.snapshot();
    if (snap == null) {
      return '❌ [serviceOff] Accesibilidad apagada o canal sin respuesta.';
    }
    if (snap.isEmpty) {
      return '❌ [snapshotEmpty] Sin ventana activa (rebind en curso).';
    }
    final visible = snap.visibleNodes;
    final top = visible.take(10).map((n) => '${n.depth} ${n.label} '
        '@(${n.bounds.centerX.round()},${n.bounds.centerY.round()})');
    return '✅ Pantalla "${snap.package}" · ${snap.nodes.length} nodos '
        '(${visible.length} visibles). Top visibles:\n${top.join('\n')}';
  }

  Future<String> _resolve(String expr) async {
    final (selector, err) = _tryParse(expr);
    if (selector == null) return err!;
    final outcome = await _executor.resolve(selector);
    if (!outcome.isResolved) {
      return '❌ [${outcome.status.name}] ${outcome.reason}';
    }
    final top = outcome.candidates.take(5).map(
          (e) =>
              '• "${e.node.label}" — ${e.score} pts [${e.matchedCriteria.join(',')}]',
        );
    return '✅ Resuelto: "${outcome.best!.node.label}" '
        '(${outcome.best!.score} pts).\n${top.join('\n')}';
  }

  Future<String> _tap(String expr) async {
    final (selector, err) = _tryParse(expr);
    if (selector == null) return err!;
    final r = await _executor.tap(selector);
    if (!r.ok) return '❌ [${r.errorCode!.name}] ${r.reason}';
    final b = r.targetNode!.bounds;
    return '✅ tap en "${r.targetNode!.label}" '
        '@(${b.centerX.round()},${b.centerY.round()})';
  }

  Future<String> _write(String rest) async {
    // Sintaxis: `texto | selector` (el texto puede contener espacios).
    final sep = rest.lastIndexOf(' | ');
    if (sep < 0) {
      return '❌ [tool] Sintaxis: @escribir <texto> | <selector>. '
          'Ej: @escribir wifi | editable=true';
    }
    final text = rest.substring(0, sep).trim();
    final expr = rest.substring(sep + 3).trim();
    if (text.isEmpty) return '❌ [tool] Texto vacío en @escribir.';
    final (selector, err) = _tryParse(expr);
    if (selector == null) return err!;
    final r = await _executor.setText(selector, text);
    if (!r.ok) return '❌ [${r.errorCode!.name}] ${r.reason}';
    return '✅ "$text" escrito en "${r.targetNode!.label}"';
  }

  Future<String> _back() async {
    final ok = await NanoRuntimeApi.instance.agentGlobalAction('back');
    return ok ? '✅ Botón atrás ejecutado.' : '❌ [gestureFailed] Back falló.';
  }

  /// Parseo con error legible: (selector, null) o (null, motivo).
  (NanoSelector?, String?) _tryParse(String expr) {
    try {
      return (NanoSelector.parse(expr), null);
    } on SelectorFormatException catch (e) {
      return (null, '❌ Selector inválido "$expr": ${e.message}');
    }
  }
}
