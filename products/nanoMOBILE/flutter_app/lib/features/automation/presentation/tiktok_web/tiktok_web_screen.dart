// tiktok_web_screen.dart
// QUÉ HACE: conecta la bandeja de TikTok Web (adaptada en vertical y horizontal)
//   con Nano: web auténtica + barra de control para leer y responder mensajes.
// CÓMO: identidad desktop, viewport device-width, CSS anti-solapamiento lista↔chat,
//   y captura del botón Atrás del sistema para volver a la lista de chats.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'tiktok_web_adapter.dart';
import 'tiktok_web_control_deck.dart';
import 'tiktok_web_scripts.dart';

class TikTokWebScreen extends StatefulWidget {
  const TikTokWebScreen({super.key});

  static final InAppWebViewKeepAlive _keepAlive = InAppWebViewKeepAlive();
  static final TikTokWebAdapter _persistentAdapter = TikTokWebAdapter();
  static bool _hasCreatedPersistentWebView = false;

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TikTokWebScreen()),
    );
  }

  @override
  State<TikTokWebScreen> createState() => _TikTokWebScreenState();
}

class _TikTokWebScreenState extends State<TikTokWebScreen> {
  final _adapter = TikTokWebScreen._persistentAdapter;
  final _composer = TextEditingController();

  List<TikTokConversation> _conversations = const [];
  String? _activeChatName;
  String? _statusText;
  bool _busy = false;
  double _progress = 0;

  @override
  void dispose() {
    _adapter.detachController();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _bootFirstLoad(InAppWebViewController controller) async {
    final ok = await _adapter.applyDesktopIdentity();
    debugPrint('[TikTokWeb][Identity] desktop=true applied=$ok');
    if (!mounted) return;
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(TikTokWebAdapter.entryUrl)),
    );
  }

  Future<void> _refreshConversations() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    await _adapter.applyPanelLayoutFix();
    if (_activeChatName == null) await _adapter.setChatView(chatOpen: false);
    final chats = await _adapter.readConversations();
    if (!mounted) return;
    setState(() {
      _conversations = chats;
      _busy = false;
      _statusText = chats.isEmpty ? 'Sin chats visibles' : null;
    });
  }

  Future<void> _openConversation(int index) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await _adapter.openConversation(index);
    if (ok) await _adapter.setChatView(chatOpen: true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final name = await _adapter.readActiveChatName();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _activeChatName = name;
      _statusText = ok ? null : 'No se pudo abrir el chat';
    });
  }

  Future<void> _backToList() async {
    await _adapter.setChatView(chatOpen: false);
    if (!mounted) return;
    setState(() => _activeChatName = null);
  }

  Future<void> _send(String text) async {
    if (_busy) return;
    setState(() => _busy = true);
    final reason = await _adapter.sendReply(text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (reason == null) {
        _composer.clear();
        _statusText = 'Mensaje enviado';
      } else {
        _statusText = 'No enviado: $reason';
      }
    });
  }

  Future<NavigationActionPolicy> _guardNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final url = action.request.url?.toString() ?? '';
    if (TikTokWebAdapter.isAllowedUrl(url)) return NavigationActionPolicy.ALLOW;
    debugPrint('[TikTokWeb] navegación externa bloqueada: $url');
    return NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _activeChatName == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _activeChatName != null) _backToList();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TikTok · Mensajes'),
          bottom: _progress < 1
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _progress, minHeight: 2),
                )
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: InAppWebView(
                keepAlive: TikTokWebScreen._keepAlive,
                initialUrlRequest: null,
                initialSettings: TikTokWebAdapter.buildWebViewSettings(),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    groupName: 'tiktok_web_viewport',
                    source: deviceWidthViewportScript,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                  UserScript(
                    groupName: 'tiktok_web_panel_layout',
                    source: panelLayoutCssScript,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                  ),
                ]),
                onWebViewCreated: (controller) {
                  _adapter.attachController(controller);
                  if (!TikTokWebScreen._hasCreatedPersistentWebView) {
                    TikTokWebScreen._hasCreatedPersistentWebView = true;
                    unawaited(_bootFirstLoad(controller));
                  }
                },
                shouldOverrideUrlLoading: _guardNavigation,
                onProgressChanged: (_, progress) {
                  if (mounted) setState(() => _progress = progress / 100);
                },
                onLoadStop: (_, __) => _refreshConversations(),
              ),
            ),
            TikTokWebControlDeck(
              conversations: _conversations,
              activeChatName: _activeChatName,
              busy: _busy,
              composer: _composer,
              statusText: _statusText,
              onRefreshConversations: _refreshConversations,
              onOpenConversation: _openConversation,
              onBackToList: _backToList,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}
