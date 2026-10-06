import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/account_providers.dart';
import 'nano_danger_dialog.dart';

/// Acciones sensibles de cuenta: reutiliza autenticación y espera su resultado.
/// No navega al acceso si el servidor rechazó la eliminación.
class ProfileAccountActions extends ConsumerStatefulWidget {
  final bool disabled;
  const ProfileAccountActions({super.key, this.disabled = false});

  @override
  ConsumerState<ProfileAccountActions> createState() =>
      _ProfileAccountActionsState();
}

class _ProfileAccountActionsState extends ConsumerState<ProfileAccountActions> {
  bool _busy = false;

  /// Bloquea doble pulsación y conserva la pantalla cuando falla una operación.
  Future<void> _execute({required bool delete}) async {
    if (_busy || widget.disabled) return;
    setState(() => _busy = true);
    try {
      if (delete) {
        final confirmed = await NanoDangerDialog.show(
          context: context,
          title: 'Eliminar cuenta',
          message:
              'Se eliminará tu cuenta de acceso. Esta acción no se puede deshacer.',
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
              delete
                  ? 'No se pudo eliminar la cuenta. Vuelve a intentarlo.'
                  : 'No se pudo cerrar la sesión. Vuelve a intentarlo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Wrap permite que los botones pasen de línea sin desbordar en horizontal.
  @override
  Widget build(BuildContext context) {
    final disabled = _busy || widget.disabled;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        TextButton.icon(
          onPressed: disabled ? null : () => _execute(delete: false),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Cerrar sesión'),
        ),
        TextButton.icon(
          onPressed: disabled ? null : () => _execute(delete: true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Eliminar cuenta'),
        ),
      ],
    );
  }
}
