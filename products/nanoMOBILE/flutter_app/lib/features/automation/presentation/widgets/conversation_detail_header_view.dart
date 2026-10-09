part of 'conversation_detail_sheet.dart';

/// [ConversationDetailHeaderView] — Cabecera de chat y alternancia Bot/Humano (< 200 líneas).
extension ConversationDetailHeaderView on _ConversationDetailSheetState {
  Widget _buildHeader(AutomationVisualPalette visual) {
    final title = _cleanName(widget.item.displayName);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.fromLTRB(16, isLandscape ? 6 : 10, 16, isLandscape ? 6 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(bottom: BorderSide(color: visual.isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0x33CBD5E1))),
      ),
      child: Row(
        children: [
          Container(
            width: isLandscape ? 36 : 44,
            height: isLandscape ? 36 : 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [visual.accent, visual.accent.withValues(alpha: 0.65)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            ),
            child: widget.item.isGroup
                ? Icon(Icons.groups_rounded, color: Colors.white, size: isLandscape ? 18 : 22)
                : Text(title.isNotEmpty ? title[0].toUpperCase() : '?', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontFamilyFallback: ConversationDetailSheet._sfFallback, fontWeight: FontWeight.w700, fontSize: isLandscape ? 15 : 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(color: visual.text, fontFamily: 'Inter', fontFamilyFallback: ConversationDetailSheet._sfFallback, fontSize: isLandscape ? 15 : 17, fontWeight: FontWeight.w600, letterSpacing: -0.4),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.item.isGroup) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(color: const Color(0xFF60A5FA).withValues(alpha: 0.20), borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.45), width: 0.6)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.groups_rounded, size: 10, color: Color(0xFF93C5FD)), SizedBox(width: 3), Text('GRUPO', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 8.5, fontWeight: FontWeight.w700))]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${widget.item.appLabel}${widget.item.isGroup ? " · Grupo" : ""} · ${_agentId.displayName}',
                        style: TextStyle(color: visual.textMuted, fontFamily: 'Inter', fontFamilyFallback: ConversationDetailSheet._sfFallback, fontSize: isLandscape ? 11 : 12, letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Asignar a otro agente',
            button: true,
            child: IconButton(
              icon: Icon(Icons.swap_horiz_rounded, color: visual.text, size: isLandscape ? 18 : 20),
              onPressed: _busy ? null : () => _showTransferAgentPicker(context, visual),
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: visual.textMuted.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8)),
              child: Icon(CupertinoIcons.xmark, size: isLandscape ? 14 : 16, color: visual.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(AutomationVisualPalette visual) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 4 : 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: visual.isDark ? const Color(0xFF1E293B).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: visual.isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.85),
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
          Expanded(child: _buildControlOption(isBot: true, visual: visual, isLandscape: isLandscape)),
          const SizedBox(width: 4),
          Expanded(child: _buildControlOption(isBot: false, visual: visual, isLandscape: isLandscape)),
        ],
      ),
    );
  }

  Widget _buildControlOption({required bool isBot, required AutomationVisualPalette visual, required bool isLandscape}) {
    final active = isBot ? !_isHumanOwned : _isHumanOwned;
    final icon = isBot ? CupertinoIcons.sparkles : CupertinoIcons.person_fill;
    final label = isBot ? 'IA Activa (Bot)' : 'Control Humano';

    final borderGradient = active
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: visual.isDark
                ? [const Color(0xFFFFFFFF).withValues(alpha: 0.85), const Color(0xFF38BDF8).withValues(alpha: 0.55), const Color(0xFF818CF8).withValues(alpha: 0.40), const Color(0xFFFFFFFF).withValues(alpha: 0.20)]
                : [const Color(0xFFFFFFFF), const Color(0xFF38BDF8).withValues(alpha: 0.70), const Color(0xFF94A3B8)],
          )
        : null;

    final bgGradient = active
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: visual.isDark
                ? [const Color(0xFF334155).withValues(alpha: 0.80), const Color(0xFF1E293B).withValues(alpha: 0.90)]
                : [Colors.white.withValues(alpha: 0.95), const Color(0xFFF1F5F9).withValues(alpha: 0.90)],
          )
        : null;

    final activeColor = visual.isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

    return GestureDetector(
      onTap: () => _toggleOwnership(!isBot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: borderGradient,
          boxShadow: active
              ? [
                  BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: visual.isDark ? 0.20 : 0.12), blurRadius: 8, offset: const Offset(0, 1.5)),
                  BoxShadow(color: Colors.black.withValues(alpha: visual.isDark ? 0.25 : 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                ]
              : null,
        ),
        padding: EdgeInsets.all(active ? 1.2 : 0),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isLandscape ? 6 : 7.5),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: bgGradient),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? activeColor : visual.textMuted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active ? (visual.isDark ? Colors.white : const Color(0xFF0F172A)) : visual.textMuted,
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
