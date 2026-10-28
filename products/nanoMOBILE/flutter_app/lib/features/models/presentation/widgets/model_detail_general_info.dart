// model_detail_general_info.dart — Cuadrícula de información general del modelo.
// QUÉ HACE: Renderiza especificaciones clave (Tamaño, Tipo, Familia, Contexto, Licencia, Cuantización).
// CÓMO FUNCIONA: Grid de 2 columnas con tarjetas de superficie óptica y tipografía Inter.
// POR QUÉ: Extraído para mantener modularidad arquitectónica y archivos estrictamente < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_catalog_types.dart';
import '../../data/model_source_registry.dart';

class ModelDetailGeneralInfo extends StatelessWidget {
  final UnifiedModelItem item;

  const ModelDetailGeneralInfo({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final cat = item.catalog;
    final isVoice = cat?.isVoiceStt ?? false;
    final metadata = ModelSourceRegistry.definitionFor(item.name);

    final infoItems = [
      _InfoItem(
        label: 'Tamaño',
        value: '${item.sizeGb.toStringAsFixed(1)} GB',
        icon: Icons.inventory_2_outlined,
      ),
      _InfoItem(
        label: 'Tipo',
        value: isVoice ? 'Voz (STT)' : (cat?.params ?? 'Instruct'),
        icon: Icons.psychology_outlined,
      ),
      _InfoItem(
        label: 'Familia',
        value: item.company,
        icon: Icons.account_tree_outlined,
      ),
      _InfoItem(
        label: 'Contexto',
        value: metadata.isIdentified && metadata.officialContext > 0
            ? '${metadata.officialContext} tokens (modelo)'
            : 'No verificado',
        icon: Icons.history_edu_outlined,
      ),
      _InfoItem(
        label: 'Licencia',
        value: metadata.isIdentified
            ? metadata.officialLicense
            : 'No verificada',
        icon: Icons.verified_user_outlined,
      ),
      _InfoItem(
        label: 'Cuantización',
        value: item.format,
        icon: Icons.compress_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Información general',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
          ),
          itemCount: infoItems.length,
          itemBuilder: (context, index) {
            final entry = infoItems[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(NanoRadius.medium),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(entry.icon, size: 16, color: const Color(0xFF34D399)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;
  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}
