// nano_nav_search_panel.dart — Estado y lógica del buscador desplegable.
// QUÉ HACE: Conecta texto, voz, adjuntos y envío con el slot activo.
// CÓMO FUNCIONA: Reutiliza controladores inyectados y cancela la voz al salir.
// POR QUÉ: Mantiene el dock visual pequeño y separa su lógica de entrada.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/nano_runtime_api.dart';
import 'nano_nav_search_input_row.dart';
import 'nano_search_dispatcher.dart';
import 'nano_universal_input.dart';

class NanoNavSearchPanel extends StatefulWidget {
  const NanoNavSearchPanel({
    super.key,
    required this.brightness,
    required this.compact,
    this.inputConfig,
    this.onSearch,
    this.onVoice,
    this.searchHint = NanoUniversalInputConfig.defaultHint,
  });

  final NanoUniversalInputConfig? inputConfig;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;
  final String searchHint;
  final Brightness brightness;
  final bool compact;

  @override
  State<NanoNavSearchPanel> createState() => _NanoNavSearchPanelState();
}

class _NanoNavSearchPanelState extends State<NanoNavSearchPanel> {
  final _internalController = TextEditingController();
  final _internalFocusNode = FocusNode();
  StreamSubscription<String>? _voiceSubscription;
  bool _hasText = false;
  bool _dictating = false;

  TextEditingController get _controller =>
      widget.inputConfig?.controller ?? _internalController;
  FocusNode get _focusNode =>
      widget.inputConfig?.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _applyInitialText();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant NanoNavSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController =
        oldWidget.inputConfig?.controller ?? _internalController;
    if (!identical(oldController, _controller)) {
      oldController.removeListener(_onTextChanged);
      _controller.addListener(_onTextChanged);
    }
    final next = widget.inputConfig?.initialText;
    if (next != null && next != oldWidget.inputConfig?.initialText) {
      _controller.text = next;
      _controller.selection = TextSelection.collapsed(offset: next.length);
    }
    _hasText = _controller.text.trim().isNotEmpty;
  }

  // Sincroniza el texto inicial sin crear un segundo controlador.
  void _applyInitialText() {
    final initial = widget.inputConfig?.initialText;
    if (initial != null) _controller.text = initial;
    _hasText = _controller.text.trim().isNotEmpty;
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) setState(() => _hasText = hasText);
    widget.inputConfig?.onChanged?.call(_controller.text);
  }

  // Envía al slot activo y respeta sus reglas de limpieza y foco.
  void _submit(String raw) {
    final text = raw.trim();
    if (text.isEmpty || widget.inputConfig?.isGenerating == true) return;
    final handler = widget.inputConfig?.onSubmit ?? widget.onSearch;
    if (handler != null) {
      handler(text);
    } else {
      NanoSearchDispatcher.dispatch(context, text);
    }
    if (widget.inputConfig?.clearOnSubmit ?? true) _controller.clear();
    if (!(widget.inputConfig?.keepFocusOnSubmit ?? false)) {
      _focusNode.unfocus();
    }
  }

  Future<void> _voiceAction() async {
    final config = widget.inputConfig;
    if (config?.isListening == true && config?.onStop != null) {
      config!.onStop!();
      return;
    }
    final external = config?.onVoice ?? widget.onVoice;
    if (external != null) {
      external();
      return;
    }
    await _toggleDictation();
  }

  // La suscripción se cancela antes de iniciar otra y también en dispose.
  Future<void> _toggleDictation() async {
    if (_dictating) {
      await _stopDictation();
      return;
    }
    await _voiceSubscription?.cancel();
    if (mounted) setState(() => _dictating = true);
    _voiceSubscription = NanoRuntimeApi.instance.voicePartialStream.listen(
      (text) {
        if (!mounted || !_dictating) return;
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
      },
      onDone: () {
        if (mounted) setState(() => _dictating = false);
      },
      onError: (_) {
        if (mounted) setState(() => _dictating = false);
      },
    );
    try {
      await NanoRuntimeApi.instance.startVoiceRecognition();
    } catch (_) {
      if (mounted) setState(() => _dictating = false);
    }
  }

  Future<void> _stopDictation() async {
    await _voiceSubscription?.cancel();
    _voiceSubscription = null;
    await NanoRuntimeApi.instance.cancelVoiceRecognition();
    if (mounted) setState(() => _dictating = false);
  }

  @override
  void dispose() {
    _voiceSubscription?.cancel();
    _controller.removeListener(_onTextChanged);
    _internalController.dispose();
    _internalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NanoNavSearchInputRow(
    brightness: widget.brightness,
    controller: _controller,
    focusNode: _focusNode,
    hint: widget.inputConfig?.hint ?? widget.searchHint,
    hasText: _hasText,
    onAttach: widget.inputConfig?.onAttach,
    onSubmitted: _submit,
    onClear: _controller.clear,
    onVoice: _voiceAction,
    listening: (widget.inputConfig?.isListening ?? false) || _dictating,
    compact: widget.compact,
    processing: widget.inputConfig?.isGenerating ?? false,
    onStop: widget.inputConfig?.onStop,
  );
}
