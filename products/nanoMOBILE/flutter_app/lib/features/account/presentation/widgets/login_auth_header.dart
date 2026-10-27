import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

/// Cabecera de autenticación estilo iOS: sobria, con jerarquía tipográfica limpia,
/// icono institucional en squircle y sin componentes gráficos innecesarios que resten seriedad.
class LoginAuthHeader extends StatelessWidget {
  const LoginAuthHeader({super.key, required this.isLandscape});
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    final themeExt = NanoThemeExtension.maybeOf(context);
    final colors = themeExt?.colors ?? const NanoDarkColors();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icono de identidad sobrio en squircle estilo Apple
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceVariant.withValues(alpha: 0.65)
                : colors.surface.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: isDark ? 0.40 : 0.60),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.onSurface.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 28,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Nano AI',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: colors.onSurface,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Entorno soberano de inteligencia artificial local',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
            height: 1.35,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
