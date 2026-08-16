import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/dashboard_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/domain/detected_model.dart';
import 'package:nanoai/features/models/domain/local_model.dart';

/// Tokens locales Material 3 Expressive aplicados SOLO a este módulo.
///
/// M3E: formas más grandes y pill-shaped (superficies de radio amplio,
/// chips y botones stadium), color saturado en superficies de acción
/// (FilledButtons con accent + texto oscuro), tipografía con más peso y
/// motion con énfasis (curvas con overshoot en entradas y cambios de estado).
class _M3 {
  // Shape — radios mayores que M3 base, camino a squircle.
  static const cardRadius = 24.0;
  static const compactRadius = 22.0;
  static const barRadius = 18.0;
  static const iconRadius = 16.0;
  static const chipRadius = BorderRadius.all(Radius.circular(999));

  // Typography — display con más peso.
  static const titleSize = 18.0;

  // Motion — énfasis: overshoot sutil en entradas y cambios de estado.
  static const pressScale = 0.94;
}

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

    // Auto-escaneo al entrar: primero el de todo el storage (vía principal).
    // Al terminar, si el acceso completo no está concedido, se intenta el
    // auto-escaneo del árbol SAF (maybeAutoScan se salta si scanAll cubrió).
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modelsProvider);
    final dashboard = ref.watch(dashboardProvider);
    final notifier = ref.read(modelsProvider.notifier);

    // Política de lista: DESCARGADOS primero. Activo, instalados y
    // descargas en curso arriba; disponible/incompatible abajo. El sort
    // de Dart es estable — dentro de cada grupo se conserva el orden del
    // catálogo.
    final catalogModels = List<LocalModel>.of(state.models)
      ..sort((a, b) => _listRank(a, dashboard).compareTo(_listRank(b, dashboard)));

    final installedModels = catalogModels
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
          // BUG-FIX orientación: maxWidth >= 640 marcaba "landscape" en
          // portrait de phones anchos (1080px). La orientación real se mide
          // comparando ancho contra alto.
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final totalCount = catalogModels.length + detected.length;

          Widget buildCardAt(int index) {
            if (index >= catalogModels.length) {
              // Modelo detectado en storage SAF: se usa directo desde su
              // ubicación original (fd por Binder, cero copias).
              final detectedModel = detected[index - catalogModels.length];
              return _DetectedCard(
                model: detectedModel,
                loading:
                    state.loadingDetectedUri ==
                    (detectedModel.path ?? detectedModel.uri),
                active: state.activeDetected == detectedModel.name,
                onUse: () => notifier.useDetected(detectedModel),
              );
            }

            final model = catalogModels[index];
            final status = _statusOf(model, dashboard);

            final card = _ModelCard(
              name: model.name,
              quantization: model.quant,
              sizeGb: model.sizeGb,
              description: model.description,
              error: model.error,
              status: status,
              ramNote: status == ModelUiStatus.incompatible
                  ? 'Requiere ${model.ramGb.toStringAsFixed(0)} GB de RAM (dispositivo: ${dashboard.ramTotalGb.toStringAsFixed(1)} GB)'
                  : null,
              progress: model.progress,
              onUse: () => notifier.loadModel(model.id),
              onDownload: () => notifier.downloadModel(model.id),
              onCancel: notifier.cancelDownload,
            );

            if (MediaQuery.disableAnimationsOf(context)) return card;

            // Tramo propio del controller compartido: entrada escalonada
            // fade + slide + escala (M3E emphasis: overshoot sutil).
            final start = (index * 0.08).clamp(0.0, 0.75);
            final end = (start + 0.22).clamp(0.0, 1.0);
            final entry = CurvedAnimation(
              parent: _entryController,
              curve: Interval(start, end, curve: Curves.easeOutBack),
            );

            return AnimatedBuilder(
              animation: _entryController,
              builder: (_, child) {
                final value = entry.value;
                return Opacity(
                  // easeOutBack puede pasar de 1 en el rebote: clamp.
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - value.clamp(0.0, 1.0))),
                    child: Transform.scale(
                      scale: 0.94 + 0.06 * value,
                      child: child,
                    ),
                  ),
                );
              },
              child: card,
            );
          }

          // Resumen y pie SOLO cuando hay algo instalado: con 0 modelos son
          // componentes estáticos que repiten "0 · 0 GB" sin información.
          final hasInstalled = installedModels.isNotEmpty;
          final hasAny = totalCount > 0;

          final summary = _ModelsSummary(
            installedCount: installedModels.length,
            usedGb: usedGb,
          );
          final scanBar = _ScanBar(
            scanning: state.scanning,
            allFilesGranted: state.allFilesGranted,
            treeGranted: state.treeGranted,
            detectedCount: detected.length,
            error: state.scanError,
            onGrant: notifier.requestAllFilesAccess,
            onPickTree: notifier.pickTreeAndScan,
            onRescan: notifier.scanStorageAll,
          );

          if (isLandscape) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  child: Row(
                    children: [
                      if (hasInstalled) ...[
                        Expanded(child: summary),
                        const SizedBox(width: 10),
                      ],
                      Expanded(child: scanBar),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: hasAny
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: constraints.maxWidth >= 1000
                                ? 3
                                : 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 172,
                          ),
                          itemCount: totalCount,
                          itemBuilder: (context, index) => buildCardAt(index),
                        )
                      : const _EmptyModels(),
                ),
                if (hasInstalled)
                  _StorageUsage(
                    usedGb: usedGb,
                    storageTotalGb: dashboard.storageTotalGb,
                    storageFreeGb: dashboard.storageFreeGb,
                    compact: true,
                  ),
              ],
            );
          }

          return Column(
            children: [
              if (hasInstalled) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                  child: summary,
                ),
                const SizedBox(height: 12),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                child: scanBar,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: hasAny
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        itemCount: totalCount,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) => buildCardAt(index),
                      )
                    : const _EmptyModels(),
              ),
              if (hasInstalled)
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
    // Compara contra la RAM TOTAL del device (dato estable): con la RAM
    // libre el estado INCOMPATIBLE parpadeaba según el uso del momento.
    if (dashboard.ramTotalGb > 0 && model.ramGb > dashboard.ramTotalGb) {
      return ModelUiStatus.incompatible;
    }
    return ModelUiStatus.available;
  }

  /// Prioridad de orden en la lista: descargados primero (activo arriba de
  /// todo, luego instalados, luego descargas en curso); error y disponible
  /// quedan al final.
  int _listRank(LocalModel model, DashboardState dashboard) {
    if (model.active) return 0;
    if (model.installed) return 1;
    if (model.downloadState == ModelDownloadState.downloading ||
        model.downloadState == ModelDownloadState.verifying) {
      return 2;
    }
    if (model.downloadState == ModelDownloadState.failed) return 3;
    if (dashboard.ramTotalGb > 0 && model.ramGb > dashboard.ramTotalGb) {
      return 4;
    }
    return 5;
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

/// Miniatura circular compartida por las barras (summary/scan/empty):
/// misma identidad visual, un solo punto de mantenimiento.
class _MiniIcon extends StatelessWidget {
  const _MiniIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    this.bgAlpha = 0.14,
    this.borderAlpha = 0.4,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double bgAlpha;
  final double borderAlpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

class _ModelsSummary extends StatelessWidget {
  const _ModelsSummary({
    required this.installedCount,
    required this.usedGb,
  });

  final int installedCount;
  final double usedGb;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(isCompact ? 12 : _M3.barRadius),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Miniatura: icono más pequeño y compacto
          _MiniIcon(
            icon: Icons.view_in_ar_rounded,
            color: colors.accent,
            size: isCompact ? 28 : 32,
            iconSize: isCompact ? 15 : 17,
            bgAlpha: 0.16,
          ),
          SizedBox(width: isCompact ? 8 : 10),
          Expanded(
            child: Text(
              '$installedCount · ${usedGb <= 0 ? '0 GB' : formatGb(usedGb)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: isCompact ? 12 : 13,
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final accent = _statusColor(status, colors);

    // El icono del modelo activo flota ±2px (FloatingModelIcon).
    final icon = FloatingModelIcon(
      active: status == ModelUiStatus.active,
      child: _ModelIcon(name: name),
    );

    return Semantics(
      label: '$name, ${_statusLabel(status)}',
      child: AnimatedActiveBorder(
        active: status == ModelUiStatus.active,
        borderRadius: _M3.cardRadius,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_M3.cardRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: status == ModelUiStatus.active
                      ? colors.success.withValues(alpha: 0.62)
                      : colors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(_M3.cardRadius),
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

  /// Icono y accent por familia (M3E: color expresivo por identidad del
  /// modelo, no blanco neutro).
  static (IconData, Color) _styleFor(String name, NanoColors colors) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('deepseek') || lowerName.contains('r1')) {
      return (Icons.psychology_rounded, colors.tertiary);
    }
    if (lowerName.contains('coder') || lowerName.contains('code')) {
      return (Icons.code_rounded, colors.warning);
    }
    if (lowerName.contains('gemma')) {
      return (Icons.diamond_rounded, colors.success);
    }
    if (lowerName.contains('llama')) {
      return (Icons.smart_toy_rounded, colors.warning);
    }
    if (lowerName.contains('phi')) {
      return (Icons.auto_awesome_rounded, colors.tertiary);
    }
    if (lowerName.contains('27b') || lowerName.contains('32b')) {
      return (Icons.bolt_rounded, colors.accent);
    }
    if (lowerName.contains('qwen')) {
      return (Icons.hub_rounded, colors.accent);
    }
    return (Icons.memory_rounded, colors.accent);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final (iconData, tint) = _styleFor(name, colors);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(_M3.iconRadius),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Icon(
        iconData,
        color: tint,
        size: 26,
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: _M3.titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            _StatusChip(label: _statusLabel(status), color: accent),
            if (quantization.isNotEmpty)
              _StatusChip(label: quantization, color: colors.accent),
          ],
        ),
        const SizedBox(height: 7),
        if (ramNote != null)
          Text(
            ramNote!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.warning, fontSize: 12),
          )
        else if (status == ModelUiStatus.error && error != null)
          Text(
            error!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.danger, fontSize: 12),
          )
        else
          Text(
            '${formatGb(sizeGb)} · $description',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.62),
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
              backgroundColor: colors.onSurface.withValues(alpha: 0.1),
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
                backgroundColor: colors.onSurface.withValues(alpha: 0.1),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: _M3.chipRadius,
        border: Border.all(color: color.withValues(alpha: 0.5)),
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

    // Cambio de estado (INSTALADO → ACTIVO, etc.) con fade + escala y
    // overshoot (M3E emphasis motion).
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final accent = _statusColor(status, colors);

    switch (status) {
      case ModelUiStatus.active:
        // M3E: estado resaltado con badge circular + glow, no icono suelto.
        return Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.success.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.success.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.success.withValues(alpha: 0.35),
                blurRadius: 12,
              ),
            ],
          ),
          child: Icon(
            Icons.check_rounded,
            color: colors.success,
            size: 22,
          ),
        );

      case ModelUiStatus.installed:
        return _PillButton(label: 'Usar', accent: accent, onPressed: onUse);

      case ModelUiStatus.available:
        return _PillButton(label: 'Descargar', accent: accent, onPressed: onDownload);

      case ModelUiStatus.downloading:
        return PressableScale(
          pressedScale: _M3.pressScale,
          child: IconButton(
            tooltip: 'Cancelar descarga',
            onPressed: onCancel,
            style: IconButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.16),
              foregroundColor: accent,
              shape: const CircleBorder(),
              side: BorderSide(color: accent.withValues(alpha: 0.5)),
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        );

      case ModelUiStatus.error:
        return _PillButton(label: 'Reintentar', accent: accent, onPressed: onDownload);

      case ModelUiStatus.incompatible:
        // Política consistente con los detectados: se permite intentar.
        // El ramNote naranja ya advierte el requisito de RAM real.
        return _PillButton(label: 'Descargar', accent: accent, onPressed: onDownload);
    }
  }
}

