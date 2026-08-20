import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'nano_ambient_background.dart';

/// Shell compartido de las pantallas secundarias (Chat, Modelos, Settings, etc.).
///
/// Refleja la estética de alta gama de la Home: fondo translúcido blanco/ice,
/// tipografía con gradiente para la marca `nanoai`, títulos claros en Slate 900
/// y compatibilidad total con modo claro y oscuro.
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
                      ? const EdgeInsets.fromLTRB(16, 4, 16, 6)
                      : const EdgeInsets.fromLTRB(18, 4, 18, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (rect) {
                          return LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            stops: const [0.0, 0.65, 0.85, 1.0],
                            colors: [
                              colors.textPrimary,
                              colors.textPrimary,
                              colors.accentCyan,
                              colors.accentLavender,
                            ],
                          ).createShader(rect);
                        },
                        child: const Text(
                          'NanoAI',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3.5,
                        height: 3.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.textSecondary.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        Flexible(flex: 2, child: trailing!),
                      ],
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
