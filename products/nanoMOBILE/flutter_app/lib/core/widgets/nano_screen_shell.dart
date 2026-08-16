import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'nano_ambient_background.dart';

/// Shell compartido de las pantallas Chat y Modelos.
///
/// Identidad visual de la pantalla Inicio: fondo azul marino casi negro con
/// reflejos ambientales, header con marca pequeña `nanoai` + título grande,
/// sin AppBar tradicional ni menú inferior.
class NanoScreenShell extends StatelessWidget {
  const NanoScreenShell({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
  });

  final String title;
  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    // Header adaptativo: en landscape el título grande (40px) roba el alto
    // que las listas/grids necesitan — se compacta a la mitad.
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: NanoAmbientBackground()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: isLandscape
                      ? const EdgeInsets.fromLTRB(18, 6, 18, 8)
                      : const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'nanoai',
                              style: TextStyle(
                                color: colors.onSurface.withValues(alpha: 0.92),
                                fontSize: isLandscape ? 14 : 19,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: isLandscape ? 2 : 6),
                            Text(
                              title,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: isLandscape ? 24 : 40,
                                height: 1,
                                fontWeight: FontWeight.w400,
                                letterSpacing: isLandscape ? -0.6 : -1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

