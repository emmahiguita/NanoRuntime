import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/dashboard_provider.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/domain/detected_model.dart';
import 'package:nanoai/features/models/domain/local_model.dart';

/// Pantalla Modelos — identidad visual de Inicio (glassmorphism, sin AppBar).
///
/// Nombres reales del dominio: `LocalModel.quant`/`sizeGb`/`active`/
/// `installed`/`downloadState`, `ModelsNotifier.loadModel`/`downloadModel`/
/// `cancelDownload`. Sin datos simulados: compatibilidad RAM derivada de
/// datos reales (ramGb del modelo vs ramFreeGb del dashboard) y pie con
/// almacenamiento real del device.
class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen>
    with SingleTickerProviderStateMixin {
  /// Entrada escalonada de las tarjetas: UN solo controller para toda la
  /// lista (nunca uno por tarjeta). Cada tarjeta mapea su tramo con un
  /// Interval; las primeras entran antes, las últimas terminan después.
  late final AnimationController _entryController;
  bool _entryStarted = false;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // Auto-escaneo de todo el storage al entrar: no-op si el permiso no
    // está concedido o si el último escaneo tiene menos de 30 s.
    ref.read(modelsProvider.notifier).maybeAutoScanAll();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modelsProvider);
    final dashboard = ref.watch(dashboardProvider);
    final notifier = ref.read(modelsProvider.notifier);

    final installedModels = state.models
        .where((model) => model.installed)
        .toList(growable: false);

    final usedGb = installedModels.fold<double>(
      0,
      (total, model) => total + model.sizeGb,
    );

    final detected = state.detected;

    return NanoScreenShell(
      title: 'Modelos',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth >= 640;
          final totalCount = state.models.length + detected.length;

          Widget buildCardAt(int index) {
            if (index >= state.models.length) {
              // Modelo detectado en storage SAF: se usa directo desde su
              // ubicación original (fd por Binder, cero copias).
              final detectedModel = detected[index - state.models.length];
              return _DetectedCard(
                model: detectedModel,
                loading:
                    state.loadingDetectedUri ==
                    (detectedModel.path ?? detectedModel.uri),
                onUse: () => notifier.useDetected(detectedModel),
              );
            }

            final model = state.models[index];
            final status = _statusOf(model, dashboard);

            final card = _ModelCard(
              name: model.name,
              quantization: model.quant,
              sizeGb: model.sizeGb,
              description: model.description,
              error: model.error,
              status: status,
              ramNote: status == ModelUiStatus.incompatible
                  ? 'Requiere ${model.ramGb.toStringAsFixed(0)} GB de RAM (disponible: ${dashboard.ramFreeGb.toStringAsFixed(1)} GB)'
                  : null,
              progress: model.progress,
              onUse: () => notifier.loadModel(model.id),
              onDownload: () => notifier.downloadModel(model.id),
              onCancel: notifier.cancelDownload,
            );

            if (MediaQuery.disableAnimationsOf(context)) return card;

            // Tramo propio del controller compartido: entrada escalonada
            // fade + slide sin crear ningún controller por tarjeta.
            final start = (index * 0.08).clamp(0.0, 0.75);
            final end = (start + 0.22).clamp(0.0, 1.0);
            final entry = CurvedAnimation(
              parent: _entryController,
              curve: Interval(start, end, curve: Curves.easeOutCubic),
            );

            return AnimatedBuilder(
              animation: _entryController,
              builder: (_, child) {
                final value = entry.value;
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: card,
            );
          }

          if (isLandscape) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModelsSummary(
                          installedCount: installedModels.length,
                          usedGb: usedGb,
                          margin: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ScanBar(
                          scanning: state.scanning,
                          allFilesGranted: state.allFilesGranted,
                          detectedCount: detected.length,
                          error: state.scanError,
                          margin: EdgeInsets.zero,
                          onGrant: notifier.requestAllFilesAccess,
                          onPickTree: notifier.pickTreeAndScan,
                          onRescan: notifier.scanStorageAll,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth >= 1000 ? 3 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 185,
                    ),
                    itemCount: totalCount,
                    itemBuilder: (context, index) => buildCardAt(index),
                  ),
                ),
                _StorageUsage(
                  usedGb: usedGb,
                  storageTotalGb: dashboard.storageTotalGb,
                  storageFreeGb: dashboard.storageFreeGb,
                ),
              ],
            );
          }

          return Column(
            children: [
              _ModelsSummary(
                installedCount: installedModels.length,
                usedGb: usedGb,
              ),
              const SizedBox(height: 12),
              _ScanBar(
                scanning: state.scanning,
                allFilesGranted: state.allFilesGranted,
                detectedCount: detected.length,
                error: state.scanError,
                onGrant: notifier.requestAllFilesAccess,
                onPickTree: notifier.pickTreeAndScan,
                onRescan: notifier.scanStorageAll,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  itemCount: totalCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => buildCardAt(index),
                ),
              ),
              _StorageUsage(
                usedGb: usedGb,
                storageTotalGb: dashboard.storageTotalGb,
                storageFreeGb: dashboard.storageFreeGb,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Estado visual derivado SOLO de campos reales del dominio.
  /// El activo es `LocalModel.active`; el instalado, el getter `installed`
  /// (downloadState == installed, GGUF verificado por el notifier).
  /// El NO COMPATIBLE compara el requisito real del modelo (ramGb) contra
  /// la RAM libre real reportada por el dashboard — sin inventar datos.
  ModelUiStatus _statusOf(LocalModel model, DashboardState dashboard) {
    if (model.downloadState == ModelDownloadState.failed) {
      return ModelUiStatus.error;
    }
    if (model.downloadState == ModelDownloadState.downloading ||
        model.downloadState == ModelDownloadState.verifying) {
      return ModelUiStatus.downloading;
    }
    if (model.active) return ModelUiStatus.active;
    if (model.installed) return ModelUiStatus.installed;
    if (dashboard.ramTotalGb > 0 && model.ramGb > dashboard.ramFreeGb) {
      return ModelUiStatus.incompatible;
    }
    return ModelUiStatus.available;
  }
}

enum ModelUiStatus {
  active,
  installed,
  available,
  downloading,
  error,
  incompatible,
}

class _ModelsSummary extends StatelessWidget {
  const _ModelsSummary({
    required this.installedCount,
    required this.usedGb,
    this.margin,
  });

  final int installedCount;
  final double usedGb;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(18, 4, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF07192B).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF42D9FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.view_in_ar_rounded, color: Color(0xFF42D9FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              installedCount == 1
                  ? '1 instalado · ${usedGb <= 0 ? '0 GB' : formatGb(usedGb)}'
                  : '$installedCount instalados · ${usedGb <= 0 ? '0 GB' : formatGb(usedGb)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.name,
    required this.quantization,
    required this.sizeGb,
    required this.description,
    required this.error,
    required this.status,
    required this.ramNote,
    required this.progress,
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
  final String? ramNote;
  final double progress;
  final VoidCallback onUse;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final accent = _statusColor(status);

    // El icono del modelo activo flota ±2px (FloatingModelIcon).
    final icon = FloatingModelIcon(
      active: status == ModelUiStatus.active,
      child: _ModelIcon(name: name),
    );

    return Semantics(
      label: '$name, ${_statusLabel(status)}',
      child: AnimatedActiveBorder(
        active: status == ModelUiStatus.active,
        borderRadius: 18,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: status == ModelUiStatus.active
                      ? const Color(0xFF005840).withValues(alpha: 0.62)
                      : const Color(0xFF07192B).withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.62)),
                  boxShadow: status == ModelUiStatus.active
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.16),
                            blurRadius: 18,
                          ),
                        ]
                      : null,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // En pantallas angostas la acción (botón/check) no cabe
                    // junto al icono de 66px: baja a su propia fila.
                    final compact = constraints.maxWidth < 310;

                    final details = _ModelDetails(
                      name: name,
                      quantization: quantization,
                      sizeGb: sizeGb,
                      description: description,
                      error: error,
                      status: status,
                      ramNote: ramNote,
                      progress: progress,
                      accent: accent,
                    );

                    final action = _ModelAction(
                      status: status,
                      onUse: onUse,
                      onDownload: onDownload,
                      onCancel: onCancel,
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              icon,
                              const SizedBox(width: 14),
                              Expanded(child: details),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: action,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        icon,
                        const SizedBox(width: 14),
                        Expanded(child: details),
                        const SizedBox(width: 10),
                        action,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelIcon extends StatelessWidget {
  const _ModelIcon({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final lowerName = name.toLowerCase();
    final IconData iconData;
    if (lowerName.contains('deepseek') || lowerName.contains('r1')) {
      iconData = Icons.psychology_rounded;
    } else if (lowerName.contains('coder') || lowerName.contains('code')) {
      iconData = Icons.code_rounded;
    } else if (lowerName.contains('gemma')) {
      iconData = Icons.diamond_rounded;
    } else if (lowerName.contains('llama')) {
      iconData = Icons.smart_toy_rounded;
    } else if (lowerName.contains('phi')) {
      iconData = Icons.auto_awesome_rounded;
    } else if (lowerName.contains('27b') || lowerName.contains('32b')) {
      iconData = Icons.bolt_rounded;
    } else if (lowerName.contains('qwen')) {
      iconData = Icons.hub_rounded;
    } else {
      iconData = Icons.memory_rounded;
    }

    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Icon(
        iconData,
        color: Colors.white,
        size: 36,
      ),
    );
  }
}

/// Columna informativa de la card (nombre, chips, tamaño, progreso).
class _ModelDetails extends StatelessWidget {
  const _ModelDetails({
    required this.name,
    required this.quantization,
    required this.sizeGb,
    required this.description,
    required this.error,
    required this.status,
    required this.ramNote,
    required this.progress,
    required this.accent,
  });

  final String name;
  final String quantization;
  final double sizeGb;
  final String description;
  final String? error;
  final ModelUiStatus status;
  final String? ramNote;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            _StatusChip(label: _statusLabel(status), color: accent),
            if (quantization.isNotEmpty)
              _StatusChip(label: quantization, color: const Color(0xFF42D9FF)),
          ],
        ),
        const SizedBox(height: 7),
        if (ramNote != null)
          Text(
            ramNote!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFFFA726), fontSize: 12),
          )
        else if (status == ModelUiStatus.error && error != null)
          Text(
            error!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFFF5C6C), fontSize: 12),
          )
        else
          Text(
            '${formatGb(sizeGb)} · $description',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
        if (status == ModelUiStatus.downloading) ...[
          const SizedBox(height: 10),
          if (MediaQuery.disableAnimationsOf(context))
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              color: accent,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
            )
          else
            TweenAnimationBuilder<double>(
              // El progreso de descarga avanza con suavidad hacia cada
              // nuevo valor real reportado por el notifier.
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              builder: (_, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                color: accent,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      key: ValueKey(label),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return chip;

    // Cambio de estado (INSTALADO → ACTIVO, etc.) con fade + escala suave.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: chip,
    );
  }
}

