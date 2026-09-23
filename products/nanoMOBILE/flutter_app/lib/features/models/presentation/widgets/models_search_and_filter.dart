// models_search_and_filter.dart — Barra de búsqueda y pills de filtrado de modelos.
// QUÉ HACE: Renderiza la entrada de búsqueda de texto y las cápsulas de categoría (Qwen, DeepSeek, etc).
// CÓMO FUNCIONA: Componente desacoplado con Material Expressive 3 y Micro-interacciones visuales.
// POR QUÉ: Permite reutilizar la búsqueda tanto en modo vertical como en el panel lateral horizontal.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_action_components.dart';

class ModelsSearchAndFilter extends StatelessWidget {
  final TextEditingController controller;
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String>? onSearchChanged;
  final bool isCompact;

  const ModelsSearchAndFilter({
    super.key,
    required this.controller,
    required this.activeFilter,
    required this.onFilterChanged,
    this.onSearchChanged,
    this.isCompact = false,
  });

  static const filterOptions = [
    'Todos',
    'Qwen',
    'DeepSeek',
    'Llama',
    'Gemma',
    'Phi',
    'SD / Local',
    'Instalados',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: isCompact ? 34 : 38,
          child: TextField(
            controller: controller,
            onChanged: onSearchChanged,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: isCompact ? 11.5 : 12.5,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar modelos por nombre, familia...',
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: isCompact ? 11 : 12,
                color: colors.onSurfaceVariant,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: isCompact ? 16 : 18,
                color: colors.onSurfaceVariant,
              ),
              filled: true,
              fillColor: colors.surface.withValues(alpha: 0.6),
              contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NanoRadius.medium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filterOptions
                .map(
                  (opt) => Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: IosSegmentPill(
                      label: opt,
                      selected: activeFilter == opt,
                      onTap: () => onFilterChanged(opt),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
