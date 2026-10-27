part of 'terminal_coverflow_card.dart';

/// Ficha de terminal: small; conserva navegación y tema.
class TerminalHubSmallCard extends StatelessWidget {
  const TerminalHubSmallCard({
    super.key,
    required this.card,
    this.compact = false,
    this.titleOpacity = 1.0,
  });

  final TerminalHubCard card;
  final bool compact;
  final double titleOpacity;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildLandscape(context);
    return _buildPortrait();
  }

  /// Layout portrait estándar — AspectRatio vertical con imagen + título abajo.
  Widget _buildPortrait() {
    return AspectRatio(
      aspectRatio: 0.66,
      child: Column(
        children: [
          Expanded(child: TerminalCover(card: card)),
          const SizedBox(height: 10),
          Opacity(
            opacity: titleOpacity.clamp(0.0, 1.0),
            child: _TitleBlock(card: card, compact: false),
          ),
        ],
      ),
    );
  }

  /// Layout landscape compacto — Row: imagen cuadrada | info a la derecha.
  Widget _buildLandscape(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: TerminalCover(card: card),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Opacity(
              opacity: titleOpacity.clamp(0.0, 1.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.eyebrow,
                    style: TextStyle(
                      color: card.accent,
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.title,
                    style: TextStyle(
                      color: NanoThemeExtension.of(context).colors.textPrimary,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.description,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.card, required this.compact});
  final TerminalHubCard card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: compact ? 18 : 22,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                card.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NanoThemeExtension.of(context).colors.textPrimary,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 14 : 16,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: compact ? 14 : 16,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                card.eyebrow,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: card.accent,
                  fontFamily: 'Inter',
                  fontSize: compact ? 10 : 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pantalla Modal transparente para la inspección 3D (360° Turntable + Información).
///
/// Reproduce con exactitud la composición del ejemplo:
/// - Fondo oscuro cinematográfico con desenfoque (`ImageFilter.blur`).
/// - Botón `...` en la esquina superior izquierda.
/// - Botón `X` en la esquina superior derecha para cerrar.
/// - Caja física 3D en el centro con perspectiva, grosor y rotación 360° interactiva.
/// - Panel inferior con título grande, badge de metadata, tags y descripción.
