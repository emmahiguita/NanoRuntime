import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/core/services/device_location_service.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';

import '../../../browser/infrastructure/browser_security_firewall.dart';
import 'nano_siata_floating_window.dart';
import 'nano_siata_injection.dart';

part 'nano_siata_radar_sheet_controls.part.dart';

/// Ventana flotante de alta fidelidad estilo iOS Frosted Glass para el radar SIATA.
/// Soporta zoom infinito, selector de capas en vivo, GPS y desacople a ventana flotante.
class NanoSiataRadarSheet extends StatefulWidget {
  const NanoSiataRadarSheet({super.key});

  static const portalUrl = 'https://geoportal.siata.gov.co/';

  static Future<void> show(BuildContext context) {
    return showNanoGlassWindow(
      context: context,
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
      source:
          '''
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
    final height = MediaQuery.sizeOf(context).height * 0.84;

    return SizedBox(
      height: height,
      child: Column(
        children: [
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
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
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
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                      Factory<ScaleGestureRecognizer>(
                        () => ScaleGestureRecognizer(),
                      ),
                      Factory<PanGestureRecognizer>(
                        () => PanGestureRecognizer(),
                      ),
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
          ),
        ],
      ),
    );
  }
}
