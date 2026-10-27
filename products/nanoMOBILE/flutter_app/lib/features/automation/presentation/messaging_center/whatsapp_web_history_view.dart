/// Archivo local verificado primero, con la vista original Web disponible.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../engine/messaging/conversation_memory.dart';
import '../../application/visible_whatsapp_history_sync.dart';
import 'saved_whatsapp_history_view.dart';
import '../../engine/web_bridge/whatsapp_web_bridge_controller.dart';
import '../../engine/web_bridge/whatsapp_web_readiness.dart';
import '../whatsapp_web/whatsapp_web_adapter.dart';
import '../whatsapp_web/whatsapp_web_chat_request.dart';
import '../whatsapp_web/whatsapp_web_session_ownership.dart';
import '../whatsapp_web/widgets/whatsapp_web_view_container.dart';

class WhatsAppWebHistoryView extends StatefulWidget {
  final String title, alias;
  final Widget Function(ConversationMemoryEntry) bubble;

  const WhatsAppWebHistoryView({
    super.key,
    required this.title,
    required this.alias,
    required this.bubble,
  });

  @override
  State<WhatsAppWebHistoryView> createState() => _WhatsAppWebHistoryViewState();
}

class _WhatsAppWebHistoryViewState extends State<WhatsAppWebHistoryView> {
  final _adapter = WhatsAppWebAdapter();
  InAppWebViewController? _controller;
  bool _preparing = false, _opening = false, _ready = false;
  bool _probing = false;
  bool _showWeb = false, _forceSaved = false;
  late final _sync = VisibleWhatsAppHistorySync(
    title: widget.title,
    alias: widget.alias,
  );
  String? _error;

  @override
  void dispose() {
    _sync.dispose();
    unawaited(_adapter.suspendDomObserver().catchError((Object _) {}));
    _adapter.detachController();
    _controller = null;
    super.dispose();
  }

  /// Sondeo ligero al avanzar la página: no espera a onLoadStop para abrir.
  Future<void> _tryEarlyPreparation(InAppWebViewController controller) async {
    if (!mounted || _probing || _preparing || _ready) return;
    _probing = true;
    try {
      if (await WhatsAppWebReadiness.check(controller) && mounted) {
        await _prepare(controller, WhatsAppWebAdapter.entryUrl);
      }
    } catch (_) {
      /* onLoadStop conserva la ruta de error/reintento visible. */
    } finally {
      _probing = false;
    }
  }

  Future<void> _prepare(InAppWebViewController controller, String? url) async {
    if (!mounted ||
        _preparing ||
        _ready ||
        url == null ||
        !WhatsAppWebAdapter.isAllowedUrl(url)) {
      return;
    }
    _preparing = true;
    try {
      final useTabletLayout = MediaQuery.sizeOf(context).shortestSide >= 600;
      await _adapter.applyResponsiveCss(useTabletLayout: useTabletLayout);
      if (!mounted) return;
      await _adapter.setupDomObserver(onNavChanged: (_) {});
      await _openChat();
      // La apertura tiene prioridad sobre el escaneo del feed completo.
      if (mounted && _ready) {
        unawaited(
          whatsAppWebBridgeController
              .onPageFinished(url)
              .catchError((Object _) {}),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo preparar la sesión Web. Reintenta.',
        );
      }
    } finally {
      _preparing = false;
    }
  }

  Future<void> _openChat() async {
    final controller = _controller;
    if (!mounted || controller == null || _opening || _ready) return;
    _opening = true;
    final openingWatch = Stopwatch()..start();
    if (mounted) setState(() => _error = null);
    try {
      await WhatsAppWebChatRequest.open(
        controller,
        widget.title,
        widget.alias,
        () => !mounted,
      );
      if (!mounted) return;
      await _adapter.syncNavigationState(WhatsAppNavState.conversation);
      if (mounted) setState(() => _ready = true);
      _sync.start();
      debugPrint(
        '[wa-web-open] verified=true elapsedMs=${openingWatch.elapsedMilliseconds}',
      );
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
            unawaited(_tryEarlyPreparation(controller));
          },
          onLoadStop: (controller, url) {
            unawaited(_prepare(controller, url?.toString()));
          },
          onProgressChanged: (progress) {
            final controller = _controller;
            if (progress >= 40 && controller != null) {
              unawaited(_tryEarlyPreparation(controller));
            }
          },
        ),
        if (!_showWeb || !_ready)
          SavedWhatsAppHistoryView(
            alias: widget.alias,
            bubble: widget.bubble,
            revision: _sync.revision,
            ready: _ready,
            autoOpenWebIfEmpty: !_forceSaved,
            error: _error,
            onWeb: () => setState(() => _showWeb = true),
            onRetry: () {
              final controller = _controller;
              if (controller != null) {
                unawaited(_prepare(controller, WhatsAppWebAdapter.entryUrl));
              }
            },
          ),
        if (_showWeb && _ready)
          Positioned(
            top: 4,
            right: 4,
            child: FilledButton.tonal(
              onPressed: () => setState(() {
                _showWeb = false;
                _forceSaved = true;
              }),
              child: const Text('Guardados'),
            ),
          ),
      ],
    );
  }
}
