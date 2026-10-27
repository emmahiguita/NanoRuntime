import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../application/account_providers.dart';
import 'nano_danger_dialog.dart';

/// Acciones de sesión y gobernanza de cuenta estilo iOS Cupertino compacto.
///
/// - QUÉ HACE: Provee botones sobrios de baja altura para cerrar sesión o eliminar cuenta.
/// - CÓMO FUNCIONA: Utiliza superficies discretas con bordes neutros y tipografía nítida,
///   descartando gradientes o neones saturados.
/// - POR QUÉ: Cumple con la directiva de componentes pequeños, ejecutivos y serios.
class ProfileAccountActions extends ConsumerStatefulWidget {
  final bool disabled;
  const ProfileAccountActions({super.key, this.disabled = false});

  @override
  ConsumerState<ProfileAccountActions> createState() => _ProfileAccountActionsState();
}

class _ProfileAccountActionsState extends ConsumerState<ProfileAccountActions> {
  bool _busy = false;

  Future<void> _execute({required bool delete}) async {
    if (_busy || widget.disabled) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      if (delete) {
        final confirmed = await NanoDangerDialog.show(
          context: context,
          title: 'Eliminar cuenta',
          message: 'Se eliminará tu cuenta de acceso de forma permanente. Esta acción no se puede deshacer.',
          confirmLabel: 'Eliminar cuenta',
        );
        if (confirmed != true || !mounted) return;
      }
      final controller = ref.read(authControllerProvider.notifier);
      if (delete) {
        final error = await controller.deleteAccount();
        if (error != null) throw StateError(error);
      } else {
        await controller.signOut();
      }
      if (mounted) context.go('/auth/login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              delete ? 'No se pudo eliminar la cuenta.' : 'No se pudo cerrar la sesión.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final disabled = _busy || widget.disabled;

    return Row(
      children: [
        Expanded(
          child: _CompactActionButton(
            icon: Icons.logout_rounded,
            label: 'Cerrar sesión',
            iconColor: colors.onSurfaceVariant,
            textColor: colors.onSurface,
            disabled: disabled,
            onTap: () => _execute(delete: false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Eliminar cuenta',
            iconColor: colors.error.withValues(alpha: 0.85),
            textColor: colors.error.withValues(alpha: 0.90),
            disabled: disabled,
            onTap: () => _execute(delete: true),
          ),
        ),
      ],
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final bool disabled;
  final VoidCallback onTap;

  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeExt = NanoThemeExtension.maybeOf(context);
    final colors = themeExt?.colors ?? const NanoDarkColors();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceVariant.withValues(alpha: 0.40)
                    : colors.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.45),
                  width: 0.75,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14.5, color: iconColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
