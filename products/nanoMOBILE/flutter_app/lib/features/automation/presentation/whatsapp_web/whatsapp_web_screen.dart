// whatsapp_web_screen.dart
//
// QUÉ HACE:
// Pantalla de ejecución para WhatsApp Web dentro de Nano Mobile con
// ciclo de vida persistente (KeepAlive), navegación nativa y teclado adaptativo.
//
// CÓMO FUNCIONA:
// - Mantiene viva la sesión de WhatsApp entre cambios de pantalla sin recargar la página.
// - Coordina PopScope para interceptar el botón atrás físico y retornar a la lista de chats.
// - Emplea WhatsAppWebAppBar y WhatsAppWebViewContainer como componentes desacoplados.
// - Adapta los insets del teclado virtual para prevenir solapamiento con la barra de redacción.
//
// POR QUÉ:
// Aplica Clean Architecture y principios SOLID dividiendo responsabilidades en widgets
// independientes, cada uno estrictamente menor a 200 líneas de código y altamente mantenible.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/whatsapp_media_payload.dart';
import '../../engine/web_bridge/whatsapp_web_bridge_controller.dart';
import 'whatsapp_web_adapter.dart';
import 'whatsapp_web_session_ownership.dart';
import 'whatsapp_web_chat_request.dart';

import 'widgets/whatsapp_web_app_bar.dart';
import 'widgets/whatsapp_web_view_container.dart';

part 'whatsapp_web_screen_layout.dart';
part 'whatsapp_web_requested_chat.dart';

class WhatsAppWebScreen extends ConsumerStatefulWidget {
  final String? chatTitle, chatAlias;
  const WhatsAppWebScreen({super.key, this.chatTitle, this.chatAlias});

  static final WhatsAppWebAdapter _persistentAdapter = WhatsAppWebAdapter();

  /// Cede el WebView del panel antes de montar la ruta; nunca hay dos dueños.
  static Future<void> navigateTo(
    BuildContext context, {
    String? chatTitle,
    String? chatAlias,
  }) async {
    if (WhatsAppWebSessionOwnership.foreground.value) return;
    WhatsAppWebSessionOwnership.foreground.value = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      final route = MaterialPageRoute<void>(
        builder: (_) =>
            WhatsAppWebScreen(chatTitle: chatTitle, chatAlias: chatAlias),
      );
      await Navigator.of(context).push(route);
      // Pop completa antes de retirar el overlay; espera la disposición real.
      await route.completed;
    } finally {
      WhatsAppWebSessionOwnership.foreground.value = false;
    }
  }

  @override
  ConsumerState<WhatsAppWebScreen> createState() => _WhatsAppWebScreenState();
}

class _WhatsAppWebScreenState extends ConsumerState<WhatsAppWebScreen> {
  final _adapter = WhatsAppWebScreen._persistentAdapter;
  InAppWebViewController? _webViewController;
  double _progress = 0.0;
  bool _isOriginalMode = false;
  bool _openingRequestedChat = false, _requestedChatReady = false;
  String? _requestedChatError;
  late WhatsAppWebSessionInfo _session;
  StreamSubscription<WhatsAppWebSessionInfo>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _session = whatsAppWebBridgeController.currentSession;
    _sessionSubscription = whatsAppWebBridgeController.sessionStream.listen((
      session,
    ) {
      if (mounted) setState(() => _session = session);
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    unawaited(_adapter.suspendDomObserver());
    _adapter.detachController();
    super.dispose();
  }

  Future<void> _handlePop() async {
    // Un chat abierto desde el panel retorna al panel, no a otra conversación Web.
    if (widget.chatTitle != null) {
      Navigator.of(context).pop();
      return;
    }
    final handledByWeb = await _adapter.handleBackPress();
    if (!handledByWeb && mounted) {
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleDisplayMode({required bool useTabletLayout}) async {
    HapticFeedback.selectionClick();
    if (_isOriginalMode) {
      await _adapter.applyResponsiveCss(useTabletLayout: useTabletLayout);
      if (!mounted) return;
      setState(() => _isOriginalMode = false);
      await _adapter.setupDomObserver(
        onNavChanged: (_) {
          if (mounted) setState(() {});
        },
      );
    } else {
      await _adapter.restoreOriginalMode();
      if (!mounted) return;
      setState(() => _isOriginalMode = true);
    }
  }

  Future<void> _synchronizeAttachedView({required bool useTabletLayout}) async {
    if (_isOriginalMode) {
      await _adapter.restoreOriginalMode();
      return;
    }
    await _adapter.applyResponsiveCss(useTabletLayout: useTabletLayout);
    await _adapter.setupDomObserver(
      onNavChanged: (_) {
        if (mounted) setState(() {});
      },
    );
    await _openRequestedChat();
  }

  Future<void> _restorePersistentView({required bool useTabletLayout}) async {
    final controller = _webViewController;
    if (controller == null) return;

    final currentUrl = (await controller.getUrl())?.toString() ?? '';
    if (!WhatsAppWebAdapter.isAllowedUrl(currentUrl)) {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(WhatsAppWebAdapter.entryUrl)),
      );
      return;
    }

    await whatsAppWebBridgeController.onPageFinished(currentUrl);
    await _synchronizeAttachedView(useTabletLayout: useTabletLayout);
  }

  bool _usesTablet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide >= 600 && size.width >= 700;
  }

  @override
  Widget build(BuildContext context) => _buildLayout(context);
}
