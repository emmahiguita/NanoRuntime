/// NANO-PERSONAL-CONTACT-DIALOG — Diálogo para agregar o editar contacto.
///
/// QUÉ HACE:
/// Despliega modal para configurar relación, estilo y auto-reply de un contacto.
///
/// CÓMO FUNCIONA:
/// Valida campos y genera un mapa con name, relation, style, autoReply.
/// Usa useRootNavigator: true.
///
/// POR QUÉ:
/// Modulariza la lógica del diálogo manteniendo los archivos < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../personal_agent/domain/persona_profile.dart';
import '../automation_visual_theme.dart';

class ContactConfigResult {
  final String name;
  final String relationship;
  final String styleRegister;
  final bool autoReply;

  const ContactConfigResult({
    required this.name,
    required this.relationship,
    required this.styleRegister,
    required this.autoReply,
  });
}

class NanoPersonalContactDialog {
  static Future<ContactConfigResult?> show(
    BuildContext context, [
    PersonaProfile? existing,
  ]) async {
    final nameController =
        TextEditingController(text: existing?.displayName ?? '');
    String relation = existing?.facts['relationship'] ?? 'Amigos';
    String style = existing?.facts['styleRegister'] ?? 'Cercano';
    bool autoReply = existing?.facts['autoReply'] != 'false';

    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        final visual = AutomationVisual.of(ctx);
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: visual.surface,
              title: Text(
                existing == null ? 'Nuevo contacto' : 'Editar contacto',
                style: TextStyle(color: visual.text, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Nombre del contacto',
                        hintText: 'Ej. Mamá, Juan Pérez',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Relación:',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                    // Dropdown blindado: asegura que 'relation' esté siempre presente en los items
                    DropdownButton<String>(
                      value: relation,
                      isExpanded: true,
                      dropdownColor: visual.surface,
                      items: {'Familia', 'Amigos', 'Trabajo', 'Cliente', relation}
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => relation = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Estilo de respuesta:',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                    // Dropdown blindado: asegura que 'style' esté siempre presente en los items
                    DropdownButton<String>(
                      value: style,
                      isExpanded: true,
                      dropdownColor: visual.surface,
                      items: {'Cercano', 'Formal', 'Breve', style}
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => style = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Responder automáticamente'),
                      subtitle: const Text('Si está apagado, solo genera borrador'),
                      value: autoReply,
                      onChanged: (v) => setDialogState(() => autoReply = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final name = nameController.text.trim();
      if (name.isNotEmpty) {
        return ContactConfigResult(
          name: name,
          relationship: relation,
          styleRegister: style,
          autoReply: autoReply,
        );
      }
    }
    return null;
  }
}
