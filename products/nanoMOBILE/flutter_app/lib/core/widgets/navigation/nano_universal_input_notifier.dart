part of 'nano_universal_input.dart';

class NanoUniversalInputNotifier
    extends StateNotifier<NanoUniversalInputConfig> {
  NanoUniversalInputNotifier() : super(const NanoUniversalInputConfig());

  /// Config por ámbito con `scopeId` (una por pestaña/pantalla). El frame del
  /// shell deriva la config del destino ACTIVO desde aquí: como las branches
  /// viven en un IndexedStack y no reciben señal al cambiar de pestaña, sin
  /// slots el último scope montado pisaba a los demás (p.ej. Models dejaba
  /// su búsqueda activa al ir a Chat).
  final Map<String, NanoUniversalInputConfig> _byScope = {};

  /// Config guardada para [scopeId], o la universal por defecto si no hay.
  NanoUniversalInputConfig slotFor(String scopeId) =>
      _byScope[scopeId] ?? const NanoUniversalInputConfig();

  void setConfig(NanoUniversalInputConfig config, {String? scopeId}) {
    if (scopeId != null) {
      final prev = _byScope[scopeId];
      if (prev != null && _sameData(prev, config)) {
        // NAV-UI-AUDIT-01 — mismos DATOS: refrescar closures sin disparar rebuild innecesario
        _byScope[scopeId] = config;
        return;
      }
      _byScope[scopeId] = config;
    } else {
      if (state == config) return;
    }
    // Asigna state para que Riverpod notifique a los observadores (NanoNavigationPanel)
    state = config;
  }

  /// Compara SOLO los campos de datos (nunca closures): dos configs del
  /// mismo scope con los mismos datos no requieren notificación.
  static bool _sameData(
    NanoUniversalInputConfig a,
    NanoUniversalInputConfig b,
  ) =>
      a.toolControls == b.toolControls &&
      a.toolContext == b.toolContext &&
      a.submitLabel == b.submitLabel &&
      a.hint == b.hint &&
      a.initialText == b.initialText &&
      a.isGenerating == b.isGenerating &&
      a.isListening == b.isListening &&
      a.clearOnSubmit == b.clearOnSubmit &&
      a.keepFocusOnSubmit == b.keepFocusOnSubmit &&
      a.keepDockVisible == b.keepDockVisible &&
      identical(a.controller, b.controller) &&
      identical(a.focusNode, b.focusNode);

  /// Olvida el slot del ámbito desmontado (ya no informa a la barra).
  void removeScope(String scopeId, {NanoUniversalInputConfig? expected}) {
    // Un ámbito antiguo no puede borrar la entrada de otra pantalla con el mismo id.
    if (expected != null && !identical(_byScope[scopeId], expected)) return;
    final removed = _byScope.remove(scopeId);
    if (identical(state, removed)) reset();
  }

  /// True si [config] sigue siendo la config global activa (para que el
  /// dispose de un scope sin id no pise una config más reciente).
  bool isActive(NanoUniversalInputConfig config) => state == config;

  void reset() {
    const fresh = NanoUniversalInputConfig();
    if (state == fresh) return;
    state = fresh;
  }
}

/// Provider global que expone la configuración activa para la barra cósmica.
final nanoUniversalInputProvider =
    StateNotifierProvider<NanoUniversalInputNotifier, NanoUniversalInputConfig>(
      (ref) => NanoUniversalInputNotifier(),
    );
