part of 'terminal_coverflow_card.dart';

/// Ficha de terminal: detail heading; conserva navegación y tema.
extension _TerminalHeading on TerminalHubDetailCard {
  Widget _portraitHeading(BuildContext context, bool isCompact) {
    final colors = NanoThemeExtension.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -------------------------------------------------------------
        // 1. VISOR 3D TURNTABLE INTERACTIVO (GAME CUBE PHYSICAL CASE)
        // -------------------------------------------------------------
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 20),
          child: Center(
            child: _MotionAwareTerminalBox(
              card: card,
              width: isCompact ? 175 : 210,
              height: isCompact ? 250 : 300,
              depth: 26,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // -------------------------------------------------------------
        // 2. TÍTULO PRINCIPAL (JERÁRQUICO CON TIPOGRAFÍA DEL SISTEMA)
        // -------------------------------------------------------------
        Text(
          card.title,
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),

        const SizedBox(height: 6),

        // -------------------------------------------------------------
        // 3. SUB-FILA: ICONO DEL MÓDULO + METADATOS
        // -------------------------------------------------------------
        Row(
          children: [
            Icon(card.icon, size: 15, color: card.accent),
            const SizedBox(width: 6),
            Text(
              '${card.eyebrow} • 2026',
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}
