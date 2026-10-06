import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/account_providers.dart';
import '../../domain/account_exceptions.dart';

/// Modal bottom sheet profesional de selección e inicio de sesión con Google.
class GoogleSignInSheet extends ConsumerStatefulWidget {
  const GoogleSignInSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GoogleSignInSheet(),
    );
  }

  @override
  ConsumerState<GoogleSignInSheet> createState() => _GoogleSignInSheetState();
}

class _GoogleSignInSheetState extends ConsumerState<GoogleSignInSheet> {
  bool _isLoading = false;
  String? _errorMessage;

  // Abre el selector nativo; la UI nunca acepta correos escritos como identidad.
  Future<void> _selectAccount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    HapticFeedback.lightImpact();
    try {
      final error = await ref
          .read(authControllerProvider.notifier)
          .continueWithGoogle();
      if (!mounted) return;
      if (error != null) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
        return;
      }
      Navigator.of(context).pop(true);
    } on GoogleSignInCancelledException {
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildHeader(context),
                const SizedBox(height: 18),
                Divider(color: colors.outlineVariant, height: 1),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  _buildError(),
                  const SizedBox(height: 14),
                ],
                FilledButton.icon(
                  onPressed: _isLoading ? null : _selectAccount,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_circle_outlined),
                  label: Text(
                    _isLoading
                        ? 'Verificando cuenta...'
                        : 'Elegir cuenta de Google',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Google confirma tu identidad. Nano guarda la sesión en este dispositivo; Drive, Sheets y otros servicios requieren permisos separados.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4285F4).withValues(alpha: 0.35),
              blurRadius: 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      const SizedBox(width: 14),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acceder con Google',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Autenticación segura de la cuenta',
              style: TextStyle(fontSize: 12.5),
            ),
          ],
        ),
      ),
      IconButton(
        icon: const Icon(Icons.close_rounded, size: 20),
        onPressed: () => Navigator.of(context).pop(false),
      ),
    ],
  );

  Widget _buildError() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      _errorMessage!,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onErrorContainer,
        fontSize: 12,
      ),
    ),
  );
}
