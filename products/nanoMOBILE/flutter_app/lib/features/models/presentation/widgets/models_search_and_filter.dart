// QUÉ: búsqueda local y filtros reales del catálogo.
// CÓMO: texto nativo y filtros desplazables; respeta escala y ancho disponibles.
// POR QUÉ: evita encerrar la tipografía en alturas de 34 píxeles.
library;

import 'package:flutter/material.dart';
import 'model_action_components.dart';

class ModelsSearchAndFilter extends StatelessWidget {
  const ModelsSearchAndFilter({
    super.key,
    required this.controller,
    required this.activeFilter,
    required this.onFilterChanged,
    this.onSearchChanged,
    this.isCompact = false,
  });
  final TextEditingController controller;
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String>? onSearchChanged;
  final bool isCompact;
  // Solo muestra familias presentes en el catálogo curado.
  static const filterOptions = [
    'Todos',
    'Instalados',
    'Qwen',
    'Gemma',
    'Liquid AI',
    'DeepSeek',
    'Voz',
    'SD / Local',
  ];

  /// Buscar no dispara inferencia ni descarga; solo filtra elementos existentes.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            // El foco sigue visible, pero usa un borde neutro en este módulo.
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                width: 1.5,
              ),
            ),
            hintText: 'Buscar modelos',
            filled: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      controller.clear();
                      onSearchChanged?.call('');
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final option in filterOptions)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IosSegmentPill(
                  label: option,
                  selected: activeFilter == option,
                  onTap: () => onFilterChanged(option),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
