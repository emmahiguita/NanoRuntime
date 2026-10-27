// whatsapp_web_view_container.dart
//
// QUÉ HACE:
// Contenedor modular de InAppWebView configurado con las banderas óptimas
// para ejecutar WhatsApp Web y su pila WebRTC/VoIP de manera fluida en Android.
//
// CÓMO FUNCIONA:
// - Aplica aceleración de hardware y composición híbrida de Android.
// - Conserva intactos los scripts y Web Workers oficiales de WhatsApp Web.
// - Endurece `onPermissionRequest` autorizando exclusivamente `MICROPHONE` y `CAMERA`
//   para el origen `https://web.whatsapp.com` tras verificar permisos nativos de Android.
//
// POR QUÉ:
// Aplica SRP aislando la configuración de WebView y seguridad WebRTC fuera del Screen
// principal, manteniendo el archivo estrictamente por debajo de 200 líneas.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../engine/web_bridge/whatsapp_web_js_bridge.dart';
import '../scripts/whatsapp_web_rtc_helper.dart';
import '../whatsapp_web_adapter.dart';

class WhatsAppWebViewContainer extends StatelessWidget {
  final InAppWebViewKeepAlive keepAlive;
  final bool hasCreatedPersistentWebView;
  final void Function(InAppWebViewController) onWebViewCreated;
  final void Function(InAppWebViewController, WebUri?) onLoadStop;
  final void Function(int) onProgressChanged;

  const WhatsAppWebViewContainer({
    super.key,
    required this.keepAlive,
    required this.hasCreatedPersistentWebView,
    required this.onWebViewCreated,
    required this.onLoadStop,
    required this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: InAppWebView(
        keepAlive: keepAlive,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
        },
        initialUrlRequest: hasCreatedPersistentWebView
            ? null
            : URLRequest(url: WebUri(WhatsAppWebAdapter.entryUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent: WhatsAppWebJsBridge.desktopUserAgent,
          javaScriptEnabled: true,
          domStorageEnabled: true,
          cacheEnabled: true,
          cacheMode: CacheMode.LOAD_DEFAULT,
          databaseEnabled: true,
          useHybridComposition: true,
          hardwareAcceleration: true,
          thirdPartyCookiesEnabled: true,
          supportZoom: true,
          builtInZoomControls: true,
          displayZoomControls: false,
          ignoresViewportScaleLimits: true,
          enableViewportScale: true,
          minimumZoomScale: 0.65,
          maximumZoomScale: 5.0,
          useWideViewPort: true,
          loadWithOverviewMode: true,
          loadsImagesAutomatically: true,
          blockNetworkImage: false,
          offscreenPreRaster: true,
          verticalScrollBarEnabled: false,
          horizontalScrollBarEnabled: false,
          overScrollMode: OverScrollMode.NEVER,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          iframeAllow:
              'camera; microphone; autoplay; encrypted-media; fullscreen',
          safeBrowsingEnabled: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
          preferredContentMode: UserPreferredContentMode.DESKTOP,
        ),
        onWebViewCreated: (controller) {
          unawaited(WhatsAppWebRtcHelper.initializeForWebView(controller));
          onWebViewCreated(controller);
        },
        onLoadStop: (controller, url) {
          unawaited(WhatsAppWebRtcHelper.verifyWebRtcEnvironment(controller));
          onLoadStop(controller, url);
        },
        onProgressChanged: (_, progress) => onProgressChanged(progress),
        onPermissionRequest: WhatsAppWebRtcHelper.handlePermissionRequest,
        shouldOverrideUrlLoading: (ctrl, action) async {
          final navUrl = action.request.url?.toString() ?? '';
          if (WhatsAppWebAdapter.isAllowedUrl(navUrl)) {
            return NavigationActionPolicy.ALLOW;
          }
          return NavigationActionPolicy.CANCEL;
        },
      ),
    );
  }
}
