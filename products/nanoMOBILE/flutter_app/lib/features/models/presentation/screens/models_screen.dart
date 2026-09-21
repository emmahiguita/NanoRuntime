import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/providers/dashboard_provider.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/data/model_source_registry.dart';
import 'package:nanoai/features/models/domain/detected_model.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import 'package:nanoai/features/models/domain/model_viability.dart';
import 'package:nanoai/features/models/presentation/providers/model_metadata_providers.dart';
import 'package:nanoai/features/models/presentation/widgets/model_brand_logos.dart';
import 'package:nanoai/features/models/presentation/widgets/model_detail_bottom_sheet.dart';
import 'package:nanoai/features/models/presentation/widgets/model_info_button.dart';

/// Filtros de categoría de modelos (estilo segmentado iOS).
enum _ModelFilter {
  all('Todos', CupertinoIcons.square_grid_2x2),
  installed('Instalados', CupertinoIcons.arrow_down_circle),
  voice('Voz / Audio', CupertinoIcons.mic_fill),
  vision('Cámara / Visión', CupertinoIcons.camera_fill),
  storage('En SD / Local', CupertinoIcons.archivebox),
  gemma('Gemma', CupertinoIcons.sparkles),
  llama('LLaMA', CupertinoIcons.infinite),
  qwen('Qwen', CupertinoIcons.cube_box),
  deepseek('DeepSeek', CupertinoIcons.bolt),
  phi('Phi', CupertinoIcons.function),
  mistral('Mistral', CupertinoIcons.wind);

  final String label;
  final IconData icon;
  const _ModelFilter(this.label, this.icon);
}

/// Estado visual unificado para acciones de tarjeta.
enum ModelUiStatus {
  active,
  installed,
  available,
  downloading,
  error,
  incompatible,
  runtimeUnavailable,
}

