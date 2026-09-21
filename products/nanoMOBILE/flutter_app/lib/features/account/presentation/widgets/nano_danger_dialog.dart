import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

/// QUÉ HACE:
/// Diálogo de confirmación para acciones destructivas e irreversibles (Eliminar Cuenta).
///
/// CÓMO FUNCIONA:
/// Muestra un modal con advertencia explícita sobre la pérdida de datos asociados,
/// requiriendo una confirmación consciente antes de proceder.
///
/// POR QUÉ:
/// Cumple con las políticas de Google Play sobre eliminación de cuentas y UX defensiva.
class NanoDangerDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;

  const NanoDangerDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => NanoDangerDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg),
      child: NanoOpticalSurface(
        borderRadius: NanoRadius.large,
        padding: const EdgeInsets.all(NanoSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(NanoRadius.small),
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: colors.error, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: NanoType.headline(colors.error)),
                ),
              ],
            ),
            const SizedBox(height: NanoSpacing.md),
            Text(message, style: NanoType.body(colors.onSurfaceVariant)),
            const SizedBox(height: NanoSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancelar', style: NanoType.label(colors.onSurfaceVariant)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(NanoRadius.medium),
                    ),
                  ),
                  onPressed: onConfirm,
                  child: Text(confirmLabel, style: NanoType.label(Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
