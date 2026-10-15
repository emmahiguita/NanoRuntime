/// Coordina el WebView vinculado; retiene su identidad y delega parsing/envíos.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/whatsapp_media_payload.dart';
import 'whatsapp_web_bridge_actions.dart';
import 'whatsapp_web_conversation_cache.dart';
import 'whatsapp_web_js_bridge.dart';
import 'whatsapp_web_conversation_decoder.dart';
import 'whatsapp_web_message_transport.dart';
import 'whatsapp_web_observer_access.dart';
import 'whatsapp_web_session_decoder.dart';

export 'whatsapp_web_conversation_decoder.dart'
    show WhatsAppWebConversationSummary;

final class WhatsAppWebBridgeController {
  InAppWebViewController? _controller;
  final _sessionController =
      StreamController<WhatsAppWebSessionInfo>.broadcast();
  final _conversationsController =
      StreamController<List<WhatsAppWebConversationSummary>>.broadcast();
  WhatsAppWebSessionInfo _currentSession = const WhatsAppWebSessionInfo(
    status: WhatsAppWebSessionStatus.disconnected,
  );
  List<WhatsAppWebConversationSummary> _currentConversations = const [];
  String? _conversationAccount;
  bool _conversationFeedEnabled = false;
  WhatsAppWebBridgeController();

  InAppWebViewController? get retainedController => _controller;
  WhatsAppWebSessionInfo get currentSession => _currentSession;
  Stream<WhatsAppWebSessionInfo> get sessionStream => _sessionController.stream;
  List<WhatsAppWebConversationSummary> get currentConversations =>
      _currentConversations;
  String? get conversationAccount => _conversationAccount;
  Stream<List<WhatsAppWebConversationSummary>> get conversationsStream =>
      _conversationsController.stream;

  void attachController(InAppWebViewController controller) {
    _controller = controller;
    _registerJsHandlers(controller);
    unawaited(_syncConversationObserver());
  }

  void detachController() => _controller = null;

  void _registerJsHandlers(InAppWebViewController controller) {
    controller.removeJavaScriptHandler(handlerName: 'WhatsAppWebEvent');
    controller.addJavaScriptHandler(
      handlerName: 'WhatsAppWebEvent',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) return {'accepted': false};
        final map = Map<String, dynamic>.from(args.first as Map);
        final event = map['event'] as String?;
        final data = map['data'] is Map
            ? Map<String, dynamic>.from(map['data'] as Map)
            : <String, dynamic>{};
        if (event == 'status_changed') {
          _updateSession(decodeWhatsAppWebSession(data));
        } else if (event == 'conversations_changed') {
          if (!_conversationFeedEnabled || data['conversations'] is! List) {
            return {'accepted': false};
          }
          final account = '${data['account'] ?? ''}';
          if (account.isEmpty) return {'accepted': false};
          _handleConversationEvent(data['conversations'], account);
          return {'accepted': true};
        }
        return {'accepted': false};
      },
    );
  }

  // Una única publicación por snapshot recibido y reconocido por Flutter.
  void _handleConversationEvent(Object? rawValue, String account) {
    // Otra cuenta vinculada no hereda los chats de la anterior.
    final previous =
        account.isNotEmpty &&
            _conversationAccount != null &&
            _conversationAccount != account
        ? const <WhatsAppWebConversationSummary>[]
        : _currentConversations;
    if (account.isNotEmpty) _conversationAccount = account;
    _publishConversations(
      WhatsAppWebConversationDecoder().decode(rawValue, previous),
    );
    unawaited(
      WhatsAppWebConversationCache.save(
        _conversationAccount,
        _currentConversations,
      ),
    );
    debugPrint('[wa-web-feed] received rows=${_currentConversations.length}');
  }

  void _publishConversations(List<WhatsAppWebConversationSummary> value) {
    _currentConversations = List.unmodifiable(value);
    if (!_conversationsController.isClosed) {
      _conversationsController.add(_currentConversations);
    }
  }

  Future<void> setConversationFeedEnabled(bool enabled) async {
    _conversationFeedEnabled = enabled;
    if (!enabled) {
      _publishConversations(const []);
    } else if (_currentConversations.isEmpty) {
      final cached = await WhatsAppWebConversationCache.restore();
      if (cached != null &&
          _currentConversations.isEmpty &&
          _conversationFeedEnabled) {
        _conversationAccount = cached.account;
        _publishConversations(cached.items);
      }
    }
    await _syncConversationObserver(failOnError: true);
  }

  Future<void> _syncConversationObserver({bool failOnError = false}) async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      final applied = await WhatsAppWebObserverAccess.evaluate(
        ctrl,
        _conversationFeedEnabled
            ? WhatsAppWebJsBridge.conversationObserverScript
            : WhatsAppWebJsBridge.stopConversationObserverScript,
      );
      if (!applied) throw StateError('WebView observer not applied');
      debugPrint('[wa-web-feed] observer enabled=$_conversationFeedEnabled');
    } catch (error) {
      debugPrint('[wa-web-feed] observer failed type=${error.runtimeType}');
      if (failOnError) rethrow;
    }
  }

  void _updateSession(WhatsAppWebSessionInfo info) {
    _currentSession = info;
    if (!_sessionController.isClosed) {
      _sessionController.add(info);
    }
  }

  /// Inyecta el script de observación cuando la página termina de cargar.
  Future<void> onPageFinished(String? url) async {
    if (url != null && url.contains('web.whatsapp.com')) {
      await _controller?.evaluateJavascript(
        source: WhatsAppWebJsBridge.sessionObserverScript,
      );
      await _syncConversationObserver();
    }
  }

  /// Delega el envío existente; observar el feed nunca activa estos métodos.
  Future<bool> sendMedia(
    WhatsAppMediaPayload payload, {
    required String recipientPhone,
  }) => WhatsAppWebMessageTransport.sendMedia(
    _controller,
    _currentSession.isConnected,
    payload,
    recipientPhone: recipientPhone,
  );

  Future<bool> sendText(String text, {required String recipientPhone}) =>
      WhatsAppWebMessageTransport.sendText(
        _controller,
        _currentSession.isConnected,
        text,
        recipientPhone: recipientPhone,
        expectedAccount: _conversationAccount ?? '',
      );

  Future<bool> switchToPhoneLinking() =>
      WhatsAppWebBridgeActions.switchToPhoneLinking(_controller);

  Future<Uint8List?> captureScreen() =>
      WhatsAppWebBridgeActions.captureScreen(_controller);

  Future<String?> getPairingCode() =>
      WhatsAppWebBridgeActions.getPairingCode(_controller);

  Future<void> reloadSession() =>
      WhatsAppWebBridgeActions.reloadSession(_controller);

  void dispose() {
    _sessionController.close();
    _conversationsController.close();
    _controller = null;
  }
}

/// Instancia singleton para el bridge de WhatsApp Web.
final whatsAppWebBridgeController = WhatsAppWebBridgeController();
