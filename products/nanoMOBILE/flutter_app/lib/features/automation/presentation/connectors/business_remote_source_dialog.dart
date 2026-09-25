// QUÉ: solicita una URL remota y, solo para REST, un token Bearer opcional.
// CÓMO: mantiene la credencial en memoria hasta iniciar la importación.
// POR QUÉ: una pantalla que anuncia API autorizada debe cablear autenticación real.
library;

import 'package:flutter/material.dart';

final class BusinessRemoteSourceInput {
  const BusinessRemoteSourceInput({required this.url, this.authToken});

  final String url;
  final String? authToken;
}

class BusinessRemoteSourceDialog extends StatefulWidget {
  const BusinessRemoteSourceDialog({super.key, required this.isSheets});

  final bool isSheets;

  @override
  State<BusinessRemoteSourceDialog> createState() =>
      _BusinessRemoteSourceDialogState();
}

class _BusinessRemoteSourceDialogState
    extends State<BusinessRemoteSourceDialog> {
  final _url = TextEditingController();
  final _token = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.isSheets ? 'URL de Google Sheets' : 'Endpoint API REST'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'URL',
              hintText: widget.isSheets
                  ? 'https://docs.google.com/spreadsheets/d/...'
                  : 'https://api.negocio.com/v1/productos',
            ),
          ),
          if (!widget.isSheets) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Token Bearer (opcional)',
                helperText: 'Se usa una vez y no se guarda.',
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Conectar')),
    ],
  );

  void _submit() {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    final token = _token.text.trim();
    Navigator.pop(
      context,
      BusinessRemoteSourceInput(
        url: url,
        authToken: token.isEmpty ? null : token,
      ),
    );
  }
}
