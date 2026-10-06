// models_landscape_view.dart — Vista horizontal adaptativa de modelos neurales.
// QUÉ HACE: Organiza la pantalla en 2 columnas (panel de control + catálogo) en modo apaisado.
// CÓMO FUNCIONA: Row flexible con panel izquierdo (almacenamiento y filtros) y derecho (modelos con scroll).
// POR QUÉ: En pantallas apaisadas (~380px de alto) evita que la tarjeta empuje los modelos fuera de vista (< 160 líneas).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../application/models_notifier.dart';
import '../../application/models_state.dart';
import 'model_new_badge_banner.dart';
import 'model_screen_helpers.dart';
import 'model_storage_summary_card.dart';
import 'models_catalog_header.dart';
import 'models_list_section.dart';
import 'models_recommended_carousel.dart';
import 'models_search_and_filter.dart';
import 'models_top_nav_tabs.dart';

class ModelsLandscapeView extends StatelessWidget {
  final ModelsState state;
  final ModelsNotifier notifier;
  final String chatModel;
  final TextEditingController searchController;
  final String activeFilter;
  final ModelsCatalogTab activeTab;
  final List<UnifiedModelItem> items;
  final double totalInstalledGb;
  final int totalInstalledCount, favoritesCount, downloadsCount;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<ModelsCatalogTab> onTabChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDownloadDir;
  final ValueChanged<UnifiedModelItem> onShowDetails;
  final ValueChanged<String> onSelectRecommendedModel;

  const ModelsLandscapeView({
    super.key,
    required this.state,
    required this.notifier,
    required this.chatModel,
    required this.searchController,
    required this.activeFilter,
    required this.activeTab,
    required this.items,
    required this.totalInstalledGb,
    required this.totalInstalledCount,
    this.favoritesCount = 0,
    this.downloadsCount = 0,
    required this.onFilterChanged,
    required this.onTabChanged,
    required this.onSearchChanged,
    required this.onPickDownloadDir,
    required this.onShowDetails,
    required this.onSelectRecommendedModel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Izquierdo: Encabezado, Pestañas, Filtros y Almacenamiento
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.only(right: 6, bottom: 40),
              children: [
                if (!state.allFilesGranted)
                  IosPermissionBanner(onRequestAccess: () => notifier.requestAllFilesAccess()),
                const ModelsCatalogHeader(),
                ModelsTopNavTabs(
                  activeTab: activeTab,
                  onTabSelected: onTabChanged,
                  installedCount: totalInstalledCount,
                  favoritesCount: favoritesCount,
                  downloadsCount: downloadsCount,
                ),
                const SizedBox(height: 6),
                ModelsSearchAndFilter(
                  controller: searchController,
                  activeFilter: activeFilter,
                  onFilterChanged: onFilterChanged,
                  onSearchChanged: onSearchChanged,
                  isCompact: true,
                ),
                const SizedBox(height: 6),
                ModelStorageSummaryCard(
                  totalInstalledGb: totalInstalledGb,
                  totalInstalledCount: totalInstalledCount,
                  isScanning: state.scanning,
                  downloadDir: state.downloadDir,
                  onScan: () => notifier.scanStorageAll(),
                  onPickDownloadDir: onPickDownloadDir,
                  onImportFromSd: () => notifier.pickCustomModelFile(),
                ),
                const SizedBox(height: 4),
                ModelNewBadgeBanner(models: state.models),
                if (state.scanError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.scanError!,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: colors.error),
                  ),
                ],
              ],
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant.withValues(alpha: 0.15)),
          // Panel Derecho: Carrusel y Catálogo scrollable
          Expanded(
            flex: 6,
            child: ListView(
              padding: const EdgeInsets.only(left: 6, bottom: 50),
              children: [
                if (activeTab == ModelsCatalogTab.explorar && searchController.text.isEmpty) ...[
                  ModelsRecommendedCarousel(onModelTap: onSelectRecommendedModel),
                  const SizedBox(height: 8),
                ],
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
