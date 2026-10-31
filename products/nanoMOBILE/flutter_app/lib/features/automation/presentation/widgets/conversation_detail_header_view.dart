part of 'conversation_detail_sheet.dart';

/// [ConversationDetailHeaderView] — Cabecera de conversación conectada al tema del sistema (< 180 líneas).
extension ConversationDetailHeaderView on _ConversationDetailSheetState {
  Widget _buildHeader(AutomationVisualPalette visual) {
    final title = _cleanName(widget.item.displayName);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        isLandscape ? 6 : 10,
        14,
        isLandscape ? 6 : 11,
      ),
      decoration: BoxDecoration(
        color: visual.surface.withValues(alpha: visual.isDark ? 0.35 : 0.60),
        border: Border(
          bottom: BorderSide(
            color: visual.line,
            width: 0.7,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar circular con presencia de estado
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: isLandscape ? 36 : 42,
                height: isLandscape ? 36 : 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      visual.accent,
                      visual.accent.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: visual.accent.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: widget.item.isGroup
                    ? Icon(
                        Icons.groups_rounded,
                        color: visual.onAccent,
                        size: isLandscape ? 18 : 20,
                      )
                    : Text(
                        title.isNotEmpty ? title[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: visual.onAccent,
                          fontFamily: 'Inter',
                          fontFamilyFallback:
                              ConversationDetailSheet._sfFallback,
                          fontWeight: FontWeight.w700,
                          fontSize: isLandscape ? 15 : 17,
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: visual.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: visual.surface,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 11),
          // Nombre de contacto e indicador de plataforma
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
                        style: TextStyle(
                          color: visual.text,
                          fontFamily: 'Inter',
                          fontFamilyFallback:
                              ConversationDetailSheet._sfFallback,
                          fontSize: isLandscape ? 15 : 16.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.35,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.item.isGroup) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: visual.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'GRUPO',
                          style: TextStyle(
                            color: visual.accent,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1.5),
                Text(
                  '${_hasWebSource ? (_preferWebHistory ? "WhatsApp Web" : "WhatsApp") : widget.item.appLabel} · ${_agentId.displayName}',
                  style: TextStyle(
                    color: visual.textMuted,
                    fontFamily: 'Inter',
                    fontFamilyFallback: ConversationDetailSheet._sfFallback,
                    fontSize: isLandscape ? 11 : 12,
                    letterSpacing: -0.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Botón de reasignación sutil
          IconButton(
            tooltip: 'Asignar a otro agente',
            icon: Icon(
              Icons.swap_horiz_rounded,
              color: visual.textMuted,
              size: isLandscape ? 19 : 21,
            ),
            onPressed: _busy
                ? null
                : () => _showTransferAgentPicker(context, visual),
          ),
          // Botón de cierre iOS circular
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: visual.textMuted.withValues(
                  alpha: visual.isDark ? 0.18 : 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 15,
                  color: visual.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
