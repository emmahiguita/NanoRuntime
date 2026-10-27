part of 'conversation_detail_sheet.dart';

/// Alternancia Bot/Humano: conserva la lógica de propiedad del chat.
extension ConversationDetailControlBar on _ConversationDetailSheetState {
  Widget _buildControlBar(AutomationVisualPalette visual) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isLandscape ? 4 : 8,
      ),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: visual.isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: visual.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.85),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: visual.isDark ? 0.20 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
          const SizedBox(width: 4),
          Expanded(
            child: _buildControlOption(
              isBot: false,
              visual: visual,
              isLandscape: isLandscape,
            ),
          ),
        ],
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
    final label = isBot ? 'IA Activa (Bot)' : 'Control Humano';

    final borderGradient = active
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: visual.isDark
                ? [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                    const Color(0xFF38BDF8).withValues(alpha: 0.55),
                    const Color(0xFF818CF8).withValues(alpha: 0.40),
                    const Color(0xFFFFFFFF).withValues(alpha: 0.20),
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFF38BDF8).withValues(alpha: 0.70),
                    const Color(0xFF94A3B8),
                  ],
          )
        : null;

    final bgGradient = active
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: visual.isDark
                ? [
                    const Color(0xFF334155).withValues(alpha: 0.80),
                    const Color(0xFF1E293B).withValues(alpha: 0.90),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.95),
                    const Color(0xFFF1F5F9).withValues(alpha: 0.90),
                  ],
          )
        : null;

    final activeColor = visual.isDark
        ? const Color(0xFF38BDF8)
        : const Color(0xFF0284C7);

    return GestureDetector(
      onTap: () => _toggleOwnership(!isBot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: borderGradient,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(
                      0xFF38BDF8,
                    ).withValues(alpha: visual.isDark ? 0.20 : 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 1.5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: visual.isDark ? 0.25 : 0.04,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.all(active ? 1.2 : 0),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isLandscape ? 6 : 7.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: bgGradient,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? activeColor : visual.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? (visual.isDark ? Colors.white : const Color(0xFF0F172A))
                      : visual.textMuted,
                  fontFamily: 'Inter',
                  fontFamilyFallback: ConversationDetailSheet._sfFallback,
                  fontSize: isLandscape ? 11.5 : 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
