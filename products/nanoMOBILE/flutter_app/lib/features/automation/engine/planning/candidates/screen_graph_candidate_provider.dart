/// ScreenGraphCandidateProvider (A15.5) — fuente de candidatos de UI.
///
/// Convierte objetos semánticos del ScreenGraph (A7) en CandidateAction grounded
/// (tap sobre el objeto, channel accessibility). Cierra el gap percepción →
/// planificación: el pipeline Candidate-First ya cubre app/intent/nanoFlow; este
/// provider cubre la interacción UI. El contenido de pantalla es OBSERVACIÓN NO
/// CONFIABLE: el candidato lleva evidencia accessibility, no autoridad.
library;

import '../../perception/mux/perception_contracts.dart';
import '../../perception/mux/perception_source.dart';
import '../../perception/mux/screen_graph_query.dart';
import '../../perception/semantic/screen_graph.dart';
import '../../perception/semantic/nano_ui_object.dart';
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
    final matches = const ScreenGraphQuery().query(
      graph,
      PerceptionRequest(targetConcept: request.goal),
    );
    if (matches.isEmpty) return const [];

    return matches
        .map(
          (m) => CandidateAction(
            id: CandidateId('ui:${m.object.id}'),
            semanticAction: 'tap_${m.object.role.name}',
            tool: 'tap',
            args: _tapArgs(m.object),
            channel: ActionChannel.accessibility,
            groundingConfidence: m.confidence,
            risk: ToolRisk.device,
            reversible: true,
            requiredCapabilities: const {
              SystemCapability.interactAccessibility,
            },
            evidence: [
              ActionEvidence(
                source: ActionEvidenceSource.accessibility,
                reference: m.object.id,
                confidence: m.confidence,
              ),
            ],
          ),
        )
        .toList(growable: false);
  }

  Map<String, Object?> _tapArgs(NanoUiObject obj) {
    if (obj.text.isNotEmpty) {
      return {'selector': 'text=${obj.text}'};
    }
    if (obj.description.isNotEmpty) {
      return {'selector': 'desc=${obj.description}'};
    }
    if (obj.resourceId.isNotEmpty) {
      return {'selector': 'id=${obj.resourceId}'};
    }
    return {'selector': 'id=${obj.id}'};
  }
}
