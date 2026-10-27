// tiktok_web_adapter.dart
//
// QUÉ HACE: puente entre Flutter y la bandeja de mensajes real de TikTok Web.
//   Expone operaciones tipadas: leer conversaciones, abrir una, leer el chat
//   activo, listar mensajes y enviar una respuesta.
// CÓMO FUNCIONA: mantiene el controller del WebView y ejecuta los scripts de
//   `tiktok_web_scripts.dart` (selectores data-e2e verificados en dispositivo),
//   parseando el JSON devuelto a modelos inmutables.
// POR QUÉ: SRP — la pantalla no conoce JavaScript ni selectores; el adapter
//   concentra el contrato con el DOM y puede evolucionar solo si TikTok cambia.
// SEGURIDAD: solo se opera sobre hosts tiktok.com por HTTPS (isAllowedUrl).

import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/core/platform/browser_web_compatibility_bridge.dart';

import 'tiktok_web_scripts.dart';
import 'tiktok_web_types.dart';

export 'tiktok_web_types.dart';

class TikTokWebAdapter {
  /// Bandeja de mensajes (misma sesión ya iniciada en el WebView de Nano).
  static const String entryUrl = 'https://www.tiktok.com/messages';

  /// Hosts legítimos navegables dentro de la pantalla de mensajes.
  static const List<String> allowedHosts = ['tiktok.com', 'www.tiktok.com'];

  /// Settings de fluidez del WebView (HW + offscreen + composición híbrida).
  /// El UA/CH coherentes los fija el bridge nativo; nunca un userAgent falso.
  static InAppWebViewSettings buildWebViewSettings() => InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        thirdPartyCookiesEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        useShouldOverrideUrlLoading: true,
        hardwareAcceleration: true,
        useHybridComposition: true,
        offscreenPreRaster: true,
        overScrollMode: OverScrollMode.IF_CONTENT_SCROLLS,
        supportZoom: true,
        builtInZoomControls: true,
        displayZoomControls: false,
        // Garantiza escala 1:1 + pan horizontal del lienzo 720px: sin esto
        // Chromium puede forzar el ajuste del ancho y encoger todo.
        ignoresViewportScaleLimits: true,
      );

  InAppWebViewController? _controller;

  void attachController(InAppWebViewController controller) {
    _controller = controller;
  }

  void detachController() {
    _controller = null;
  }

  /// Aplica la identidad de escritorio real (UA Windows + Client Hints
  /// coherentes + layout por ancho físico) ANTES de la primera carga.
  ///
  /// Mismo pipeline nativo que usa el navegador de Nano para TikTok escritorio:
  /// sin él, la bandeja se renderiza como página móvil en vez de la vista
  /// de 3 paneles auténtica.
  Future<bool> applyDesktopIdentity() async {
    final ctrl = _controller;
    if (ctrl == null) return false;
    return const BrowserWebCompatibilityBridge().setDesktopIdentity(
      ctrl,
      enabled: true,
      forceMobileLayout: true,
    );
  }

  /// Valida https + host TikTok (bloquea terceros y esquemas de app).
  static bool isAllowedUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'https') return false;
    final host = uri.host.toLowerCase();
    return allowedHosts.any(
      (allowed) => host == allowed || host.endsWith('.$allowed'),
    );
  }

  /// Ejecuta un script y devuelve el JSON decodificado (null si falla).
  Future<Object?> _eval(String script) async {
    final ctrl = _controller;
    if (ctrl == null) return null;
    try {
      final raw = await ctrl.evaluateJavascript(source: script);
      if (raw == null) return null;
      return jsonDecode(raw is String ? raw : raw.toString());
    } catch (_) {
      return null;
    }
  }

  /// Ejecuta un script sin parsear su resultado (operaciones de UI).
  Future<String?> _run(String script) async {
    final ctrl = _controller;
    if (ctrl == null) return null;
    try {
      final raw = await ctrl.evaluateJavascript(source: script);
      return raw?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Reaplica el CSS adaptativo vertical/horizontal para evitar solapes.
  Future<void> applyPanelLayoutFix() => _run(panelLayoutCssScript);

  /// Alterna la vista: en vertical cambia lista/chat; en horizontal coexisten.
  Future<void> setChatView({required bool chatOpen}) =>
      _run(buildSetChatViewScript(chatOpen: chatOpen));

  /// Lista real de conversaciones, reintentando mientras la SPA monta la lista.
  ///
  /// La carrera real: `onLoadStop` dispara antes de que React pinte las filas
  /// (por eso el deck mostraba «0 chats» con la lista visible en pantalla).
  Future<List<TikTokConversation>> readConversations({
    int attempts = 6,
    Duration retryDelay = const Duration(milliseconds: 1200),
  }) async {
    for (var i = 0; i < attempts; i++) {
      final data = await _eval(buildReadConversationsScript());
      if (data is List && data.isNotEmpty) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(TikTokConversation.fromJson)
            .where((c) => c.name.isNotEmpty)
            .toList();
      }
      if (i < attempts - 1) await Future<void>.delayed(retryDelay);
    }
    return const [];
  }

  /// Abre la conversación en la posición [index]; true si el clic ocurrió.
  Future<bool> openConversation(int index) async {
    final data = await _eval(buildOpenConversationScript(index));
    return data is Map && data['ok'] == true;
  }

  /// Nombre y @usuario del chat actualmente abierto (null si no hay chat).
  Future<String?> readActiveChatName() async {
    final data = await _eval(buildReadActiveChatScript());
    if (data is! Map) return null;
    final name = (data['name'] as String?)?.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  /// Mensajes visibles del chat abierto (últimos 30, orden cronológico).
  Future<List<TikTokChatMessage>> readMessages() async {
    final data = await _eval(buildReadMessagesScript());
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(TikTokChatMessage.fromJson)
        .where((m) => m.text.isNotEmpty)
        .toList();
  }

  /// Envía [text] al chat abierto; devuelve el motivo real si falla.
  Future<String?> sendReply(String text) async {
    final data = await _eval(buildSendReplyScript(text));
    if (data is Map && data['ok'] == true) return null;
    if (data is Map) return (data['reason'] as String?) ?? 'envío rechazado';
    return 'sin editor disponible';
  }

  /// No leídos globales de la barra lateral (0 si TikTok no lo expone).
  Future<int> readUnreadBadge() async {
    final data = await _eval(buildUnreadBadgeScript());
    if (data is! Map) return 0;
    return int.tryParse('${data['unread'] ?? ''}') ?? 0;
  }
}
