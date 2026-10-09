part of 'conversation_detail_sheet.dart';

/// [ConversationDetailSuggestionsView] — Carrusel horizontal de sugerencias inteligentes IA (< 120 líneas).
extension ConversationDetailSuggestionsView on _ConversationDetailSheetState {
  Widget _buildSuggestionActions(
    AutomationVisualPalette visual, {
    required bool isLandscape,
  }) {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) =>
                    _buildSuggestionChip(visual, index),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Botón para cerrar sugerencias
          Semantics(
            label: 'Cerrar sugerencias',
            button: true,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _safeSetState(() => _suggestions = const []);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: visual.isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.50)
                      : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 13,
                  color: visual.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(AutomationVisualPalette visual, int index) {
    final text = _suggestions[index];
    final selected = _inputController.text.trim() == text.trim();

    return ActionChip(
      avatar: Icon(
        selected ? Icons.check_circle_rounded : CupertinoIcons.sparkles,
        size: 13,
        color: selected ? const Color(0xFF38BDF8) : visual.textMuted,
      ),
      label: Text(
        'Opción ${index + 1}: $text',
        style: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: ConversationDetailSheet._sfFallback,
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? (visual.isDark ? Colors.white : const Color(0xFF0F172A))
              : visual.text,
        ),
      ),
      backgroundColor: selected
          ? (visual.isDark
              ? const Color(0xFF334155).withValues(alpha: 0.85)
              : const Color(0xFFE0F2FE))
          : (visual.isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.50)
              : Colors.white.withValues(alpha: 0.80)),
      side: BorderSide(
        color: selected
            ? const Color(0xFF38BDF8).withValues(alpha: 0.70)
            : (visual.isDark
                ? Colors.white.withValues(alpha: 0.14)
                : const Color(0xFFCBD5E1)),
        width: selected ? 1.2 : 0.9,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: () {
        HapticFeedback.selectionClick();
        _safeSetState(() => _inputController.text = text);
      },
    );
  }
}
