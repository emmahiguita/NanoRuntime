import 'package:flutter/material.dart';

/// Género e idioma comparten selector; su contenido desplaza en horizontal.
class ProfileChoiceField extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const ProfileChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.options,
    required this.onChanged,
  });

  /// Espera selección y evita invocar al padre después de salir de la ruta.
  Future<void> _choose(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SingleChildScrollView(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final option in options)
                ListTile(
                  title: Text(option),
                  trailing: value == option
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
            ],
          ),
        ),
      ),
    );
    if (context.mounted && selected != null) onChanged(selected);
  }

  /// Área táctil nativa y textos flexibles, sin filas rígidas.
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(value.isEmpty ? 'Sin especificar' : value),
    trailing: const Icon(Icons.expand_more_rounded),
    onTap: () => _choose(context),
  );
}
