// models_portrait_view.dart — Vista vertical de catálogo de modelos neurales.
// QUÉ HACE: Despliega la interfaz de modelos optimizada para orientación vertical en móviles.
// CÓMO FUNCIONA: Scroll continuo con header, pestañas, carrusel andante, banner, filtros y lista.
// POR QUÉ: Permite navegación fluida a una sola mano con espaciado anti-dock flotante (< 180 líneas).
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

class ModelsPortraitView extends StatelessWidget {
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

  const ModelsPortraitView({
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

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: NanoSpacing.md,
        vertical: 2,
      ),
      children: [
        if (!state.allFilesGranted)
          IosPermissionBanner(
            onRequestAccess: () => notifier.requestAllFilesAccess(),
          ),
        const ModelsCatalogHeader(),
        ModelsTopNavTabs(
          activeTab: activeTab,
          onTabSelected: onTabChanged,
          installedCount: totalInstalledCount,
          favoritesCount: favoritesCount,
          downloadsCount: downloadsCount,
        ),
        const SizedBox(height: 10),
        // Carrusel andante animado con modelos recomendados y hardware probado
        // El slot permanece: retirar dos hijos al teclear recreaba el TextField.
        Visibility(
          visible:
              activeTab == ModelsCatalogTab.explorar &&
              searchController.text.isEmpty,
          child: Column(
            children: [
              ModelsRecommendedCarousel(onModelTap: onSelectRecommendedModel),
              const SizedBox(height: 8),
            ],
          ),
        ),
        // Banner de nuevos modelos
        ModelNewBadgeBanner(models: state.models),
        const SizedBox(height: 4),
        ModelsSearchAndFilter(
          key: const ValueKey('models-search'),
          controller: searchController,
          activeFilter: activeFilter,
          onFilterChanged: onFilterChanged,
          onSearchChanged: onSearchChanged,
        ),
        const SizedBox(height: 8),
        if (activeTab == ModelsCatalogTab.descargas ||
            activeTab == ModelsCatalogTab.instalados) ...[
          ModelStorageSummaryCard(
            totalInstalledGb: totalInstalledGb,
            totalInstalledCount: totalInstalledCount,
            isScanning: state.scanning,
            downloadDir: state.downloadDir,
            onScan: () => notifier.scanStorageAll(),
            onPickDownloadDir: onPickDownloadDir,
            onImportFromSd: () => notifier.pickCustomModelFile(),
          ),
          const SizedBox(height: 8),
        ],
        if (state.scanError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              state.scanError!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: colors.error,
              ),
            ),
          ),
        ModelsListSection(
          items: items,
          chatModel: chatModel,
          activeFilter: activeFilter,
          notifier: notifier,
          onShowDetails: onShowDetails,
        ),
        const SizedBox(height: 130),
      ],
    );
  }
}
