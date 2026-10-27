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
import 'nano_siata_radar_sheet.dart';

/// Radar oficial SIATA montado dentro del chat con diseño iOS Glassmorphism.
/// Soporta zoom, scroll fluido 360°, selector de capas, y modo ventana flotante iOS iPhone.
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
  SiataLayer _selectedLayer = SiataLayer.radar;
  int _progress = 0;
  final bool _interactive = true;
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
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF0F172A) : colors.surface).withValues(
                alpha: isDark ? 0.85 : 0.92,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: isDark ? 0.16 : 0.08,
                ),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(isDark, colors, canMountMap),
                _buildLayerChips(isDark),
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
      ),
    );
  }

  Widget _buildHeader(bool isDark, dynamic colors, bool canMountMap) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF38BDF8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0xFF38BDF8), blurRadius: 6, spreadRadius: 1),
            ],
          ),
        ),
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
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _locationShared
                    ? 'GPS activo · Vista interactiva'
                    : 'Estilo iOS · Zoom y capas 360°',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white60 : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Ventana Flotante iOS',
          onPressed: () => NanoSiataFloatingOverlay.show(context),
          icon: const Icon(Icons.picture_in_picture_alt_rounded),
          iconSize: 18,
        ),
        IconButton(
          tooltip: 'Recargar',
          onPressed: _controller == null ? null : () => _controller!.reload(),
          icon: const Icon(Icons.refresh_rounded),
          iconSize: 18,
        ),
        IconButton(
          tooltip: 'Visor Completo',
          onPressed: () => NanoSiataRadarSheet.show(context),
          icon: const Icon(Icons.open_in_full_rounded),
          iconSize: 17,
        ),
      ],
    ),
  );

  Widget _buildLayerChips(bool isDark) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.22)
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? const Color(0xFF38BDF8) : Colors.transparent,
                  width: 0.9,
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
                      fontSize: 10.5,
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
          initialSettings: () {
            final s = BrowserSecurityFirewall.createWebViewSettings(
              enableGeolocation: true,
            );
            s.mixedContentMode = MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW;
            return s;
          }(),
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
            if (value > 40) NanoSiataInjection.inject(controller);
          },
          onLoadStop: (controller, _) => NanoSiataInjection.inject(controller),
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
        alpha: 0.88,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
        width: 0.8,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _zoomIn,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(Icons.add_rounded, size: 16),
          ),
        ),
        Container(
          width: 1,
          height: 14,
          color: isDark ? Colors.white12 : Colors.black12,
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
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        InkWell(
          onTap: _locateUser,
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(
              Icons.my_location_rounded,
              size: 15,
              color: _locationShared ? const Color(0xFF38BDF8) : null,
            ),
          ),
        ),
      ],
    ),
  );
}
