// guided_fact_dialog_header.dart
// Encapsula el encabezado y el cambio accesible entre modo guiado y libre.

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

class GuidedFactDialogHeader extends StatelessWidget {
  const GuidedFactDialogHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.isRawMode,
    required this.onToggleMode,
  });

  final String title;
  final IconData icon;
  final bool isRawMode;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: visual.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: visual.accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: visual.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Semantics(
            label: isRawMode ? 'Modo guiado' : 'Texto libre',
            button: true,
            child: IconButton(
              icon: Icon(
                isRawMode ? Icons.view_list_rounded : Icons.edit_note_rounded,
                color: visual.accent,
                size: 22,
              ),
              onPressed: onToggleMode,
            ),
          ),
        ],
      ),
    );
  }
}
