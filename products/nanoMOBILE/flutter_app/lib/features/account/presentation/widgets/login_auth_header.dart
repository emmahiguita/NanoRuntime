import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_owl_avatar.dart';
import 'nano_security_badge.dart';

/// QUÉ HACE:
/// Cabecera visual de alta fidelidad para la pantalla de inicio de sesión de Nano AI.
///
/// CÓMO FUNCIONA:
/// Ajusta la presentación entre modo vertical (Avatar prominente con halo radial de energía,
/// títulos ejecutivos y badge de cifrado local) y modo horizontal (layout compacto en fila).
class LoginAuthHeader extends StatelessWidget {
  final bool isLandscape;

  const LoginAuthHeader({
    super.key,
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    if (isLandscape) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const NanoOwlAvatar(size: 36, state: NanoOwlState.idle),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NANO INTELLIGENCE CORE', style: NanoType.title(colors.onSurface)),
              Text(
                'Nodo local de automatización & IA soberana',
                style: NanoType.caption(colors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.22),
                    colors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            const NanoOwlAvatar(size: 58, state: NanoOwlState.idle),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'NANO INTELLIGENCE CORE',
          style: NanoType.headline(colors.onSurface).copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Computación local e inferencia autónoma en dispositivo',
          style: NanoType.caption(colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const NanoSecurityBadge(),
      ],
    );
  }
}
