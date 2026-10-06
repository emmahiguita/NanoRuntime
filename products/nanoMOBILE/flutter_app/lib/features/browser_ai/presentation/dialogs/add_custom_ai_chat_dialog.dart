// add_custom_ai_chat_dialog.dart — Diálogo para añadir proveedores web de IA adicionales.
// QUÉ HACE: Permite al usuario registrar cualquier chat web (ej. Mistral, Grok, HuggingChat).
// CÓMO FUNCIONA: Captura Nombre y URL, valida el formato HTTP/HTTPS y persiste la configuración.
// POR QUÉ: Permite incorporar nuevas IAs del mercado sin modificar el código ni esperar actualizaciones.
library;

import 'package:flutter/material.dart';
import '../../domain/browser_ai_custom_provider_model.dart';
import '../../infrastructure/browser_ai_preferences.dart';

class AddCustomAiChatDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const AddCustomAiChatDialog({super.key, required this.onSaved});

  @override
  State<AddCustomAiChatDialog> createState() => _AddCustomAiChatDialogState();
}

class _AddCustomAiChatDialogState extends State<AddCustomAiChatDialog> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    var rawUrl = _urlController.text.trim();
    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
      rawUrl = 'https://$rawUrl';
    }

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final model = BrowserAiCustomProviderModel(
      id: id,
      name: _nameController.text.trim(),
      url: rawUrl,
    );

    await BrowserAiPreferences.saveCustomProvider(model);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981)),
          SizedBox(width: 8),
          Text('Añadir Chat de IA', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Proveedor',
                  hintText: 'Ej. Mistral Le Chat',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.smart_toy_outlined, size: 20),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Ingresa un nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL Oficial del Chat',
                  hintText: 'https://chat.mistral.ai/',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link_rounded, size: 20),
                ),
                keyboardType: TextInputType.url,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresa la URL';
                  final uri = Uri.tryParse(val.trim());
                  if (uri == null || (!uri.hasScheme && !val.contains('.'))) {
                    return 'URL no válida';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
