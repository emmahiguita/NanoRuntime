import 'package:flutter/material.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';

/// Opción declarativa: la ventana devuelve una clave, nunca ejecuta operaciones.
class BusinessLibraryOption {
  const BusinessLibraryOption(this.value, this.label, {this.destructive = false});
  final String value, label;
  final bool destructive;
}

/// Menú flotante compartido de la biblioteca. Solo la elección explícita retorna
/// una acción; cerrar o tocar fuera devuelve null y conserva los datos.
Future<String?> showBusinessLibraryMenu(
  BuildContext context, {
  required String title,
  required List<BusinessLibraryOption> options,
  String? selectedValue,
}) => showNanoGlassWindow<String>(
  context: context,
  constraints: const BoxConstraints(maxWidth: 440),
  builder: (context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final option in options)
            ListTile(
              title: Text(option.label, style: TextStyle(color: option.destructive ? colors.error : colors.onSurface)),
              trailing: selectedValue == option.value ? Icon(Icons.check_rounded, color: colors.primary) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () => Navigator.of(context).pop(option.value),
            ),
        ],
      ),
    );
  },
);
