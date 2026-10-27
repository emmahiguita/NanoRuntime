// QUÉ: edita el nombre comercial real usado por el agente de Negocios.
// CÓMO: valida una entrada corta y la devuelve a la capa de persistencia.
// POR QUÉ: evita respuestas genéricas o nombres inventados en WhatsApp.
library;

import 'package:flutter/material.dart';

import '../../automation_visual_theme.dart';
import 'dialog_container_shell.dart';

class BusinessNameEditDialog extends StatefulWidget {
  const BusinessNameEditDialog({super.key, required this.initial});

  final String initial;

  @override
  State<BusinessNameEditDialog> createState() => _BusinessNameEditDialogState();
}

class _BusinessNameEditDialogState extends State<BusinessNameEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return DialogContainerShell(
      child: SizedBox(
        height: 220,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nombre del negocio',
                style: TextStyle(
                  color: visual.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nano lo usará al saludar. Déjalo vacío para usar “nuestra tienda”.',
                style: TextStyle(color: visual.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 80,
                textInputAction: TextInputAction.done,
                style: TextStyle(color: visual.text),
                decoration: const InputDecoration(
                  labelText: 'Nombre comercial',
                  hintText: 'Ej. Café Aurora',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _save(),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('Guardar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());
}
