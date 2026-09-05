import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef UniversalInputSubmitHandler = void Function(String text);

/// Configuración desacoplada para la barra de escritura universal de Nano AI.
///
/// Aplica el principio de Inversión de Dependencias (DIP) e Inversión de Control:
/// cada pantalla (Chat, Automatización, Terminal, etc.) puede inyectar su
/// contexto y comportamiento a la barra global única sin acoplar la barra a
/// estados o modelos concretos de cada módulo.
@immutable
class NanoUniversalInputConfig {
  const NanoUniversalInputConfig({
    this.hint,
    this.initialText,
    this.onSubmit,
    this.onChanged,
    this.onVoice,
    this.onAttach,
    this.isGenerating = false,
    this.isListening = false,
    this.onStop,
    this.clearOnSubmit = true,
    this.keepFocusOnSubmit = false,
  });

  final String? hint;
  final String? initialText;
  final UniversalInputSubmitHandler? onSubmit;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onVoice;
  final VoidCallback? onAttach;
  final bool isGenerating;

  /// NAV-BAR-FIX-05 — true mientras el micrófono escucha. La barra lo usa
  /// para pintar el orbe en estado de grabación (stop) en vez de micrófono;
  /// sin este espejo la voz funcionaba pero el botón mentía (siempre decía
  /// "mic disponible" aunque ya estuviera escuchando).
  final bool isListening;
  final VoidCallback? onStop;
  final bool clearOnSubmit;

  /// NAV-BAR-FIX-01 — si es true, enviar NO cierra el teclado. El chat lo
  /// activa: la conversación continua (escribir ↔ responder ↔ escribir) no
  /// debe obligar a reabrir el teclado en cada mensaje.
  final bool keepFocusOnSubmit;

  static const defaultHint = 'Buscar, conversar o ejecutar en Nano AI...';

