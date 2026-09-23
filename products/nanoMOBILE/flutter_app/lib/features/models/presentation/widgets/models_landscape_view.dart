// models_landscape_view.dart — Vista horizontal adaptativa de modelos neurales.
// QUÉ HACE: Organiza la pantalla en 2 columnas (panel de control + catálogo) en modo apaisado.
// CÓMO FUNCIONA: Row flexible con panel izquierdo (almacenamiento y filtros) y derecho (modelos con scroll).
// POR QUÉ: En pantallas apaisadas (~380px de alto) evita que la tarjeta empuje los modelos fuera de vista.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../application/models_notifier.dart';
import '../../application/models_state.dart';
import 'model_screen_helpers.dart';
import 'model_storage_summary_card.dart';
import 'models_list_section.dart';
import 'models_search_and_filter.dart';

class ModelsLandscapeView extends StatelessWidget {
  final ModelsState state;
  final ModelsNotifier notifier;
  final String chatModel;
  final TextEditingController searchController;
  final String activeFilter;
  final List<UnifiedModelItem> items;
  final double totalInstalledGb;
  final int totalInstalledCount;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDownloadDir;
  final ValueChanged<UnifiedModelItem> onShowDetails;

  const ModelsLandscapeView({
    super.key,
    required this.state,
    required this.notifier,
    required this.chatModel,
    required this.searchController,
    required this.activeFilter,
    required this.items,
    required this.totalInstalledGb,
    required this.totalInstalledCount,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onPickDownloadDir,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Izquierdo: Resumen de Almacenamiento, Búsqueda y Filtros
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.only(right: 6, bottom: 40),
              children: [
                if (!state.allFilesGranted)
                  IosPermissionBanner(
                    onRequestAccess: () => notifier.requestAllFilesAccess(),
                  ),
                ModelStorageSummaryCard(
                  totalInstalledGb: totalInstalledGb,
                  totalInstalledCount: totalInstalledCount,
                  isScanning: state.scanning,
                  downloadDir: state.downloadDir,
                  onScan: () => notifier.scanStorageAll(),
                  onPickDownloadDir: onPickDownloadDir,
                  onImportFromSd: () => notifier.pickCustomModelFile(),
                ),
                const SizedBox(height: 6),
                ModelsSearchAndFilter(
                  controller: searchController,
                  activeFilter: activeFilter,
                  onFilterChanged: onFilterChanged,
                  onSearchChanged: onSearchChanged,
                  isCompact: true,
                ),
                if (state.scanError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.scanError!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      color: colors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Divisor sutil
          VerticalDivider(
            width: 12,
            thickness: 0.5,
            color: colors.onSurfaceVariant.withValues(alpha: 0.15),
          ),
          // Panel Derecho: Catálogo de Modelos con scroll independiente
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.only(left: 6, bottom: 70),
              children: [
                ModelsListSection(
                  items: items,
                  chatModel: chatModel,
                  activeFilter: activeFilter,
                  notifier: notifier,
                  onShowDetails: onShowDetails,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
