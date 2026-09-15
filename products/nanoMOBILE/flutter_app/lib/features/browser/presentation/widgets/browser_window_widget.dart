import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/browser/application/browser_context_extractor.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';
import 'package:nanoai/features/browser/infrastructure/browser_security_firewall.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_chrome_bar.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_quick_shortcuts_bar.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_tab_bar_widget.dart';

/// Ventana visual profesional y reactiva del Navegador Web Real de Nano AI.
///
/// Soporta modo embebido (en Inicio / Dashboard con altura adaptable y minimizable)
/// o pantalla completa en la ruta /browser.
class BrowserWindowWidget extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onFullscreen;
  final VoidCallback? onClose;
  final String? initialUrl;

  const BrowserWindowWidget({
    super.key,
    this.isEmbedded = false,
    this.onFullscreen,
    this.onClose,
    this.initialUrl,
  });

  @override
  ConsumerState<BrowserWindowWidget> createState() => _BrowserWindowWidgetState();
}

class _BrowserWindowWidgetState extends ConsumerState<BrowserWindowWidget> {
  final Map<String, InAppWebViewController> _controllers = {};
  final TextEditingController _urlCtrl = TextEditingController();
  final FocusNode _urlFocus = FocusNode();

  bool _isMinimized = false;
  bool _showTabBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialUrl?.isNotEmpty == true) {
        final resolved = BrowserUrlResolver.resolveUrl(widget.initialUrl!);
        ref.read(browserTabProvider.notifier).updateActiveTab(url: resolved);
      }
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _urlFocus.dispose();
    _controllers.clear();
    super.dispose();
  }

  void _onUrlSubmit(String input) {
    _urlFocus.unfocus();
    final url = BrowserUrlResolver.resolveUrl(input);
    _urlCtrl.text = url;

    // Captura el ID activo ANTES de modificar el estado para evitar
    // la condición de carrera donde el controlador no se encontraría.
    final activeTabId = ref.read(browserTabProvider).activeTabId;
    final notifier = ref.read(browserTabProvider.notifier);
    notifier.updateActiveTab(url: url, isLoading: true, progress: 0.15);

    final ctrl = _controllers[activeTabId];
    if (ctrl != null) {
      ctrl.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    }
    // Si ctrl==null el InAppWebView aún no se montó; su initialUrlRequest
    // ya se actualizó en el estado y cargará al renderizar.
  }

  void _toggleMinimize() {
    HapticFeedback.lightImpact();
    setState(() => _isMinimized = !_isMinimized);
  }

  void _openFullscreen() {
    HapticFeedback.mediumImpact();
    if (widget.onFullscreen != null) {
      widget.onFullscreen!();
    } else {
      context.push('/browser');
    }
  }

  Future<void> _askOwl() async {
    final tab = ref.read(browserTabProvider).activeTab;
    final ctrl = _controllers[tab.id];
    if (ctrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cargando página...')),
      );
      return;
    }
    final ctx = await BrowserContextExtractor.getSanitizedContext(
      controller: ctrl,
      sourceUrl: tab.url,
      pageTitle: tab.title,
    );
    if (ctx == null || ctx.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin texto legible para analizar.')),
        );
      }
      return;
    }
    ref.read(chatProvider.notifier).send(
          'Analiza esta página web observada:\n\nTítulo: ${tab.title}\nURL: ${tab.url}\n\n$ctx\n\n¿Qué resumen y datos clave puedes darme?',
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${tab.title}" enviado a Nano Chat.'),
        action: SnackBarAction(
          label: 'IR AL CHAT',
          onPressed: () => context.go('/chat'),
        ),
      ));
    }
  }

  void _showSslDialog(String url, bool isSecure) {
    final host = BrowserUrlResolver.extractHost(url);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(
            isSecure ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
            color: isSecure ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSecure ? 'Conexión HTTPS Segura' : 'HTTP No Seguro',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sitio: $host',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              isSecure
                  ? 'Tu comunicación está cifrada mediante SSL/TLS. Nano Firewall de aislamiento web activo.'
                  : 'Sin cifrado SSL. No introduzcas credenciales ni datos sensibles.',
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(children: [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Sandbox local & cortafuegos de dominios activo.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          )
        ],
      ),
    );
  }

  void _promptExternalApp(String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Aplicación Externa'),
        content: Text('Esta página solicita abrir en una aplicación externa:\n\n$url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ABRIR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabState = ref.watch(browserTabProvider);
    final tab = tabState.activeTab;
    final notifier = ref.read(browserTabProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;

    if (!_urlFocus.hasFocus && _urlCtrl.text != tab.url) {
      _urlCtrl.text = tab.url;
    }

    final accent = tab.isSecure
        ? (isDark ? const Color(0xFF10B981) : const Color(0xFF1D6FE8))
        : const Color(0xFFEF4444);

    final embeddedHeight = _isMinimized
        ? 58.0
        : (isLandscape ? 310.0 : 420.0);

    final windowDecoration = BoxDecoration(
      color: isDark ? const Color(0xF0071420) : const Color(0xF8F1F5F9),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
          blurRadius: 32,
          spreadRadius: -3,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.18),
          blurRadius: 20,
          spreadRadius: -5,
        ),
      ],
    );

    // Modo embebido: altura controlada por AnimatedContainer → Expanded OK.
    if (widget.isEmbedded) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        height: embeddedHeight,
        width: double.infinity,
        decoration: windowDecoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildChrome(tab, tabState, notifier, colors, isDark),
              if (_showTabBar && !_isMinimized) const BrowserTabBarWidget(),
              if (!_isMinimized)
                BrowserQuickShortcutsBar(
                  isDark: isDark,
                  onSelectUrl: _onUrlSubmit,
                ),
              if (!_isMinimized)
                Expanded(child: _buildWebArea(tab, tabState, notifier, isDark)),
            ],
          ),
        ),
      );
    }

    // Modo fullscreen: LayoutBuilder proporciona la altura real disponible
    // para que el Container tenga dimensiones definidas y Expanded no explote.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: constraints.maxHeight,
          decoration: windowDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                _buildChrome(tab, tabState, notifier, colors, isDark),
                if (_showTabBar) const BrowserTabBarWidget(),
                BrowserQuickShortcutsBar(
                  isDark: isDark,
                  onSelectUrl: _onUrlSubmit,
                ),
                Expanded(child: _buildWebArea(tab, tabState, notifier, isDark)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChrome(
    BrowserTabModel tab,
    BrowserTabState tabState,
    BrowserTabNotifier notifier,
    dynamic colors,
    bool isDark,
  ) {
    return BrowserChromeBar(
      tab: tab,
      tabCount: tabState.tabs.length,
      urlCtrl: _urlCtrl,
      urlFocus: _urlFocus,
      isDark: isDark,
      colors: colors,
      isEmbedded: widget.isEmbedded,
      isMinimized: _isMinimized,
      showTabBar: _showTabBar,
      onGoBack: () => _controllers[tab.id]?.goBack(),
      onGoForward: () => _controllers[tab.id]?.goForward(),
      onReload: () {
        final ctrl = _controllers[tab.id];
        if (ctrl != null) {
          tab.isLoading ? ctrl.stopLoading() : ctrl.reload();
        }
      },
      onUrlSubmitted: _onUrlSubmit,
      onSslTap: () => _showSslDialog(tab.url, tab.isSecure),
      onToggleTabBar: () {
        HapticFeedback.selectionClick();
        setState(() => _showTabBar = !_showTabBar);
      },
      onToggleMinimize: _toggleMinimize,
      onOpenFullscreen: _openFullscreen,
      onMenuAction: (v) => _handleMenu(v, tab, notifier),
    );
  }


  Widget _buildWebArea(
    dynamic tab,
    dynamic tabState,
    dynamic notifier,
    bool isDark,
  ) {
    return Stack(
      children: [
        IndexedStack(
          index: (tabState.tabs as List).indexWhere((t) => t.id == tab.id),
          children: (tabState.tabs as List).map<Widget>((t) {
            return InAppWebView(
              key: ValueKey(t.id),
              initialUrlRequest: URLRequest(url: WebUri(t.url)),
              initialSettings: BrowserSecurityFirewall.defaultWebViewSettings,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer(),
                ),
                Factory<HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(),
                ),
              },
              onWebViewCreated: (ctrl) => _controllers[t.id] = ctrl,
              onLoadStart: (ctrl, url) {
                if (url != null) {
                  notifier.updateTabById(
                    t.id,
                    url: url.toString(),
                    isLoading: true,
                    progress: 0.1,
                  );
                }
              },
              onLoadStop: (ctrl, url) async {
                final title = await ctrl.getTitle();
                final canBack = await ctrl.canGoBack();
                final canFwd = await ctrl.canGoForward();
                if (url != null) {
                  notifier.updateTabById(
                    t.id,
                    url: url.toString(),
                    title: (title?.isNotEmpty == true) ? title : null,
                    isLoading: false,
                    progress: 1.0,
                    canGoBack: canBack,
                    canGoForward: canFwd,
                  );
                }
              },
              onProgressChanged: (ctrl, progress) => notifier.updateTabById(
                t.id,
                progress: progress / 100.0,
                isLoading: progress < 100,
              ),
              onTitleChanged: (ctrl, title) {
                if (title?.isNotEmpty == true) {
                  notifier.updateTabById(t.id, title: title);
                }
              },
              shouldOverrideUrlLoading: (ctrl, action) async {
                final uri = action.request.url;
                if (uri == null) return NavigationActionPolicy.CANCEL;
                final url = uri.toString();
                if (BrowserSecurityFirewall.isExternalScheme(url)) {
                  _promptExternalApp(url);
                  return NavigationActionPolicy.CANCEL;
                }
                if (!BrowserSecurityFirewall.isAllowedUrl(url)) {
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              onPermissionRequest: (ctrl, req) async => PermissionResponse(
                resources: req.resources,
                action: PermissionResponseAction.GRANT,
              ),
            );
          }).toList(),
        ),
        if (tab.isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: tab.progress > 0 ? tab.progress : null,
              backgroundColor: Colors.transparent,
              color: isDark ? const Color(0xFF10B981) : const Color(0xFF1D6FE8),
              minHeight: 2.5,
            ),
          ),
      ],
    );
  }

  Future<void> _handleMenu(String value, dynamic tab, dynamic notifier) async {
    switch (value) {
      case 'ask_owl':
        await _askOwl();
      case 'new_tab':
        notifier.addTab();
      case 'toggle_tabs':
        setState(() => _showTabBar = !_showTabBar);
      case 'toggle_minimize':
        _toggleMinimize();
      case 'fullscreen':
        _openFullscreen();
      case 'copy_url':
        final msg = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(text: tab.url));
        if (mounted) {
          msg.showSnackBar(const SnackBar(content: Text('Enlace copiado al portapapeles.')));
        }
      case 'share':
        // ignore: deprecated_member_use
        await Share.share(tab.url, subject: tab.title);
      case 'clear_cache':
        final msg = ScaffoldMessenger.of(context);
        await InAppWebViewController.clearAllCache();
        if (mounted) {
          msg.showSnackBar(const SnackBar(content: Text('Caché del navegador limpiada.')));
        }
    }
  }
}
