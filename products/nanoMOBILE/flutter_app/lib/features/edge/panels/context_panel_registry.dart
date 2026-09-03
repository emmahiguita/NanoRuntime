/// EDGE-03 — ContextPanelRegistry: resolución por paquete, extensible y
/// const. El orden de la lista ES la prioridad; el genérico siempre al
/// final (matchea todo, nunca opaca a un panel específico).
library;

import 'context_panel.dart';
import 'generic_context_panel.dart';
import 'messaging_context_panel.dart';
import 'browser_context_panel.dart';
import 'system_context_panel.dart';

/// Registro por defecto de paneles (EDGE-03). Para añadir una familia de
/// apps: nueva implementación de [ContextPanel] + un elemento aquí. Nada
/// más cambia (OCP).
const ContextPanelRegistry defaultContextPanelRegistry =
    ContextPanelRegistry([
  MessagingContextPanel(),
  SystemContextPanel(),
  BrowserContextPanel(),
  GenericContextPanel(),
]);

/// Resuelve QUÉ panel aplica para una app en foreground.
final class ContextPanelRegistry {
  const ContextPanelRegistry(this.panels);

  /// Orden = prioridad; el genérico SIEMPRE al final.
  final List<ContextPanel> panels;

  /// Primer panel cuyo [ContextPanel.matches] acepta [packageName]; si
  /// ninguno (imposible con el genérico, pero por contrato) → [GenericContextPanel].
  ContextPanel resolve(String packageName) {
    for (final panel in panels) {
      if (panel.matches(packageName)) return panel;
    }
    return const GenericContextPanel();
  }
}
