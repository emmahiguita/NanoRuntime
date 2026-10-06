import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';

/// Cabecera breve y accesible; la apariencia ya se explica en su propia tarjeta.
class SettingsHeaderSection extends StatelessWidget {
  final NanoColors colors;
  final String themeMode;
  const SettingsHeaderSection({
    super.key,
    required this.colors,
    required this.themeMode,
  });

  /// El texto puede envolver líneas; no se oculta cuando aumenta la fuente.
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      children: [
        Icon(Icons.tune_rounded, color: colors.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajustes', style: NanoType.headline(colors.onSurface)),
              const SizedBox(height: 4),
              Text(
                'Cuenta, inteligencia artificial y dispositivo.',
                style: NanoType.body(colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
