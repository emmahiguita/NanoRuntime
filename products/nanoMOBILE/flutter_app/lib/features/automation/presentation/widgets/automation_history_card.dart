import 'package:flutter/material.dart';
import 'automation_history_panel.dart';

/// Acceso compacto a datos reales. No necesita una tarjeta con desenfoque
/// propio: conserva espacio y evita otra capa de composición en el dashboard.
class AutomationHistoryCard extends StatelessWidget {
  const AutomationHistoryCard({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: () => showAutomationHistory(context),
      icon: const Icon(Icons.history_rounded, size: 18),
      label: const Text('Historial'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
  );
}