class _ModelAction extends StatelessWidget {
  const _ModelAction({
    required this.status,
    required this.onUse,
    required this.onDownload,
    required this.onCancel,
  });

  final ModelUiStatus status;
  final VoidCallback onUse;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ModelUiStatus.active:
        return const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF21F2B2),
          size: 30,
        );

      case ModelUiStatus.installed:
        return PressableScale(
          child: OutlinedButton(onPressed: onUse, child: const Text('Usar')),
        );

      case ModelUiStatus.available:
        return PressableScale(
          child: OutlinedButton(
            onPressed: onDownload,
            child: const Text('Descargar'),
          ),
        );

      case ModelUiStatus.downloading:
        return PressableScale(
          child: IconButton(
            tooltip: 'Cancelar descarga',
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
          ),
        );

      case ModelUiStatus.error:
        return PressableScale(
          child: OutlinedButton(
            onPressed: onDownload,
            child: const Text('Reintentar'),
          ),
        );

      case ModelUiStatus.incompatible:
        // Sin acción: no se puede descargar un modelo que no cabe en la
        // RAM libre real del device.
        return const Icon(
          Icons.block_rounded,
          color: Color(0xFFFFA726),
          size: 28,
        );
    }
  }
}

/// Barra del scanner automático del storage. Estados honestos:
/// scanning=true (ocupado), detectedCount>0 (resultados), error!=null
/// (fallo SAF), allFilesGranted=false (falta permiso).
class _ScanBar extends StatelessWidget {
  const _ScanBar({
    required this.scanning,
    required this.allFilesGranted,
    required this.detectedCount,
    required this.error,
    this.margin,
    required this.onGrant,
    required this.onPickTree,
    required this.onRescan,
  });

