import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';
import 'browser_zoom_quick_scales.dart';

/// Control Material de escala por pestaña; usa el estado como única vía de aplicación.
/// El slider previsualiza el porcentaje y confirma al soltar, sin saturar el canal JS.
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
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
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
    _zoom = widget.currentZoom.isFinite ? widget.currentZoom.clamp(0.1, 3.0) : 1;
  }

  void _applyZoom(double value) {
    if (!mounted) return;
    final scale = value.clamp(0.1, 3.0);
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
      if (!mobile && result is num && result.isFinite) _applyZoom(result.toDouble());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('La página ya no está disponible.')));
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
                child: Text('Zoom de página', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
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
              IconButton(
                tooltip: 'Reducir',
                onPressed: _zoom > 0.1 ? () => _applyZoom(_zoom - 0.1) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  '${(_zoom * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Ampliar',
                onPressed: _zoom < 3 ? () => _applyZoom(_zoom + 0.1) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          Slider(
            value: _zoom,
            min: 0.1,
            max: 3,
            divisions: 29,
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
