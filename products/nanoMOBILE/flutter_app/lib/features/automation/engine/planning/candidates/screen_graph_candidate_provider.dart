/// ScreenGraphCandidateProvider (A14.8) — fuente de candidatos de UI SEMÁNTICOS.
///
/// Convierte el ScreenGraph en CandidateAction con semántica de tarea:
/// - open_conversation  (listItem/card/button que matchea el target)
/// - write_message_text (textField editable del compositor)
/// - send_message       (botón send asociado al compositor)
///
/// El objeto del ScreenGraph NO es una acción: el candidato expresa la INTENCIÓN
/// semántica. El tool subyacente sigue siendo tap/write, pero la semántica de
/// planificación es explícita. El contenido de pantalla es OBSERVACIÓN NO
/// CONFIABLE: el candidato lleva evidencia accessibility, no autoridad.
library;

import '../../perception/mux/perception_contracts.dart';
import '../../perception/mux/perception_source.dart';
import '../../perception/mux/screen_graph_query.dart';
import '../../perception/semantic/nano_ui_object.dart';
import '../../perception/semantic/screen_graph.dart';
import '../../perception/semantic/semantic_role.dart';
import '../../execution/action_verifier.dart' show ActionExpectation;
import '../../execution/platform_verification.dart' show TextFieldContains;
import '../../execution/tool_registry.dart' show ToolRisk;
import '../../system/system_capability.dart';
import 'candidate_action.dart';
import 'candidate_provider.dart';

class ScreenGraphCandidateProvider implements CandidateProvider {
  ScreenGraphCandidateProvider(this._observer);

  final ScreenObserver _observer;

  @override
  String get id => 'screenGraph';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async {
    final snapshot = await _observer.snapshot();
    if (snapshot == null || snapshot.isEmpty) return const [];

    final graph = ScreenGraph.fromSnapshot(snapshot);
    final goal = request.goal.toLowerCase();
    // Los candidatos semánticos de mensajería SOLO se generan cuando el
    // objetivo es de mensajería (responde/contesta/enviar). Para cualquier otro
    // objetivo, un textField o un botón "Enviar" NO es un compositor de mensaje.
    final isMessaging = _messagingVerbs.any(goal.contains);
    // Target de continuación grounded (sender de la notificación) tiene
    // prioridad sobre el texto del goal (A14.8, sección 12).
    final target = (request.continuationTarget ?? _targetFromGoal(goal))
        .toLowerCase();

    final candidates = <CandidateAction>[];

    // Objetos ya cubiertos por un candidato semántico: el tap genérico no debe
    // duplicarlos (el candidato semántico es más fuerte, sección 20).
    final covered = <String>{};

    if (isMessaging) {
      // 1. open_conversation: objeto conversacional (listItem/card/button) cuyo
      //    label/text matchea el target del objetivo (ej. "responde a Juan").
      if (target.isNotEmpty) {
        for (final obj in graph.objects) {
          if (!_isConversationObject(obj)) continue;
          final score = _matchScore(obj, target);
          if (score <= 0.3) continue;
          candidates.add(_openConversation(obj, target, score));
          covered.add(obj.id);
        }
      }

      // 2. write_message_text / focus_message_input: campo de texto editable del
      //    compositor (NO searchField/passwordField).
      for (final obj in graph.objects) {
        if (!obj.visible || !obj.editable) continue;
        if (obj.role != SemanticRole.textField) continue;
        candidates.add(_writeMessageText(obj, request.draftText));
        candidates.add(_focusMessageInput(obj));
      }

      // 3. send_message: botón de envío asociado al compositor.
      for (final obj in graph.objects) {
        if (!obj.visible) continue;
        if (!_isSendControl(obj)) continue;
        candidates.add(_sendMessage(obj, target));
        covered.add(obj.id);
      }
    }

    // 4. fallback genérico (compat A15.5): tap por matching del goal, salvo
    //    objetos ya cubiertos por un candidato semántico.
    final genericMatches = const ScreenGraphQuery().query(
      graph,
      PerceptionRequest(targetConcept: request.goal),
    );
    for (final m in genericMatches) {
      if (covered.contains(m.object.id)) continue;
      candidates.add(_genericTap(m));
    }

    return candidates;
  }

  static const _messagingVerbs = [
    'responde',
    'responder',
    'contesta',
    'contestar',
    'enviar',
    'envia',
    'envía',
    'reply',
  ];

  /// Extrae el target de conversación del objetivo ("responde a Juan" → "juan").
  String _targetFromGoal(String goal) {
    const verbs = [
      'responde a',
      'responder a',
      'contesta a',
      'contestar a',
      'responde',
      'responder',
      'contesta',
      'contestar',
      'reply to',
      'reply',
    ];
    final g = goal.toLowerCase();
    for (final v in verbs) {
      final i = g.indexOf(v);
      if (i >= 0) {
        return g
            .substring(i + v.length)
            .trim()
            .replaceAll(RegExp(r'[?!.,]'), '');
      }
    }
    return '';
  }

  bool _isConversationObject(NanoUiObject obj) =>
      obj.role == SemanticRole.listItem ||
      obj.role == SemanticRole.card ||
      obj.role == SemanticRole.button;

