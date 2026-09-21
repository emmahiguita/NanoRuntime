/// WA-WEB-BRIDGE-CTRL-01 — Controlador del puente WhatsApp Web embebido.
///
/// **QUÉ HACE:**
/// Administra el ciclo de vida, la inyección de scripts y el despacho de mensajes
/// de texto y multimedia a través de una instancia dedicada de InAppWebViewController.
///
/// **CÓMO FUNCIONA:**
/// Se vincula al WebView cargando 'https://web.whatsapp.com', registra un handler
/// de comunicación JavaScript y expone métodos asíncronos para enviar fotos y videos.
///
/// **POR QUÉ:**
/// Permite despachar multimedia 100% en segundo plano sin requerir que el usuario
/// abandone Nano ni interactúe con la app nativa de WhatsApp.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/whatsapp_media_payload.dart';
import 'whatsapp_web_js_bridge.dart';

final class WhatsAppWebBridgeController {
  InAppWebViewController? _controller;
  final _sessionController = StreamController<WhatsAppWebSessionInfo>.broadcast();
  WhatsAppWebSessionInfo _currentSession = const WhatsAppWebSessionInfo(
    status: WhatsAppWebSessionStatus.disconnected,
  );

  WhatsAppWebBridgeController();

  /// Información actual del estado de la sesión de WhatsApp Web.
  WhatsAppWebSessionInfo get currentSession => _currentSession;

  /// Flujo reactivo de cambios en el estado de la sesión.
  Stream<WhatsAppWebSessionInfo> get sessionStream => _sessionController.stream;

  /// Vincula el controlador del WebView activo y registra los listeners de JavaScript.
  void attachController(InAppWebViewController controller) {
    _controller = controller;
    _registerJsHandlers(controller);
  }

  /// Desvincula el controlador cuando el WebView se destruye o pasa a reposo.
  void detachController() {
    _controller = null;
  }

  void _registerJsHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'WhatsAppWebEvent',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) return;
        final map = Map<String, dynamic>.from(args.first as Map);
        final event = map['event'] as String?;
        final data = map['data'] is Map ? Map<String, dynamic>.from(map['data'] as Map) : {};

        if (event == 'status_changed') {
          final statusStr = data['status'] as String? ?? 'disconnected';
          final qrDataUrl = data['qrDataUrl'] as String?;
          final qrDataRef = data['qrDataRef'] as String?;
          final newStatus = switch (statusStr) {
            'waitingForQr' => WhatsAppWebSessionStatus.waitingForQr,
            'syncing' => WhatsAppWebSessionStatus.syncing,
            'connected' => WhatsAppWebSessionStatus.connected,
            _ => WhatsAppWebSessionStatus.disconnected,
          };
          _updateSession(_currentSession = WhatsAppWebSessionInfo(
            status: newStatus,
            lastActive: DateTime.now(),
            qrDataUrl: qrDataUrl,
            qrDataRef: qrDataRef,
          ));
        }
      },
    );
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
    }
  }

  /// Despacha un archivo multimedia (foto, video, documento) a un número de teléfono.
  Future<bool> sendMedia(
    WhatsAppMediaPayload payload, {
    required String recipientPhone,
  }) async {
    final ctrl = _controller;
    if (ctrl == null || !_currentSession.isConnected) return false;

    // Obtener los bytes en Base64
    final bytes = payload.bytes ?? (payload.filePath != null ? await File(payload.filePath!).readAsBytes() : null);
    if (bytes == null || bytes.isEmpty) return false;

    final base64Data = base64Encode(bytes);
    final script = WhatsAppWebJsBridge.buildSendMediaScript(
      base64Data: base64Data,
      mimeType: payload.mimeType,
      fileName: payload.fileName,
      caption: payload.caption,
    );

    final rawResult = await ctrl.evaluateJavascript(source: script);
    if (rawResult == null) return false;

    try {
      final parsed = jsonDecode(rawResult.toString()) as Map<String, dynamic>;
      return parsed['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Despacha un mensaje de texto simple a través del canal Web.
  Future<bool> sendText(String text, {required String recipientPhone}) async {
    final ctrl = _controller;
    if (ctrl == null || !_currentSession.isConnected) return false;

    final cleanText = Uri.encodeComponent(text);
    final script = '''(function(){var i=document.querySelector('div[contenteditable="true"][data-tab="10"]');if(i){i.focus();document.execCommand('insertText',false,decodeURIComponent('$cleanText'));var b=document.querySelector('button[data-testid="compose-btn-send"]')||document.querySelector('span[data-icon="send"]');if(b){b.click();return true;}}return false;})();''';
    final result = await ctrl.evaluateJavascript(source: script);
    return result == true;
  }

  /// Alterna el modo de vinculación a código de 8 dígitos (sin requerir segundo teléfono).
  Future<bool> switchToPhoneLinking() async {
    final ctrl = _controller;
    if (ctrl == null) return false;
    final result = await ctrl.evaluateJavascript(
      source: WhatsAppWebJsBridge.switchToPhoneCodeScript,
    );
    return result == true;
  }

  /// Captura la pantalla física actual del WebView nativo en formato PNG.
  ///
  /// **QUÉ HACE:**
  /// Genera un buffer de bytes PNG directamente de la textura del WebView.
  ///
  /// **CÓMO FUNCIONA:**
  /// Llama a `takeScreenshot()` del InAppWebViewController.
  ///
  /// **POR QUÉ:**
  /// Permite mostrar el código QR real en pantalla aun si el DOM de WhatsApp bloquea canvas.toDataURL.
  Future<Uint8List?> captureScreen() async {
    final ctrl = _controller;
    if (ctrl == null) return null;
    try {
      return await ctrl.takeScreenshot();
    } catch (_) {
      return null;
    }
  }

  /// Extrae el código de vinculación de 8 dígitos de WhatsApp Web si está visible.
  Future<String?> getPairingCode() async {
    final ctrl = _controller;
    if (ctrl == null) return null;
    final res = await ctrl.evaluateJavascript(
      source: WhatsAppWebJsBridge.extractPairingCodeScript,
    );
    return res?.toString();
  }

  /// Recarga la página de WhatsApp Web si se produce una pérdida de sincronización.
  Future<void> reloadSession() async {
    await _controller?.reload();
  }

  void dispose() {
    _sessionController.close();
    _controller = null;
  }
}

/// Instancia singleton para el bridge de WhatsApp Web.
final whatsAppWebBridgeController = WhatsAppWebBridgeController();
