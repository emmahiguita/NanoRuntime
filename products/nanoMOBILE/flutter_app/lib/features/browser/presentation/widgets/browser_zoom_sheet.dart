import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';

/// Modal estilo iOS Safari para control de tamaño de página, zoom y adaptación móvil.
class BrowserZoomSheet extends StatefulWidget {
  final BrowserTabModel tab;
  final double currentZoom;
  final InAppWebViewController? controller;
  final ValueChanged<double> onZoomChanged;

  const BrowserZoomSheet({
    super.key,
    required this.tab,
    required this.currentZoom,
    required this.controller,
    required this.onZoomChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required BrowserTabModel tab,
    required double currentZoom,
    required InAppWebViewController? controller,
    required ValueChanged<double> onZoomChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BrowserZoomSheet(
        tab: tab,
        currentZoom: currentZoom,
        controller: controller,
        onZoomChanged: onZoomChanged,
      ),
    );
  }

  @override
  State<BrowserZoomSheet> createState() => _BrowserZoomSheetState();
}

class _BrowserZoomSheetState extends State<BrowserZoomSheet> {
  late double _zoom;

  @override
  void initState() {
    super.initState();
    _zoom = widget.currentZoom;
  }

  Future<void> _applyZoom(double newZoom) async {
    final clamped = newZoom.clamp(0.1, 5.0);
    setState(() => _zoom = clamped);
    widget.onZoomChanged(clamped);
    final ctrl = widget.controller;
    if (ctrl != null) {
      try {
        await ctrl.evaluateJavascript(
          source: BrowserScripts.setZoomLevelScript(clamped),
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final screenHeight = mq.size.height;
    final zoomPercent = (_zoom * 100).round();

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: screenHeight * 0.92,
        ),
        margin: EdgeInsets.all(isLandscape ? 8 : 16),
        padding: EdgeInsets.all(isLandscape ? 12 : 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF20F1D2C) : const Color(0xF6FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tamaño de Página & Zoom',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Controles principales +/- de zoom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF081420) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : const Color(0xFF2563EB).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _applyZoom(_zoom - 0.15);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.remove_rounded, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Reducir',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  '$zoomPercent%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFF10B981)
                        : const Color(0xFF2563EB),
                  ),
                ),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _applyZoom(_zoom + 0.15);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Ampliar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Botones rápidos de escala fija
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [0.25, 0.5, 0.75, 1.0, 1.5, 2.0].map((scale) {
              final percent = (scale * 100).round();
              final isSelected = (_zoom - scale).abs() < 0.05;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _applyZoom(scale);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                              ? const Color(0xFF10B981)
                              : const Color(0xFF2563EB))
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // Botón para forzar adaptación responsive a pantalla móvil
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);
                final ctrl = widget.controller;
                if (ctrl != null) {
                  try {
                    await ctrl.evaluateJavascript(
                      source: BrowserScripts.mobileViewportAdapterScript,
                    );
                  } catch (_) {}
                }
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Vista móvil adaptada (viewport flexible activo).',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.smartphone_rounded, size: 18),
              label: const Text('Adaptar página a vista móvil'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
