part of 'models_screen.dart';

// QUÉ HACE: Agrupa acciones de pantalla sin mezclar estado visual con composición.
// CÓMO FUNCIONA: Extiende el State privado y reutiliza sus dependencias ya montadas.
// POR QUÉ: Mantiene cada archivo bajo 200 líneas y separa eventos de renderizado.
extension _ModelsScreenActions on _ModelsScreenState {
  void _onTabChanged(ModelsCatalogTab tab) {
    setState(() {
      _activeTab = tab;
      _filter = switch (tab) {
        ModelsCatalogTab.instalados => 'Instalados',
        ModelsCatalogTab.favoritos => 'Favoritos',
        ModelsCatalogTab.descargas => 'Descargas',
        ModelsCatalogTab.explorar => 'Todos',
      };
    });
  }

  void _toggleFavorite(String name) {
    setState(() {
      _favorites.contains(name)
          ? _favorites.remove(name)
          : _favorites.add(name);
    });
    ModelsScreenActions.saveFavorites(_favorites);
  }

  void _openBenchmark(List models) {
    final gguf = models
        .where((m) => m.installed && m.backendType == ModelBackendType.gguf)
        .firstOrNull;
    final liteRt = models
        .where((m) => m.installed && m.backendType == ModelBackendType.litertlm)
        .firstOrNull;
    // Solo mide archivos cuya integridad ya verificó el repositorio.
    if (gguf?.localPath == null || liteRt?.localPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Instala un modelo GGUF y uno LiteRT para compararlos.',
          ),
        ),
      );
      return;
    }
    showInferenceBenchmarkSheet(
      context,
      coordinator: ref.read(nanoInferenceCoordinatorProvider),
      ggufModelPath: gguf!.localPath!,
      liteRtModelPath: liteRt!.localPath!,
    );
  }

  void _onSelectModelByName(List<UnifiedModelItem> items, String name) {
    final lower = name.toLowerCase();
    final match = items
        .where(
          (it) =>
              it.name.toLowerCase().contains(lower) ||
              lower.contains(it.name.toLowerCase()),
        )
        .firstOrNull;
    if (match != null) {
      _showDetails(context, match, items);
    } else {
      _search.text = name;
      setState(() {});
    }
  }

  Future<void> _pickDownloadDir() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || !mounted) return;
    await ref.read(modelsProvider.notifier).setDownloadDir(path);
  }

  void _showDetails(
    BuildContext targetContext,
    UnifiedModelItem item,
    List<UnifiedModelItem> items,
  ) {
    final chatModel = ref.read(chatProvider).activeModel;
    final isVoice = item.catalog?.isVoiceStt ?? false;
    final isActive = isVoice
        ? WhisperSttService.instance.activeModelFile == item.fileName
        : (chatModel.isNotEmpty &&
            (chatModel.toLowerCase() == item.name.toLowerCase() ||
             item.name.toLowerCase().contains(chatModel.toLowerCase()) ||
             chatModel.toLowerCase().contains(item.name.toLowerCase())));
    final notifier = ref.read(modelsProvider.notifier);
    ModelFloatingDialogRoute.show(
      targetContext,
      item: item,
      isActive: isActive,
      isFavorite: _favorites.contains(item.name),
      onToggleFavorite: () => _toggleFavorite(item.name),
      // Reutiliza los dos archivos instalados y comprobados por el catálogo.
      onCompare: () => _openBenchmark(items),
      onShare: () => ModelsScreenActions.shareModel(context, item),
      onUse: () => isActive
          ? (isVoice ? notifier.unloadVoiceModel() : notifier.unloadModel())
          : (item.isCatalog
              ? notifier.loadModel(item.catalog!.id)
              : notifier.useDetected(item.detected!)),
      onDownload: item.isCatalog
          ? () => notifier.downloadModel(item.catalog!.id)
          : null,
      onCancel: item.isCatalog ? notifier.cancelDownload : null,
      onUnload: () =>
          isVoice ? notifier.unloadVoiceModel() : notifier.unloadModel(),
      onDelete: item.isCatalog || item.detected != null
          ? () => confirmModelDeletion(
              context: targetContext,
              modelName: item.name,
              fileName: item.fileName,
              delete: () => item.isCatalog
                  ? notifier.deleteModel(item.catalog!.id)
                  : notifier.deleteDetectedModel(item.detected!),
            )
          : null,
    );
  }
}
