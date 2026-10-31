part of 'conversation_detail_sheet.dart';

/// Alternancia Bot/Humano: Selector segmentado conectado al tema del sistema (< 120 líneas).
extension ConversationDetailControlBar on _ConversationDetailSheetState {
  Widget _buildControlBar(AutomationVisualPalette visual) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, isLandscape ? 3 : 6, 16, 2),
      child: Container(
        height: isLandscape ? 32 : 36,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: visual.isDark
              ? Colors.black.withValues(alpha: 0.30)
              : visual.line.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: visual.line,
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildControlOption(
                isBot: true,
                visual: visual,
                isLandscape: isLandscape,
              ),
            ),
            Expanded(
              child: _buildControlOption(
                isBot: false,
                visual: visual,
                isLandscape: isLandscape,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlOption({
    required bool isBot,
    required AutomationVisualPalette visual,
    required bool isLandscape,
  }) {
    final active = isBot ? !_isHumanOwned : _isHumanOwned;
    final icon = isBot ? CupertinoIcons.sparkles : CupertinoIcons.person_fill;
    final label = isBot ? 'IA Activa' : 'Control Humano';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _toggleOwnership(!isBot);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active
              ? (visual.isDark ? visual.cardStart : visual.surface)
              : Colors.transparent,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: visual.shadow.withValues(
                      alpha: visual.isDark ? 0.35 : 0.08,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? visual.accent : visual.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? visual.text : visual.textMuted,
                fontFamily: 'Inter',
                fontFamilyFallback: ConversationDetailSheet._sfFallback,
                fontSize: isLandscape ? 11 : 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
