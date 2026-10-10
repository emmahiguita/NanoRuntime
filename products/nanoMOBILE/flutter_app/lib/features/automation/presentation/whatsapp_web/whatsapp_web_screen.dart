// whatsapp_web_screen.dart
//
// QUÉ HACE:
// Pantalla mobile nativa de WhatsApp Web adaptado dentro de la suite Nano.
//
// CÓMO FUNCIONA:
// - Integra InAppWebView con hardware acceleration, cookies persistentes y desktop UA legítimo.
// - Orquesta WhatsAppWebAdapter para aplicar el layout responsive móvil/tablet.
// - PopScope inteligente: Si está en conversación, 'Atrás' regresa a la lista de chats;
//   si está en lista de chats, 'Atrás' cierra la pantalla y regresa al Centro de Mensajería.
// - Permite alternar entre la Vista Móvil Nano y la Vista Web Original con 1 tap.
//
// POR QUÉ:
// Ofrece una experiencia WhatsApp Web perfectamente ergonómica en móviles sin emular UI ni inventar datos.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/whatsapp_media_payload.dart';
import '../../engine/web_bridge/whatsapp_web_bridge_controller.dart';
import '../../engine/web_bridge/whatsapp_web_js_bridge.dart';
import 'whatsapp_web_adapter.dart';

class WhatsAppWebScreen extends ConsumerStatefulWidget {
  const WhatsAppWebScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WhatsAppWebScreen()),
    );
  }

  @override
  ConsumerState<WhatsAppWebScreen> createState() => _WhatsAppWebScreenState();
}

class _WhatsAppWebScreenState extends ConsumerState<WhatsAppWebScreen> {
  final _adapter = WhatsAppWebAdapter();
  InAppWebViewController? _webViewController;
  double _progress = 0.0;
  bool _isOriginalMode = false;

  @override
  void dispose() {
    _adapter.detachController();
    super.dispose();
  }

  Future<void> _handlePop() async {
    final handledByWeb = await _adapter.handleBackPress();
    if (!handledByWeb && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildHeader(context, isDark, isLandscape),
        ),
        body: Column(
          children: [
            if (_progress < 1.0)
              LinearProgressIndicator(
                value: _progress,
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                ),
              ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(WhatsAppWebAdapter.entryUrl)),
                initialSettings: InAppWebViewSettings(
                  userAgent: WhatsAppWebJsBridge.desktopUserAgent,
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  cacheEnabled: true,
                  databaseEnabled: true,
                  useHybridComposition: true,
                  hardwareAcceleration: true,
                  thirdPartyCookiesEnabled: true,
                  supportZoom: true,
                  builtInZoomControls: true,
                  displayZoomControls: false,
                  useWideViewPort: true,
                  loadWithOverviewMode: true,
                  safeBrowsingEnabled: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                  preferredContentMode: UserPreferredContentMode.DESKTOP,
                ),
                onWebViewCreated: (c) {
                  _webViewController = c;
                  _adapter.attachController(c);
                  whatsAppWebBridgeController.attachController(c);
                },
                onLoadStop: (c, url) async {
                  final urlStr = url?.toString() ?? '';
                  if (WhatsAppWebAdapter.isAllowedUrl(urlStr)) {
                    await whatsAppWebBridgeController.onPageFinished(urlStr);
                    if (!_isOriginalMode) {
                      await _adapter.applyResponsiveCss(isLandscape: isLandscape);
                      await _adapter.setupDomObserver(
                        onNavChanged: (_) {
                          if (mounted) setState(() {});
                        },
                      );
                    }
                  }
                },
                onProgressChanged: (_, p) {
                  if (mounted) setState(() => _progress = p / 100);
                },
                shouldOverrideUrlLoading: (c, action) async {
                  final navUrl = action.request.url?.toString() ?? '';
                  if (WhatsAppWebAdapter.isAllowedUrl(navUrl)) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  // Si el link sale a un sitio web externo, se rechaza para seguridad
                  return NavigationActionPolicy.CANCEL;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isLandscape) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        left: 8,
        right: 12,
      ),
      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.95),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _adapter.isConversationActive ? Icons.arrow_back : Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
            tooltip: _adapter.isConversationActive ? 'Volver a chats' : 'Volver a Nano',
            onPressed: _handlePop,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _adapter.isConversationActive ? 'WhatsApp Chat' : 'WhatsApp Web',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                StreamBuilder<WhatsAppWebSessionInfo>(
                  stream: whatsAppWebBridgeController.sessionStream,
                  initialData: whatsAppWebBridgeController.currentSession,
                  builder: (_, snap) {
                    final isOk = snap.data?.status == WhatsAppWebSessionStatus.connected;
                    return Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOk ? Colors.green : Colors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOk ? 'Sesión conectada' : 'Esperando vinculación',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Botón switch entre Vista Móvil Nano y Web Original
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(
              _isOriginalMode ? Icons.desktop_windows_outlined : Icons.phone_android_rounded,
              size: 15,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
            label: Text(
              _isOriginalMode ? 'Web Original' : 'Vista Móvil',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            onPressed: () async {
              HapticFeedback.selectionClick();
              if (_isOriginalMode) {
                await _adapter.applyResponsiveCss(isLandscape: isLandscape);
                setState(() => _isOriginalMode = false);
              } else {
                await _adapter.restoreOriginalMode();
                setState(() => _isOriginalMode = true);
              }
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Recargar',
            onPressed: () => _webViewController?.reload(),
          ),
        ],
      ),
    );
  }
}
