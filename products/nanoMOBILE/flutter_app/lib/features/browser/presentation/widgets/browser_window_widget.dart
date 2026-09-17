import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_history_notifier.dart';
import 'package:nanoai/features/browser/application/browser_pip_notifier.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_3d_carousel_view.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_dialog_helper.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_find_in_page_widget.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_history_bookmarks_dialog.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_options_sheet.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_tab_bar_widget.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_zoom_sheet.dart';
import 'package:nanoai/features/browser/presentation/widgets/single_browser_instance_widget.dart';

/// Modos de visualización soportados en el Navegador Nano AI
enum BrowserDisplayMode {
  focused,       // Vista limpia / completa de una pestaña activa
  verticalStack, // Vista scroll vertical con tarjetas apiladas y estirables
  carousel3D,    // Vista carrusel 3D espacial con perspectiva y escala
}

/// Workspace Profesional Multi-Ventana del Navegador Web Real de Nano AI.
/// Permite gestionar múltiples ventanas de navegadores completos simultáneos
/// en Inicio (Google, DeepSeek, ChatGPT, Wikipedia, YouTube, etc.) con minimizado,
/// maximizado, reproducción continua de audio/vídeo y acoplamiento lateral.
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
  ConsumerState<BrowserWindowWidget> createState() =>
      _BrowserWindowWidgetState();
}