/// Pantalla Modelos — Gestión, descarga y ejecución con diseño iOS Dark limpio y estable.
class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  _ModelFilter _selectedFilter = _ModelFilter.all;
  bool _entryStarted = false;

  /// Cache del veredicto del RuntimePlanner (Rust) por modelo.
  final Map<String, ViabilityStatus> _viabilityCache = {};
  final Set<String> _viabilityFetching = {};

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Auto-escaneo seguro de modelos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(modelsProvider.notifier);
      notifier.maybeAutoScanAll().then((_) {
        if (mounted) notifier.maybeAutoScan();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_entryStarted && !MediaQuery.disableAnimationsOf(context)) {
      _entryStarted = true;
      _entryController.forward();
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Viabilidad sin efectos secundarios durante el build/sort.
  ModelViability _getViability(LocalModel model, DashboardState dashboard) {
    final cached = _viabilityCache[model.id];
    if (cached != null) {
      return switch (cached.tier) {
        'FAST' => ModelViability.fast,
        'BALANCED' => ModelViability.balanced,
        'STREAMING' => ModelViability.streaming,
        'EXTREME' => ModelViability.extreme,
        _ => viabilityFor(model.ramGb, dashboard.ramTotalGb),
      };
    }
    return viabilityFor(model.ramGb, dashboard.ramTotalGb);
  }

  /// Consulta la viabilidad al motor de fondo sin bloquear el render.
  void _fetchViabilityAsync(LocalModel model) {
    if ((model.kind != ModelKind.llm &&
            model.kind != ModelKind.multimodalVision) ||
        _viabilityCache.containsKey(model.id) ||
        _viabilityFetching.contains(model.id) ||
        model.sizeGb <= 0) {
      return;
    }
    _viabilityFetching.add(model.id);
    final sizeBytes = (model.sizeGb * 1024 * 1024 * 1024).round();
    final client = ref.read(runtimeEngineProvider.notifier).client;
    client
        .assessModelViability(sizeBytes)
        .then((status) {
          if (mounted) {
            setState(() => _viabilityCache[model.id] = status);
          }
        })
        .catchError((_) {
          // Si el motor está offline, queda el cálculo síncrono.
        });
  }

  int _listRank(
    LocalModel model,
    DashboardState dashboard,
    String? readyModelPath,
  ) {
    if (readyModelPath != null && model.localPath == readyModelPath) return 0;
    if (model.installed) return 1;
    if (model.downloadState == ModelDownloadState.downloading) return 2;
    if (model.downloadState == ModelDownloadState.verifying) return 3;
    final viability = _getViability(model, dashboard);
    return switch (viability) {
      ModelViability.fast => 4,
      ModelViability.balanced => 5,
      ModelViability.streaming => 6,
      ModelViability.extreme => 7,
      ModelViability.unknown => 8,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modelsProvider);
    final dashboard = ref.watch(dashboardProvider);
    final chat = ref.watch(chatProvider);
    final notifier = ref.read(modelsProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;

    // Catálogo filtrado por capacidad física de RAM
    final catalogModels =
        state.models
            .where(
              (m) =>
                  dashboard.ramTotalGb <= 0 || m.ramGb <= dashboard.ramTotalGb,
            )
            .toList()
          ..sort(
            (a, b) =>
                _listRank(
                  a,
                  dashboard,
                  chat.connection == ModelConnectionState.ready
                      ? chat.activeModelPath
                      : null,
                ).compareTo(
                  _listRank(
                    b,
                    dashboard,
                    chat.connection == ModelConnectionState.ready
                        ? chat.activeModelPath
                        : null,
                  ),
                ),
          );

    final installedModels = catalogModels.where((m) => m.installed).toList();
    final usedGb = installedModels.fold<double>(0, (acc, m) => acc + m.sizeGb);
    final detected = state.detected;
    final query = _searchQuery.trim().toLowerCase();

    // 1. Filtrar Detectados
    final filteredDetected = detected.where((m) {
      if (_selectedFilter == _ModelFilter.installed) return false;
      final name = m.name.toLowerCase();
      if (_selectedFilter == _ModelFilter.voice &&
          !name.contains('whisper') &&
          !name.contains('voice') &&
          !name.contains('audio')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.vision &&
          !name.contains('vision') &&
          !name.contains('moondream') &&
          !name.contains('mmproj') &&
          !name.contains('camera')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.gemma && !name.contains('gemma')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.llama && !name.contains('llama')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.qwen && !name.contains('qwen')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.deepseek &&
          !name.contains('deepseek') &&
          !name.contains('r1')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.phi && !name.contains('phi')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.mistral &&
          !name.contains('mistral')) {
        return false;
      }

      if (query.isEmpty) return true;
      return name.contains(query) ||
          m.format.name.toLowerCase().contains(query) ||
          (m.path?.toLowerCase().contains(query) ?? false);
    }).toList();

    // 2. Filtrar Catálogo
    final filteredCatalog = catalogModels.where((m) {
      if (_selectedFilter == _ModelFilter.storage) return false;
      if (_selectedFilter == _ModelFilter.installed && !m.installed) {
        return false;
      }
      final name = m.name.toLowerCase();
      if (_selectedFilter == _ModelFilter.voice &&
          m.kind != ModelKind.voiceStt &&
          !name.contains('whisper') &&
          !name.contains('voice') &&
          !name.contains('audio')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.vision &&
          m.kind != ModelKind.multimodalVision &&
          !m.isMultimodal &&
          !name.contains('vision') &&
          !name.contains('moondream')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.gemma && !name.contains('gemma')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.llama && !name.contains('llama')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.qwen && !name.contains('qwen')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.deepseek &&
          !name.contains('deepseek') &&
          !name.contains('r1')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.phi && !name.contains('phi')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.mistral &&
          !name.contains('mistral')) {
        return false;
      }

      if (query.isEmpty) return true;
      return name.contains(query) ||
          m.description.toLowerCase().contains(query) ||
          m.quant.toLowerCase().contains(query) ||
          (m.kind == ModelKind.voiceStt &&
              (query.contains('voz') ||
                  query.contains('audio') ||
                  query.contains('whisper'))) ||
          (m.kind == ModelKind.multimodalVision &&
              (query.contains('vision') ||
                  query.contains('visión') ||
                  query.contains('camara') ||
                  query.contains('cámara')));
    }).toList();

    final List<_UnifiedItem> unifiedList = [
      if (_selectedFilter != _ModelFilter.installed)
        ...filteredDetected.map(_UnifiedItem.detected),
      ...filteredCatalog.map(_UnifiedItem.catalog),
    ];

    final totalCount = catalogModels.length + detected.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        NanoInputScope(
          scopeId: 'models',
          hint: 'Buscar modelos (Gemma, LLaMA, Qwen, DeepSeek)...',
          initialText: _searchQuery,
          onChanged: (val) {
            if (_searchQuery != val) {
              setState(() => _searchQuery = val);
            }
          },
          onSubmit: (_) => FocusScope.of(context).unfocus(),
          clearOnSubmit: false,
          child: Column(
            children: [
              // Banner iOS de acceso al almacenamiento si falta permiso
              if (!state.allFilesGranted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                  child: _IosPermissionBanner(
                    onGrant: () => notifier.requestAllFilesAccess(),
                  ),
                ),

              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 640;

                    Widget buildCard(int index) {
                      final item = unifiedList[index];
                      if (item.isDetected) {
                        final d = item.detected!;
                        final isSelected = chat.activeModel == d.name;
                        final isActive =
                            isSelected &&
                            chat.connection == ModelConnectionState.ready;
                        return _ModelItemCard.detected(
                          model: d,
                          isActive: isActive,
                          isLoading:
                              state.loadingDetectedUri == (d.path ?? d.uri) ||
                              (isSelected &&
                                  chat.connection ==
                                      ModelConnectionState.loadingModel),
                          onTapDetails: () => _openModelDetails(
                            name: d.name,
                            quant: d.format.name.toUpperCase(),
                            sizeGb: d.sizeBytes > 0
                                ? d.sizeBytes / (1024 * 1024 * 1024)
                                : 0,
                            description: d.usable
                                ? 'Modelo local detectado en almacenamiento SD / interno.'
                                : 'Archivo rechazado: cabecera GGUF no válida.',
                            path: d.path ?? d.uri,
                            isDetected: true,
                            isActive: isActive,
                            dashboard: dashboard,
                            actionLabel: d.usable
                                ? 'Cargar Modelo'
                                : 'Incompatible',
                            onAction: d.usable
                                ? () => notifier.useDetected(d)
                                : () {},
                          ),
                          onUse: d.usable
                              ? () => notifier.useDetected(d)
                              : null,
                        );
                      } else {
                        final m = item.catalog!;
                        // Una ruta nula nunca identifica un modelo activo.
                        final isSelected =
                            m.localPath != null &&
                            chat.activeModelPath == m.localPath;
                        final isActive =
                            isSelected &&
                            chat.connection == ModelConnectionState.ready;
                        final isLoading =
                            isSelected &&
                            chat.connection ==
                                ModelConnectionState.loadingModel;
                        final status = _statusOf(m, dashboard, isActive);
                        final viability = m.kind == ModelKind.llm
                            ? _getViability(m, dashboard)
                            : null;

                        // Petición asíncrona de veredicto solo si se va a renderizar
                        _fetchViabilityAsync(m);

                        return _ModelItemCard.catalog(
                          model: m,
                          isActive: isActive,
                          isLoading: isLoading,
                          status: status,
                          viability: viability,
                          onTapDetails: () => _openModelDetails(
                            name: m.name,
                            quant: m.quant,
                            sizeGb: m.sizeGb,
                            description: m.description,
                            ramGb: m.ramGb,
                            isDetected: false,
                            kind: m.kind,
                            isActive: status == ModelUiStatus.active,
                            dashboard: dashboard,
                            actionLabel: status == ModelUiStatus.installed
                                ? (m.kind == ModelKind.voiceStt
                                    ? 'Activar Voz'
                                    : m.kind == ModelKind.multimodalVision
                                        ? 'Cargar Visión'
                                        : 'Cargar en Chat')
                                : status == ModelUiStatus.active
                                ? 'Modelo Activo'
                                : status == ModelUiStatus.runtimeUnavailable
                                ? 'Runtime no conectado'
                                : m.kind == ModelKind.voiceStt
                                ? 'Descargar Voz'
                                : m.kind == ModelKind.multimodalVision
                                ? 'Descargar Visión'
                                : 'Descargar GGUF',
                            onAction: () {
                              if (status == ModelUiStatus.installed) {
                                _confirmAndUse(m);
                              } else if (status == ModelUiStatus.available ||
                                  status == ModelUiStatus.error ||
                                  status == ModelUiStatus.incompatible) {
                                notifier.downloadModel(m.id);
                              }
                            },
                          ),
                          onUse: () => _confirmAndUse(m),
                          onDownload: () => notifier.downloadModel(m.id),
                          onCancel: notifier.cancelDownload,
                        );
                      }
                    }

                    // ==========================================
                    // CABECERA ESTILO iOS + FILTROS SEGMENTADOS COMPACTOS
                    // ==========================================
                    final header = Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Modelos',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.4,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '${unifiedList.length} disponibles • ${installedModels.length + detected.where((m) => m.usable).length} instalados',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11.5,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Botón de escaneo rápido estilo iOS
                              ModelInfoButton(
                                icon: state.scanning
                                    ? CupertinoIcons.arrow_2_circlepath
                                    : CupertinoIcons.refresh,
                                label: 'Escanear almacenamiento',
                                onTap: notifier.scanStorageAll,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Filtros segmentados estilo iOS compactos
                          SizedBox(
                            height: 28,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _ModelFilter.values.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 5),
                              itemBuilder: (context, index) {
                                final f = _ModelFilter.values[index];
                                final isSelected = f == _selectedFilter;
                                return _IosSegmentPill(
                                  label: f.label,
                                  icon: f.icon,
                                  isSelected: isSelected,
                                  onTap: () =>
                                      setState(() => _selectedFilter = f),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );

                    if (totalCount == 0 && !state.scanning) {
                      return Column(
                        children: [
                          header,
                          const Expanded(
                            child: _IosEmptyState(isSearch: false),
                          ),
                        ],
                      );
                    }

                    if (unifiedList.isEmpty) {
                      return Column(
                        children: [
                          header,
                          Expanded(
                            child: _IosEmptyState(
                              isSearch: true,
                              query: _searchQuery,
                              onReset: () {
                                setState(() {
                                  _searchQuery = '';
                                  _selectedFilter = _ModelFilter.all;
                                });
                              },
                            ),
                          ),
                        ],
                      );
                    }

                    if (isWide) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            children: [
                              header,
                              Expanded(
                                child: CustomScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  slivers: [
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        4,
                                        16,
                                        12,
                                      ),
                                      sliver: SliverGrid(
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              mainAxisSpacing: 8,
                                              crossAxisSpacing: 10,
                                              mainAxisExtent: 100,
                                            ),
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) => buildCard(index),
                                          childCount: unifiedList.length,
                                        ),
                                      ),
                                    ),
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        kNanoBarScrollReserve,
                                      ),
                                      sliver: SliverToBoxAdapter(
                                        child: _StorageSummaryCard(
                                          usedGb: usedGb,
                                          storageTotalGb:
                                              dashboard.storageTotalGb,
                                          storageFreeGb:
                                              dashboard.storageFreeGb,
                                          downloadDir: state.downloadDir,
                                          onPickDir: _pickDownloadDir,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          children: [
                            header,
                            Expanded(
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  kNanoBarScrollReserve,
                                ),
                                itemCount: unifiedList.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == unifiedList.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: _StorageSummaryCard(
                                        usedGb: usedGb,
                                        storageTotalGb:
                                            dashboard.storageTotalGb,
                                        storageFreeGb: dashboard.storageFreeGb,
                                        downloadDir: state.downloadDir,
                                        onPickDir: _pickDownloadDir,
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: buildCard(index),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openModelDetails({
    required String name,
    required String quant,
    required double sizeGb,
    required String description,
    required bool isDetected,
    ModelKind kind = ModelKind.llm,
    required bool isActive,
    required VoidCallback onAction,
    required String actionLabel,
    required DashboardState dashboard,
    double? ramGb,
    String? path,
  }) {
    final totalRam = dashboard.ramTotalGb;
    final repo = ref.read(modelMetadataRepositoryProvider);
    final def = ModelSourceRegistry.definitionFor(name);

    if (def.quantizedRepo.isNotEmpty) {
      repo.refreshRemoteMetadata(def.quantizedRepo);
    }
    if (def.officialRepo.isNotEmpty && def.officialRepo != def.quantizedRepo) {
      repo.refreshRemoteMetadata(def.officialRepo);
    }

    final verifiedInfo = repo.getVerifiedModelInfo(
      modelName: name,
      phoneTotalRamGb: totalRam,
      customRamGb: ramGb,
      customSizeGb: sizeGb,
      customQuant: quant,
    );

    ModelDetailBottomSheet.show(
      context: context,
      name: name,
      quant: quant,
      sizeGb: sizeGb,
      description: description,
      isDetected: isDetected,
      kind: kind,
      isActive: isActive,
      onAction: onAction,
      actionLabel: actionLabel,
      phoneTotalRamGb: totalRam,
      verifiedInfo: verifiedInfo,
      sourceDef: def,
      ramGb: ramGb,
      path: path,
    );
  }

  Future<void> _confirmAndUse(LocalModel model) async {
    if (model.tier != ModelTier.extreme) {
      ref.read(modelsProvider.notifier).loadModel(model.id);
      return;
    }
    final confirmed = await showNanoModalDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modelo EXTREME'),
        content: Text(
          '${model.name} (${model.params}) excede la RAM de este dispositivo '
          'y provocará lentitud (thrashing). ¿Cargar de todos modos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cargar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref
          .read(modelsProvider.notifier)
          .loadModel(model.id, confirmedExtreme: true);
    }
  }

  Future<void> _pickDownloadDir() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || !mounted) return;
    await ref.read(modelsProvider.notifier).setDownloadDir(path);
  }
}

// =============================================================
// COMPONENTE TARJETA UNIFICADA (CLEAN ARCHITECTURE & iOS STYLE)
// =============================================================

class _ModelItemCard extends StatelessWidget {
  final String name;
  final String format;
  final double sizeGb;
  final String description;
  final bool isActive;
  final bool isDetected;
  final bool isLoading;
  final ModelUiStatus status;
  final ModelViability? viability;
  final double progress;
  final String? error;
  final VoidCallback onTapDetails;
  final VoidCallback? onUse;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;

  _ModelItemCard.catalog({
    required LocalModel model,
    required this.isActive,
    required this.isLoading,
    required this.status,
    required this.viability,
    required this.onTapDetails,
    required this.onUse,
    required this.onDownload,
    required this.onCancel,
  }) : name = model.name,
       format = model.quant,
       sizeGb = model.sizeGb,
       description = model.description,
       isDetected = false,
       progress = model.progress,
       error = model.error;

  _ModelItemCard.detected({
    required DetectedModel model,
    required this.isActive,
    required this.isLoading,
    required this.onTapDetails,
    required this.onUse,
  }) : name = model.name,
       format = model.format.name,
       sizeGb = model.sizeBytes > 0
           ? model.sizeBytes / (1024 * 1024 * 1024)
           : 0,
       description = model.usable
           ? 'Almacenamiento Local / Tarjeta SD'
           : 'Formato o cabecera GGUF no válida',
       isDetected = true,
       status = isActive ? ModelUiStatus.active : ModelUiStatus.installed,
       viability = null,
       progress = 0,
       error = model.usable ? null : 'Incompatible',
       onDownload = null,
       onCancel = null;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Semantics(
      label: '$name, ${_statusLabel(status)}',
      child: AnimatedActiveBorder(
        active: isActive,
        borderRadius: 16,
        child: Container(
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.30)
                      : const Color(0xFFD1FAE5).withValues(alpha: 0.70))
                : (isDark
                      ? colors.surface.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF10B981).withValues(alpha: 0.65)
                  : colors.onSurface.withValues(alpha: isDark ? 0.08 : 0.12),
              width: isActive ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? const Color(
                        0xFF10B981,
                      ).withValues(alpha: isDark ? 0.20 : 0.10)
                    : Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
                blurRadius: isActive ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTapDetails,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Logo Oficial de Marca en Squircle iOS (40x40)
                    ModelBrandLogo(name: name, size: 40),
                    const SizedBox(width: 12),

                    // 2. Información Central (iOS Typography)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 6),
                                const _IosTag(
                                  label: 'EN MEMORIA',
                                  color: Color(0xFF10B981),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),

                          // Fila limpia de especificaciones esenciales
                          Row(
                            children: [
                              Flexible(
                                flex: 0,
                                child: _IosSpecText(
                                  sizeGb > 0 ? formatGb(sizeGb) : 'Local',
                                  colors: colors,
                                ),
                              ),
                              _IosDotSeparator(colors: colors),
                              Flexible(
                                flex: 0,
                                child: _IosSpecText(
                                  format.toUpperCase(),
                                  colors: colors,
                                  isHighlight: true,
                                ),
                              ),
                              if (viability != null) ...[
                                _IosDotSeparator(colors: colors),
                                Flexible(
                                  child: _IosSpecText(
                                    _viabilityLabel(viability!),
                                    colors: colors,
                                    color: _viabilityColor(viability!, colors),
                                  ),
                                ),
                              ] else if (isDetected) ...[
                                _IosDotSeparator(colors: colors),
                                Flexible(
                                  flex: 0,
                                  child: _IosSpecText(
                                    'SD',
                                    colors: colors,
                                    color: colors.accentMint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),

                          // Descripción concisa o estado de error
                          Text(
                            error ?? description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: error != null
                                  ? colors.error
                                  : colors.textSecondary.withValues(alpha: 0.8),
                            ),
                          ),

                          // Barra de progreso elegante si está descargando
                          if (status == ModelUiStatus.downloading) ...[
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress > 0
                                    ? progress.clamp(0.0, 1.0)
                                    : null,
                                minHeight: 3.0,
                                backgroundColor: colors.metalSilver.withValues(
                                  alpha: 0.20,
                                ),
                                valueColor: AlwaysStoppedAnimation(
                                  colors.accentMint,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 3. Acción Primaria Estilo iOS
                    _buildActionButton(context, colors),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, NanoColors colors) {
    if (isLoading) {
      return const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (status) {
      case ModelUiStatus.active:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.40),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.checkmark_alt,
                color: Color(0xFF10B981),
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                'Activo',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        );

      case ModelUiStatus.installed:
        return _IosActionButton(
          label: 'Cargar',
          color: const Color(0xFF10B981),
          isPrimary: true,
          onPressed: onUse ?? () {},
        );

      case ModelUiStatus.available:
        return _IosActionButton(
          label: 'Obtener',
          color: colors.accent,
          isPrimary: false,
          onPressed: onDownload ?? () {},
        );

      case ModelUiStatus.downloading:
        return GestureDetector(
          onTap: onCancel,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.warning.withValues(alpha: 0.15),
              border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
            ),
            child: Icon(
              CupertinoIcons.stop_fill,
              size: 12,
              color: colors.warning,
            ),
          ),
        );

      case ModelUiStatus.error:
        return _IosActionButton(
          label: 'Reintentar',
          color: colors.error,
          isPrimary: false,
          onPressed: onDownload ?? () {},
        );

      case ModelUiStatus.incompatible:
        return _IosActionButton(
          label: 'Incompatible',
          color: colors.textSecondary,
          isPrimary: false,
          onPressed: () {},
        );

      case ModelUiStatus.runtimeUnavailable:
        return _IosActionButton(
          label: 'Sin conector',
          color: colors.warning,
          isPrimary: false,
          onPressed: () {},
        );
    }
  }
}

// =============================================================
// MICROCOMPONENTES VISUALES ESTILO iOS
// =============================================================

class _IosActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _IosActionButton({
    required this.label,
    required this.color,
    this.isPrimary = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isPrimary
                ? color.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPrimary
                  ? color.withValues(alpha: 0.50)
                  : Colors.white.withValues(alpha: 0.22),
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: isPrimary ? color : Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
    );
  }
}

class _IosSegmentPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _IosSegmentPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accentMint.withValues(alpha: 0.14)
              : colors.backgroundSecondary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isSelected
                ? colors.accentMint.withValues(alpha: 0.42)
                : colors.borderSecondaryColor.withValues(alpha: 0.25),
            width: 0.7,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11.5,
              color: isSelected ? colors.accentMint : colors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.accentMint : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IosTag extends StatelessWidget {
  final String label;
  final Color color;

  const _IosTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}

class _IosSpecText extends StatelessWidget {
  final String text;
  final NanoColors colors;
  final bool isHighlight;
  final Color? color;

  const _IosSpecText(
    this.text, {
    required this.colors,
    this.isHighlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: TextStyle(
        fontFamily: isHighlight ? 'JetBrainsMono' : 'Inter',
        fontSize: 10.5,
        fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
        color:
            color ?? (isHighlight ? colors.accentMint : colors.textSecondary),
      ),
    );
  }
}

class _IosDotSeparator extends StatelessWidget {
  final NanoColors colors;
  const _IosDotSeparator({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '•',
        style: TextStyle(
          fontSize: 10,
          color: colors.textSecondary.withValues(alpha: 0.40),
        ),
      ),
    );
  }
}

// =============================================================
// RESUMEN DE ALMACENAMIENTO & PERMISOS
// =============================================================

class _StorageSummaryCard extends StatelessWidget {
  final double usedGb;
  final double storageTotalGb;
  final double storageFreeGb;
  final String? downloadDir;
  final VoidCallback onPickDir;

  const _StorageSummaryCard({
    required this.usedGb,
    required this.storageTotalGb,
    required this.storageFreeGb,
    required this.downloadDir,
    required this.onPickDir,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final usedPct = storageTotalGb > 0
        ? (usedGb / storageTotalGb).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.borderSecondaryColor.withValues(alpha: 0.25),
          width: 0.7,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Almacenamiento',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                '${formatGb(usedGb)} de ${formatGb(storageTotalGb)}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: usedPct,
              minHeight: 3.5,
              backgroundColor: colors.metalSilver.withValues(alpha: 0.20),
              valueColor: AlwaysStoppedAnimation(
                usedPct > 0.85 ? colors.error : colors.accentMint,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  downloadDir == null
                      ? 'Destino: Almacenamiento de la App'
                      : 'Destino: $downloadDir',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onPickDir,
                child: Text(
                  downloadDir == null ? 'Cambiar' : 'Elegir',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.accentMint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IosPermissionBanner extends StatelessWidget {
  final VoidCallback onGrant;
  const _IosPermissionBanner({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.warning.withValues(alpha: 0.35),
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: colors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Concede acceso al almacenamiento para detectar tus modelos GGUF.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _IosActionButton(
            label: 'Conceder',
            color: colors.warning,
            isPrimary: false,
            onPressed: onGrant,
          ),
        ],
      ),
    );
  }
}

class _IosEmptyState extends StatelessWidget {
  final bool isSearch;
  final String query;
  final VoidCallback? onReset;

  const _IosEmptyState({required this.isSearch, this.query = '', this.onReset});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearch ? CupertinoIcons.search : CupertinoIcons.tray,
              size: 38,
              color: colors.textSecondary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 10),
            Text(
              isSearch ? 'Sin resultados' : 'Sin modelos instalados',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isSearch
                  ? 'No se encontraron modelos para "$query".'
                  : 'Descarga un modelo del catálogo o escanea tu almacenamiento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: colors.textSecondary,
              ),
            ),
            if (isSearch && onReset != null) ...[
              const SizedBox(height: 14),
              _IosActionButton(
                label: 'Restablecer filtros',
                color: colors.accentMint,
                isPrimary: true,
                onPressed: onReset!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================
// HELPERS & DTOs
// =============================================================

class _UnifiedItem {
  final DetectedModel? detected;
  final LocalModel? catalog;

  const _UnifiedItem.detected(this.detected) : catalog = null;
  const _UnifiedItem.catalog(this.catalog) : detected = null;

  bool get isDetected => detected != null;
}

ModelUiStatus _statusOf(
  LocalModel model,
  DashboardState dashboard,
  bool isActive,
) {
  if (isActive) return ModelUiStatus.active;
  if (model.downloadState == ModelDownloadState.downloading ||
      model.downloadState == ModelDownloadState.verifying) {
    return ModelUiStatus.downloading;
  }
  if (model.downloadState == ModelDownloadState.failed) {
    return ModelUiStatus.error;
  }
  if (model.installed) {
    return model.kind == ModelKind.llm
        ? ModelUiStatus.installed
        : ModelUiStatus.runtimeUnavailable;
  }
  if (dashboard.ramTotalGb > 0 && model.ramGb > dashboard.ramTotalGb) {
    return ModelUiStatus.incompatible;
  }
  return ModelUiStatus.available;
}

String _statusLabel(ModelUiStatus status) => switch (status) {
  ModelUiStatus.active => 'Activo',
  ModelUiStatus.installed => 'Instalado',
  ModelUiStatus.available => 'Disponible',
  ModelUiStatus.downloading => 'Descargando',
  ModelUiStatus.error => 'Error',
  ModelUiStatus.incompatible => 'Incompatible',
  ModelUiStatus.runtimeUnavailable => 'Runtime no conectado',
};

String _viabilityLabel(ModelViability v) => switch (v) {
  ModelViability.unknown => 'Sin medir',
  ModelViability.fast => 'Rápido',
  ModelViability.balanced => 'Equilibrado',
  ModelViability.streaming => 'Streaming',
  ModelViability.extreme => 'Extremo',
};

Color _viabilityColor(ModelViability v, NanoColors colors) => switch (v) {
  ModelViability.unknown => colors.textSecondary,
  ModelViability.fast => colors.accentMint,
  ModelViability.balanced => colors.metalSilver,
  ModelViability.streaming => colors.warning,
  ModelViability.extreme => colors.error,
};

String formatGb(double gb) {
  if (gb < 1.0) {
    return '${(gb * 1024).toStringAsFixed(0)} MB';
  }
  return '${gb.toStringAsFixed(1)} GB';
}
