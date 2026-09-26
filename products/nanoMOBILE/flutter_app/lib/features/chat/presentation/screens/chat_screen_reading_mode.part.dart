part of 'chat_screen.dart';

// ================================================================
// Modo lectura real e inmersivo
// ================================================================

/// Modo lectura REAL: superficie serena de bajo deslumbramiento, columna
/// centrada legible (720px), tipografía amplia (17px/1.75), barra de progreso
/// y salida elegante. Abandona el chrome del chat para enfocarse en el
/// contenido — no es un simple ocultar barra.
class _ReadingMode extends StatefulWidget {
  const _ReadingMode({
    required this.messages,
    required this.model,
    required this.onExit,
  });

  final List<ChatMessage> messages;
  final String model;
  final VoidCallback onExit;

  @override
  State<_ReadingMode> createState() => _ReadingModeState();
}

class _ReadingModeState extends State<_ReadingMode> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final surface = Stack(
      children: [
        // UI-REV-07: vidrio sutil de lectura — antes el gradiente claro iba
        // al 40/72% de blanco y tapaba el fondo vivo del shell. Ahora asoma
        // el ambient sin sacrificar la legibilidad del texto centrado.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        colors.glass100.withValues(alpha: 0.08),
                        colors.surface.withValues(alpha: 0.72),
                        colors.glass300.withValues(alpha: 0.10),
                      ]
                    : [
                        colors.surface.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0.30),
                        colors.surface.withValues(alpha: 0.18),
                      ],
              ),
            ),
          ),
        ),
        // Contenido centrado legible (foco en el texto, no en las burbujas)
        Positioned.fill(
          child: Center(
            child: ConstrainedBox(
              // 680 dp mantiene 65—œ75 caracteres por línea en texto de 18dp,
              // rango editorial que reduce los saltos oculares en lectura.
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView.builder(
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                // NAV-FLOAT-01 — reserva propia bajo la barra flotante.
                padding: const EdgeInsets.fromLTRB(
                  28,
                  56,
                  28,
                  kNanoBarScrollReserve,
                ),
                itemCount: widget.messages.length,
                itemBuilder: (context, i) => _ReadingParagraph(
                  message: widget.messages[i],
                  model: widget.model,
                ),
              ),
            ),
          ),
        ),
        // Barra de progreso de lectura (delgada, superior)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _ReadingProgress(scroll: _scroll),
        ),
        // Salida elegante: píldora de vidrio fija, siempre accesible.
        Positioned(
          top: 8,
          right: 12,
          child: _ReadingExitPill(onExit: widget.onExit),
        ),
      ],
    );

    if (reduceMotion) return surface;

    // Entrada inmersiva: fundido + escala suave al abrir el modo lectura
    // (transición glass, respeta reduce-motion).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.982 + 0.018 * t, child: child),
        );
      },
      child: surface,
    );
  }
}
