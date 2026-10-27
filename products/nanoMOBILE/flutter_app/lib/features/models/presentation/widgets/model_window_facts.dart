// QUÉ: ficha compacta de formato, almacenamiento y estado del archivo.
// CÓMO: Wrap deja que cada dato ocupe su altura sin forzar una fila horizontal.
// POR QUÉ: la ficha también se abre en horizontal y con texto ampliado.
import 'package:flutter/material.dart';
import 'model_catalog_types.dart';

class ModelWindowFacts extends StatelessWidget {
  const ModelWindowFacts({super.key, required this.item});
  final UnifiedModelItem item;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = <String, String>{
      'Motor / formato': item.backendLabel,
      'Archivo': '${item.sizeGb.toStringAsFixed(2)} GB',
      if (item.ramGb > 0)
        'RAM estimada': '≈ ${item.ramGb.toStringAsFixed(1)} GB',
      'Almacenamiento': item.installed ? 'Instalado' : 'Sin instalar',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          for (final fact in facts.entries)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fact.key,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(fact.value, style: theme.textTheme.labelLarge),
              ],
            ),
        ],
      ),
    );
  }
}
