// models_screen.dart — Catálogo neural móvil organizado por etiquetas y familias.
// QUÉ HACE: Explora, categoriza, descarga y ejecuta modelos GGUF y modelos de voz Whisper.
// CÓMO FUNCIONA: Controlador adaptativo que alterna vistas Vertical / Horizontal según orientación.
// POR QUÉ: Asegura soporte dual portrait/landscape, Material Expressive 3 y código < 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/models/catalog_models.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/services/nano_inference_coordinator.dart';
import '../../../../core/services/whisper_stt_service.dart';
import '../../../../core/theme/adaptive_theme.dart';
import '../../domain/local_model.dart';
import '../../application/models_provider.dart';
import '../widgets/inference_benchmark_sheet.dart';
import '../widgets/model_catalog_types.dart';
import '../widgets/model_download_feedback.dart';
import '../widgets/model_delete_confirmation.dart';
import '../widgets/model_floating_dialog_route.dart';
import '../widgets/models_landscape_view.dart';
import '../widgets/models_portrait_view.dart';
import '../widgets/models_screen_actions.dart';
import '../widgets/models_top_nav_tabs.dart';

part 'models_screen_actions.part.dart';

class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen> {
  final _search = TextEditingController();
  String _filter = 'Todos';
  ModelsCatalogTab _activeTab = ModelsCatalogTab.explorar;
  Set<String> _favorites = {};
  final Set<String> _observedDownloads = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(modelsProvider.notifier).maybeAutoScanAll();
      WhisperSttService.instance.init();
      final favs = await ModelsScreenActions.loadFavorites();
      if (mounted) setState(() => _favorites = favs);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Solo avisa resultados de descargas iniciadas mientras el catálogo está activo.
    ref.listen(modelsProvider, (previous, next) {
      if (previous == null) return;
      for (final model in next.models) {
        final oldIndex = previous.models.indexWhere(
          (old) => old.id == model.id,
        );
        if (oldIndex < 0) continue;
        if (model.isDownloading) {
          _observedDownloads.add(model.id);
          continue;
        }
        if (!_observedDownloads.remove(model.id)) continue;
        if (model.downloadState != ModelDownloadState.installed &&
            model.downloadState != ModelDownloadState.failed) {
          continue;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ModelDownloadFeedback.show(context, model);
        });
      }
    });

    final state = ref.watch(modelsProvider);
    final notifier = ref.read(modelsProvider.notifier);
    final chatModel = ref.watch(chatProvider).activeModel;
    final isLandscape = AdaptiveTheme.isLandscape(context);

    final query = _search.text.trim().toLowerCase();
    final items = ModelFilterHelper.filter(
      catalog: state.models,
      detected: state.detected,
      query: query,
      filter: _filter,
      favorites: _favorites,
    );

    final totalInstalledGb = state.models
        .where((m) => m.installed)
        .fold(0.0, (acc, m) => acc + m.sizeGb);
    final totalInstalledCount =
        state.models.where((m) => m.installed).length +
        state.detected.where((d) => d.usable).length;
    final downloadsCount = state.models.where((m) => m.isDownloading).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Modelos & Redes Neuronales',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed_rounded, size: 21),
            tooltip: 'Benchmark LiteRT vs llama.cpp',
            onPressed: () => _openBenchmark(state.models),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 21),
            tooltip: 'Actualizar catálogo y escanear',
            onPressed: () => notifier.refreshCatalogAndStorage(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isLandscape
          ? ModelsLandscapeView(
              state: state,
              notifier: notifier,
              chatModel: chatModel,
              searchController: _search,
              activeFilter: _filter,
              activeTab: _activeTab,
              items: items,
              totalInstalledGb: totalInstalledGb,
              totalInstalledCount: totalInstalledCount,
              favoritesCount: _favorites.length,
              downloadsCount: downloadsCount,
              onFilterChanged: (f) => setState(() => _filter = f),
              onTabChanged: _onTabChanged,
              onSearchChanged: (_) => setState(() {}),
              onPickDownloadDir: _pickDownloadDir,
              onShowDetails: (it) => _showDetails(context, it, items),
              onSelectRecommendedModel: (name) =>
                  _onSelectModelByName(items, name),
            )
          : ModelsPortraitView(
              state: state,
              notifier: notifier,
              chatModel: chatModel,
              searchController: _search,
              activeFilter: _filter,
              activeTab: _activeTab,
              items: items,
              totalInstalledGb: totalInstalledGb,
              totalInstalledCount: totalInstalledCount,
              favoritesCount: _favorites.length,
              downloadsCount: downloadsCount,
              onFilterChanged: (f) => setState(() => _filter = f),
              onTabChanged: _onTabChanged,
              onSearchChanged: (_) => setState(() {}),
              onPickDownloadDir: _pickDownloadDir,
              onShowDetails: (it) => _showDetails(context, it, items),
              onSelectRecommendedModel: (name) =>
                  _onSelectModelByName(items, name),
            ),
    );
  }
}
