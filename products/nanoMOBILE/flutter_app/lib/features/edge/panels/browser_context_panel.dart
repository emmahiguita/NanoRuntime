/// EDGE-03 — Panel de navegador: aplica a los navegadores comunes. Muestra
/// lo visible de la página actual (título derivado de los primeros textos).
/// Puro: solo [NanoEdgeState].
library;

import '../nano_edge_state.dart';
import 'context_panel.dart';

/// Paquetes de navegadores conocidos. Const local: una familia de apps es
/// un detalle de ESTE panel, no del dominio de mensajería.
const _browserPackages = <String>{
  'com.android.chrome',
  'com.chrome.beta',
  'com.chrome.dev',
  'com.brave.browser',
  'org.mozilla.firefox',
  'com.opera.browser',
  'com.microsoft.emmx',
};

final class BrowserContextPanel implements ContextPanel {
  const BrowserContextPanel();

  @override
  String get id => 'browser';

  @override
  bool matches(String packageName) => _browserPackages.contains(packageName);

  @override
  NanoEdgeContent contentFor(NanoEdgeState state) {
    final summary = state.snapshot?.screenGraphSummary;
    final texts = summary?.visibleTexts ?? const <String>[];
    return NanoEdgeContent(
      title: 'Navegador',
      body: texts.isEmpty
          ? 'Página sin texto visible observado.'
          : texts.join(' · '),
    );
  }
}
