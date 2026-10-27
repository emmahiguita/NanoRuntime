// guided_fact_dialog.dart
//
// QUÉ HACE: reúne la estructura visual compartida por los editores guiados.
// CÓMO: recibe campos, modo libre y acciones sin conocer el dato comercial.
// POR QUÉ: evita duplicar el layout responsivo y mantiene cada editor bajo 200 líneas.

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'dialog_container_shell.dart';
import 'guided_fact_dialog_header.dart';

/// Marco Material compacto que mantiene el formulario usable en ambas orientaciones.
class GuidedFactDialog extends StatelessWidget {
  const GuidedFactDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.isRawMode,
    required this.rawController,
    required this.rawHint,
    required this.guidedFields,
    required this.onToggleMode,
    required this.onSave,
  });

  final String title;
  final IconData icon;
  final bool isRawMode;
  final TextEditingController rawController;
  final String rawHint;
  final List<Widget> guidedFields;
  final VoidCallback onToggleMode;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return DialogContainerShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GuidedFactDialogHeader(
            title: title,
            icon: icon,
            isRawMode: isRawMode,
            onToggleMode: onToggleMode,
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isRawMode
                  ? TextField(
                      controller: rawController,
                      maxLines: 6,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: rawHint,
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: guidedFields,
                    ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: visual.textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: visual.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo común con tipografía y densidad coherentes con Material Expressive.
class GuidedFactField extends StatelessWidget {
  const GuidedFactField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return TextField(
      controller: controller,
      style: TextStyle(color: visual.text, fontSize: 12.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 11, color: visual.textMuted),
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 10,
          color: visual.textMuted.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: visual.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}
