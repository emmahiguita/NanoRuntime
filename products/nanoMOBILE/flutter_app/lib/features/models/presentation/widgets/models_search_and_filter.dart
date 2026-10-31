// models_search_and_filter.dart — Barra de búsqueda y selector de filtros estilo Liquid Glass.
// QUÉ HACE: Búsqueda reactiva de modelos y filtros horizontales por familia y origen.
// CÓMO FUNCIONA: Campo de texto encapsulado en cristal translúcido con icono Cupertino y clear táctil.
// POR QUÉ: Diseño iOS profesional, sin bordes pesados de Material y tipografía Inter (< 130 líneas).
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/design_tokens.dart';
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

  static const filterOptions = [
    'Todos',
    'Qwen',
    'Gemma',
    'Granite',
    'Liquid AI',
    'DeepSeek',
    'SD / Local',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => Container(
            height: isCompact ? 38 : 42,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.20),
                width: 0.7,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  CupertinoIcons.search,
                  size: 16.5,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onSearchChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      hintText: 'Buscar por nombre, familia, GGUF o tarea...',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                ),
                if (value.text.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      controller.clear();
                      onSearchChanged?.call('');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        CupertinoIcons.clear_circled_solid,
                        size: 16,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final option in filterOptions)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IosSegmentPill(
                    label: option,
                    selected: activeFilter == option,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onFilterChanged(option);
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
