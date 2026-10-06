import 'package:flutter/material.dart';

/// Diálogo con controlador propio: se libera al terminar también la transición.
class BrowserUrlEditDialog extends StatefulWidget {
  final String initialUrl;
  const BrowserUrlEditDialog({super.key, required this.initialUrl});

  @override
  State<BrowserUrlEditDialog> createState() => _BrowserUrlEditDialogState();
}

class _BrowserUrlEditDialogState extends State<BrowserUrlEditDialog> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialUrl);
  }

  /// Devuelve el texto; el propietario de la página decide cómo navegar.
  void _submit() {
    final input = _text.text.trim();
    if (input.isNotEmpty) Navigator.of(context).pop(input);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Dirección o búsqueda'),
    content: TextField(
      controller: _text,
      autofocus: true,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.go,
      autocorrect: false,
      onSubmitted: (_) => _submit(),
      decoration: const InputDecoration(
        hintText: 'Escribe una dirección o una búsqueda',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Ir')),
    ],
  );
}
