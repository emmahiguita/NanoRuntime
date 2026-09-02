/// KoogCandidateSelector (A6.5) — selector de ambigüedad asistido por el LLM.
///
/// SOLO recibe candidatos ambiguos. El output del modelo es DATA: se parsea
/// estrictamente y solo un `candidateId` existente en el set se acepta. El
/// modelo NO crea acciones, NO inventa package/selector/intent/coordenadas.
/// Abstention (candidateId null) preserva la ambigüedad (no es fallo).
///
/// Koog legado (koog.dart: PlanGenerator/KoogStep/Koog.run) queda intacto para
/// sus callers (tests); este selector usa [LLMEngineClient] directamente, el
/// mismo runtime local.
library;

import 'dart:convert';

import 'package:nanoai/core/services/llm_engine_client.dart'
    show LLMEngineClient;

import 'candidate_action.dart';
import 'candidate_selection.dart';
import 'candidate_selector.dart';

class KoogCandidateSelector implements CandidateSelector {
  KoogCandidateSelector(this._client);

  final LLMEngineClient _client;

  @override
  Future<CandidateSelection> select(CandidateSelectionRequest request) async {
    final String text;
    try {
      final result = await _client.generate(
        prompt: _buildPrompt(request),
        temperature: 0.0,
        maxTokens: 32,
      );
      text = result.text;
    } on Object {
      // El motor local no está disponible (no cargado, apagado o falló):
      // el LLM es OPCIONAL por diseño. La ambigüedad se preserva para
      // clarificación humana; NUNCA se lanza al llamador.
      return AmbiguousCandidates(
        request.candidates.items,
        'LLM no disponible para desambiguar; la ambigüedad queda sin resolver.',
      );
    }
    return _interpret(request, text);
  }

  CandidateSelection _interpret(
    CandidateSelectionRequest request,
    String text,
  ) {
    final parsed = _parseOutput(text);
    if (parsed.malformed) {
      return const InvalidCandidateSelection(
        'Salida del modelo no interpretable.',
      );
    }
    if (parsed.abstain) {
      return AmbiguousCandidates(
        request.candidates.items,
        'Koog se abstuvo de resolver la ambigüedad.',
      );
    }
    final candidate = request.candidates.byId(CandidateId(parsed.id!));
    if (candidate == null) {
      return InvalidCandidateSelection('CandidateId desconocido: ${parsed.id}');
    }
    return SelectedCandidate(candidate);
  }

  /// Parseo estricto: solo `{"candidateId": "<id>"}` o `{"candidateId": null}`.
  /// Un JSON sin `candidateId` (p. ej. un ToolCall o un selector) es malformed.
  ({String? id, bool abstain, bool malformed}) _parseOutput(String text) {
    try {
      final decoded = jsonDecode(text.trim());
      if (decoded is! Map) {
        return (id: null, abstain: false, malformed: true);
      }
      if (!decoded.containsKey('candidateId')) {
        return (id: null, abstain: false, malformed: true);
      }
      final value = decoded['candidateId'];
      if (value == null) return (id: null, abstain: true, malformed: false);
      if (value is! String) {
        return (id: null, abstain: false, malformed: true);
      }
      return (id: value, abstain: false, malformed: false);
    } catch (_) {
      return (id: null, abstain: false, malformed: true);
    }
  }

  String _buildPrompt(CandidateSelectionRequest request) {
    final lines = request.candidates.items
        .map((c) {
          final evidence = c.evidence.map((e) => e.source.name).join(', ');
          return '- id: ${c.id.value} | acción: ${c.semanticAction} '
              '| evidencia: $evidence';
        })
        .join('\n');
    return 'Selecciona UNA acción EXISTENTE para el objetivo: '
        '"${request.goal}".\n'
        'Solo puedes devolver un candidateId de esta lista (cópialo exacto) '
        'o abstenerte.\n'
        'NO inventes actions, tools, packages, selectors, intents ni '
        'coordenadas.\n'
        '$lines\n'
        'Responde SOLO con JSON: {"candidateId":"<id>"} o '
        '{"candidateId":null}.';
  }
}
