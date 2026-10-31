import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';
import 'browser_zoom_quick_scales.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';

/// QUÉ HACE:
/// Control Material de escala libre por pestaña para Nano Browser.
///
/// CÓMO FUNCIONA:
/// Slider continuo libre desde 5% hasta 300% sin divisiones rígidas, permitiendo
/// reducción extrema (menor de 30%, 20%, 10%, 5%) y previsualización en tiempo real.
///
/// POR QUÉ:
/// Ofrece ajuste milimétrico libre para adaptar páginas web de cualquier tamaño (< 175 líneas).
class BrowserZoomSheet extends StatefulWidget {
  const BrowserZoomSheet({
    super.key,
    required this.tab,
    required this.currentZoom,
    required this.controller,
    required this.onZoomChanged,
  });
  final BrowserTabModel tab;
  final double currentZoom;
  final InAppWebViewController? controller;
  final ValueChanged<double> onZoomChanged;

  static Future<void> show({
    required BuildContext context,
    required BrowserTabModel tab,
    required double currentZoom,
    required InAppWebViewController? controller,
    required ValueChanged<double> onZoomChanged,
  }) => showNanoGlassWindow(
    context: context,
    constraints: const BoxConstraints(maxWidth: 440),
    builder: (_) => BrowserZoomSheet(
      tab: tab,
      currentZoom: currentZoom,
      controller: controller,
      onZoomChanged: onZoomChanged,
    ),
  );

  @override
  State<BrowserZoomSheet> createState() => _BrowserZoomSheetState();
}

class _BrowserZoomSheetState extends State<BrowserZoomSheet> {
  late double _zoom;
  bool _adapting = false;

  @override
  void initState() {
    super.initState();
    _zoom = widget.currentZoom.isFinite
        ? widget.currentZoom.clamp(0.05, 3.0)
        : 1.0;
  }

  void _applyZoom(double value) {
    if (!mounted) return;
    final scale = value.clamp(0.05, 3.0);
    setState(() => _zoom = scale);
    widget.onZoomChanged(scale);
  }

  /// Comprobar mounted después del puente nativo evita setState tras cerrar el modal.
  Future<void> _adapt({bool mobile = false}) async {
    final controller = widget.controller;
    if (controller == null || _adapting) return;
    setState(() => _adapting = true);
    try {
      final result = await controller.evaluateJavascript(
        source: mobile
            ? BrowserScripts.mobileViewportAdapterScript
            : BrowserScripts.fitToScreenOverviewScript,
      );
      if (!mounted) return;
      if (!mobile && result is num && result.isFinite) {
        _applyZoom(result.toDouble());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('La página ya no está disponible.')),
        );
      }
    } finally {
      if (mounted) setState(() => _adapting = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Zoom de página',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Semantics(
                label: 'Cerrar',
                button: true,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
          Text(
            widget.tab.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Semantics(
                label: 'Reducir zoom',
                button: true,
                child: IconButton(
                  onPressed: _zoom > 0.05
                      ? () => _applyZoom(
                          (_zoom <= 0.15 ? _zoom - 0.02 : _zoom - 0.05)
                              .clamp(0.05, 3.0),
                        )
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
              ),
              Expanded(
                child: Text(
                  '${(_zoom * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Semantics(
                label: 'Ampliar zoom',
                button: true,
                child: IconButton(
                  onPressed: _zoom < 3.0
                      ? () => _applyZoom((_zoom + 0.05).clamp(0.05, 3.0))
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
          Slider(
            value: _zoom.clamp(0.05, 3.0),
            min: 0.05,
            max: 3.0,
            label: '${(_zoom * 100).round()}%',
            onChanged: (value) => setState(() => _zoom = value),
            onChangeEnd: _applyZoom,
          ),
          IgnorePointer(
            ignoring: _adapting,
            child: BrowserZoomQuickScales(
              currentZoom: _zoom,
              onSelectScale: _applyZoom,
              onFitToScreen: _adapt,
              onMobileAdapt: () => _adapt(mobile: true),
            ),
          ),
        ],
      ),
    ),
  );
}
