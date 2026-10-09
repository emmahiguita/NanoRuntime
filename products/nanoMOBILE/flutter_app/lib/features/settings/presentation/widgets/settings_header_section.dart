import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';

/// Cabecera ejecutiva estilo iOS para los Ajustes del sistema.
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
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primary.withValues(alpha: 0.12),
            border: Border.all(color: colors.primary.withValues(alpha: 0.25), width: 1),
          ),
          child: Icon(Icons.tune_rounded, color: colors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajustes',
                style: NanoType.headline(colors.onSurface).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Cuenta, inteligencia artificial y dispositivo.',
                style: NanoType.caption(colors.onSurfaceVariant).copyWith(
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
