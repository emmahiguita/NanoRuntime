part of 'conversation_detail_sheet.dart';

/// [ConversationDetailInputView] — Estructura inferior iOS Liquid Glass translúcida y limpia.
extension ConversationDetailInputView on _ConversationDetailSheetState {
  Widget _buildBottomActionBar(AutomationVisualPalette visual) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        isLandscape ? 3 : 5,
        12,
        isLandscape ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: visual.isDark
            ? visual.canvas.withValues(alpha: 0.40)
            : visual.surface.withValues(alpha: 0.65),
        border: Border(
          top: BorderSide(
            color: visual.line,
            width: 0.6,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSuggestionActions(visual, isLandscape: isLandscape),
          _buildComposerRow(visual, isLandscape: isLandscape),
        ],
      ),
    );
  }
}
