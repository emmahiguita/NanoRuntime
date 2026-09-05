import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/providers/dashboard_provider.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/data/model_source_registry.dart';
import 'package:nanoai/features/models/domain/detected_model.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import 'package:nanoai/features/models/domain/model_viability.dart';
import 'package:nanoai/features/models/presentation/providers/model_metadata_providers.dart';
import 'package:nanoai/features/models/presentation/widgets/model_brand_logos.dart';
import 'package:nanoai/features/models/presentation/widgets/model_detail_bottom_sheet.dart';

/// Tokens locales para el módulo de Modelos (White Optical Glass + M3E).
class _M3 {
  static const cardRadius = NanoRadius.large;
  static const compactRadius = NanoRadius.medium;
  static const barRadius = NanoRadius.medium;
  static const chipRadius = BorderRadius.all(Radius.circular(999));
  static const titleSize = 15.5;
}

enum _ModelFilter {
  all('Todos', Icons.apps_rounded),
  gemma('Gemma', Icons.auto_awesome_rounded),
  llama('LLaMA', Icons.all_inclusive_rounded),
  qwen('Qwen', Icons.interests_rounded),
  deepseek('DeepSeek', Icons.psychology_rounded),
  phi('Phi', Icons.functions_rounded),
  mistral('Mistral', Icons.air_rounded),
  storage('En Memoria / SD', Icons.sd_storage_rounded),
  installed('Instalados', Icons.download_done_rounded);

  final String label;
  final IconData icon;
  const _ModelFilter(this.label, this.icon);
}

