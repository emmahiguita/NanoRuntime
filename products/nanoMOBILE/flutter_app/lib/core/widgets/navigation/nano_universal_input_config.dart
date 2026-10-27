part of 'nano_universal_input.dart';

@immutable
class NanoUniversalInputConfig {
  const NanoUniversalInputConfig({
    this.hint,
    this.toolContext,
    this.toolControls,
    this.submitLabel = 'Enviar',
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
    this.keepDockVisible = false,
    this.focusNode,
    this.controller,
  });

  final String? hint;
  final NanoInputToolContext? toolContext;
  final NanoInputToolControls? toolControls;
  final String submitLabel;
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

  /// Mantiene la barra expandida en horizontal cuando escribir es la acción
  /// principal. El usuario todavía puede contraerla con el control manual.
  final bool keepDockVisible;

  /// FocusNode y controller únicos inyectados por el scope (Terminal, etc.)
  /// para garantizar una única fuente de verdad y foco directo.
  final FocusNode? focusNode;
  final TextEditingController? controller;

  static const defaultHint = 'Buscar, conversar o ejecutar en Nano AI...';

  NanoUniversalInputConfig copyWith({
    String? hint,
    NanoInputToolContext? toolContext,
    NanoInputToolControls? toolControls,
    bool clearToolContext = false,
    String? submitLabel,
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
    bool? keepDockVisible,
    FocusNode? focusNode,
    TextEditingController? controller,
  }) {
    return NanoUniversalInputConfig(
      hint: hint ?? this.hint,
      toolControls: toolControls ?? this.toolControls,
      toolContext: clearToolContext ? null : toolContext ?? this.toolContext,
      submitLabel: submitLabel ?? this.submitLabel,
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
      keepDockVisible: keepDockVisible ?? this.keepDockVisible,
      focusNode: focusNode ?? this.focusNode,
      controller: controller ?? this.controller,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NanoUniversalInputConfig &&
          runtimeType == other.runtimeType &&
          hint == other.hint &&
          toolContext == other.toolContext &&
          toolControls == other.toolControls &&
          submitLabel == other.submitLabel &&
          initialText == other.initialText &&
          onSubmit == other.onSubmit &&
          onChanged == other.onChanged &&
          onVoice == other.onVoice &&
          onAttach == other.onAttach &&
          isGenerating == other.isGenerating &&
          isListening == other.isListening &&
          onStop == other.onStop &&
          clearOnSubmit == other.clearOnSubmit &&
          keepFocusOnSubmit == other.keepFocusOnSubmit &&
          keepDockVisible == other.keepDockVisible &&
          focusNode == other.focusNode &&
          controller == other.controller;

  @override
  int get hashCode => Object.hash(
    hint,
    toolContext,
    toolControls,
    submitLabel,
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
    keepDockVisible,
    focusNode,
    controller,
  );
}
