import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/core/services/device_location_service.dart';

import '../../../browser/infrastructure/browser_security_firewall.dart';
import 'nano_siata_injection.dart';

/// Modo de visualización de la ventana flotante estilo iOS.
enum NanoFloatingMode { pill, window }

/// Capa meteorológica SIATA seleccionable.
enum SiataLayer {
  radar('Radar Lluvia', '🌧️', 'radar'),
  lightning('Tormentas', '⚡', 'rayos'),
  streams('Quebradas', '🌊', 'nivel'),
  air('Calidad Aire', '🍃', 'calidad_aire');

  const SiataLayer(this.label, this.icon, this.id);
  final String label;
  final String icon;
  final String id;
}

/// Overlay Manager para la ventana flotante estilo iOS iPhone.
class NanoSiataFloatingOverlay {
  static OverlayEntry? _currentEntry;
  static bool get isShowing => _currentEntry != null;

  static void show(BuildContext context) {
    if (_currentEntry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _currentEntry = OverlayEntry(
      builder: (ctx) => const NanoSiataFloatingWindow(),
    );
    overlay.insert(_currentEntry!);
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void toggle(BuildContext context) {
    if (isShowing) {
      hide();
    } else {
      show(context);
    }
  }
}

/// Ventana flotante interactiva con estética iOS Glassmorphism (iPhone Style).
class NanoSiataFloatingWindow extends StatefulWidget {
  const NanoSiataFloatingWindow({super.key});

  static const portalUrl = 'https://geoportal.siata.gov.co/';

  @override
  State<NanoSiataFloatingWindow> createState() =>
      _NanoSiataFloatingWindowState();
}

class _NanoSiataFloatingWindowState extends State<NanoSiataFloatingWindow>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _controller;
  NanoFloatingMode _mode = NanoFloatingMode.window;
  SiataLayer _selectedLayer = SiataLayer.radar;
  Offset _position = const Offset(8, 100);
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

  InAppWebViewSettings _createSettings() {
    final s = BrowserSecurityFirewall.createWebViewSettings(
      enableGeolocation: true,
    );
    s.mixedContentMode = MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    // Aprovechamiento total del ancho de la pantalla
    final winWidth = _mode == NanoFloatingMode.pill ? 210.0 : (size.width - 16);
    final winHeight = _mode == NanoFloatingMode.pill
        ? 52.0
        : (size.height * 0.60).clamp(380.0, 560.0);

    // Clamping de la posición en pantalla
    final maxX = (size.width - winWidth - 4).clamp(0.0, double.infinity);
    final maxY = (size.height - winHeight - 20).clamp(0.0, double.infinity);
    final clampedPos = Offset(
      _position.dx.clamp(8.0, maxX),
      _position.dy.clamp(30.0, maxY),
    );

    return Positioned(
      left: clampedPos.dx,
      top: clampedPos.dy,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _position += details.delta;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: winWidth,
            height: winHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_mode == NanoFloatingMode.pill ? 26 : 24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_mode == NanoFloatingMode.pill ? 26 : 24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: isDark ? 0.88 : 0.95),
                    borderRadius: BorderRadius.circular(_mode == NanoFloatingMode.pill ? 26 : 24),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.20 : 0.12),
                      width: 1.2,
                    ),
                  ),
                  child: _mode == NanoFloatingMode.pill
                      ? _buildPillContent(isDark)
                      : _buildWindowContent(isDark),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillContent(bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFF38BDF8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0xFF38BDF8), blurRadius: 6, spreadRadius: 1),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Radar SIATA',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.open_in_full_rounded, size: 16),
          onPressed: () => setState(() => _mode = NanoFloatingMode.window),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 16),
          onPressed: () => NanoSiataFloatingOverlay.hide(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );

  Widget _buildWindowContent(bool isDark) => Column(
    children: [
      _buildWindowHeader(isDark),
      _buildLayerSelector(isDark),
      if (_progress < 100)
        LinearProgressIndicator(
          value: _progress == 0 ? null : _progress / 100,
          minHeight: 2,
          color: const Color(0xFF38BDF8),
          backgroundColor: Colors.transparent,
        ),
      Expanded(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(NanoSiataFloatingWindow.portalUrl),
              ),
              initialSettings: _createSettings(),
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
              },
              onWebViewCreated: (c) => _controller = c,
              onProgressChanged: (c, p) {
                if (mounted) setState(() => _progress = p);
                if (p > 60) NanoSiataInjection.inject(c);
              },
              onLoadStop: (c, _) => NanoSiataInjection.inject(c),
            ),
            _buildFloatingZoomControls(isDark),
          ],
        ),
      ),
    ],
  );

  Widget _buildWindowHeader(bool isDark) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF38BDF8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Radar SIATA · iOS Flotante',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_rounded, size: 18),
          onPressed: () => setState(() => _mode = NanoFloatingMode.pill),
          tooltip: 'Minimizar',
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 17),
          onPressed: () => _controller?.reload(),
          tooltip: 'Recargar',
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: () => NanoSiataFloatingOverlay.hide(),
          tooltip: 'Cerrar',
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
      ],
    ),
  );

  Widget _buildLayerSelector(bool isDark) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: Row(
      children: SiataLayer.values.map((l) {
        final active = _selectedLayer == l;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            onTap: () => _selectLayer(l),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? const Color(0xFF38BDF8) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.icon, style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text(
                    l.label,
                    style: TextStyle(
                      fontSize: 11,
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

  Widget _buildFloatingZoomControls(bool isDark) => Positioned(
    bottom: 10,
    right: 10,
    child: Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 17),
            onPressed: _zoomIn,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Container(
            width: 20,
            height: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 17),
            onPressed: _zoomOut,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Container(
            width: 20,
            height: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          IconButton(
            icon: Icon(
              Icons.my_location_rounded,
              size: 16,
              color: _locationShared ? const Color(0xFF38BDF8) : null,
            ),
            onPressed: _locateUser,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    ),
  );
}