  bool _isSendControl(NanoUiObject obj) {
    if (obj.role != SemanticRole.button &&
        obj.role != SemanticRole.iconButton) {
      return false;
    }
    final hay = '${obj.label} ${obj.text} ${obj.description}'.toLowerCase();
    return hay.contains('send') ||
        hay.contains('enviar') ||
        hay.contains('enviar mensaje') ||
        hay.contains('send message');
  }

  double _matchScore(NanoUiObject obj, String target) {
    final needle = target.toLowerCase();
    final label = obj.label.toLowerCase();
    final text = obj.text.toLowerCase();
    final desc = obj.description.toLowerCase();
    if (label.isNotEmpty && label == needle) return 0.98;
    if (text.isNotEmpty && text == needle) return 0.95;
    if (desc.isNotEmpty && desc == needle) return 0.92;
    if (label.isNotEmpty && label.contains(needle)) return 0.75;
    if (text.isNotEmpty && text.contains(needle)) return 0.70;
    if (desc.isNotEmpty && desc.contains(needle)) return 0.70;
    return 0.0;
  }

  String _selectorFor(NanoUiObject obj) {
    if (obj.text.isNotEmpty) return 'text=${obj.text}';
    if (obj.description.isNotEmpty) return 'desc=${obj.description}';
    if (obj.resourceId.isNotEmpty) return 'id=${obj.resourceId}';
    return 'id=${obj.id}';
  }

  CandidateAction _openConversation(
    NanoUiObject obj,
    String target,
    double score,
  ) => CandidateAction(
    id: CandidateId('ui:conversation:${obj.id}:$target'),
    semanticAction: 'open_conversation',
    tool: 'tap',
    args: {'selector': _selectorFor(obj), 'conversation': target},
    channel: ActionChannel.accessibility,
    groundingConfidence: score,
    risk: ToolRisk.device,
    reversible: true,
    requiredCapabilities: const {SystemCapability.interactAccessibility},
    evidence: [
      ActionEvidence(
        source: ActionEvidenceSource.accessibility,
        reference: obj.id,
        confidence: score,
      ),
    ],
    expectation: const ActionExpectation(mustChangeSnapshot: true),
  );

  CandidateAction _writeMessageText(NanoUiObject obj, String? draft) =>
      CandidateAction(
        id: CandidateId('ui:message_input:${obj.id}'),
        semanticAction: 'write_message_text',
        tool: 'write',
        args: {
          'selector': _selectorFor(obj),
          if (draft != null && draft.isNotEmpty) 'text': draft,
        },
        channel: ActionChannel.accessibility,
        groundingConfidence: 0.8,
        risk: ToolRisk.device,
        reversible: true,
        requiredCapabilities: const {SystemCapability.interactAccessibility},
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.accessibility,
            reference: obj.id,
            confidence: 0.8,
          ),
        ],
        // Postcondición real del write: el campo contiene el borrador esperado
        // (A14.8, sección 7). Sin draft no se asume éxito de contenido.
        expectation: (draft != null && draft.isNotEmpty)
            ? ActionExpectation(platformPredicates: [TextFieldContains(draft)])
            : null,
      );

  CandidateAction _focusMessageInput(NanoUiObject obj) => CandidateAction(
    id: CandidateId('ui:focus_input:${obj.id}'),
    semanticAction: 'focus_message_input',
    tool: 'tap',
    args: {'selector': _selectorFor(obj)},
    channel: ActionChannel.accessibility,
    groundingConfidence: 0.8,
    risk: ToolRisk.device,
    reversible: true,
    requiredCapabilities: const {SystemCapability.interactAccessibility},
    evidence: [
      ActionEvidence(
        source: ActionEvidenceSource.accessibility,
        reference: obj.id,
        confidence: 0.8,
      ),
    ],
  );

  CandidateAction _sendMessage(NanoUiObject obj, String target) =>
      CandidateAction(
        id: CandidateId('ui:send:${obj.id}:$target'),
        semanticAction: 'send_message',
        tool: 'tap',
        args: {'selector': _selectorFor(obj), 'conversation': target},
        channel: ActionChannel.accessibility,
        groundingConfidence: 0.7,
        risk: ToolRisk.externalWrite,
        reversible: false,
        requiredCapabilities: const {SystemCapability.interactAccessibility},
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.accessibility,
            reference: obj.id,
            confidence: 0.7,
          ),
        ],
      );

  CandidateAction _genericTap(ScreenGraphMatch m) => CandidateAction(
    id: CandidateId('ui:${m.object.id}'),
    semanticAction: 'tap_${m.object.role.name}',
    tool: 'tap',
    args: {'selector': _selectorFor(m.object)},
    channel: ActionChannel.accessibility,
    groundingConfidence: m.confidence,
    risk: ToolRisk.device,
    reversible: true,
    requiredCapabilities: const {SystemCapability.interactAccessibility},
    evidence: [
      ActionEvidence(
        source: ActionEvidenceSource.accessibility,
        reference: m.object.id,
        confidence: m.confidence,
      ),
    ],
  );
}
