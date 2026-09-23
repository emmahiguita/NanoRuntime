part of 'conversation_detail_sheet.dart';

/// Opciones de respuesta separadas del compositor para mantener la vista breve.
extension ConversationDetailSuggestionsView on _ConversationDetailSheetState {
  Widget _buildSuggestionActions(
    AutomationVisualPalette visual, {
    required bool isLandscape,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isLandscape)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _generateAiSuggestion,
              icon: const Icon(CupertinoIcons.sparkles, size: 13),
              label: const Text(
                'Sugerir con IA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
                side: BorderSide(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.45),
                ),
                backgroundColor: const Color(
                  0xFF007AFF,
                ).withValues(alpha: 0.10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
            ),
          ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) =>
                  _buildSuggestionChip(visual, index),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestionChip(AutomationVisualPalette visual, int index) {
    final text = _suggestions[index];
    final selected = _inputController.text.trim() == text.trim();
    final label = text.length > 24 ? '${text.substring(0, 24)}...' : text;
    return ActionChip(
      avatar: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.chat_bubble_outline_rounded,
        size: 12,
        color: selected ? const Color(0xFF007AFF) : visual.textMuted,
      ),
      label: Text(
        'Opción ${index + 1}: $label',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? const Color(0xFF007AFF) : visual.text,
        ),
      ),
      backgroundColor: selected
          ? const Color(0xFF007AFF).withValues(alpha: 0.14)
          : (visual.isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.04)),
      side: BorderSide(
        color: selected
            ? const Color(0xFF007AFF).withValues(alpha: 0.50)
            : (visual.isDark ? Colors.white12 : Colors.black12),
      ),
      onPressed: () => _safeSetState(() => _inputController.text = text),
    );
  }
}