/// Pantalla Modelos — Gestión, descarga, inspección gráfica y ejecución de modelos GGUF.
class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _reflectionController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  _ModelFilter _selectedFilter = _ModelFilter.all;
  bool _isSearchExpanded = false;
  bool _entryStarted = false;

  /// Veredicto del RuntimePlanner (Rust) por modelo — autoridad primaria.
  /// `viabilityFor` es solo el fallback offline hasta que esto se rellena.
  final Map<String, ViabilityStatus> _viabilityByModel = {};
  final Set<String> _viabilityFetching = {};

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _reflectionController = AnimationController(
      vsync: this,
      duration: NanoMotionDurations.ambient,
    )..repeat();

    final notifier = ref.read(modelsProvider.notifier);
    notifier.maybeAutoScanAll().then((_) {
      if (mounted) notifier.maybeAutoScan();
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
    _reflectionController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (_isSearchExpanded) {
        _searchFocusNode.requestFocus();
      } else {
        _searchQuery = '';
        _searchController.clear();
        _searchFocusNode.unfocus();
      }
    });
  }

  /// Viabilidad de un modelo: veredicto del motor (Rust) si está cacheado;
  /// si no, dispara el fetch y cae al fallback síncrono offline.
  ModelViability _modelViability(LocalModel model, DashboardState dashboard) {
    final cached = _viabilityByModel[model.id];
    if (cached != null) return _viabilityFromStatus(cached, model, dashboard);
    _fetchViability(model);
    return viabilityFor(model.ramGb, dashboard.ramTotalGb);
  }

  /// POST /api/viability → RuntimePlanner. Fire-and-forget: si el motor no
  /// responde (offline), queda el fallback y se permite reintentar.
  void _fetchViability(LocalModel model) {
    if (_viabilityFetching.contains(model.id)) return;
    if (model.sizeGb <= 0) return;
    _viabilityFetching.add(model.id);
    final sizeBytes = (model.sizeGb * 1024 * 1024 * 1024).round();
    final client = ref.read(runtimeEngineProvider.notifier).client;
    client
        .assessModelViability(sizeBytes)
        .then((status) {
          if (mounted) setState(() => _viabilityByModel[model.id] = status);
        })
        .catchError((_) {
          // offline: queda el fallback síncrono. El modelo permanece en
          // _viabilityFetching para NO reintentar en esta sesión (evita bucle
          // fetch→fail→rebuild→fetch). El veredicto se consulta al re-entrar.
        });
  }

  ModelViability _viabilityFromStatus(
    ViabilityStatus status,
    LocalModel model,
    DashboardState dashboard,
  ) {
    switch (status.tier) {
      case 'FAST':
        return ModelViability.fast;
      case 'BALANCED':
        return ModelViability.balanced;
      case 'STREAMING':
        return ModelViability.streaming;
      case 'EXTREME':
        return ModelViability.extreme;
      default:
        return viabilityFor(model.ramGb, dashboard.ramTotalGb);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modelsProvider);
    final dashboard = ref.watch(dashboardProvider);
    final notifier = ref.read(modelsProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;

    // MODELS-CAT-02 — solo se listan modelos que caben en la RAM de ESTE
    // dispositivo. D1 ya marcaba "incompatible" el exceso sobre la RAM
    // total; ahora ni aparecen: descargar algo condenado a OOM no es una
    // opción real para el usuario.
    final catalogModels = state.models
        .where(
          (model) =>
              dashboard.ramTotalGb <= 0 || model.ramGb <= dashboard.ramTotalGb,
        )
        .toList()
      ..sort(
        (a, b) => _listRank(a, dashboard).compareTo(_listRank(b, dashboard)),
      );

    final installedModels = catalogModels
        .where((model) => model.installed)
        .toList(growable: false);

    final usedGb = installedModels.fold<double>(
      0,
      (total, model) => total + model.sizeGb,
    );

    final detected = state.detected;

    // Filtrado interactivo por texto y categoría/familia
    final query = _searchQuery.trim().toLowerCase();

    // 1. Filtrar Detectados (SD / Storage Local)
    final filteredDetected = detected.where((model) {
      if (_selectedFilter == _ModelFilter.installed) return false;
      if (_selectedFilter == _ModelFilter.gemma &&
          !model.name.toLowerCase().contains('gemma'))
        return false;
      if (_selectedFilter == _ModelFilter.llama &&
          !model.name.toLowerCase().contains('llama'))
        return false;
      if (_selectedFilter == _ModelFilter.qwen &&
          !model.name.toLowerCase().contains('qwen'))
        return false;
      if (_selectedFilter == _ModelFilter.deepseek &&
          !model.name.toLowerCase().contains('deepseek') &&
          !model.name.toLowerCase().contains('r1')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.phi &&
          !model.name.toLowerCase().contains('phi'))
        return false;
      if (_selectedFilter == _ModelFilter.mistral &&
          !model.name.toLowerCase().contains('mistral'))
        return false;

      if (query.isEmpty) return true;
      return model.name.toLowerCase().contains(query) ||
          model.format.name.toLowerCase().contains(query) ||
          (model.path?.toLowerCase().contains(query) ?? false);
    }).toList();

    // 2. Filtrar Catálogo
    final filteredCatalog = catalogModels.where((model) {
      if (_selectedFilter == _ModelFilter.storage) return false;
      if (_selectedFilter == _ModelFilter.installed && !model.installed)
        return false;
      if (_selectedFilter == _ModelFilter.gemma &&
          !model.name.toLowerCase().contains('gemma'))
        return false;
      if (_selectedFilter == _ModelFilter.llama &&
          !model.name.toLowerCase().contains('llama'))
        return false;
      if (_selectedFilter == _ModelFilter.qwen &&
          !model.name.toLowerCase().contains('qwen'))
        return false;
      if (_selectedFilter == _ModelFilter.deepseek &&
          !model.name.toLowerCase().contains('deepseek') &&
          !model.name.toLowerCase().contains('r1')) {
        return false;
      }
      if (_selectedFilter == _ModelFilter.phi &&
          !model.name.toLowerCase().contains('phi'))
        return false;
      if (_selectedFilter == _ModelFilter.mistral &&
          !model.name.toLowerCase().contains('mistral'))
        return false;

      if (query.isEmpty) return true;
      return model.name.toLowerCase().contains(query) ||
          model.description.toLowerCase().contains(query) ||
          model.quant.toLowerCase().contains(query);
    }).toList();

    // ORDEN: Detectados en SD primero, luego Catálogo
    final List<_UnifiedModelItem> unifiedList = [
      if (_selectedFilter != _ModelFilter.installed)
        ...filteredDetected.map((d) => _UnifiedModelItem.detected(d)),
      ...filteredCatalog.map((c) => _UnifiedModelItem.catalog(c)),
    ];

    final totalFilteredCount = unifiedList.length;
    final totalCount = catalogModels.length + detected.length;
    final totalInStorage = detected.length + installedModels.length;

    // UI-REV-07: el fondo ya lo pone el shell (NanoAmbientBackground único).
    // Antes esta pantalla pintaba su propio ambient encima (doble capa).
    return Column(
      children: [
        if (!state.allFilesGranted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _AllFilesBanner(
              onGrant: () => notifier.requestAllFilesAccess(),
            ),
          ),
        // MODELS-CAT-01 — destino de descarga. Solo con acceso completo al
        // storage: sin MANAGE, Android 11+ no deja escribir en el externo y
        // un path SAF no sirve para dart:io directo. Sin carpeta elegida,
        // descarga al interno de la app (comportamiento original).
        if (state.allFilesGranted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _DownloadDirBar(
              dir: state.downloadDir,
              onPick: _pickDownloadDir,
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              final compactLandscape =
                  isLandscape && constraints.maxHeight < 520;

              Widget buildCardAt(int index) {
                final item = unifiedList[index];

                final Widget card;
                if (item.isDetected) {
                  final detectedModel = item.detected!;
                  final isActive = state.activeDetected == detectedModel.name;
                  card = _DetectedCard(
                    model: detectedModel,
                    loading:
                        state.loadingDetectedUri ==
                        (detectedModel.path ?? detectedModel.uri),
                    active: isActive,
                    reflectionController: _reflectionController,
                    onTapDetails: () => _openModelDetails(
                      name: detectedModel.name,
                      quant: detectedModel.format.name.toUpperCase(),
                      sizeGb: detectedModel.sizeBytes > 0
                          ? detectedModel.sizeBytes / (1024 * 1024 * 1024)
                          : 0,
                      description: detectedModel.usable
                          ? 'Modelo local detectado en almacenamiento SD / interno.'
                          : 'Archivo rechazado: la cabecera GGUF es inválida o incompleta.',
                      path: detectedModel.path ?? detectedModel.uri,
                      isDetected: true,
                      isActive: isActive,
                      dashboard: dashboard,
                      onAction: detectedModel.usable
                          ? () => notifier.useDetected(detectedModel)
                          : () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se puede cargar: cabecera GGUF inválida.',
                                ),
                              ),
                            ),
                      actionLabel: detectedModel.usable
                          ? 'Cargar Modelo'
                          : 'Archivo no compatible',
                    ),
                    onUse: detectedModel.usable
                        ? () => notifier.useDetected(detectedModel)
                        : null,
                  );
                } else {
                  final model = item.catalog!;
                  final status = _statusOf(model, dashboard);

                  card = _ModelCard(
                    name: model.name,
                    quantization: model.quant,
                    sizeGb: model.sizeGb,
                    description: model.description,
                    error: model.error,
                    status: status,
                    viability: _modelViability(model, dashboard),
                    tier: model.tier,
                    ramNote: status == ModelUiStatus.incompatible
                        ? 'Requiere ${model.ramGb.toStringAsFixed(0)} GB de RAM (dispositivo: ${dashboard.ramTotalGb.toStringAsFixed(1)} GB)'
                        : null,
                    progress: model.progress,
                    reflectionController: _reflectionController,
                    onTapDetails: () => _openModelDetails(
                      name: model.name,
                      quant: model.quant,
                      sizeGb: model.sizeGb,
                      description: model.description,
                      ramGb: model.ramGb,
                      isDetected: false,
                      isActive: status == ModelUiStatus.active,
                      dashboard: dashboard,
                      onAction: () {
                        if (status == ModelUiStatus.installed) {
                          _confirmAndUse(model);
                        } else if (status == ModelUiStatus.available ||
                            status == ModelUiStatus.error ||
                            status == ModelUiStatus.incompatible) {
                          // incompatible también descarga: la ficha mostrada en
                          // la sábana no debe diferir de la tarjeta (que sí
                          // ofrece "Descargar" para modelos grandes).
                          notifier.downloadModel(model.id);
                        }
                      },
                      actionLabel: status == ModelUiStatus.installed
                          ? 'Cargar en Chat'
                          : status == ModelUiStatus.active
                          ? 'Modelo Activo'
                          : 'Descargar GGUF',
                    ),
                    onUse: () => _confirmAndUse(model),
                    onDownload: () => notifier.downloadModel(model.id),
                    onCancel: notifier.cancelDownload,
                  );
                }

                if (MediaQuery.disableAnimationsOf(context)) return card;

                final start = (index * 0.05).clamp(0.0, 0.75);
                final end = (start + 0.20).clamp(0.0, 1.0);
                final entry = CurvedAnimation(
                  parent: _entryController,
                  curve: Interval(
                    start,
                    end,
                    curve: NanoMotionCurves.standardDecel,
                  ),
                );

                return AnimatedBuilder(
                  animation: _entryController,
                  builder: (_, child) {
                    final value = entry.value;
                    return Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - value.clamp(0.0, 1.0))),
                        child: Transform.scale(
                          scale: 0.96 + 0.04 * value,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: card,
                );
              }

              final hasAny = totalCount > 0;

              // ==========================================
              // TOP HEADER: NANOAI + SEARCH + FILTERS
              // ==========================================
              final topHeader = Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Column(
                  children: [
                    SizedBox(
                      height: 42,
                      child: Row(
                        children: [
                          Text(
                            'Modelos',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Barra de búsqueda expandible
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              height: 38,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: _isSearchExpanded
                                    ? SizedBox(
                                        key: const ValueKey('search_expanded'),
                                        child: NanoOpticalSurface(
                                          borderRadius: 12,
                                          blurSigma: 12,
                                          borderStrength: 0.80,
                                          reflectionStrength: 0.65,
                                          accent: colors.accentSky,
                                          reflectionController:
                                              _reflectionController,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.search_rounded,
                                                size: 18,
                                                color: colors.accentSky,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: TextField(
                                                  controller: _searchController,
                                                  focusNode: _searchFocusNode,
                                                  onChanged: (val) => setState(
                                                    () => _searchQuery = val,
                                                  ),
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: colors.textPrimary,
                                                  ),
                                                  decoration: InputDecoration(
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                        ),
                                                    hintText:
                                                        'Buscar (Gemma, LLaMA, Qwen, DeepSeek...)',
                                                    hintStyle: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 12,
                                                      color: colors
                                                          .textSecondary
                                                          .withValues(
                                                            alpha: 0.70,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: _toggleSearch,
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  size: 18,
                                                  color: colors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Row(
                                        key: const ValueKey('search_collapsed'),
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (totalInStorage > 0)
                                            Flexible(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colors.accentSky
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(99),
                                                  border: Border.all(
                                                    color: colors.accentSky
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  '$totalInStorage en memoria',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: colors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(width: 6),
                                          NanoOpticalSurface(
                                            geometry:
                                                NanoSurfaceGeometry.circle,
                                            blurSigma: 8,
                                            borderStrength: 0.60,
                                            reflectionStrength: 0.40,
                                            accent: colors.accentSky,
                                            onTap: _toggleSearch,
                                            child: SizedBox(
                                              width: 34,
                                              height: 34,
                                              child: Icon(
                                                Icons.search_rounded,
                                                size: 18,
                                                color: colors.accentSky,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          NanoOpticalSurface(
                                            geometry:
                                                NanoSurfaceGeometry.circle,
                                            blurSigma: 8,
                                            borderStrength: 0.60,
                                            reflectionStrength: 0.40,
                                            accent: colors.accentSky,
                                            onTap: notifier.scanStorageAll,
                                            child: SizedBox(
                                              width: 34,
                                              height: 34,
                                              child: Icon(
                                                state.scanning
                                                    ? Icons.sync_rounded
                                                    : Icons.refresh_rounded,
                                                size: 18,
                                                color: colors.accentSky,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Filtros Rápidos por Categoría y Familia de Modelos
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _ModelFilter.values.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final filter = _ModelFilter.values[index];
                          final isSelected = filter == _selectedFilter;

                          return NanoOpticalSurface(
                            geometry: NanoSurfaceGeometry.capsule,
                            blurSigma: 8,
                            borderStrength: isSelected ? 0.85 : 0.45,
                            reflectionStrength: isSelected ? 0.65 : 0.30,
                            accent: isSelected
                                ? colors.accentSky
                                : colors.metalSilver,
                            onTap: () =>
                                setState(() => _selectedFilter = filter),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  filter.icon,
                                  size: 13,
                                  color: isSelected
                                      ? colors.accentSky
                                      : colors.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  filter.label,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? colors.textPrimary
                                        : colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );

              if (isLandscape) {
                return Column(
                  children: [
                    topHeader,
                    Expanded(
                      child: !hasAny
                          ? const _EmptyModels()
                          : totalFilteredCount == 0
                          ? _EmptySearchResults(
                              query: _searchQuery,
                              onClear: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _selectedFilter = _ModelFilter.all;
                                });
                              },
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                              gridDelegate: compactLandscape
                                  ? SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount:
                                          constraints.maxWidth >= 560 ? 3 : 2,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      mainAxisExtent: 178,
                                    )
                                  : const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 360,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      // Altura reservada para nombre en
                                      // 2 líneas + descripción en 2 (sin
                                      // overflow al envolver texto).
                                      mainAxisExtent: 212,
                                    ),
                              itemCount: totalFilteredCount,
                              itemBuilder: (context, index) =>
                                  buildCardAt(index),
                            ),
                    ),
                  ],
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      topHeader,
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: const Offset(0, 0.035),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: offset,
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(
                              '${_selectedFilter.name}_${_searchQuery.trim()}',
                            ),
                            child: !hasAny
                                ? const _EmptyModels()
                                : totalFilteredCount == 0
                                ? _EmptySearchResults(
                                    query: _searchQuery,
                                    onClear: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _selectedFilter = _ModelFilter.all;
                                      });
                                    },
                                  )
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      2,
                                      14,
                                      20,
                                    ),
                                    itemCount: totalFilteredCount + 1,
                                    itemBuilder: (context, index) {
                                      if (index == totalFilteredCount) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: _StorageUsage(
                                            usedGb: usedGb,
                                            storageTotalGb:
                                                dashboard.storageTotalGb,
                                            storageFreeGb:
                                                dashboard.storageFreeGb,
                                          ),
                                        );
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: buildCardAt(index),
                                      );
                                    },
                                  ),
                          ),
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
    );
  }

  void _openModelDetails({
    required String name,
    required String quant,
    required double sizeGb,
    required String description,
    required bool isDetected,
    required bool isActive,
    required VoidCallback onAction,
    required String actionLabel,
    required DashboardState dashboard,
    double? ramGb,
    String? path,
  }) {
    final totalRam = dashboard.ramTotalGb > 0 ? dashboard.ramTotalGb : 8.0;
    final repo = ref.read(modelMetadataRepositoryProvider);
    final def = ModelSourceRegistry.definitionFor(name);

    repo.refreshRemoteMetadata(def.quantizedRepo);
    if (def.officialRepo != def.quantizedRepo) {
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

  /// Gate R9 — selección con confirmación para EXTREME (9B+). interactive y
  /// deep se cargan directo; extreme exige diálogo explícito. Sin confirmación,
  /// `selectModel` lo ignora (defensa en profundidad, no solo UI).
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
          '${model.name} (${model.params}) excede la RAM típica de este '
          'dispositivo y hará el chat lento (thrashing). Solo para '
          'batch/experimental. ¿Continuar de todos modos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usar de todos modos'),
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

  /// MODELS-CAT-01 — selector de carpeta de descarga (file_picker). Devuelve
  /// un directorio real del storage externo (MANAGE concedido): las descargas
  /// quedan ahí de forma permanente. Cancelar no cambia nada.
  Future<void> _pickDownloadDir() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || !mounted) return;
    await ref.read(modelsProvider.notifier).setDownloadDir(path);
  }

  int _listRank(LocalModel model, DashboardState dashboard) {
    if (model.active) return 0;
    if (model.installed) return 1;
    if (model.downloadState == ModelDownloadState.downloading) return 2;
    if (model.downloadState == ModelDownloadState.verifying) return 3;
    final viability = _modelViability(model, dashboard);
    if (viability == ModelViability.fast) return 4;
    if (viability == ModelViability.balanced) return 5;
    if (viability == ModelViability.streaming) return 6;
    return 7;
  }
}

class _UnifiedModelItem {
  final DetectedModel? detected;
  final LocalModel? catalog;

  const _UnifiedModelItem.detected(this.detected) : catalog = null;
  const _UnifiedModelItem.catalog(this.catalog) : detected = null;

  bool get isDetected => detected != null;
}

ModelUiStatus _statusOf(LocalModel model, DashboardState dashboard) {
  if (model.active) return ModelUiStatus.active;
  if (model.downloadState == ModelDownloadState.downloading) {
    return ModelUiStatus.downloading;
  }
  if (model.downloadState == ModelDownloadState.verifying) {
    return ModelUiStatus.downloading;
  }
  if (model.downloadState == ModelDownloadState.failed) {
    return ModelUiStatus.error;
  }
  if (model.installed) return ModelUiStatus.installed;
  // D1 — se compara contra RAM TOTAL del device (dato estable). Un modelo
  // cuyo footprint estimado supera la RAM total no cabe ni con streaming:
  // marcarlo incompatible evita descargar algo condenado a OOM.
  if (dashboard.ramTotalGb > 0 && model.ramGb > dashboard.ramTotalGb) {
    return ModelUiStatus.incompatible;
  }
  return ModelUiStatus.available;
}

enum ModelUiStatus {
  active,
  installed,
  available,
  downloading,
  error,
  incompatible,
}

/// Gate R9 — etiqueta del tier de rendimiento para el badge de la tarjeta.
String _tierLabel(ModelTier tier) => switch (tier) {
  ModelTier.interactive => 'INTERACTIVE',
  ModelTier.deep => 'DEEP',
  ModelTier.extreme => 'EXTREME',
};

/// Color del badge de tier: verde (interactive), ámbar (deep), rojo (extreme).
Color _tierColor(ModelTier tier, NanoColors colors) => switch (tier) {
  ModelTier.interactive => colors.accentMint,
  ModelTier.deep => colors.warning,
  ModelTier.extreme => colors.error,
};

class _EmptySearchResults extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const _EmptySearchResults({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniIcon(
              icon: Icons.search_off_rounded,
              color: colors.accentSky,
              size: 52,
              iconSize: 24,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin resultados',
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              query.isEmpty
                  ? 'No hay modelos que coincidan con el filtro seleccionado.'
                  : 'No se encontraron modelos para "$query".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            _PillButton(
              label: 'Restablecer filtros',
              onPressed: onClear,
              accent: colors.accentSky,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return NanoOpticalSurface(
      geometry: NanoSurfaceGeometry.circle,
      blurSigma: 8,
      borderStrength: 0.60,
      reflectionStrength: 0.40,
      accent: color,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}

// =============================================================
// MODEL CARD CON IDENTIDAD DE MARCA Y BADGES ORGANIZADOS
// =============================================================

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.name,
    required this.quantization,
    required this.sizeGb,
    required this.description,
    required this.error,
    required this.status,
    required this.viability,
    required this.tier,
    required this.ramNote,
    required this.progress,
    required this.reflectionController,
    required this.onTapDetails,
    required this.onUse,
    required this.onDownload,
    required this.onCancel,
  });

  final String name;
  final String quantization;
  final double sizeGb;
  final String description;
  final String? error;
  final ModelUiStatus status;
  final ModelViability viability;
  final ModelTier tier;
  final String? ramNote;
  final double progress;
  final AnimationController reflectionController;
  final VoidCallback onTapDetails;
  final VoidCallback onUse;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final mediaSize = MediaQuery.sizeOf(context);
    final denseLandscape =
        mediaSize.width > mediaSize.height && mediaSize.height < 520;
    final accent = _statusColor(status, colors);

    final icon = FloatingModelIcon(
      active: status == ModelUiStatus.active,
      child: ModelBrandLogo(name: name),
    );

    return Semantics(
      label: '$name, ${_statusLabel(status)}',
      child: AnimatedActiveBorder(
        active: status == ModelUiStatus.active,
        borderRadius: _M3.cardRadius,
        child: RepaintBoundary(
          child: NanoOpticalSurface(
            borderRadius: _M3.cardRadius,
            blurSigma: status == ModelUiStatus.active ? 18 : 14,
            hasBackdropBlur: false,
            borderStrength: status == ModelUiStatus.active ? 0.90 : 0.70,
            reflectionStrength: status == ModelUiStatus.active ? 0.85 : 0.50,
            accent: accent,
            reflectionController: reflectionController,
            onTap: onTapDetails,
            padding: EdgeInsets.all(denseLandscape ? 8 : 13),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 310;
                final isDense = denseLandscape || compact;

                final details = _ModelDetails(
                  name: name,
                  quantization: quantization,
                  sizeGb: sizeGb,
                  description: description,
                  error: error,
                  status: status,
                  viability: viability,
                  tier: tier,
                  ramNote: ramNote,
                  progress: progress,
                  accent: accent,
                  dense: isDense,
                );

                final action = _ModelAction(
                  status: status,
                  onUse: onUse,
                  onDownload: onDownload,
                  onCancel: onCancel,
                  dense: isDense,
                );

                if (denseLandscape) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox.square(
                              dimension: 34,
                              child: FittedBox(child: icon),
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: details),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Align(alignment: Alignment.centerRight, child: action),
                    ],
                  );
                }

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox.square(
                            dimension: isDense ? 36 : 44,
                            child: FittedBox(child: icon),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: details),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerRight, child: action),
                    ],
                  );
                }

                return Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    action,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// DETALLES Y BADGES EN MODEL CARD
// =============================================================

class _ModelDetails extends StatelessWidget {
  const _ModelDetails({
    required this.name,
    required this.quantization,
    required this.sizeGb,
    required this.description,
    required this.error,
    required this.status,
    required this.viability,
    required this.tier,
    required this.ramNote,
    required this.progress,
    required this.accent,
    this.dense = false,
  });

  final String name;
  final String quantization;
  final double sizeGb;
  final String description;
  final String? error;
  final ModelUiStatus status;
  final ModelViability viability;
  final ModelTier tier;
  final String? ramNote;
  final double progress;
  final Color accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final (familyColor, familyLabel) = ModelBrandLogo.familyMetaFor(
      name,
      colors,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Badge de Familia
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: familyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: familyColor.withValues(alpha: 0.45),
                  width: 0.7,
                ),
              ),
              child: Text(
                familyLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: NanoTextColors.forText(familyColor, colors),
                  fontSize: dense ? 7 : 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            SizedBox(width: dense ? 3 : 6),
            Expanded(
              child: Text(
                name,
                // Nombre del modelo: 2 líneas — un título no debe cortarse
                // (el grid reserva altura para el wrap, ver mainAxisExtent).
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.textPrimary,
                  fontSize: dense ? 11.5 : _M3.titleSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            SizedBox(width: dense ? 2 : 4),
            Icon(
              Icons.info_outline_rounded,
              size: dense ? 11 : 14,
              color: colors.accentSky.withValues(alpha: 0.7),
            ),
          ],
        ),
        SizedBox(height: dense ? 2 : 4),
        Wrap(
          spacing: dense ? 3 : 6,
          runSpacing: dense ? 2 : 4,
          children: [
            _StatusChip(
              label: _statusLabel(status),
              color: accent,
              dense: dense,
            ),
            _StatusChip(
              label: _tierLabel(tier),
              color: _tierColor(tier, colors),
              dense: dense,
            ),
            if (quantization.isNotEmpty)
              _StatusChip(
                label: quantization,
                color: colors.accentSky,
                dense: dense,
              ),
            _StatusChip(
              label: _viabilityLabel(viability),
              color: _viabilityColor(viability, colors),
              dense: dense,
            ),
          ],
        ),
        SizedBox(height: dense ? 2 : 5),
        if (ramNote != null)
          Text(
            ramNote!,
            maxLines: dense ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              color: NanoTextColors.forText(colors.warning, colors),
              fontSize: dense ? 8.5 : 11.5,
              fontWeight: FontWeight.w500,
            ),
          )
        else if (status == ModelUiStatus.error && error != null)
          Text(
            error!,
            maxLines: dense ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              color: NanoTextColors.forText(colors.error, colors),
              fontSize: dense ? 8.5 : 11.5,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text(
            '${formatGb(sizeGb)} · $description',
            // Descripción: 2 líneas — información, no label corto.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              color: colors.textSecondary,
              fontSize: dense ? 8.5 : 11.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        if (status == ModelUiStatus.downloading) ...[
          SizedBox(height: dense ? 3 : 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: dense ? 3 : 5,
              color: colors.metalSilver.withValues(alpha: 0.40),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 260),
                curve: NanoMotionCurves.standardDecel,
                builder: (_, value, child) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: LinearGradient(
                        colors: [accent, colors.accentCyan],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final chip = Container(
      key: ValueKey(label),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 4 : 7,
        vertical: dense ? 1 : 2.5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: _M3.chipRadius,
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          color: NanoTextColors.forText(color, colors),
          fontSize: dense ? 7.5 : 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return chip;

    return AnimatedSwitcher(
      duration: NanoMotionDurations.quick,
      switchInCurve: NanoMotionCurves.standardDecel,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.90, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: chip,
    );
  }
}

// =============================================================
// ACCIONES DE MODELO Y BOTONES
// =============================================================

class _ModelAction extends StatelessWidget {
  const _ModelAction({
    required this.status,
    required this.onUse,
    required this.onDownload,
    required this.onCancel,
    this.dense = false,
  });

  final ModelUiStatus status;
  final VoidCallback onUse;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final accent = _statusColor(status, colors);

    switch (status) {
      case ModelUiStatus.active:
        return NanoOpticalSurface(
          geometry: NanoSurfaceGeometry.circle,
          blurSigma: 8,
          borderStrength: 0.80,
          reflectionStrength: 0.60,
          accent: colors.accentMint,
          child: SizedBox(
            width: dense ? 28 : 36,
            height: dense ? 28 : 36,
            child: Icon(
              Icons.check_rounded,
              color: colors.accentMint,
              size: dense ? 16 : 20,
            ),
          ),
        );

      case ModelUiStatus.installed:
        return _PillButton(
          label: 'Usar',
          accent: accent,
          onPressed: onUse,
          dense: dense,
        );

      case ModelUiStatus.available:
        return _PillButton(
          label: 'Descargar',
          accent: accent,
          onPressed: onDownload,
          dense: dense,
        );

      case ModelUiStatus.downloading:
        return NanoOpticalSurface(
          geometry: NanoSurfaceGeometry.circle,
          blurSigma: 8,
          borderStrength: 0.70,
          reflectionStrength: 0.50,
          accent: accent,
          onTap: onCancel,
          child: SizedBox(
            width: dense ? 28 : 36,
            height: dense ? 28 : 36,
            child: Icon(
              Icons.close_rounded,
              size: dense ? 15 : 18,
              color: accent,
            ),
          ),
        );

      case ModelUiStatus.error:
        return _PillButton(
          label: 'Reintentar',
          accent: accent,
          onPressed: onDownload,
          dense: dense,
        );

      case ModelUiStatus.incompatible:
        return _PillButton(
          label: 'Descargar',
          accent: accent,
          onPressed: onDownload,
          dense: dense,
        );
    }
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onPressed,
    this.accent,
    this.dense = false,
  });

  final String label;
  final VoidCallback onPressed;
  final Color? accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final buttonAccent = accent ?? colors.accentSky;

    return NanoOpticalSurface(
      geometry: NanoSurfaceGeometry.capsule,
      blurSigma: 10,
      borderStrength: 0.75,
      reflectionStrength: 0.60,
      accent: buttonAccent,
      onTap: onPressed,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 14,
        vertical: dense ? 4 : 7,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: dense ? 9.5 : 12,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

// =============================================================
// DETECTED CARD (LOCAL / SD CARD)
// =============================================================

class _DetectedCard extends StatelessWidget {
  const _DetectedCard({
    required this.model,
    required this.loading,
    required this.active,
    required this.reflectionController,
    required this.onTapDetails,
    required this.onUse,
  });

  final DetectedModel model;
  final bool loading;
  final bool active;
  final AnimationController reflectionController;
  final VoidCallback onTapDetails;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final mediaSize = MediaQuery.sizeOf(context);
    final denseLandscape =
        mediaSize.width > mediaSize.height && mediaSize.height < 520;

    return Semantics(
      label: '${model.name}, detectado en memoria${active ? ', activo' : ''}',
      child: AnimatedActiveBorder(
        active: active,
        borderRadius: _M3.compactRadius,
        child: RepaintBoundary(
          child: NanoOpticalSurface(
            borderRadius: _M3.compactRadius,
            blurSigma: active ? 16 : 12,
            hasBackdropBlur: false,
            borderStrength: active ? 0.85 : 0.65,
            reflectionStrength: active ? 0.75 : 0.45,
            accent: active ? colors.accentMint : colors.accentMint,
            reflectionController: reflectionController,
            onTap: onTapDetails,
            padding: EdgeInsets.all(denseLandscape ? 8 : 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 310;
                final isDense = denseLandscape || compact;

                final iconWidget = SizedBox.square(
                  dimension: isDense ? 34 : 48,
                  child: FittedBox(child: ModelBrandLogo(name: model.name)),
                );

                final detailsWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            model.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: colors.textPrimary,
                              fontSize: isDense ? 11.5 : 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        SizedBox(width: isDense ? 2 : 4),
                        Icon(
                          Icons.info_outline_rounded,
                          size: isDense ? 11 : 14,
                          color: colors.accentMint,
                        ),
                      ],
                    ),
                    SizedBox(height: isDense ? 2 : 4),
                    Wrap(
                      spacing: isDense ? 3 : 6,
                      runSpacing: isDense ? 2 : 4,
                      children: [
                        _StatusChip(
                          label: 'MEMORIA SD',
                          color: colors.accentMint,
                          dense: isDense,
                        ),
                        if (active)
                          _StatusChip(
                            label: 'ACTIVO',
                            color: colors.accentSky,
                            dense: isDense,
                          ),
                        _StatusChip(
                          label: model.format.name.toUpperCase(),
                          color: colors.accentSky,
                          dense: isDense,
                        ),
                      ],
                    ),
                    SizedBox(height: isDense ? 2 : 4),
                    Text(
                      model.sizeBytes > 0
                          ? formatBytes(model.sizeBytes)
                          : 'Archivo local en SD / almacenamiento',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.textSecondary,
                        fontSize: isDense ? 8.5 : 11.5,
                      ),
                    ),
                    if (model.path != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        model.path!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          color: colors.textSecondary.withValues(alpha: 0.65),
                          fontSize: isDense ? 8 : 9.5,
                        ),
                      ),
                    ],
                  ],
                );

                final actionWidget = loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.accentMint,
                        ),
                      )
                    : !model.usable
                    ? _StatusChip(
                        label: 'GGUF INVÁLIDO',
                        color: colors.error,
                        dense: isDense,
                      )
                    : active
                    ? NanoOpticalSurface(
                        geometry: NanoSurfaceGeometry.circle,
                        blurSigma: 8,
                        borderStrength: 0.80,
                        reflectionStrength: 0.60,
                        accent: colors.accentMint,
                        child: SizedBox(
                          width: isDense ? 28 : 34,
                          height: isDense ? 28 : 34,
                          child: Icon(
                            Icons.check_rounded,
                            color: colors.accentMint,
                            size: isDense ? 15 : 18,
                          ),
                        ),
                      )
                    : _PillButton(
                        label: 'Cargar',
                        accent: colors.accentMint,
                        onPressed: onUse!,
                        dense: isDense,
                      );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          iconWidget,
                          const SizedBox(width: 8),
                          Expanded(child: detailsWidget),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: actionWidget,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    iconWidget,
                    SizedBox(width: isDense ? 6 : 12),
                    Expanded(child: detailsWidget),
                    SizedBox(width: isDense ? 4 : 8),
                    actionWidget,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// ESTADO VACÍO & ALMACENAMIENTO
// =============================================================

class _EmptyModels extends StatelessWidget {
  const _EmptyModels();

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniIcon(
            icon: Icons.folder_off_rounded,
            color: colors.accentSky,
            size: 52,
            iconSize: 24,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin modelos',
            style: TextStyle(
              fontFamily: 'Inter',
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Concede acceso al storage o descarga un GGUF del catálogo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              color: colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageUsage extends StatelessWidget {
  const _StorageUsage({
    required this.usedGb,
    required this.storageTotalGb,
    required this.storageFreeGb,
  });

  final double usedGb;
  final double storageTotalGb;
  final double storageFreeGb;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final usedPct = storageTotalGb > 0 ? usedGb / storageTotalGb : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: NanoOpticalSurface(
        borderRadius: _M3.barRadius,
        blurSigma: 12,
        borderStrength: 0.60,
        reflectionStrength: 0.40,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Almacenamiento',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${formatGb(usedGb)} de ${formatGb(storageTotalGb)}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 5,
                color: colors.metalSilver.withValues(alpha: 0.40),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: usedPct.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: usedPct > 0.9
                          ? colors.error
                          : usedPct > 0.7
                          ? colors.warning
                          : colors.accentMint,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${formatGb(storageFreeGb)} libres',
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatGb(double gb) {
  if (gb < 1.0) {
    return '${(gb * 1024).toStringAsFixed(0)} MB';
  }
  return '${gb.toStringAsFixed(1)} GB';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024)
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _viabilityLabel(ModelViability v) {
  switch (v) {
    case ModelViability.fast:
      return 'RÁPIDO';
    case ModelViability.balanced:
      return 'EQUILIBRADO';
    case ModelViability.streaming:
      return 'STREAMING';
    case ModelViability.extreme:
      return 'EXTREMO';
  }
}

Color _viabilityColor(ModelViability v, NanoColors colors) {
  switch (v) {
    case ModelViability.fast:
      return colors.accentMint;
    case ModelViability.balanced:
      return colors.accentSky;
    case ModelViability.streaming:
      return colors.warning;
    case ModelViability.extreme:
      return colors.error;
  }
}

Color _statusColor(ModelUiStatus status, NanoColors colors) {
  switch (status) {
    case ModelUiStatus.active:
      return colors.accentMint;
    case ModelUiStatus.installed:
      return colors.accentSky;
    case ModelUiStatus.available:
      return colors.accentLavender;
    case ModelUiStatus.downloading:
      return colors.warning;
    case ModelUiStatus.error:
      return colors.error;
    case ModelUiStatus.incompatible:
      return colors.warning;
  }
}

String _statusLabel(ModelUiStatus status) {
  switch (status) {
    case ModelUiStatus.active:
      return 'ACTIVO';
    case ModelUiStatus.installed:
      return 'INSTALADO';
    case ModelUiStatus.available:
      return 'DISPONIBLE';
    case ModelUiStatus.downloading:
      return 'DESCARGANDO';
    case ModelUiStatus.error:
      return 'ERROR';
    case ModelUiStatus.incompatible:
      return 'INCOMPATIBLE';
  }
}

/// MODELS-CAT-01 — barra del destino de descarga: muestra la carpeta elegida
/// (persistida en prefs) y permite cambiarla. Sin carpeta elegida, los GGUF
/// van al storage interno de la app y se pierden al desinstalar.
class _DownloadDirBar extends StatelessWidget {
  const _DownloadDirBar({required this.dir, required this.onPick});

  final String? dir;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Material(
      color: colors.accentSky.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.folder_rounded, size: 18, color: colors.accentSky),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dir == null
                    ? 'Descargas: storage interno de la app'
                    : 'Descargas: $dir',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _PillButton(
              label: dir == null ? 'Elegir carpeta' : 'Cambiar',
              accent: colors.accentSky,
              dense: true,
              onPressed: onPick,
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner de "conceder acceso a todos los archivos" (P7): en Android 11+
/// escanear /storage/emulated/0 requiere MANAGE_EXTERNAL_STORAGE, que no se
/// concede en runtime. Guía al usuario al ajuste exacto con un solo toque.
class _AllFilesBanner extends StatelessWidget {
  const _AllFilesBanner({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Material(
      color: colors.warning.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Acceso al storage no concedido — no se detectan tus modelos.',
                style: TextStyle(
                  color: NanoTextColors.forText(colors.warning, colors),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: onGrant, child: const Text('Conceder')),
          ],
        ),
      ),
    );
  }
}
