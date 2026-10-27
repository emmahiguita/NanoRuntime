part of 'nano_nav_search_panel.dart';

/// Ensambla una sola entrada; el estado conserva voz, foco y controladores.
extension _NanoNavSearchPanelView on _NanoNavSearchPanelState {
  Widget buildEditor(BuildContext context) => AnimatedSize(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    alignment: Alignment.bottomCenter,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.inputConfig?.toolContext != null ||
            widget.inputConfig?.toolControls != null)
          NanoInputContextBar(
            tool: widget.inputConfig?.toolContext,
            controls: widget.inputConfig?.toolControls,
          ),
        NanoNavSearchInputRow(
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
          toolControls: widget.inputConfig?.toolControls,
          submitLabel: widget.inputConfig?.submitLabel ?? 'Enviar',
        ),
      ],
    ),
  );
}
