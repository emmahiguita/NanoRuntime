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

    // Auto-escaneo del storage SAF al entrar: no-op si no hay árbol
    // concedido o si el último escaneo tiene menos de 30 s.
    ref.read(modelsProvider.notifier).maybeAutoScan();
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
      body: Column(
        children: [
          _ModelsSummary(
            installedCount: installedModels.length,
            usedGb: usedGb,
          ),
          const SizedBox(height: 12),
          _ScanBar(
            scanning: state.scanning,
            treeGranted: state.treeGranted,
            detectedCount: detected.length,
            error: state.scanError,
            onPickTree: notifier.pickTreeAndScan,
            onRescan: notifier.scanStorage,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              itemCount: state.models.length + detected.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index >= state.models.length) {
                  // Modelo detectado en storage SAF: se usa directo desde su
                  // ubicación original (fd por Binder, cero copias).
                  final detectedModel = detected[index - state.models.length];
                  return _DetectedCard(
                    model: detectedModel,
                    loading: state.loadingDetectedUri == detectedModel.uri,
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
                      ? 'Requiere ${model.ramGb.toStringAsFixed(0)} GB de '
                            'RAM libre (hay '
                            '${dashboard.ramFreeGb.toStringAsFixed(1)})'
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
              },
            ),
          ),
          _StorageUsage(
            usedGb: usedGb,
            storageTotalGb: dashboard.storageTotalGb,
            storageFreeGb: dashboard.storageFreeGb,
          ),
        ],
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
  const _ModelsSummary({required this.installedCount, required this.usedGb});

  final int installedCount;
  final double usedGb;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 0),
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
              installedCount == 0 || usedGb <= 0
                  ? '$installedCount instalados · —'
                  : '$installedCount instalados · '
                        '${formatGb(usedGb)}',
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
      child: const _ModelIcon(),
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
  const _ModelIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const Icon(
        Icons.view_in_ar_rounded,
        color: Colors.white,
        size: 38,
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

/// Barra de escaneo del storage SAF. Tres estados honestos:
/// escaneando (spinner), sin permiso (botón "Escanear storage" que abre el
/// selector de carpeta) o concedido (N detectados + re-escanear). El error
/// del último escaneo se muestra debajo.
class _ScanBar extends StatelessWidget {
  const _ScanBar({
    required this.scanning,
    required this.treeGranted,
    required this.detectedCount,
    required this.error,
    required this.onPickTree,
    required this.onRescan,
  });

  final bool scanning;
  final bool treeGranted;
  final int detectedCount;
  final String? error;
  final VoidCallback onPickTree;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (scanning) {
      content = const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF42D9FF),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Escaneando storage...',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      );
    } else if (!treeGranted) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final label = const Row(
            children: [
              Icon(Icons.folder_open_rounded, color: Color(0xFF42D9FF)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Detecta GGUF en todo el storage',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          );
          final button = PressableScale(
            child: OutlinedButton(
              onPressed: onPickTree,
              child: const Text('Escanear storage'),
            ),
          );

          // En pantallas angostas el botón no cabe junto al texto: baja a
          // su propia fila (mismo patrón que _ModelCard).
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            );
          }
          return Row(children: [label, button]);
        },
      );
    } else {
      content = Row(
        children: [
          const Icon(Icons.sd_storage_rounded, color: Color(0xFF42D9FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              detectedCount == 0
                  ? 'Ningún GGUF/safetensors/onnx detectado'
                  : '$detectedCount detectados en storage',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          IconButton(
            tooltip: 'Re-escanear',
            onPressed: onRescan,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF42D9FF)),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF07192B).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9B8AFF).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFFF5C6C), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card de un modelo detectado en el storage SAF. "Usar directo" abre el fd
/// en el worker y arranca el engine desde la ubicación original; si el
/// archivo no pasó la verificación (magic GGUF o formato no engine), se
/// muestra NO USABLE — honesto, sin botones muertos.
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
    final accent = model.usable
        ? const Color(0xFF21F2B2)
        : const Color(0xFFFFA726);

    final sizeLabel = model.sizeBytes > 0
        ? formatGb(model.sizeBytes / 1e9)
        : 'tamaño desconocido';

    return Semantics(
      label: '${model.name}, detectado en storage',
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF07192B).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withValues(alpha: 0.55)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.folder_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 14),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _StatusChip(
                              label: model.usable ? 'DETECTADO' : 'NO USABLE',
                              color: accent,
                            ),
                            _StatusChip(
                              label: model.format.name.toUpperCase(),
                              color: const Color(0xFF9B8AFF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          sizeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (model.usable)
                    loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF21F2B2),
                            ),
                          )
                        : PressableScale(
                            child: OutlinedButton(
                              onPressed: onUse,
                              child: const Text('Usar directo'),
                            ),
                          ),
                ],
              ),
            ),
          ),
        ),
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
    // Pie con datos REALES del device: GB usados por los modelos instalados
    // y GB libres reportados por el dashboard. La barra es esa proporción.
    final hasFreeData = storageTotalGb > 0;
    final totalGb = usedGb + storageFreeGb;
    final fraction = hasFreeData && totalGb > 0
        ? (usedGb / totalGb).clamp(0.0, 1.0)
        : null;

    final text = hasFreeData
        ? '${formatGb(usedGb)} usados por modelos · '
              '${_formatFreeGb(storageFreeGb)} libres'
        : usedGb > 0
        ? 'Espacio usado por modelos: ${formatGb(usedGb)}'
        : 'Espacio usado por modelos: —';

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF07192B).withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6592FF).withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage_rounded, color: Color(0xFF42D9FF)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            if (fraction != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                color: const Color(0xFF42D9FF),
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatFreeGb(double gb) {
  if (gb <= 0) return '—';
  if (gb >= 10) return '${gb.toStringAsFixed(0)} GB';
  return '${gb.toStringAsFixed(1)} GB';
}

String _statusLabel(ModelUiStatus status) {
  return switch (status) {
    ModelUiStatus.active => 'ACTIVO',
    ModelUiStatus.installed => 'INSTALADO',
    ModelUiStatus.available => 'DISPONIBLE',
    ModelUiStatus.downloading => 'DESCARGANDO',
    ModelUiStatus.error => 'ERROR',
    ModelUiStatus.incompatible => 'NO COMPATIBLE',
  };
}

Color _statusColor(ModelUiStatus status) {
  return switch (status) {
    ModelUiStatus.active => const Color(0xFF21F2B2),
    ModelUiStatus.installed => const Color(0xFF42D9FF),
    ModelUiStatus.available => const Color(0xFF9B8AFF),
    ModelUiStatus.downloading => const Color(0xFF6592FF),
    ModelUiStatus.error => const Color(0xFFFF5C6C),
    ModelUiStatus.incompatible => const Color(0xFFFFA726),
  };
}

/// Formato de tamaño real (GB con 1 decimal; MB sin decimales si < 1 GB).
String formatGb(double gb) {
  if (gb <= 0) return '—';
  if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
  return '${(gb * 1024).toStringAsFixed(0)} MB';
}