  final bool scanning;
  final bool allFilesGranted;
  final int detectedCount;
  final String? error;
  final EdgeInsetsGeometry? margin;
  final VoidCallback onGrant;
  final VoidCallback onPickTree;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF07192B).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error != null
              ? const Color(0xFFFF5C6C).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            scanning
                ? Icons.refresh_rounded
                : detectedCount > 0
                    ? Icons.folder_open_rounded
                    : Icons.folder_off_rounded,
            size: 20,
            color: error != null
                ? const Color(0xFFFF5C6C)
                : Colors.white.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error ??
                  (scanning
                      ? 'Buscando modelos en el dispositivo...'
                      : detectedCount > 0
                          ? (detectedCount == 1
                              ? '1 modelo local detectado'
                              : '$detectedCount modelos locales detectados')
                          : 'No se encontraron modelos locales'),
              style: TextStyle(
                color: error != null
                    ? const Color(0xFFFF5C6C)
                    : Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
              ),
            ),
          ),
          if (!allFilesGranted)
            PressableScale(
              child: TextButton(
                onPressed: onGrant,
                child: const Text('Dar permiso'),
              ),
            )
          else if (error != null)
            PressableScale(
              child: TextButton(
                onPressed: onPickTree,
                child: const Text('Elegir carpeta'),
              ),
            )
          else if (!scanning)
            PressableScale(
              child: TextButton(
                onPressed: onRescan,
                child: const Text('Reescanear'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card de modelo detectado por SAF (sin instalación: uso directo desde su
/// ubicación original). Botón CARGAR invoca `useDetected`.
class _DetectedCard extends StatelessWidget {
  const _DetectedCard({
    required this.model,
    required this.loading,
    required this.onUse,
  });

  final DetectedModel model;
  final bool loading;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF07192B).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  model.sizeBytes > 0
                      ? formatBytes(model.sizeBytes)
                      : 'Tamaño desconocido',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF42D9FF),
              ),
            )
          else
            PressableScale(
              child: OutlinedButton(
                onPressed: onUse,
                child: const Text('Cargar'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pie de la pantalla con uso de almacenamiento real del device.
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
    final usedPct = storageTotalGb > 0 ? usedGb / storageTotalGb : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF07192B).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
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
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
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
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: usedPct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                usedPct > 0.9
                    ? const Color(0xFFFF5C6C)
                    : usedPct > 0.7
                        ? const Color(0xFFFFA726)
                        : const Color(0xFF21F2B2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatGb(storageFreeGb)} libres',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 11,
            ),
          ),
        ],
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
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

Color _statusColor(ModelUiStatus status) {
  switch (status) {
    case ModelUiStatus.active:
      return const Color(0xFF21F2B2);
    case ModelUiStatus.installed:
      return const Color(0xFF42D9FF);
    case ModelUiStatus.available:
      return const Color(0xFFA78BFA);
    case ModelUiStatus.downloading:
      return const Color(0xFFFFA726);
    case ModelUiStatus.error:
      return const Color(0xFFFF5C6C);
    case ModelUiStatus.incompatible:
      return const Color(0xFFFFA726);
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
