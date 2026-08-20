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

import 'package:flutter/foundation.dart';

import '../services/nano_runtime_api.dart';
import 'action_verifier.dart';
import 'agent_executor.dart';
import 'agent_loop.dart';
import 'nano_selector.dart';
import 'nano_snapshot.dart' as nano_snapshot;
import 'tool_registry.dart';

/// Llamada a herramienta extraída de una respuesta del LLM.
class ToolCall {
  final String tool;
  final String? selector;
  final String? text;
  final String? key;

  /// Postcondiciones declaradas por el llamador (LLM o comando @):
  /// `{package, appear, disappear, text, forbidden}` — ver [ActionVerifier].
  final Map<String, dynamic>? expect;
  const ToolCall({
    required this.tool,
    this.selector,
    this.text,
    this.key,
    this.expect,
  });
}

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
    try {
      final map = jsonDecodeTolerant(candidate);
      final tool = map['tool'] as String?;
      if (tool == null || tool.isEmpty) return null;
      return ToolCall(
        tool: tool.trim().toLowerCase(),
        selector: map['selector'] as String?,
        text: map['text'] as String?,
        key: map['key'] as String?,
        expect: map['expect'] is Map
            ? (map['expect'] as Map).cast<String, dynamic>()
            : null,
      );
    } catch (_) {
      // Fallback por regex campo a campo.
      final tool = _field(candidate, 'tool');
      if (tool == null) return null;
      return ToolCall(
        tool: tool.toLowerCase(),
        selector: _field(candidate, 'selector'),
        text: _field(candidate, 'text'),
        key: _field(candidate, 'key'),
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

/// Resultado tipado de [AgentToolDispatcher.runToolGuarded]: el veredicto
/// de la política y el feedback legible para el chat/trace. Si
/// [needsConfirmation], [pendingCall] guarda la llamada a re-ejecutar con
/// `confirmed: true` cuando el usuario apruebe.
class ToolOutcome {
  const ToolOutcome({
    required this.verdict,
    required this.feedback,
    this.pendingCall,
  });

  final PolicyVerdict verdict;
  final String feedback;
  final ToolCall? pendingCall;

  bool get needsConfirmation => verdict == PolicyVerdict.needsConfirmation;
}

/// Ejecutor de comandos `@` y de [ToolCall] del LLM.
///
/// Gobernanza (§12): toda ejecución pasa por [PolicyEngine] — herramienta
/// fuera del registro, presupuesto agotado o escritura externa sin
/// confirmación NO se ejecutan. Los comandos `@` (autoría humana) llevan
/// confirmación implícita; el tool-calling del LLM (agencia autónoma) no.
class AgentToolDispatcher {
  AgentToolDispatcher({
    NanoAgentExecutor? executor,
    ToolRegistry? registry,
    PolicyEngine? policy,
    ActionVerifier? verifier,
  }) : _executor = executor ?? NanoAgentExecutor(),
       _policy = policy ?? PolicyEngine(registry: registry),
       _verifier = verifier;

  final NanoAgentExecutor _executor;
  final PolicyEngine _policy;
  ActionVerifier? _verifier;

  /// Verificador de postcondiciones (lazy: comparte el snapshot del
  /// executor). null en tests que no verifican.
  ActionVerifier get verifier =>
      _verifier ??= ActionVerifier(snapshotFn: _executor.snapshot);

  /// Loop de ejecución orquestado (lazy): reutiliza el executor + verifier
  /// existentes — añade retry transitorio + verificación entre intentos a
  /// las acciones de ACT (tap/write) con postcondición. Es la lógica real
  /// inyectada (AgentLoop), no un dispatch single-attempt.
  AgentLoop? _loop;

  AgentLoop get loop => _loop ??= AgentLoop(executor: _executor, verifier: verifier);

  /// Pasos ejecutados en el turno actual (lo incrementa cada ejecución real).
  /// El chat lo resetea con [resetTurn] en cada envío del usuario.
  int _stepsUsed = 0;

  int get stepsUsed => _stepsUsed;

  void resetTurn() => _stepsUsed = 0;

  /// True si [text] es un comando de herramienta del usuario (`@comando`).
  /// `@@` escapa: permite enviar texto literal que empiece con @.
  static bool isToolCommand(String text) {
    final t = text.trim();
    return t.startsWith('@') && !t.startsWith('@@');
  }

  // ── Comandos @ ────────────────────────────────────────────────────────────

  /// Ejecuta un comando `@` del usuario y devuelve el feedback para el chat.
  /// Autoría humana: pasa por la política con [humanInitiated] — una
  /// escritura externa escrita a mano por el usuario NO pide confirmación.
  Future<String> runCommand(String command) async {
    final t = command.trim();
    if (t.startsWith('@@')) return t.substring(1);

    // Cada comando `@` es un turno propio: presupuesto fresco. El chat ya
    // resetea en send(); esto cubre cualquier llamador directo.
    resetTurn();

    final space = t.indexOf(RegExp(r'\s'));
    final verb = (space < 0 ? t : t.substring(0, space)).substring(1);
    final rest = space < 0 ? '' : t.substring(space + 1).trim();

    final ToolCall? call;
    switch (verb) {
      case 'pantalla':
      case 'screen':
        call = const ToolCall(tool: 'screen');
      case 'resolver':
      case 'resolve':
        call = ToolCall(tool: 'resolve', selector: rest);
      case 'tap':
      case 'tocar':
        call = ToolCall(tool: 'tap', selector: rest);
      case 'escribir':
      case 'write':
        // Sintaxis: `texto | selector` (el texto puede contener espacios).
        final sep = rest.lastIndexOf(' | ');
        if (sep < 0) {
          return 'Sintaxis: @escribir <texto> | <selector>. Ej: @escribir wifi | editable=true';
        }
        call = ToolCall(
          tool: 'write',
          text: rest.substring(0, sep).trim(),
          selector: rest.substring(sep + 3).trim(),
        );
      case 'back':
      case 'atras':
      case 'atrás':
        call = const ToolCall(tool: 'back');
      case 'notificaciones':
      case 'notifications':
        call = const ToolCall(tool: 'notifications');
      default:
        return 'Comando desconocido "@$verb". Disponibles: @pantalla, @resolver <selector>, @tap <selector>, @escribir <texto> | <selector>, @notificaciones, @back.';
    }
    return (await runToolGuarded(call, humanInitiated: true)).feedback;
  }

  // ── Tool-calling LLM ──────────────────────────────────────────────────────

  /// Ejecuta un [ToolCall] del LLM bajo política. Sin [confirmed] ni autoría
  /// humana, una escritura externa devuelve needsConfirmation SIN ejecutarse
  /// (el chat muestra el diálogo y re-llama con confirmed: true).
  Future<ToolOutcome> runToolGuarded(
    ToolCall call, {
    bool humanInitiated = false,
    bool confirmed = false,
  }) async {
    final decision = _policy.decide(
      call.tool,
      stepsUsed: _stepsUsed,
      humanInitiated: humanInitiated,
      confirmed: confirmed,
    );
    if (decision.denied) {
      // Herramienta fuera del registro: el modelo ve la lista completa y
      // puede autocorregirse en la siguiente ronda.
      var feedback = '[policy] ${decision.reason}.';
      if (decision.tool == null) {
        final names = _policy.registry.all.map((t) => t.name).join(', ');
        feedback += ' Disponibles: $names.';
      }
      return ToolOutcome(verdict: PolicyVerdict.denied, feedback: feedback);
    }
    if (decision.needsConfirmation) {
      final tool = decision.tool!;
      return ToolOutcome(
        verdict: PolicyVerdict.needsConfirmation,
        pendingCall: call,
        feedback:
            '[policy] "${tool.name}" (${tool.description.toLowerCase()}) — requiere tu confirmación.',
      );
    }
    return ToolOutcome(
      verdict: PolicyVerdict.allow,
      feedback: await _executeWithTimeout(call, decision.tool!),
    );
  }

  /// Compatibilidad: ejecuta bajo política y degrada el estado de
  /// confirmación a texto (llamadores que no manejan el diálogo).
  /// Invocación standalone = turno propio (presupuesto fresco).
  Future<String> runTool(ToolCall call) async {
    resetTurn();
    final outcome = await runToolGuarded(call);
    return outcome.feedback;
  }

  /// Ejecución real con timeout del registro. Un tool colgado nunca congela
  /// el turno: degrada a feedback legible y el modelo puede corregirse.
  Future<String> _executeWithTimeout(ToolCall call, ToolDefinition tool) async {
    _stepsUsed++;
    debugPrint(
      '[agent-policy] tool=${tool.name} risk=${tool.risk.name} '
      'steps=$_stepsUsed timeout=${tool.timeout.inMilliseconds}ms',
    );
    try {
      return await _executeTool(call).timeout(
        tool.timeout,
        onTimeout: () =>
            '[timeout] "${tool.name}" excedió ${tool.timeout.inSeconds}s — acción cancelada.',
      );
    } catch (e) {
      return '[error] "${tool.name}" falló: $e';
    }
  }

  /// Ejecución de la herramienta (sin política — la puerta es [_policy]).
  Future<String> _executeTool(ToolCall call) async {
    switch (call.tool) {
      case 'screen':
        return _describeScreen();
      case 'resolve':
        if (call.selector == null || call.selector!.isEmpty) {
          return '[tool] resolve requiere "selector".';
        }
        return _resolve(call.selector!);
      case 'tap':
        if (call.selector == null || call.selector!.isEmpty) {
          return '[tool] tap requiere "selector".';
        }
        return _tap(call);
      case 'write':
        if (call.selector == null || call.selector!.isEmpty) {
          return '[tool] write requiere "selector".';
        }
        return _write(call);
      case 'back':
        return _back(call);
      case 'notifications':
        return _notifications();
      case 'reply_notification':
        final key = call.key?.trim() ?? '';
        final text = call.text?.trim() ?? '';
        if (key.isEmpty) {
          return '[tool] reply_notification requiere "key".';
        }
        if (text.isEmpty) {
          return '[tool] reply_notification requiere "text".';
        }
        return _replyNotification(key: key, text: text);
      default:
        return '[tool] Herramienta desconocida "${call.tool}".';
    }
  }

  // ── Implementaciones ──────────────────────────────────────────────────────

  Future<String> _describeScreen() async {
    final snap = await _executor.snapshot();
    if (snap == null) {
      return '[serviceOff] Accesibilidad apagada o canal sin respuesta.';
    }
    if (snap.isEmpty) {
      return '[snapshotEmpty] Sin ventana activa (rebind en curso).';
    }
    final visible = snap.visibleNodes;
    final top = visible
        .take(10)
        .map(
          (n) =>
              '${n.depth} ${n.label} '
              '@(${n.bounds.centerX.round()},${n.bounds.centerY.round()})',
        );
    return 'Pantalla "${snap.package}" · ${snap.nodes.length} nodos '
        '(${visible.length} visibles). Top visibles:\n${top.join('\n')}';
  }

  Future<String> _resolve(String expr) async {
    final (selector, err) = _tryParse(expr);
    if (selector == null) return err!;
    final outcome = await _executor.resolve(selector);
    if (!outcome.isResolved) {
      return '[${outcome.status.name}] ${outcome.reason}';
    }
    final top = outcome.candidates
        .take(5)
        .map(
          (e) =>
              '• "${e.node.label}" — ${e.score} pts [${e.matchedCriteria.join(',')}]',
        );
    return 'Resuelto: "${outcome.best!.node.label}" '
        '(${outcome.best!.score} pts).\n${top.join('\n')}';
  }

  Future<String> _tap(ToolCall call) async {
    final (selector, err) = _tryParse(call.selector!);
    if (selector == null) return err!;
    // Postcondición por defecto: la pantalla debe cambiar (un tap que no
    // cambia nada es sospechoso aunque el gesto devuelva true).
    final expectation = _expectationFor(call).copyWith(
      mustChangeSnapshot: true,
    );
    // AgentLoop orquestado: ejecuta + verifica. maxAttempts=1 para un tap:
    // reintentar un gesto podría ser doble-tap (la verificación se reporta).
    final result = await loop.run([
      AgentStep(
        id: 'tap(${call.selector})',
        selector: selector,
        action: AgentAction.tap,
        expectation: expectation,
        maxAttempts: 1,
      ),
    ]);
    final sr = result.steps.first;
    if (!sr.execution.ok) {
      return '[${sr.execution.errorCode!.name}] ${sr.execution.reason}';
    }
    final b = sr.execution.targetNode!.bounds;
    final base =
        'tap en "${sr.execution.targetNode!.label}" '
        '@(${b.centerX.round()},${b.centerY.round()})';
    if (result.completed) return base;
    return '$base [verify:${sr.verification?.status.name}] '
        '${sr.verification?.reason}';
  }

  Future<String> _write(ToolCall call) async {
    final text = (call.text ?? '').trim();
    if (text.isEmpty) {
      return 'Texto vacío en @escribir.';
    }
    final (selector, err) = _tryParse(call.selector!);
    if (selector == null) return err!;
    // AgentLoop orquestado: el texto escrito debe ser visible (verificación
    // + retry; reescribir es idempotente, maxAttempts=3 es seguro).
    final expectation = _expectationFor(call).copyWith(expectedText: text);
    final result = await loop.run([
      AgentStep(
        id: 'write(${call.selector})',
        selector: selector,
        action: AgentAction.setText,
        text: text,
        expectation: expectation,
        maxAttempts: 3,
      ),
    ]);
    final sr = result.steps.first;
    if (!sr.execution.ok) {
      return '[${sr.execution.errorCode!.name}] ${sr.execution.reason}';
    }
    final base = '"$text" escrito en "${sr.execution.targetNode!.label}"';
    if (result.completed) return base;
    return '$base [verify:${sr.verification?.status.name}] '
        '${sr.verification?.reason}';
  }

  Future<String> _back(ToolCall call) async {
    final pre = await _executor.snapshot();
    final ok = await NanoRuntimeApi.instance.agentGlobalAction('back');
    if (!ok) return '[gestureFailed] Back falló.';
    // Postcondición por defecto: la pantalla debe cambiar.
    final expectation = _expectationFor(call).copyWith(
      mustChangeSnapshot: true,
    );
    return 'Botón atrás ejecutado.'
        '${await _verifySuffix(expectation, preSnapshot: pre)}';
  }

  // ── Verificación de postcondiciones ───────────────────────────────────────

  /// Construye la expectativa declarada en `call.expect`
  /// (`{package, appear, disappear, text, forbidden}`). Selectores inválidos
  /// se ignoran con warning en el feedback — no rompen la acción.
  ActionExpectation _expectationFor(ToolCall call) {
    final e = call.expect;
    if (e == null) return const ActionExpectation();
    NanoSelector? parse(Object? raw) {
      if (raw is! String || raw.trim().isEmpty) return null;
      try {
        return NanoSelector.parse(raw);
      } on SelectorFormatException {
        return null;
      }
    }

    String? str(String key) {
      final v = e[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return ActionExpectation(
      expectedPackage: str('package'),
      mustAppear: parse(e['appear']),
      mustDisappear: parse(e['disappear']),
      expectedText: str('text'),
      forbiddenText: str('forbidden'),
    );
  }

  /// Sufijo de feedback con el resultado de la verificación. Vacío si está
  /// verificada; `[verify:<status>] motivo` si no — el éxito del gesto NO se
  /// reporta sin la postcondición.
  Future<String> _verifySuffix(
    ActionExpectation expectation, {
    nano_snapshot.NanoSnapshot? preSnapshot,
  }) async {
    if (!expectation.hasCriteria) return '';
    try {
      final out = await verifier.verify(
        expectation,
        preSnapshot: preSnapshot,
      );
      if (out.isVerified) return ' · verificado';
      return ' [verify:${out.status.name}] ${out.reason}';
    } catch (e) {
      return ' [verify:error] $e';
    }
  }

  Future<String> _notifications() async {
    final rows = await NanoRuntimeApi.instance.listActiveNotifications(
      limit: 20,
    );
    if (rows.isEmpty) {
      return '[notifications] No hay notificaciones activas o el acceso no está habilitado.';
    }

    final notifications = rows
        .map((raw) {
          final row = raw is Map ? raw : const <dynamic, dynamic>{};
          return <String, dynamic>{
            'key': '${row['key'] ?? ''}',
            'package': '${row['package'] ?? ''}',
            'title': '${row['title'] ?? ''}',
            'text': '${row['text'] ?? ''}',
            'canReply': row['canReply'] == true,
          };
        })
        .toList(growable: false);

    return '[notifications untrusted_data=true] ${jsonEncode(notifications)}';
  }

  Future<String> _replyNotification({
    required String key,
    required String text,
  }) async {
    if (text.length > 2000) {
      return '[tool] reply_notification excede 2000 caracteres.';
    }
    final result = await NanoRuntimeApi.instance.replyToNotification(
      key: key,
      text: text,
      confirmed: true,
    );
    if (result['ok'] == true) {
      return '[notificationReply] Respuesta enviada.';
    }
    final code = result['code'] ?? 'UNKNOWN';
    return '[notificationReply:$code] No se pudo enviar la respuesta.';
  }

  /// Parseo con error legible: (selector, null) o (null, motivo).
  (NanoSelector?, String?) _tryParse(String expr) {
    try {
      return (NanoSelector.parse(expr), null);
    } on SelectorFormatException catch (e) {
      return (null, 'Selector inválido "$expr": ${e.message}');
    }
  }
}
