import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'nano_ambient_background.dart';

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
  });

  final String title;
  final Widget body;
  final Widget? trailing;
  final bool hideHeaderInPortrait;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final showHeader = isLandscape || !hideHeaderInPortrait;

    return Stack(
      children: [
        const Positioned.fill(child: NanoAmbientBackground()),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: isLandscape
                    ? const EdgeInsets.fromLTRB(16, 6, 16, 6)
                    : const EdgeInsets.fromLTRB(18, 8, 18, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Título limpio de la pantalla sin redundancia de marca
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.textPrimary,
                        fontSize: isLandscape ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (trailing != null) ...[
                      const Spacer(),
                      trailing!,
                    ],
                  ],
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ],
    );
  }
}
