/// NANO-PERSONAL-MEMORY-DIALOG — Diálogo para añadir o editar hechos de memoria.
///
/// QUÉ HACE:
/// Muestra un modal para registrar aspectos y preferencias personales
/// ("Ciudad actual", "Café sin azúcar", etc.).
///
/// CÓMO FUNCIONA:
/// Valida campos y genera un [PersonalMemory]. Usa useRootNavigator: true.
///
/// POR QUÉ:
/// Modulariza la lógica del diálogo manteniendo los archivos < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../personal_agent/domain/personal_memory.dart';
import '../automation_visual_theme.dart';

class NanoPersonalMemoryDialog {
  static Future<PersonalMemory?> show(
    BuildContext context, [
    PersonalMemory? existing,
  ]) async {
    final keyController = TextEditingController(text: existing?.key ?? '');
    final valController = TextEditingController(text: existing?.value ?? '');

    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        final visual = AutomationVisual.of(ctx);
        return AlertDialog(
          backgroundColor: visual.surface,
          title: Text(
            existing == null ? 'Nuevo recuerdo o dato' : 'Editar dato',
            style: TextStyle(color: visual.text, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tema o aspecto:',
                  style: TextStyle(color: visual.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: keyController,
                  autofocus: true,
                  style: TextStyle(color: visual.text, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Ej. Ciudad actual, Café, Deporte',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Dato o preferencia que Nano debe saber:',
                  style: TextStyle(color: visual.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: valController,
                  maxLines: 2,
                  style: TextStyle(color: visual.text, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Ej. Vivo en Medellín y no tomo café con azúcar.',
                  ),
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

    if (result == true) {
      final key = keyController.text.trim();
      final val = valController.text.trim();
      if (key.isNotEmpty && val.isNotEmpty) {
        return PersonalMemory(
          id: existing?.id ?? -1,
          scopeKey: 'owner',
          key: key,
          value: val,
          kind: 'stablePreference',
          observedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
    return null;
  }
}
