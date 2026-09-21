part of 'conversation_detail_sheet.dart';

/// [ConversationDetailHeaderView]
///
/// QUÉ HACE:
/// Renderiza la cabecera del chat y la barra de alternancia entre Bot / Humano.
/// Se adapta a orientación horizontal (landscape) compactando paddings y alturas.
///
/// CÓMO FUNCIONA:
/// 1. `_buildHeader`: Avatar con inicial del remitente, nombre de contacto sanitizado,
///    etiqueta de la app, botón para transferir a otro bot y botón de cierre.
/// 2. `_buildControlBar`: Selector animado de dos estados ("IA Activa" vs "Control Humano").
///
/// POR QUÉ:
/// Ofrece una interfaz táctil limpia, con respuesta háptica y estética de cristal líquido
/// sin exceder el límite de 200 líneas y adaptada a cualquier orientación de pantalla.
extension ConversationDetailHeaderView on _ConversationDetailSheetState {
  Widget _buildHeader(AutomationVisualPalette visual) {
    final title = _cleanName(widget.item.displayName);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.fromLTRB(16, isLandscape ? 6 : 10, 16, isLandscape ? 6 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: visual.isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0x33CBD5E1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isLandscape ? 36 : 44,
            height: isLandscape ? 36 : 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [visual.accent, visual.accent.withValues(alpha: 0.65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontFamilyFallback: ConversationDetailSheet._sfFallback,
                fontWeight: FontWeight.w700,
                fontSize: isLandscape ? 15 : 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: visual.text,
                    fontFamily: 'Inter',
                    fontFamilyFallback: ConversationDetailSheet._sfFallback,
                    fontSize: isLandscape ? 15 : 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${widget.item.appLabel} · ${_agentId.displayName}',
                        style: TextStyle(
                          color: visual.textMuted,
                          fontFamily: 'Inter',
                          fontFamilyFallback: ConversationDetailSheet._sfFallback,
                          fontSize: isLandscape ? 11 : 12,
                          letterSpacing: -0.2,
                        ),
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
              decoration: BoxDecoration(
                color: visual.textMuted.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8),
              ),
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
        color: Colors.white.withValues(alpha: visual.isDark ? 0.07 : 0.40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: visual.isDark ? 0.16 : 0.60), width: 1.0),
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
    final color = isBot ? const Color(0xFF00FF88) : const Color(0xFF007AFF);
    final icon = isBot ? CupertinoIcons.sparkles : CupertinoIcons.person_fill;
    final label = isBot ? 'IA Activa (Bot)' : 'Control Humano';

    return GestureDetector(
      onTap: () => _toggleOwnership(!isBot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(vertical: isLandscape ? 6 : 8),
        decoration: BoxDecoration(
          gradient: active ? LinearGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.12)]) : null,
          borderRadius: BorderRadius.circular(13),
          border: active ? Border.all(color: color.withValues(alpha: 0.65), width: 1.2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: active ? color : visual.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? color : visual.textMuted,
                fontFamily: 'Inter',
                fontFamilyFallback: ConversationDetailSheet._sfFallback,
                fontSize: isLandscape ? 11.5 : 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
