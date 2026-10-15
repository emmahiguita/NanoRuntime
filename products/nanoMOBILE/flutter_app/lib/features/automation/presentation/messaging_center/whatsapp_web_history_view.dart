/// Hilo real de WhatsApp Web embebido en el detalle de Mensajería.
///
/// No reconstruye mensajes desde previews: el WebView oficial conserva texto,
/// fotos, videos, audios, reacciones y paginación con una sola fuente visual.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../engine/messaging/conversation_memory.dart';
import '../../engine/web_bridge/whatsapp_web_bridge_controller.dart';
import '../whatsapp_web/whatsapp_web_adapter.dart';
import '../whatsapp_web/whatsapp_web_chat_request.dart';
import '../whatsapp_web/whatsapp_web_session_ownership.dart';
import '../whatsapp_web/widgets/whatsapp_web_view_container.dart';

class WhatsAppWebHistoryView extends StatefulWidget {
  final String title, alias;
  final List<ConversationMemoryEntry> fallback;
  final Widget Function(ConversationMemoryEntry) bubble;

  const WhatsAppWebHistoryView({
    super.key,
    required this.title,
    required this.alias,
    required this.fallback,
    required this.bubble,
  });

  @override
  State<WhatsAppWebHistoryView> createState() => _WhatsAppWebHistoryViewState();
}

class _WhatsAppWebHistoryViewState extends State<WhatsAppWebHistoryView> {
  final _adapter = WhatsAppWebAdapter();
  InAppWebViewController? _controller;
  bool _opening = false, _ready = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_adapter.suspendDomObserver());
    _adapter.detachController();
    super.dispose();
  }

  Future<void> _prepare(InAppWebViewController controller, String? url) async {
    if (!mounted) return;
    final useTabletLayout = MediaQuery.sizeOf(context).shortestSide >= 600;
    if (url != null && WhatsAppWebAdapter.isAllowedUrl(url)) {
      await whatsAppWebBridgeController.onPageFinished(url);
    }
    await _adapter.applyResponsiveCss(useTabletLayout: useTabletLayout);
    await _adapter.setupDomObserver(onNavChanged: (_) {});
    await _openChat();
  }

  Future<void> _openChat() async {
    final controller = _controller;
    if (controller == null || _opening || _ready) return;
    _opening = true;
    if (mounted) setState(() => _error = null);
    try {
      await WhatsAppWebChatRequest.open(
        controller,
        widget.title,
        widget.alias,
        () => !mounted,
      );
      await _adapter.syncNavigationState(WhatsAppNavState.conversation);
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'No se pudo abrir el historial real de WhatsApp',
        );
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WhatsAppWebViewContainer(
          keepAlive: WhatsAppWebSessionOwnership.keepAlive,
          hasCreatedPersistentWebView: WhatsAppWebSessionOwnership.created,
          onWebViewCreated: (controller) {
            WhatsAppWebSessionOwnership.created = true;
            _controller = controller;
            _adapter.attachController(controller);
            whatsAppWebBridgeController.attachController(controller);
            unawaited(
              controller.getUrl().then(
                (url) => _prepare(controller, url?.toString()),
              ),
            );
          },
          onLoadStop: (controller, url) {
            unawaited(_prepare(controller, url?.toString()));
          },
          onProgressChanged: (_) {},
        ),
        if (!_ready)
          ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error == null) const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? 'Abriendo el historial real de WhatsApp…',
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null)
                      TextButton(
                        onPressed: _openChat,
                        child: const Text('Reintentar'),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