/// Botón principal pill (M3E): FilledButton stadium con accent saturado y
/// texto onAccent (contraste correcto en claro Y oscuro, antes onSurface
/// dejaba blanco sobre cyan). Compartido por _ModelAction y _DetectedCard —
/// mismo estilo, un solo punto de mantenimiento.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onPressed,
    this.accent,
  });

  final String label;
  final VoidCallback onPressed;

  /// Null → accent del tema.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return PressableScale(
      pressedScale: _M3.pressScale,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent ?? colors.accent,
          foregroundColor: colors.onAccent,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Barra del scanner automático del storage. Estados honestos:
/// scanning=true (ocupado), detectedCount>0 (resultados), error!=null
/// (fallo SAF), allFilesGranted=false (falta permiso).
class _ScanBar extends StatelessWidget {
  const _ScanBar({
    required this.scanning,
    required this.allFilesGranted,
    required this.treeGranted,
    required this.detectedCount,
    required this.error,
    required this.onGrant,
    required this.onPickTree,
    required this.onRescan,
  });

  final bool scanning;
  final bool allFilesGranted;
  final bool treeGranted;
  final int detectedCount;
  final String? error;
  final VoidCallback onGrant;
  final VoidCallback onPickTree;
  final VoidCallback onRescan;

  /// Botón de acción de la barra: pill con accent (M3E).
  Widget _scanButton(String label, VoidCallback onPressed, NanoColors colors) {
    return PressableScale(
      pressedScale: _M3.pressScale,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final accent = error != null ? colors.danger : colors.accent;

    // En compact los botones de texto se ocultan y la barra entera se
    // vuelve el gesto. "Conceder acceso" sin tap era un callejón muerto
    // en phone. Con permiso concedido, el tap SIEMPRE reescanea (también
    // con detectados: la acción debe seguir disponible).
    final VoidCallback? tapAction = !allFilesGranted && !treeGranted
        ? onGrant
        : !allFilesGranted && treeGranted
            ? onPickTree
            : !scanning
                ? onRescan
                : null;

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(isCompact ? 12 : _M3.barRadius),
        border: Border.all(
          color: error != null
              ? colors.danger.withValues(alpha: 0.45)
              : colors.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          // Miniatura: icono más pequeño y compacto
          _MiniIcon(
            icon: scanning
                ? Icons.refresh_rounded
                : detectedCount > 0
                    ? Icons.folder_open_rounded
                    : Icons.folder_off_rounded,
            color: accent,
            size: isCompact ? 26 : 30,
            iconSize: isCompact ? 14 : 16,
          ),
          SizedBox(width: isCompact ? 8 : 10),
          Expanded(
            child: Text(
              error ??
                  (scanning
                      ? 'Buscando...'
                      : detectedCount > 0
                          ? (detectedCount == 1
                              ? '1 detectado'
                              : '$detectedCount detectados')
                          : allFilesGranted || treeGranted
                              ? 'No hay modelos'
                              : 'Conceder acceso'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: error != null
                    ? colors.danger
                    : colors.onSurface.withValues(alpha: 0.9),
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isCompact && !allFilesGranted && !treeGranted)
            _scanButton('Dar permiso', onGrant, colors)
          else if (!isCompact && !allFilesGranted && treeGranted)
            _scanButton('Escanear', onPickTree, colors)
          else if (!isCompact && !scanning)
            _scanButton('Reescanear', onRescan, colors)
          // Compact (phone): el análisis/reescaneo sigue VISIBLE como
          // icono refresh tappable — la acción no puede desaparecer.
          // Solo con permiso concedido: sin permiso el texto dice
          // "Conceder acceso" y un refresh confundiría la acción.
          else if (isCompact &&
              !scanning &&
              (allFilesGranted || treeGranted))
            _MiniIcon(
              icon: Icons.refresh_rounded,
              color: colors.accent,
              size: 24,
              iconSize: 13,
            ),
        ],
      ),
    );

    if (tapAction == null) return content;

    final radius = BorderRadius.circular(isCompact ? 12 : _M3.barRadius);
    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tapAction,
          borderRadius: radius,
          splashColor: accent.withValues(alpha: 0.14),
          highlightColor: colors.onSurface.withValues(alpha: 0.04),
          child: content,
        ),
      ),
    );
  }
}

