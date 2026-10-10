import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/core/services/device_location_service.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

import '../../../browser/infrastructure/browser_security_firewall.dart';
import 'nano_siata_floating_window.dart';
import 'nano_siata_injection.dart';

/// Hoja modal de alta fidelidad estilo iOS Frosted Glass para el radar SIATA.
/// Soporta zoom infinito, selector de capas en vivo, GPS y desacople a ventana flotante.
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
  SiataLayer _selectedLayer = SiataLayer.radar;
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

  void _selectLayer(SiataLayer layer) {
    setState(() => _selectedLayer = layer);
    _controller?.evaluateJavascript(
      source: '''
      (function() {
        const triggers = Array.from(document.querySelectorAll('a, button, span, div')).filter(el => {
          const txt = (el.innerText || el.textContent || '').toLowerCase();
          return txt.includes('${layer.id}') || txt.includes('${layer.label.toLowerCase()}');
        });
        if (triggers.length > 0) {
          triggers[0].click();
        }
      })();
      ''',
    );
  }

  void _detachToFloatingWindow() {
    Navigator.of(context).pop();
    NanoSiataFloatingOverlay.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0F172A) : colors.surface).withValues(
              alpha: isDark ? 0.88 : 0.94,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: isDark ? 0.18 : 0.08,
                ),
                width: 1.2,
              ),
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 28, offset: Offset(0, -6)),
            ],
          ),
          child: Column(
            children: [
              _buildDragHandle(isDark),
              _buildHeader(context, isDark, colors),
              _buildLayerSelector(isDark),
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
                      initialSettings: () {
                        final s = BrowserSecurityFirewall.createWebViewSettings(
                          enableGeolocation: true,
                        );
                        s.mixedContentMode =
                            MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW;
                        return s;
                      }(),
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                        Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                        Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                      },
                      onWebViewCreated: (c) => _controller = c,
                      onProgressChanged: (c, p) {
                        if (mounted) setState(() => _progress = p);
                        if (p > 40) NanoSiataInjection.inject(c);
                      },
                      onLoadStop: (c, _) => NanoSiataInjection.inject(c),
                    ),
                    _buildFloatingZoomHud(isDark, colors),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(bool isDark) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      width: 40,
      height: 4.5,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );

  Widget _buildHeader(BuildContext context, bool isDark, dynamic colors) => Padding(
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
                    ? 'GPS activo · Selección de capas'
                    : 'Estilo iOS · Zoom libre y capas 360°',
                style: TextStyle(
                  color: isDark ? Colors.white60 : colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.picture_in_picture_alt_rounded),
          iconSize: 20,
          onPressed: _detachToFloatingWindow,
          tooltip: 'Ventana Flotante iOS',
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

  Widget _buildLayerSelector(bool isDark) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: SiataLayer.values.map((l) {
        final active = _selectedLayer == l;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => _selectLayer(l),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? const Color(0xFF38BDF8) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    l.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? const Color(0xFF38BDF8)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
            icon: Icon(
              Icons.my_location_rounded,
              size: 18,
              color: _locationShared ? const Color(0xFF38BDF8) : null,
            ),
            onPressed: _locateUser,
            tooltip: 'Mi Ubicación',
          ),
        ],
      ),
    ),
  );
}
