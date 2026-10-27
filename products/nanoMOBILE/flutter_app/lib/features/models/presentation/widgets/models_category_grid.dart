import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import 'model_catalog_types.dart';

// QUÉ: categorías completas, incluido OCR, con títulos que pueden ocupar dos líneas.
// CÓMO: calcula columnas y altura según ancho local y escala de texto del sistema.
// POR QUÉ: el catálogo también se muestra dentro de un panel horizontal estrecho.
class ModelsCategoryGrid extends StatelessWidget {
  final List<UnifiedModelItem> items;
  final ValueChanged<String> onCategorySelected;

  const ModelsCategoryGrid({
    super.key,
    required this.items,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final grouped = <String, List<UnifiedModelItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.categoryKey, () => []).add(item);
    }
    final categories = _categoryOrder
        .where(grouped.containsKey)
        .map((key) => (key, grouped[key]!))
        .toList();

    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explorar por función',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 280
                ? 1
                : (constraints.maxWidth / 220).floor().clamp(2, 4);
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 140 + (textScale - 1).clamp(0, 3) * 76,
              ),
              itemBuilder: (context, index) {
                final key = categories[index].$1;
                final models = categories[index].$2;
                final representative = models.first;
                final connected = models
                    .where((item) => item.runtimeReady)
                    .length;
                final availability = connected == 0
                    ? (key == 'local'
                          ? 'Tarea por identificar'
                          : 'Integración pendiente')
                    : key == 'multimodal'
                    ? '$connected con chat de texto'
                    : '$connected con ruta conectada';
                return Material(
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () =>
                        onCategorySelected(representative.categoryLabel),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FeatherCoreIcon(
                            type: _iconFor(key),
                            size: 38,
                            framed: false,
                          ),
                          const Spacer(),
                          Text(
                            '${models.length} ${models.length == 1 ? 'modelo' : 'modelos'}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: 36 * textScale,
                            ),
                            child: Text(
                              representative.categoryLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            availability,
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  static const _categoryOrder = [
    'multimodal',
    'vision',
    'ocr',
    'voz',
    'chat',
    'razonamiento',
    'codigo',
    'agentes',
    'rag',
    'voz_generativa',
    'voz_hablantes',
    'local',
  ];

  static FeatherCoreType _iconFor(String key) => switch (key) {
    'multimodal' => FeatherCoreType.models,
    'vision' => FeatherCoreType.vision,
    'ocr' => FeatherCoreType.documents,
    'voz' => FeatherCoreType.mic,
    'voz_generativa' => FeatherCoreType.voice,
    'voz_hablantes' => FeatherCoreType.audioSplit,
    'codigo' => FeatherCoreType.code,
    'razonamiento' => FeatherCoreType.assistant,
    'agentes' => FeatherCoreType.automation,
    'rag' => FeatherCoreType.system,
    'local' => FeatherCoreType.files,
    _ => FeatherCoreType.chat,
  };
}