/// Card de modelo detectado en storage (sin instalación: uso directo desde su
/// ubicación original). Botón CARGAR invoca `useDetected`. Misma identidad
/// visual que `_ModelCard` (glassmorphism) + chips de formato y estado.
class _DetectedCard extends StatelessWidget {
  const _DetectedCard({
    required this.model,
    required this.loading,
    required this.active,
    required this.onUse,
  });

  final DetectedModel model;
  final bool loading;
  final bool active;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Semantics(
      label: '${model.name}, detectado${active ? ', activo' : ''}',
      child: AnimatedActiveBorder(
        active: active,
        borderRadius: _M3.compactRadius,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_M3.compactRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: active
                      ? colors.success.withValues(alpha: 0.62)
                      : colors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(_M3.compactRadius),
                  border: Border.all(
                    color: (active ? colors.success : colors.onSurface)
                        .withValues(alpha: active ? 0.62 : 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    _ModelIcon(name: model.name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (active)
                                _StatusChip(
                                  label: 'ACTIVO',
                                  color: colors.success,
                                ),
                              _StatusChip(
                                label: model.format.name.toUpperCase(),
                                color: colors.accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            model.sizeBytes > 0
                                ? formatBytes(model.sizeBytes)
                                : 'Tamaño desconocido',
                            style: TextStyle(
                              color: colors.onSurface.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          if (!model.usable) ...[
                            const SizedBox(height: 4),
                            // Aviso honesto en la tarjeta: el motor solo lee
                            // GGUF con magic válido, pero se permite intentar.
                            Text(
                              model.format == DetectedModelFormat.gguf
                                  ? 'Magic GGUF no verificado. Intentando cargar de todos modos.'
                                  : 'Formato ${model.format.name}: el motor '
                                      'solo lee GGUF. Intentando de todos '
                                      'modos.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.warning,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (loading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.accent,
                        ),
                      )
                    else
                      // M3E: acción principal FilledButton pill.
                      _PillButton(label: 'Cargar', onPressed: onUse),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado vacío compacto: reemplaza la lista vacía gigante con un aviso
/// honesto y mínimo. Sin barras, sin tarjetas fantasma.
class _EmptyModels extends StatelessWidget {
  const _EmptyModels();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniIcon(
            icon: Icons.folder_off_rounded,
            color: colors.accent.withValues(alpha: 0.7),
            size: 52,
            iconSize: 24,
            bgAlpha: 0.1,
            borderAlpha: 0.3,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin modelos',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Concede acceso al storage o descarga un GGUF del catálogo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pie de la pantalla con uso de almacenamiento real del device.
/// Solo se muestra cuando hay modelos instalados (usedGb > 0).
class _StorageUsage extends StatelessWidget {
  const _StorageUsage({
    required this.usedGb,
    required this.storageTotalGb,
    required this.storageFreeGb,
    this.compact = false,
  });

  final double usedGb;
  final double storageTotalGb;
  final double storageFreeGb;

  /// Modo landscape: margen y padding reducidos para no robar alto.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final usedPct = storageTotalGb > 0 ? usedGb / storageTotalGb : 0.0;

    return Container(
      margin: compact
          ? const EdgeInsets.fromLTRB(14, 0, 14, 10)
          : const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(_M3.barRadius),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.12)),
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
                    color: colors.onSurface.withValues(alpha: 0.72),
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
                    color: colors.onSurface.withValues(alpha: 0.72),
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
              backgroundColor: colors.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                usedPct > 0.9
                    ? colors.danger
                    : usedPct > 0.7
                        ? colors.warning
                        : colors.success,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatGb(storageFreeGb)} libres',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.48),
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

Color _statusColor(ModelUiStatus status, NanoColors colors) {
  switch (status) {
    case ModelUiStatus.active:
      return colors.success;
    case ModelUiStatus.installed:
      return colors.accent;
    case ModelUiStatus.available:
      return colors.tertiary;
    case ModelUiStatus.downloading:
      return colors.warning;
    case ModelUiStatus.error:
      return colors.danger;
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
