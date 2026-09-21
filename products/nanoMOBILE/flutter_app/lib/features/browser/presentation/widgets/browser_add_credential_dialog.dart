import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_credential_notifier.dart';

/// Diálogo modal para agregar manualmente credenciales a la bóveda cifrada.
///
/// Principio SOLID: Responsabilidad Única (SRP) - Gestión exclusiva del formulario
/// de inserción manual de credenciales con validación previa de campos.
class BrowserAddCredentialDialog extends ConsumerStatefulWidget {
  final String? initialDomain;

  const BrowserAddCredentialDialog({super.key, this.initialDomain});

  static Future<void> show(BuildContext context, {String? initialDomain}) {
    return showDialog(
      context: context,
      builder: (_) => BrowserAddCredentialDialog(initialDomain: initialDomain),
    );
  }

  @override
  ConsumerState<BrowserAddCredentialDialog> createState() =>
      _BrowserAddCredentialDialogState();
}

class _BrowserAddCredentialDialogState
    extends ConsumerState<BrowserAddCredentialDialog> {
  late final TextEditingController _domainCtrl;
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _domainCtrl = TextEditingController(text: widget.initialDomain ?? '');
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    final domain = _domainCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;

    // Validación estricta: ningún campo debe estar vacío
    if (domain.isEmpty || user.isEmpty || pass.isEmpty) return;

    // Guardado reactivo en la bóveda cifrada HMAC-SHA256
    ref.read(browserCredentialProvider.notifier).saveCredential(
          domain: domain,
          username: user,
          password: pass,
        );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Credencial guardada en la bóveda cifrada'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155), width: 1.0),
      ),
      title: const Row(
        children: [
          Icon(Icons.add_moderator_rounded, color: Color(0xFF38BDF8), size: 20),
          SizedBox(width: 8),
          Text(
            'Guardar Nueva Credencial',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _domainCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Dominio o Sitio Web',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                hintText: 'ej. google.com',
                hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _userCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Usuario / Correo Electrónico',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passCtrl,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: const Color(0xFF94A3B8),
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _onSave,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