class _BrowserWindowWidgetState extends ConsumerState<BrowserWindowWidget> {
  final Map<String, InAppWebViewController> _controllers = {};
  final Set<String> _minimizedWindowIds = {};
  String? _maximizedWindowId;
  BrowserDisplayMode _displayMode = BrowserDisplayMode.verticalStack;
  double _currentZoom = 1.0;
  bool _isDesktopMode = false;
  bool _isDarkModeWeb = false;
  bool _showFindInPage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialUrl?.isNotEmpty == true) {
        final resolved = BrowserUrlResolver.resolveUrl(widget.initialUrl!);
        ref.read(browserTabProvider.notifier).updateActiveTab(url: resolved);
      }
      final tabs = ref.read(browserTabProvider).tabs;
      if (tabs.length > 1) {
        setState(() {
          for (int i = 1; i < tabs.length; i++) {
            _minimizedWindowIds.add(tabs[i].id);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controllers.clear();
    super.dispose();
  }

  void _onUrlSubmit(String input) {
    final url = BrowserUrlResolver.resolveUrl(input);
    final notifier = ref.read(browserTabProvider.notifier);
    final activeTab = ref.read(browserTabProvider).activeTab;
    notifier.updateTabById(activeTab.id, url: url);
    final ctrl = _controllers[activeTab.id] ??
        ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id);
    ctrl?.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
  }

  void _showUrlEditDialog(BuildContext context, String currentUrl) {
    BrowserDialogHelper.showUrlEditDialog(
      context: context,
      currentUrl: currentUrl,
      onSubmitted: _onUrlSubmit,
    );
  }

  void _promptExternalApp(String url) {
    BrowserDialogHelper.promptExternalApp(context, url);
  }

  void _closeTab(String tabId) {
    _controllers.remove(tabId);
    _minimizedWindowIds.remove(tabId);
    if (_maximizedWindowId == tabId) {
      _maximizedWindowId = null;
    }
    ref.read(browserWebViewRegistryProvider).removeTab(tabId);
    ref.read(browserTabProvider.notifier).closeTab(tabId);
  }

  void _openOptionsMenu() {
    final tab = ref.read(browserTabProvider).activeTab;
    final isBm = ref.read(browserHistoryProvider).isBookmarked(tab.url);
    BrowserOptionsSheet.show(
      context: context,
      tab: tab,
      isBookmarked: isBm,
      isDesktopMode: _isDesktopMode,
      isDarkModeWeb: _isDarkModeWeb,
      onAction: (act) async => _handleMenuAction(act, tab),
    );
  }

  Future<void> _handleMenuAction(String act, BrowserTabModel tab) async {
    final notifier = ref.read(browserTabProvider.notifier);
    final ctrl = _controllers[tab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(tab.id);
    switch (act) {
      case 'toggle_carousel':
        setState(() => _displayMode = _displayMode == BrowserDisplayMode.carousel3D ? BrowserDisplayMode.focused : BrowserDisplayMode.carousel3D);
        break;
      case 'show_bookmarks':
        BrowserHistoryBookmarksDialog.show(context: context, initialTabIndex: 0, onSelectUrl: _onUrlSubmit);
        break;
      case 'show_history':
        BrowserHistoryBookmarksDialog.show(context: context, initialTabIndex: 1, onSelectUrl: _onUrlSubmit);
        break;
      case 'new_tab':
        notifier.addTab();
        break;
      case 'show_zoom_sheet':
        BrowserZoomSheet.show(context: context, tab: tab, currentZoom: _currentZoom, controller: ctrl, onZoomChanged: (z) => setState(() => _currentZoom = z));
        break;
      case 'toggle_desktop_mode':
        setState(() => _isDesktopMode = !_isDesktopMode);
        break;
      case 'toggle_dark_web':
        setState(() => _isDarkModeWeb = !_isDarkModeWeb);
        break;
      case 'toggle_bookmark':
        final wasBm = ref.read(browserHistoryProvider).isBookmarked(tab.url);
        ref.read(browserHistoryProvider.notifier).toggleBookmark(tab.url, tab.title);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(!wasBm ? 'Marcador guardado' : 'Marcador eliminado'), duration: const Duration(seconds: 2)));
        break;
      case 'find_in_page':
        setState(() => _showFindInPage = true);
        break;
      case 'pip_mode':
        final ok = await ref.read(browserPipProvider.notifier).activatePip(tabId: tab.id, url: tab.url, title: tab.title, controller: ctrl);
        if (mounted && !ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se detectó video HTML5 para PiP')));
        break;
      case 'share':
      case 'copy_url':
        await Clipboard.setData(ClipboardData(text: tab.url));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(act == 'share' ? 'Enlace copiado para compartir' : 'URL copiada al portapapeles')));
        break;
      case 'show_ssl':
        BrowserDialogHelper.showSslDialog(context, tab);
        break;
      case 'ask_owl':
        BrowserDialogHelper.showOwlAssistantDialog(
          context: context, tab: tab, controller: ctrl,
          onSendToChat: (prompt) {
            Clipboard.setData(ClipboardData(text: prompt));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contexto web copiado para consultar con la IA'), duration: Duration(seconds: 3)));
          },
        );
        break;
      case 'clear_cache':
        await InAppWebViewController.clearAllCache();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caché limpiada con éxito.')));
        break;
    }
  }

  Widget _buildTopRow(
    BuildContext context,
    BrowserTabState tabState,
    BrowserTabModel activeTab,
  ) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 4 : 6, vertical: isLandscape ? 1 : 4),
      decoration: const BoxDecoration(
        color: Color(0xFF08121E),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.0)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: const Color(0xFF94A3B8), size: isLandscape ? 15 : 18),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isLandscape ? 22 : 28, minHeight: isLandscape ? 22 : 28),
            onPressed: () async {
              final ctrl = _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id);
              if (ctrl != null && await ctrl.canGoBack()) await ctrl.goBack();
            },
          ),
          SizedBox(width: isLandscape ? 2 : 3),
          Expanded(
            child: Container(
              height: isLandscape ? 26 : 34,
              padding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1E24),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.6), width: 1.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded, color: const Color(0xFF10B981), size: isLandscape ? 11 : 14),
                  SizedBox(width: isLandscape ? 3 : 6),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showUrlEditDialog(context, activeTab.url),
                      child: Text(
                        activeTab.url.isEmpty ? 'Buscar o escribir URL' : activeTab.url,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: const Color(0xFFE2E8F0), fontSize: isLandscape ? 10.5 : 12.0, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => BrowserZoomSheet.show(
                      context: context, tab: activeTab, currentZoom: _currentZoom,
                      controller: _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id),
                      onZoomChanged: (z) => setState(() => _currentZoom = z),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 3 : 5, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                      child: Text('aA', style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: isLandscape ? 8.5 : 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(width: isLandscape ? 2 : 5),
                  GestureDetector(
                    onTap: () {
                      final ctrl = _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id);
                      ctrl?.reload();
                    },
                    child: Icon(Icons.refresh_rounded, color: const Color(0xFF94A3B8), size: isLandscape ? 13 : 16),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: isLandscape ? 2 : 5),
          GestureDetector(
            onTap: () => setState(() => _displayMode = _displayMode == BrowserDisplayMode.verticalStack ? BrowserDisplayMode.focused : BrowserDisplayMode.verticalStack),
            child: Container(
              width: isLandscape ? 22 : 28, height: isLandscape ? 22 : 28,
              decoration: BoxDecoration(
                color: _displayMode != BrowserDisplayMode.focused ? const Color(0xFF10B981).withValues(alpha: 0.25) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(isLandscape ? 5 : 7),
                border: Border.all(color: _displayMode != BrowserDisplayMode.focused ? const Color(0xFF10B981) : const Color(0xFF475569), width: 1.0),
              ),
              alignment: Alignment.center,
              child: Text(
                '${tabState.tabs.length}',
                style: TextStyle(color: _displayMode != BrowserDisplayMode.focused ? const Color(0xFF10B981) : Colors.white, fontSize: isLandscape ? 9.5 : 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.view_in_ar_rounded, color: _displayMode == BrowserDisplayMode.carousel3D ? const Color(0xFF10B981) : const Color(0xFF94A3B8), size: isLandscape ? 14 : 17),
            tooltip: 'Visor Carrusel 3D', padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isLandscape ? 22 : 26, minHeight: isLandscape ? 22 : 26),
            onPressed: () => setState(() => _displayMode = _displayMode == BrowserDisplayMode.carousel3D ? BrowserDisplayMode.focused : BrowserDisplayMode.carousel3D),
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: const Color(0xFF94A3B8), size: isLandscape ? 14 : 17),
            padding: EdgeInsets.zero, constraints: BoxConstraints(minWidth: isLandscape ? 20 : 24, minHeight: isLandscape ? 20 : 24),
            onPressed: _openOptionsMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBadgeIcon(String url, {bool isLandscape = false}) {
    final lower = url.toLowerCase();
    final badgeSize = isLandscape ? 15.0 : 20.0;
    final iconSize = isLandscape ? 11.0 : 13.0;
    Color bg = const Color(0xFF334155);
    Widget icon = Icon(BrowserTabBarWidget.getBrandIcon(url), size: iconSize, color: const Color(0xFF94A3B8));
    if (lower.contains('google')) {
      bg = const Color(0xFF2563EB);
      icon = Text('G', style: TextStyle(fontSize: isLandscape ? 9.5 : 12.0, fontWeight: FontWeight.w900, color: Colors.white));
    } else if (lower.contains('youtube')) {
      bg = const Color(0xFFEF4444);
      icon = Icon(Icons.play_arrow_rounded, size: iconSize + 1, color: Colors.white);
    } else if (lower.contains('deepseek') || lower.contains('deeksepp')) {
      bg = const Color(0xFF0284C7);
      icon = Icon(Icons.auto_awesome_rounded, size: iconSize, color: Colors.white);
    } else if (lower.contains('chatgpt') || lower.contains('openai')) {
      bg = const Color(0xFF10A37F);
      icon = Icon(Icons.smart_toy_rounded, size: iconSize, color: Colors.white);
    }
    return Container(width: badgeSize, height: badgeSize, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: bg), alignment: Alignment.center, child: icon);
  }

  Widget _buildTabsStrip(
    BuildContext context,
    BrowserTabState tabState,
    BrowserTabNotifier notifier,
  ) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      height: isLandscape ? 26 : 36,
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 8, vertical: isLandscape ? 1 : 3),
      decoration: const BoxDecoration(color: Color(0xFF08121E), border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.0))),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tabState.tabs.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: isLandscape ? 5 : 8),
        itemBuilder: (context, index) {
          if (index == tabState.tabs.length) {
            return Center(
              child: InkWell(
                onTap: () => notifier.addTab(),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 10, vertical: isLandscape ? 2 : 6),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF334155))),
                  child: Icon(Icons.add_rounded, color: const Color(0xFF94A3B8), size: isLandscape ? 13 : 16),
                ),
              ),
            );
          }

          final tab = tabState.tabs[index];
          final isActive = tab.id == tabState.activeTabId;

          return Center(
            child: InkWell(
              onTap: () {
                notifier.selectTab(tab.id);
                if (_displayMode != BrowserDisplayMode.focused) setState(() => _displayMode = BrowserDisplayMode.focused);
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 10, vertical: isLandscape ? 2 : 5),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? const Color(0xFF38BDF8).withValues(alpha: 0.8) : const Color(0xFF334155).withValues(alpha: 0.4),
                    width: isActive ? 1.4 : 1.0,
                  ),
                  boxShadow: isActive ? [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.2), blurRadius: 8, spreadRadius: -1)] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabBadgeIcon(tab.url, isLandscape: isLandscape),
                    SizedBox(width: isLandscape ? 5 : 8),
                    Text(
                      tab.title.isNotEmpty ? tab.title : 'Pestaña',
                      style: TextStyle(fontSize: isLandscape ? 10.5 : 12, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? Colors.white : const Color(0xFF94A3B8)),
                    ),
                    if (tabState.tabs.length > 1) ...[
                      SizedBox(width: isLandscape ? 4 : 6),
                      GestureDetector(
                        onTap: () => notifier.closeTab(tab.id),
                        child: Icon(Icons.close_rounded, size: isLandscape ? 11 : 14, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStackItem(
    BrowserTabModel tab,
    BrowserTabState tabState,
    BrowserTabNotifier notifier,
  ) {
    final isMin = _minimizedWindowIds.contains(tab.id);
    final isMax = _maximizedWindowId == tab.id;
    return SingleBrowserInstanceWidget(
      key: ValueKey('stack_${tab.id}'),
      tab: tab,
      fillHeight: false,
      showCardHeader: true,
      isMinimized: isMin,
      isMaximized: isMax,
      isCurrentActive: tab.id == tabState.activeTabId,
      currentZoom: _currentZoom,
      isDesktopMode: _isDesktopMode,
      isDarkModeWeb: _isDarkModeWeb,
      onToggleMinimize: () => setState(() => isMin ? _minimizedWindowIds.remove(tab.id) : _minimizedWindowIds.add(tab.id)),
      onToggleMaximize: () => setState(() => _maximizedWindowId = isMax ? null : tab.id),
      onSelectTab: () => setState(() => isMin ? _minimizedWindowIds.remove(tab.id) : _minimizedWindowIds.add(tab.id)),
      onClose: () => _closeTab(tab.id),
      onControllerCreated: (ctrl) => _controllers[tab.id] = ctrl,
      onNavigate: _onUrlSubmit,
      onExternalPrompt: _promptExternalApp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabState = ref.watch(browserTabProvider);
    final notifier = ref.read(browserTabProvider.notifier);
    final activeTab = tabState.activeTab;

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final activeIndex = tabState.tabs.indexWhere(
      (t) => t.id == tabState.activeTabId,
    );
    final safeIndex = activeIndex >= 0 ? activeIndex : 0;

    // 1. MODO STACK MULTI-VENTANA EN INICIO (Exacto media_1789537500231.jpg)
    // Ventanas directas sobre el wallpaper, sin marco exterior verde redundante
    if (_displayMode == BrowserDisplayMode.verticalStack) {
      if (_maximizedWindowId != null) {
        final maxTab = tabState.tabs.firstWhere(
          (t) => t.id == _maximizedWindowId,
          orElse: () => tabState.activeTab,
        );
        return Column(
          children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _maximizedWindowId = null),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x990B1322),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFF38BDF8)),
                            SizedBox(width: 4),
                            Text(
                              'Volver a Ventanas',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFFE2E8F0)),
                      tooltip: 'Opciones',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: _openOptionsMenu,
                    ),
                  ],
                ),
              ),
              if (_showFindInPage)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: BrowserFindInPageWidget(
                    controller: _controllers[maxTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(maxTab.id),
                    onClose: () => setState(() => _showFindInPage = false),
                  ),
                ),
              Expanded(
                child: SingleBrowserInstanceWidget(
                  key: ValueKey('max_${maxTab.id}'),
                  tab: maxTab,
                  fillHeight: true,
                  showCardHeader: true,
                  isMinimized: false,
                  isMaximized: true,
                  isCurrentActive: true,
                  currentZoom: _currentZoom,
                  isDesktopMode: _isDesktopMode,
                  isDarkModeWeb: _isDarkModeWeb,
                  onToggleMinimize: () {
                    setState(() {
                      _minimizedWindowIds.add(maxTab.id);
                      _maximizedWindowId = null;
                    });
                  },
                  onToggleMaximize: () => setState(() => _maximizedWindowId = null),
                  onSelectTab: null,
                  onClose: () {
                    notifier.closeTab(maxTab.id);
                    setState(() => _maximizedWindowId = null);
                  },
                  onControllerCreated: (ctrl) => _controllers[maxTab.id] = ctrl,
                  onNavigate: _onUrlSubmit,
                  onExternalPrompt: _promptExternalApp,
                ),
              ),
            ],
          );
      }

      final allMin = _minimizedWindowIds.length >= tabState.tabs.length;
      return Column(
          children: [
            // Barra de control rápida minimalista (transparente, sin solapamientos)
            Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, isLandscape ? 2 : 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (allMin) {
                          _minimizedWindowIds.clear();
                        } else {
                          _minimizedWindowIds.addAll(tabState.tabs.map((t) => t.id));
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x990B1322),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            allMin ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                            size: 14,
                            color: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Ventanas (${tabState.tabs.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add_rounded, size: isLandscape ? 15 : 18, color: const Color(0xFF38BDF8)),
                    tooltip: 'Nueva Ventana',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: isLandscape ? 22 : 28, minHeight: isLandscape ? 22 : 28),
                    onPressed: () => notifier.addTab(),
                  ),
                  IconButton(
                    icon: Icon(Icons.view_in_ar_rounded, size: isLandscape ? 15 : 18, color: const Color(0xFF10B981)),
                    tooltip: 'Carrusel 3D',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: isLandscape ? 22 : 28, minHeight: isLandscape ? 22 : 28),
                    onPressed: () => setState(() => _displayMode = BrowserDisplayMode.carousel3D),
                  ),
                  IconButton(
                    icon: Icon(Icons.fullscreen_rounded, size: isLandscape ? 15 : 18, color: const Color(0xFFCBD5E1)),
                    tooltip: 'Vista Completa',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: isLandscape ? 22 : 28, minHeight: isLandscape ? 22 : 28),
                    onPressed: () => setState(() => _displayMode = BrowserDisplayMode.focused),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert_rounded, size: isLandscape ? 15 : 18, color: const Color(0xFFE2E8F0)),
                    tooltip: 'Opciones',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: isLandscape ? 22 : 28, minHeight: isLandscape ? 22 : 28),
                    onPressed: _openOptionsMenu,
                  ),
                ],
              ),
            ),
            if (_showFindInPage)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: isLandscape ? 1 : 3),
                child: BrowserFindInPageWidget(
                  controller: _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id),
                  onClose: () => setState(() => _showFindInPage = false),
                ),
              ),
            // Lista de ventanas apiladas estirables y minimizables (adaptadas a 2 columnas en horizontal)
            Expanded(
              child: isLandscape
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 28),
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                for (int i = 0; i < tabState.tabs.length; i += 2)
                                  _buildStackItem(tabState.tabs[i], tabState, notifier),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              children: [
                                for (int i = 1; i < tabState.tabs.length; i += 2)
                                  _buildStackItem(tabState.tabs[i], tabState, notifier),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 180),
                      physics: const BouncingScrollPhysics(),
                      itemCount: tabState.tabs.length,
                      itemBuilder: (context, index) =>
                          _buildStackItem(tabState.tabs[index], tabState, notifier),
                    ),
            ),
          ],
        );
    }

    // 2. MODO CARRUSEL 3D COMPLETO Y ACCESIBLE (Navegación espacial activa)
    if (_displayMode == BrowserDisplayMode.carousel3D) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF030712),
          borderRadius: BorderRadius.circular(isLandscape ? 14 : 20),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.2),
          boxShadow: [
            BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.15), blurRadius: isLandscape ? 12 : 20, spreadRadius: -2, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: isLandscape ? 16 : 24, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isLandscape ? 13 : 19),
          child: Column(
            children: [
              _buildTopRow(context, tabState, activeTab),
              if (_showFindInPage)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: BrowserFindInPageWidget(
                    controller: _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id),
                    onClose: () => setState(() => _showFindInPage = false),
                  ),
                ),
              Expanded(
                child: Browser3DCarouselView(
                  tabs: tabState.tabs,
                  activeTabId: tabState.activeTabId,
                  currentZoom: _currentZoom,
                  isDesktopMode: _isDesktopMode,
                  isDarkModeWeb: _isDarkModeWeb,
                  minimizedWindowIds: _minimizedWindowIds,
                  maximizedWindowId: _maximizedWindowId,
                  onSelectTab: (tabId) {
                    _minimizedWindowIds.remove(tabId);
                    notifier.selectTab(tabId);
                  },
                  onOpenFocused: () => setState(() => _displayMode = BrowserDisplayMode.focused),
                  onCloseTab: (tabId) => _closeTab(tabId),
                  onToggleMaximize: (tabId) => setState(() => _maximizedWindowId = _maximizedWindowId == tabId ? null : tabId),
                  onToggleMinimize: (tabId) => setState(() {
                    if (_minimizedWindowIds.contains(tabId)) {
                      _minimizedWindowIds.remove(tabId);
                    } else {
                      _minimizedWindowIds.add(tabId);
                    }
                  }),
                  onControllerCreated: (tabId, ctrl) => _controllers[tabId] = ctrl,
                  onNavigate: _onUrlSubmit,
                  onExternalPrompt: _promptExternalApp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. MODO NAVEGADOR ENFOCADO COMPLETO (Con Barra Superior iOS y Pestañas)
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF030712),
        borderRadius: BorderRadius.circular(isLandscape ? 14 : 20),
        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF059669).withValues(alpha: 0.15), blurRadius: isLandscape ? 12 : 20, spreadRadius: -2, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: isLandscape ? 16 : 24, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isLandscape ? 13 : 19),
        child: Column(
          children: [
            _buildTopRow(context, tabState, activeTab),
            _buildTabsStrip(context, tabState, notifier),
            if (_showFindInPage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: BrowserFindInPageWidget(
                  controller: _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id),
                  onClose: () => setState(() => _showFindInPage = false),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: safeIndex,
                children: tabState.tabs.map((tab) {
                  return SingleBrowserInstanceWidget(
                    key: ValueKey('win_${tab.id}'),
                    tab: tab,
                    fillHeight: true,
                    showCardHeader: false,
                    isMinimized: false,
                    isMaximized: true,
                    currentZoom: _currentZoom,
                    isDesktopMode: _isDesktopMode,
                    isDarkModeWeb: _isDarkModeWeb,
                    onToggleMinimize: () => setState(() => _displayMode = BrowserDisplayMode.verticalStack),
                    onToggleMaximize: () => setState(() => _displayMode = BrowserDisplayMode.verticalStack),
                    onClose: () => _closeTab(tab.id),
                    onControllerCreated: (ctrl) => _controllers[tab.id] = ctrl,
                    onNavigate: _onUrlSubmit,
                    onExternalPrompt: _promptExternalApp,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
