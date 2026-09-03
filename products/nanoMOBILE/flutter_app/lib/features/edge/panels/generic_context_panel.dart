/// EDGE-03 — Panel genérico: aplica a cualquier app sin panel específico.
/// Muestra la app en foreground y un resumen corto de lo visible.
library;

import '../nano_edge_state.dart';
import 'context_panel.dart';

final class GenericContextPanel implements ContextPanel {
  const GenericContextPanel();

  @override
  String get id => 'generic';

  @override
  bool matches(String packageName) => true;

  @override
  NanoEdgeContent contentFor(NanoEdgeState state) {
    final snapshot = state.snapshot;
    final summary = snapshot?.screenGraphSummary;
    final package = snapshot?.foregroundPackage ?? '';
    final appLabel = package.isEmpty ? 'Pantalla actual' : package;

    final parts = <String>[
      if (summary != null && summary.visibleTexts.isNotEmpty)
        summary.visibleTexts.join(' · '),
      if (state.conversationContact != null)
        'Contacto: ${state.conversationContact}',
    ];
    return NanoEdgeContent(
      title: appLabel,
      body: parts.isEmpty
          ? 'Sin contexto observable todavía.'
          : parts.join('\n'),
    );
  }
}
