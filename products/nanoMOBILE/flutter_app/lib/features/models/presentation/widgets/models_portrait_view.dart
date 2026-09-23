// models_portrait_view.dart — Vista vertical de catálogo de modelos neurales.
// QUÉ HACE: Despliega la interfaz de modelos optimizada para orientación vertical en móviles.
// CÓMO FUNCIONA: Scroll continuo con tarjeta de almacenamiento, buscador, filtros y lista categorizada.
// POR QUÉ: Permite navegación fluida a una sola mano con espaciado anti-dock flotante (< 200 líneas).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../application/models_notifier.dart';
import '../../application/models_state.dart';
import 'model_screen_helpers.dart';
import 'model_storage_summary_card.dart';
import 'models_list_section.dart';
import 'models_search_and_filter.dart';

class ModelsPortraitView extends StatelessWidget {
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

  const ModelsPortraitView({
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

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: NanoSpacing.md,
        vertical: 4,
      ),
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
        const SizedBox(height: 4),
        ModelsSearchAndFilter(
          controller: searchController,
          activeFilter: activeFilter,
          onFilterChanged: onFilterChanged,
          onSearchChanged: onSearchChanged,
        ),
        const SizedBox(height: 8),
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
