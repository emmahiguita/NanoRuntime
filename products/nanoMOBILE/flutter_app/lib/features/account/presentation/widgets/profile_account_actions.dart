import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../application/account_providers.dart';
import 'nano_danger_dialog.dart';

/// Acciones de sesión y cuenta con estilo iOS Glass.
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
          child: _GlassActionButton(
            icon: Icons.logout_rounded,
            label: 'Cerrar sesión',
            color: colors.primary,
            disabled: disabled,
            onTap: () => _execute(delete: false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GlassActionButton(
            icon: Icons.delete_forever_rounded,
            label: 'Eliminar cuenta',
            color: colors.error,
            disabled: disabled,
            onTap: () => _execute(delete: true),
          ),
        ),
      ],
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool disabled;
  final VoidCallback onTap;

  const _GlassActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: 0.30),
                  width: 0.85,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: color,
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
