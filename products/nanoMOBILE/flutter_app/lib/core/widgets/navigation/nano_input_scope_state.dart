part of 'nano_universal_input.dart';

class _NanoInputScopeState extends ConsumerState<NanoInputScope> {
  /// Config que este scope aplicó por última vez. Sirve para no pisar en
  /// dispose una config que otro scope más reciente dejó activa.
  NanoUniversalInputConfig? _applied;

  /// Notifier capturado en initState: `ref` NO es usable dentro de dispose()
  /// con Flutter 3.24+ (el elemento se marca defunct ANTES de state.dispose();
  /// flutter_riverpod 2.5.1 lanza "Cannot use ref after the widget was
  /// disposed"). Ese error durante unmount dejaba el árbol sin desmontar —
  /// renders huérfanos + pantalla gris tras navegar desde Automatización.
  late final NanoUniversalInputNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(nanoUniversalInputProvider.notifier);
  }

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
    // Un slot identificado se registra aunque haya una transición de ruta activa.
    // El frame elige el destino visible; no dependemos del foco global de ModalRoute.
    if (widget.scopeId != null || (route != null && route.isCurrent)) {
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
    if (oldWidget.toolControls != widget.toolControls ||
        oldWidget.toolContext != widget.toolContext ||
        oldWidget.submitLabel != widget.submitLabel ||
        oldWidget.hint != widget.hint ||
        oldWidget.initialText != widget.initialText ||
        oldWidget.isGenerating != widget.isGenerating ||
        oldWidget.isListening != widget.isListening ||
        oldWidget.clearOnSubmit != widget.clearOnSubmit ||
        oldWidget.keepFocusOnSubmit != widget.keepFocusOnSubmit ||
        oldWidget.keepDockVisible != widget.keepDockVisible ||
        oldWidget.focusNode != widget.focusNode ||
        oldWidget.controller != widget.controller) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyConfig());
    }
  }

  void _applyConfig() {
    if (!mounted) return;
    final config = NanoUniversalInputConfig(
      hint: widget.hint,
      toolContext: widget.toolContext,
      toolControls: widget.toolControls,
      submitLabel: widget.submitLabel,
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
      keepDockVisible: widget.keepDockVisible,
      focusNode: widget.focusNode,
      controller: widget.controller,
    );
    _applied = config;
    ref
        .read(nanoUniversalInputProvider.notifier)
        .setConfig(config, scopeId: widget.scopeId);
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
    // NF-01: usar el notifier capturado, nunca ref (disposed).
    final notifier = _notifier;
    if (scopeId != null) {
      // Los scopes con id liberan solo su slot: el frame deriva la
      // config del destino activo y no hay nada global que resetear.
      notifier.removeScope(scopeId, expected: applied);
    } else if (applied == null || notifier.isActive(applied)) {
      notifier.reset();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
