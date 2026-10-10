import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/core/services/device_location_service.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

import '../../../browser/infrastructure/browser_security_firewall.dart';

/// Hoja modal de alta fidelidad para el visor meteorológico SIATA completo.
/// Permite zoom infinito, interacción multitáctil fluida, control de capas y GPS.
class NanoSiataRadarSheet extends StatefulWidget {
  const NanoSiataRadarSheet({super.key});

  static const portalUrl = 'https://geoportal.siata.gov.co/';

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NanoSiataRadarSheet(),
    );
  }

  @override
  State<NanoSiataRadarSheet> createState() => _NanoSiataRadarSheetState();
}

class _NanoSiataRadarSheetState extends State<NanoSiataRadarSheet> {
  InAppWebViewController? _controller;
  int _progress = 0;
  bool _locationShared = false;

  void _zoomIn() {
    _controller?.evaluateJavascript(
      source:
          'if (window.map && window.map.zoomIn) { window.map.zoomIn(); } else { const el = document.querySelector(".leaflet-control-zoom-in") || document.querySelector(".ol-zoom-in"); if(el) el.click(); }',
    );
  }

  void _zoomOut() {
    _controller?.evaluateJavascript(
      source:
          'if (window.map && window.map.zoomOut) { window.map.zoomOut(); } else { const el = document.querySelector(".leaflet-control-zoom-out") || document.querySelector(".ol-zoom-out"); if(el) el.click(); }',
    );
  }

  void _locateUser() async {
    final loc = await DeviceLocationService.instance.locateOnce();
    if (loc != null) {
      _controller?.evaluateJavascript(
        source:
            'if (window.map && window.map.setView) { window.map.setView([${loc.latitude}, ${loc.longitude}], 14); } else if (window.map && window.map.locate) { window.map.locate({setView: true, maxZoom: 14}); }',
      );
      if (mounted) setState(() => _locationShared = true);
    }
  }

  void _injectOptimizations(InAppWebViewController controller) {
    controller.evaluateJavascript(
      source: '''
      (function() {
        const style = document.createElement('style');
        style.id = 'nano-siata-optimizations';
        style.innerHTML = `
          .banner-promo, .promo-banner, div[class*="banner-container"], a[href*="siata.gov.co/web"] { display: none !important; }
          body, html, #map, .leaflet-container { width: 100% !important; height: 100% !important; touch-action: auto !important; -webkit-overflow-scrolling: touch !important; }
          .leaflet-top.leaflet-left, .leaflet-top.leaflet-right { top: 8px !important; }
        `;
        if (!document.getElementById('nano-siata-optimizations')) {
          document.head.appendChild(style);
        }
        if (window.map && window.map.touchZoom) {
          window.map.touchZoom.enable();
          window.map.doubleClickZoom.enable();
          window.map.scrollWheelZoom.enable();
        }
      })();
      ''',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          _buildDragHandle(isDark),
          _buildHeader(context, isDark, colors),
          if (_progress < 100)
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress / 100,
              minHeight: 2.5,
              color: const Color(0xFF38BDF8),
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(NanoSiataRadarSheet.portalUrl),
                  ),
                  initialSettings: BrowserSecurityFirewall.createWebViewSettings(
                    enableGeolocation: true,
                  ),
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                    Factory<ScaleGestureRecognizer>(
                      () => ScaleGestureRecognizer(),
                    ),
                    Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                  },
                  onWebViewCreated: (c) => _controller = c,
                  onProgressChanged: (c, p) {
                    if (mounted) setState(() => _progress = p);
                    if (p > 60) _injectOptimizations(c);
                  },
                  onLoadStop: (c, _) => _injectOptimizations(c),
                ),
                _buildFloatingZoomHud(isDark, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle(bool isDark) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    dynamic colors,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    child: Row(
      children: [
        const Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Radar SIATA · Visor Meteorológico',
                style: TextStyle(
                  color: isDark ? Colors.white : colors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _locationShared
                    ? 'Ubicación GPS activa · Valle de Aburrá'
                    : 'Zoom libre, scroll 360° y selección de capas',
                style: TextStyle(
                  color: isDark ? Colors.white60 : colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          iconSize: 20,
          onPressed: () => _controller?.reload(),
          tooltip: 'Recargar',
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          iconSize: 20,
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Cerrar',
        ),
      ],
    ),
  );

  Widget _buildFloatingZoomHud(bool isDark, dynamic colors) => Positioned(
    bottom: 16,
    right: 14,
    child: Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(
          alpha: 0.88,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 20),
            onPressed: _zoomIn,
            tooltip: 'Acercar',
          ),
          Container(
            width: 24,
            height: 1,
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 20),
            onPressed: _zoomOut,
            tooltip: 'Alejar',
          ),
          Container(
            width: 24,
            height: 1,
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded, size: 18),
            onPressed: _locateUser,
            tooltip: 'Mi Ubicación',
          ),
        ],
      ),
    ),
  );
}
