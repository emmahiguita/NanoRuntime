part of 'conversation_detail_sheet.dart';

/// Vista de chips de opciones de respuesta generadas por el modelo local.
///
/// - **QUÉ HACE:** Muestra las 2 o 3 opciones naturales propuestas por Nano
///   para que el usuario elija cuál colocar en el compositor antes de enviar.
/// - **CÓMO FUNCIONA:** Renderiza un `Wrap` adaptable (Material 3 Expressive)
///   donde cada `ActionChip` incluye un adelanto legible de la respuesta.
/// - **POR QUÉ:** Permite distinguir visualmente cada opción de un vistazo,
///   tanto en modo vertical como en modo horizontal compacto.
extension ConversationDetailSuggestionsView on _ConversationDetailSheetState {
  /// Construye la barra de sugerencias adaptable a orientación vertical/horizontal.
  Widget _buildSuggestionActions(
    AutomationVisualPalette visual, {
    required bool isLandscape,
  }) {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: isLandscape ? 4 : 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var index = 0; index < _suggestions.length; index++)
            _buildSuggestionChip(visual, index, isLandscape: isLandscape),
          IconButton(
            tooltip: 'Cerrar sugerencias',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              HapticFeedback.lightImpact();
              _safeSetState(() => _suggestions = const []);
            },
            icon: Icon(CupertinoIcons.xmark, size: 17, color: visual.textMuted),
          ),
        ],
      ),
    );
  }

  /// Construye un chip Material 3 Expressive con vista previa de la opción.
  Widget _buildSuggestionChip(
    AutomationVisualPalette visual,
    int index, {
    required bool isLandscape,
  }) {
    final text = _suggestions[index].trim();
    final selected = _inputController.text.trim() == text;
    final maxPreviewChars = isLandscape ? 28 : 36;
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ');
    final preview = singleLine.length <= maxPreviewChars
        ? singleLine
        : '${singleLine.substring(0, maxPreviewChars - 1)}…';

    return ActionChip(
      visualDensity: isLandscape
          ? VisualDensity.compact
          : VisualDensity.standard,
      avatar: Icon(
        selected ? Icons.check_circle_rounded : CupertinoIcons.sparkles,
        size: 14,
        color: selected ? const Color(0xFF38BDF8) : visual.textMuted,
      ),
      label: Text(
        'Opción ${index + 1} · $preview',
        semanticsLabel: 'Opción ${index + 1}: $text',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: ConversationDetailSheet._sfFallback,
          fontSize: isLandscape ? 12 : 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? (visual.isDark ? Colors.white : const Color(0xFF0F172A))
              : visual.text,
        ),
      ),
      backgroundColor: selected
          ? (visual.isDark
                ? const Color(0xFF334155).withValues(alpha: 0.90)
                : const Color(0xFFE0F2FE))
          : (visual.isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.58)
                : Colors.white.withValues(alpha: 0.85)),
      side: BorderSide(
        color: selected
            ? const Color(0xFF38BDF8).withValues(alpha: 0.75)
            : (visual.isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFCBD5E1)),
        width: selected ? 1.2 : 0.9,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: () {
        HapticFeedback.selectionClick();
        _safeSetState(() => _inputController.text = text);
      },
    );
  }
}
