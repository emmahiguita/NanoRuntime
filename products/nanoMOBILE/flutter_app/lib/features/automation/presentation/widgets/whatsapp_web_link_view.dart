/// WA-WEB-LINK-VIEW-01 — Ventana flotante adaptable para WhatsApp Web en Nano.
///
/// **QUÉ HACE:**
/// Muestra WhatsApp Web como una ventana flotante responsive con soporte de zoom
/// (ampliar y reducir al máximo) sin ocultar la barra de estado (batería, wifi, hora).
///
/// **CÓMO FUNCIONA:**
/// Usa `showGeneralDialog` con fondo translúcido y márgenes seguros adaptados a
/// orientación vertical u horizontal, junto con controles de zoom en el WebView.
///
/// **POR QUÉ:**
/// Evita la deformación visual, respeta el layout del sistema y permite operar
/// WhatsApp Web tanto en teléfonos verticales como en orientación horizontal.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/whatsapp_media_payload.dart';
import '../../engine/web_bridge/whatsapp_web_bridge_controller.dart';
import '../../engine/web_bridge/whatsapp_web_js_bridge.dart';
import 'whatsapp_qr_scanner_dialog.dart';

class WhatsAppWebLinkView extends StatefulWidget {
  const WhatsAppWebLinkView({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar WA Web',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      pageBuilder: (ctx, anim1, anim2) => const SafeArea(child: WhatsAppWebLinkView()),
    );
  }

  @override
  State<WhatsAppWebLinkView> createState() => _WhatsAppWebLinkViewState();
}

class _WhatsAppWebLinkViewState extends State<WhatsAppWebLinkView> {
  InAppWebViewController? _webViewController;
  double _progress = 0.0;

  @override
  void dispose() {
    whatsAppWebBridgeController.detachController();
    super.dispose();
  }

  void _zoom(double factor) => _webViewController?.zoomBy(zoomFactor: factor);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isLandscape ? min(size.width * 0.85, 820) : size.width * 0.96,
          height: isLandscape ? size.height * 0.92 : size.height * 0.90,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(isLandscape ? 16 : 22),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, spreadRadius: 2)],
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildTopBar(theme, isLandscape),
              _buildActionChips(theme, isLandscape),
              if (_progress < 1.0) LinearProgressIndicator(value: _progress, minHeight: 2),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri('https://web.whatsapp.com')),
                  initialSettings: InAppWebViewSettings(
                    userAgent: WhatsAppWebJsBridge.desktopUserAgent,
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    cacheEnabled: true,
                    supportZoom: true,
                    builtInZoomControls: true,
                    displayZoomControls: false,
                    useWideViewPort: true,
                    loadWithOverviewMode: true,
                  ),
                  onWebViewCreated: (c) { _webViewController = c; whatsAppWebBridgeController.attachController(c); },
                  onProgressChanged: (_, p) => setState(() => _progress = p / 100),
                  onLoadStop: (_, u) => whatsAppWebBridgeController.onPageFinished(u?.toString()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, bool isLandscape) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8 : 12, vertical: isLandscape ? 4 : 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Row(
        children: [
          const Icon(Icons.qr_code_scanner, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Vincular WA Web',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: isLandscape ? 13 : 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          StreamBuilder<WhatsAppWebSessionInfo>(
            stream: whatsAppWebBridgeController.sessionStream,
            initialData: whatsAppWebBridgeController.currentSession,
            builder: (_, snap) {
              final ok = snap.data?.status == WhatsAppWebSessionStatus.connected;
              return Chip(
                avatar: CircleAvatar(radius: 4, backgroundColor: ok ? Colors.green : Colors.amber),
                label: Text(ok ? 'Conectado' : 'Pendiente', style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
          IconButton(icon: const Icon(Icons.zoom_out, size: 18), onPressed: () => _zoom(0.8), visualDensity: VisualDensity.compact),
          IconButton(icon: const Icon(Icons.zoom_in, size: 18), onPressed: () => _zoom(1.25), visualDensity: VisualDensity.compact),
          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: () => _webViewController?.reload(), visualDensity: VisualDensity.compact),
          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop(), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }

  Widget _buildActionChips(ThemeData theme, bool isLandscape) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: isLandscape ? 2 : 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ActionChip(
              avatar: const Icon(Icons.phone_android, size: 15, color: Colors.green),
              label: const Text('Código 8 Dígitos', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final ok = await whatsAppWebBridgeController.switchToPhoneLinking();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Ingresa tu teléfono en WA Web.' : 'Pulsa Vincular con teléfono.')));
                }
              },
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.launch, size: 15, color: Colors.blue),
              label: const Text('Abrir WhatsApp', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final u = Uri.parse('whatsapp://');
                if (await canLaunchUrl(u)) await launchUrl(u);
              },
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.camera_alt, size: 15, color: Colors.orange),
              label: const Text('Escanear QR', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              onPressed: () => WhatsAppQrScannerDialog.show(context),
            ),
          ],
        ),
      ),
    );
  }
}
