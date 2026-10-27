part of 'nano_universal_input.dart';

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

  final Widget child;

  /// Identificador del ámbito (p.ej. 'chat', 'models'). Con id, la config se
  /// guarda en un slot propio y el frame del shell muestra la del destino
  /// activo; sin id, comportamiento global (pantallas empujadas).
  final String? scopeId;
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
  final bool isListening;
  final VoidCallback? onStop;
  final bool clearOnSubmit;
  final bool keepFocusOnSubmit;
  final bool keepDockVisible;
  final FocusNode? focusNode;
  final TextEditingController? controller;

  @override
  ConsumerState<NanoInputScope> createState() => _NanoInputScopeState();
}
