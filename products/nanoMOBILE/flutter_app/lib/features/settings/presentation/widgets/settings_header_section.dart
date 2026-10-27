import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Cabecera ejecutiva estilo iOS Large Title para los Ajustes del sistema.
class SettingsHeaderSection extends StatelessWidget {
  final NanoColors colors;
  final String themeMode;

  const SettingsHeaderSection({
    super.key,
    required this.colors,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ajustes',
            style: TextStyle(
              fontFamily: 'Inter',
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 28,
              letterSpacing: -0.7,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Cuenta, inteligencia artificial y preferencias del dispositivo.',
            style: TextStyle(
              fontFamily: 'Inter',
              color: colors.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    ),
  );
}
