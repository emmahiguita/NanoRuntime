import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Shell compartido de las pantallas secundarias (Chat, Modelos, Settings, etc.).
///
/// Refleja la estética de alta gama sin redundancias: fondo ambiental cristalino,
/// tipografía nítida para el título de la sección y composición fluida.
class NanoScreenShell extends StatelessWidget {
  const NanoScreenShell({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.hideHeaderInPortrait = false,
    this.hideHeader = false,
    this.showBack,
  });

  final String title;
  final Widget body;
  final Widget? trailing;
  final bool hideHeaderInPortrait;
  final bool hideHeader;

  /// Muestra botón de retroceso. Por defecto (null): automático — visible
  /// solo si hay una ruta a la que volver (`Navigator.canPop`). Las rutas
  /// top-level empujadas (p.ej. /automation, /terminal/shell) lo muestran;
  /// las pestañas del shell no (el back del sistema cambia de pestaña).
  final bool? showBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final screenSize = MediaQuery.sizeOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompactLandscape = isLandscape && screenSize.height < 520;

    final showHeader = !hideHeader && (isLandscape || !hideHeaderInPortrait);
    final back = showBack ?? Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: isCompactLandscape
                  ? const EdgeInsets.fromLTRB(12, 4, 12, 4)
                  : isLandscape
                  ? const EdgeInsets.fromLTRB(16, 6, 16, 6)
                  : const EdgeInsets.fromLTRB(18, 8, 18, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (back) ...[
                    IconButton(
                      tooltip: 'Atrás',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        size: isCompactLandscape ? 18 : 20,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  // Título limpio de la pantalla sin redundancia de marca
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.textPrimary,
                        fontSize: isCompactLandscape
                            ? 15
                            : (isLandscape ? 16 : 18),
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: trailing!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
