// models_screen.dart — Catálogo neural móvil organizado por etiquetas y familias.
// QUÉ HACE: Explora, categoriza, descarga y ejecuta modelos GGUF y modelos de voz Whisper.
// CÓMO FUNCIONA: Controlador adaptativo que alterna vistas Vertical / Horizontal según orientación.
// POR QUÉ: Asegura soporte dual portrait/landscape, Material Expressive 3 y código < 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/services/whisper_stt_service.dart';
import '../../../../core/theme/adaptive_theme.dart';
import '../../application/models_provider.dart';
import '../widgets/model_catalog_types.dart';
import '../widgets/model_detail_sheet.dart';
import '../widgets/models_landscape_view.dart';
import '../widgets/models_portrait_view.dart';

class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen> {
  final _search = TextEditingController();
  String _filter = 'Todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(modelsProvider.notifier).maybeAutoScanAll();
      WhisperSttService.instance.init();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    );

    final totalInstalledGb = state.models
        .where((m) => m.installed)
        .fold(0.0, (acc, m) => acc + m.sizeGb);
    final totalInstalledCount =
        state.models.where((m) => m.installed).length +
        state.detected.where((d) => d.usable).length;

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
              items: items,
              totalInstalledGb: totalInstalledGb,
              totalInstalledCount: totalInstalledCount,
              onFilterChanged: (f) => setState(() => _filter = f),
              onSearchChanged: (_) => setState(() {}),
              onPickDownloadDir: _pickDownloadDir,
              onShowDetails: (it) => _showDetails(context, it),
            )
          : ModelsPortraitView(
              state: state,
              notifier: notifier,
              chatModel: chatModel,
              searchController: _search,
              activeFilter: _filter,
              items: items,
              totalInstalledGb: totalInstalledGb,
              totalInstalledCount: totalInstalledCount,
              onFilterChanged: (f) => setState(() => _filter = f),
              onSearchChanged: (_) => setState(() {}),
              onPickDownloadDir: _pickDownloadDir,
              onShowDetails: (it) => _showDetails(context, it),
            ),
    );
  }

  Future<void> _pickDownloadDir() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || !mounted) return;
    await ref.read(modelsProvider.notifier).setDownloadDir(path);
  }

  // QUÉ HACE: Abre la hoja modal de detalle técnico de un modelo.
  // CÓMO FUNCIONA: Usa ModelDetailSheet.show con el BuildContext activo.
  // POR QUÉ: Permite abrir el bottom sheet fluido sobre el navigator raíz.
  void _showDetails(BuildContext targetContext, UnifiedModelItem item) {
    final chatModel = ref.read(chatProvider).activeModel;
    final isVoice = item.catalog?.isVoiceStt ?? false;
    final isActive = isVoice
        ? (WhisperSttService.instance.activeModelFile == item.fileName)
        : chatModel.toLowerCase().contains(item.name.toLowerCase());
    final notifier = ref.read(modelsProvider.notifier);

    ModelDetailSheet.show(
      targetContext,
      item: item,
      isActive: isActive,
      onUse: () => item.isCatalog
          ? notifier.loadModel(item.catalog!.id)
          : notifier.useDetected(item.detected!),
      onDownload: item.isCatalog
          ? () => notifier.downloadModel(item.catalog!.id)
          : null,
      onCancel: item.isCatalog ? () => notifier.cancelDownload() : null,
      onUnload: isActive
          ? () =>
                (isVoice ? notifier.unloadVoiceModel() : notifier.unloadModel())
          : null,
      onDelete: item.isCatalog
          ? () => notifier.deleteModel(item.catalog!.id)
          : (item.detected != null
              ? () => notifier.deleteDetectedModel(item.detected!)
              : null),
    );
  }
}