  NanoUniversalInputConfig copyWith({
    String? hint,
    String? initialText,
    UniversalInputSubmitHandler? onSubmit,
    ValueChanged<String>? onChanged,
    VoidCallback? onVoice,
    VoidCallback? onAttach,
    bool? isGenerating,
    bool? isListening,
    VoidCallback? onStop,
    bool? clearOnSubmit,
    bool? keepFocusOnSubmit,
  }) {
    return NanoUniversalInputConfig(
      hint: hint ?? this.hint,
      initialText: initialText ?? this.initialText,
      onSubmit: onSubmit ?? this.onSubmit,
      onChanged: onChanged ?? this.onChanged,
      onVoice: onVoice ?? this.onVoice,
      onAttach: onAttach ?? this.onAttach,
      isGenerating: isGenerating ?? this.isGenerating,
      isListening: isListening ?? this.isListening,
      onStop: onStop ?? this.onStop,
      clearOnSubmit: clearOnSubmit ?? this.clearOnSubmit,
      keepFocusOnSubmit: keepFocusOnSubmit ?? this.keepFocusOnSubmit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NanoUniversalInputConfig &&
          runtimeType == other.runtimeType &&
          hint == other.hint &&
          initialText == other.initialText &&
          onSubmit == other.onSubmit &&
          onChanged == other.onChanged &&
          onVoice == other.onVoice &&
          onAttach == other.onAttach &&
          isGenerating == other.isGenerating &&
          isListening == other.isListening &&
          onStop == other.onStop &&
          clearOnSubmit == other.clearOnSubmit &&
          keepFocusOnSubmit == other.keepFocusOnSubmit;

  @override
  int get hashCode => Object.hash(
        hint,
        initialText,
        onSubmit,
        onChanged,
        onVoice,
        onAttach,
        isGenerating,
        isListening,
        onStop,
        clearOnSubmit,
        keepFocusOnSubmit,
      );
}

class NanoUniversalInputNotifier extends StateNotifier<NanoUniversalInputConfig> {
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
        // NAV-UI-AUDIT-01 — mismos DATOS: solo refrescar las closures en el
        // slot (apuntan a notifiers estables) SIN notificar. Antes cada
        // rebuild del chat reaplicaba la config y reconstruía la barra
        // entera por cada token de streaming.
        _byScope[scopeId] = config;
        return;
      }
      _byScope[scopeId] = config;
    } else {
      // Equality early-return: los scopes reaplican su config en cada
      // didUpdateWidget/didChangeDependencies; sin este guard cada
      // reaplicación notifica y reconstruye la barra entera sin necesidad.
      if (state == config) return;
    }
    state = config;
  }

  /// Compara SOLO los campos de datos (nunca closures): dos configs del
  /// mismo scope con los mismos datos no requieren notificación.
  static bool _sameData(
    NanoUniversalInputConfig a,
    NanoUniversalInputConfig b,
  ) =>
      a.hint == b.hint &&
      a.initialText == b.initialText &&
      a.isGenerating == b.isGenerating &&
      a.isListening == b.isListening &&
      a.clearOnSubmit == b.clearOnSubmit &&
      a.keepFocusOnSubmit == b.keepFocusOnSubmit;

  /// Olvida el slot del ámbito desmontado (ya no informa a la barra).
  void removeScope(String scopeId) {
    _byScope.remove(scopeId);
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

/// Widget que define el ámbito de entrada de la pantalla activa.
///
/// Permite que cualquier pantalla configure la barra cósmica global de forma
/// limpia y automática durante su ciclo de vida (al montarse se activa, al
/// desmontarse se restablece al estado universal de búsqueda).
class NanoInputScope extends ConsumerStatefulWidget {
  const NanoInputScope({
    super.key,
    required this.child,
    this.scopeId,
    this.hint,
    this.initialText,
    this.onSubmit,
    this.onChanged,
    this.onVoice,
    this.onAttach,
    this.isGenerating = false,
    this.isListening = false,
    this.onStop,
    this.clearOnSubmit = true,
    this.keepFocusOnSubmit = false,
  });

  final Widget child;

  /// Identificador del ámbito (p.ej. 'chat', 'models'). Con id, la config se
  /// guarda en un slot propio y el frame del shell muestra la del destino
  /// activo; sin id, comportamiento global (pantallas empujadas).
  final String? scopeId;
  final String? hint;
  final String? initialText;
  final UniversalInputSubmitHandler? onSubmit;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onVoice;
  final VoidCallback? onAttach;
  final bool isGenerating;
  final bool isListening;
  final VoidCallback? onStop;
  final bool clearOnSubmit;
  final bool keepFocusOnSubmit;

  @override
  ConsumerState<NanoInputScope> createState() => _NanoInputScopeState();
}

class _NanoInputScopeState extends ConsumerState<NanoInputScope> {
  /// Config que este scope aplicó por última vez. Sirve para no pisar en
  /// dispose una config que otro scope más reciente dejó activa.
  NanoUniversalInputConfig? _applied;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reaplica la config cuando la ruta vuelve a ser la visible (pop de una
    // pantalla empujada encima). ModalRoute.of registra la dependencia de
    // `isCurrent`; sin esto la barra conservaba la config de la pantalla
    // que se cerró hasta el siguiente rebuild casual de esta pantalla.
    // NAV-UI-AUDIT-01 — este método corre SIEMPRE tras initState antes del
    // primer build: es la ÚNICA aplicación inicial (antes initState también
    // programaba un postFrame y la config se aplicaba dos veces).
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyConfig());
    }
  }

  @override
  void didUpdateWidget(covariant NanoInputScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // NAV-UI-AUDIT-01 — comparar SOLO los campos de datos. Las closures se
    // recrean en cada build del chat (apuntan al mismo notifier estable);
    // compararlas por identidad disparaba _applyConfig → setConfig →
    // notificación → reconstrucción de la barra entera por cada token de
    // streaming. Las closures frescas se recogen en _applyConfig cuando
    // algún dato SÍ cambia.
    if (oldWidget.hint != widget.hint ||
        oldWidget.initialText != widget.initialText ||
        oldWidget.isGenerating != widget.isGenerating ||
        oldWidget.isListening != widget.isListening ||
        oldWidget.clearOnSubmit != widget.clearOnSubmit ||
        oldWidget.keepFocusOnSubmit != widget.keepFocusOnSubmit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyConfig());
    }
  }

  void _applyConfig() {
    if (!mounted) return;
    final config = NanoUniversalInputConfig(
      hint: widget.hint,
      initialText: widget.initialText,
      onSubmit: widget.onSubmit,
      onChanged: widget.onChanged,
      onVoice: widget.onVoice,
      onAttach: widget.onAttach,
      isGenerating: widget.isGenerating,
      isListening: widget.isListening,
      onStop: widget.onStop,
      clearOnSubmit: widget.clearOnSubmit,
      keepFocusOnSubmit: widget.keepFocusOnSubmit,
    );
    _applied = config;
    ref.read(nanoUniversalInputProvider.notifier).setConfig(
      config,
      scopeId: widget.scopeId,
    );
  }

  @override
  void dispose() {
    // Al desmontarse la pantalla que tomó control, se restablece limpiamente
    // SOLO si la config activa sigue siendo la que este scope aplicó. Si otra
    // pantalla la pisó después (ruta empujada encima), no la tocamos.
    // NAV-UI-AUDIT-01 — directo en dispose (ref.read es válido aquí): el
    // microtask + catch anteriores podían dejar el slot sin liberar sin
    // rastro si el contenedor ya había muerto.
    final applied = _applied;
    final scopeId = widget.scopeId;
    final notifier = ref.read(nanoUniversalInputProvider.notifier);
    if (scopeId != null) {
      // Los scopes con id liberan solo su slot: el frame deriva la
      // config del destino activo y no hay nada global que resetear.
      notifier.removeScope(scopeId);
    } else if (applied == null || notifier.isActive(applied)) {
      notifier.reset();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
