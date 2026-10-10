import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/core/services/device_location_service.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

import '../../../browser/infrastructure/browser_security_firewall.dart';
import 'nano_siata_radar_sheet.dart';

/// Radar oficial SIATA montado dentro del chat.
/// Ofrece zoom, scroll fluido 360°, control de capas y expansión sin bloqueos.
class NanoSiataRadarCard extends StatefulWidget {
  const NanoSiataRadarCard({super.key});

  static const portalUrl = 'https://geoportal.siata.gov.co/';

  static bool shouldShow(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll('í', 'i')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    final mentionsArea =
        normalized.contains('medellin') ||
        normalized.contains('valle de aburra') ||
        normalized.contains('siata');
    final mentionsRain = RegExp(
      r'\b(?:lluvia|llueve|lloviendo|llover|precipitacion|clima|tormenta|radar)\b',
    ).hasMatch(normalized);
    return mentionsArea && (mentionsRain || normalized.contains('siata'));
  }

  @override
  State<NanoSiataRadarCard> createState() => _NanoSiataRadarCardState();
}

class _NanoSiataRadarCardState extends State<NanoSiataRadarCard>
    with AutomaticKeepAliveClientMixin {
  final InAppWebViewKeepAlive _webViewKeepAlive = InAppWebViewKeepAlive();
  InAppWebViewController? _controller;
  int _progress = 0;
  bool _interactive = true; // Activo por defecto para manejo inmediato
  bool _locationShared = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
          .leaflet-top.leaflet-left, .leaflet-top.leaflet-right { top: 6px !important; }
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
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final canMountMap =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        InAppWebViewPlatform.instance != null;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final height = (screenHeight * (screenHeight < 700 ? 0.48 : 0.58)).clamp(
      280.0,
      540.0,
    );

    return Semantics(
      label: 'Mapa de precipitación y radar SIATA en vivo',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                  : const Color(0xFF1D6FE8).withValues(alpha: 0.22),
              width: 0.9,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(isDark, colors, canMountMap),
              if (_progress < 100 && _error == null)
                LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 2,
                  color: const Color(0xFF38BDF8),
                  backgroundColor: Colors.transparent,
                ),
              Expanded(child: _buildMapSurface(canMountMap, isDark, colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, dynamic colors, bool canMountMap) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
    child: Row(
      children: [
        const Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Radar SIATA en vivo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : colors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _locationShared
                    ? 'Ubicación activa · radar y capas en vivo'
                    : _interactive
                    ? 'Interactivo · zoom, scroll y capas listos'
                    : 'Modo lectura de chat',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white60 : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: _interactive ? 'Pausar gestos de mapa' : 'Activar gestos de mapa',
          onPressed: canMountMap
              ? () => setState(() => _interactive = !_interactive)
              : null,
          icon: Icon(
            _interactive ? Icons.touch_app_rounded : Icons.pan_tool_rounded,
            color: _interactive ? const Color(0xFF38BDF8) : null,
          ),
          iconSize: 19,
        ),
        IconButton(
          tooltip: 'Recargar',
          onPressed: _controller == null ? null : () => _controller!.reload(),
          icon: const Icon(Icons.refresh_rounded),
          iconSize: 19,
        ),
        IconButton(
          tooltip: 'Visor Completo',
          onPressed: () => NanoSiataRadarSheet.show(context),
          icon: const Icon(Icons.open_in_full_rounded),
          iconSize: 18,
        ),
      ],
    ),
  );

  Widget _buildMapSurface(bool canMountMap, bool isDark, dynamic colors) => Stack(
    fit: StackFit.expand,
    children: [
      if (canMountMap)
        InAppWebView(
          key: const ValueKey('siata_inline_map'),
          keepAlive: _webViewKeepAlive,
          initialUrlRequest: URLRequest(
            url: WebUri(NanoSiataRadarCard.portalUrl),
          ),
          initialSettings: BrowserSecurityFirewall.createWebViewSettings(
            enableGeolocation: true,
          ),
          gestureRecognizers: _interactive
              ? {
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                  Factory<ScaleGestureRecognizer>(
                    () => ScaleGestureRecognizer(),
                  ),
                  Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                }
              : const <Factory<OneSequenceGestureRecognizer>>{},
          onWebViewCreated: (controller) => _controller = controller,
          onProgressChanged: (controller, value) {
            if (mounted) setState(() => _progress = value);
            if (value > 60) _injectOptimizations(controller);
          },
          onLoadStop: (controller, _) => _injectOptimizations(controller),
          onGeolocationPermissionsShowPrompt: (_, origin) async {
            final uri = Uri.tryParse(origin);
            final trustedSiata =
                uri?.scheme == 'https' &&
                uri?.host.toLowerCase() == 'geoportal.siata.gov.co';
            final hasLocation =
                trustedSiata &&
                await DeviceLocationService.instance.locateOnce() != null;
            if (mounted && _locationShared != hasLocation) {
              setState(() => _locationShared = hasLocation);
            }
            return GeolocationPermissionShowPromptResponse(
              origin: origin,
              allow: hasLocation,
              retain: false,
            );
          },
          onReceivedError: (_, request, error) {
            if (request.isForMainFrame == true && mounted) {
              setState(() => _error = error.description);
            }
          },
          shouldOverrideUrlLoading: (_, action) async {
            final url = action.request.url?.toString() ?? '';
            return BrowserSecurityFirewall.isAllowedUrl(url)
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL;
          },
        )
      else
        ColoredBox(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          child: const Center(child: Text('Vista SIATA disponible en Android')),
        ),
      if (_error != null)
        ColoredBox(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          child: Center(
            child: FilledButton.tonalIcon(
              onPressed: () {
                setState(() => _error = null);
                _controller?.reload();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar mapa SIATA'),
            ),
          ),
        ),
      // Controles flotantes de zoom rápido en esquina inferior
      if (canMountMap && _interactive && _error == null)
        Positioned(
          bottom: 10,
          right: 10,
          child: _buildQuickZoomControls(isDark),
        ),
    ],
  );

  Widget _buildQuickZoomControls(bool isDark) => Container(
    decoration: BoxDecoration(
      color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(
        alpha: 0.85,
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        width: 0.8,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _zoomIn,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(Icons.add_rounded, size: 16),
          ),
        ),
        Container(
          width: 1,
          height: 14,
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        InkWell(
          onTap: _zoomOut,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(Icons.remove_rounded, size: 16),
          ),
        ),
        Container(
          width: 1,
          height: 14,
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        InkWell(
          onTap: _locateUser,
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(Icons.my_location_rounded, size: 15),
          ),
        ),
      ],
    ),
  );
}
