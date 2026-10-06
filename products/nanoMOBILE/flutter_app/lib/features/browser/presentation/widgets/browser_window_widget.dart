import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_display_mode.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_focused_window.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_options_launcher.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_stack_view.dart';

part 'browser_window_widget_actions.part.dart';

/// Coordina pestañas con IndexedStack estable en modo focused para navegación fluida.
/// Al rotar de vertical a horizontal, preserva el audio y la superficie de renderizado nativa.
class BrowserWindowWidget extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onFullscreen, onClose;
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
  final Set<String> _minimizedWindowIds = {};
  final Map<String, GlobalKey> _instanceKeys = {};
  late final ScrollController _scrollController;
  late final ProviderSubscription<BrowserTabState> _tabsSubscription;
  String? _maximizedWindowId;
  BrowserDisplayMode _displayMode = BrowserDisplayMode.focused;
  bool _isDesktopMode = false, _isDarkModeWeb = false, _showFindInPage = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tabsSubscription = ref.listenManual(
      browserTabProvider,
      (_, next) => _reconcileTabs(next),
    );
    _reconcileTabs(ref.read(browserTabProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialUrl?.isNotEmpty == true) {
        _onUrlSubmit(widget.initialUrl!);
      }
    });
  }

  @override
  void dispose() {
    _tabsSubscription.close();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabState = ref.watch(browserTabProvider);
    final notifier = ref.read(browserTabProvider.notifier);
    final activeTab = tabState.activeTab;

    if (_displayMode == BrowserDisplayMode.verticalStack) {
      return BrowserWindowStackView(
        tabState: tabState,
        minimizedWindowIds: _minimizedWindowIds,
        maximizedWindowId: _maximizedWindowId,
        isDesktopMode: _isDesktopMode,
        isDarkModeWeb: _isDarkModeWeb,
        showFindInPage: _showFindInPage,
        scrollController: _scrollController,
        ref: ref,
        instanceKeyForTab: _instanceKeyFor,
        onExit: widget.onClose,
        onToggleAllMinimized: () => _toggleAll(tabState),
        onAddTab: () => notifier.addTab(),
        onOpenCarousel: () => _setMode(BrowserDisplayMode.carousel3D),
        onOpenFocused: () => _setMode(BrowserDisplayMode.focused),
        onOpenOptions: _openOptionsMenu,
        onCloseFindInPage: () => _mutate(() => _showFindInPage = false),
        onBackToStack: () => _mutate(() => _maximizedWindowId = null),
        onToggleMinimize: _toggleMinimize,
        onToggleMaximize: _toggleMaximize,
        onCloseTab: _closeTab,
        onNavigate: (id, u) => _onUrlSubmit(u, id),
      );
    }
    return BrowserFocusedWindow(
      tabState: tabState,
      displayMode: _displayMode,
      isEmbedded: widget.isEmbedded,
      isDesktopMode: _isDesktopMode,
      isDarkModeWeb: _isDarkModeWeb,
      showFindInPage: _showFindInPage,
      minimizedWindowIds: _minimizedWindowIds,
      maximizedWindowId: _maximizedWindowId,
      instanceKeyForTab: _instanceKeyFor,
      onExit: widget.onClose,
      onAddTab: () => notifier.addTab(),
      onCloseFindInPage: () => _mutate(() => _showFindInPage = false),
      onOpenOptions: () => _openOptionsMenu(activeTab),
      onDisplayMode: _setMode,
      onCloseTab: _closeTab,
      onSelectTab: (id) => _selectTab(id),
      onSelectFocusedTab: (id) => _selectTab(id, focus: true),
      onToggleMinimize: _toggleMinimize,
      onToggleMaximize: widget.isEmbedded && widget.onFullscreen != null
          ? (_) => widget.onFullscreen!()
          : _toggleMaximize,
      onNavigate: (id, url) => _onUrlSubmit(url, id),
    );
  }
}
