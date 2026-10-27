// QUÉ: concentra las mutaciones y recursos del coordinador de ventanas.
// CÓMO: actúa sobre Riverpod y el registro nativo sin construir widgets.
// POR QUÉ: la vista principal queda pequeña y cada pestaña conserva identidad.

part of 'browser_window_widget.dart';

extension _BrowserWindowActions on _BrowserWindowWidgetState {
  GlobalKey _instanceKeyFor(String tabId) => _instanceKeys.putIfAbsent(
    tabId,
    () => GlobalKey(debugLabel: 'browser-instance-$tabId'),
  );

  void _mutate(VoidCallback change) {
    if (mounted) setState(change);
  }

  // Limpia solo recursos de pestañas eliminadas; las activas no se recrean.
  void _reconcileTabs(BrowserTabState state) {
    final ids = state.tabs.map((tab) => tab.id).toSet();
    ref.read(browserWebViewRegistryProvider).removeMissing(ids);
    _minimizedWindowIds.removeWhere((id) => !ids.contains(id));
    _instanceKeys.removeWhere((id, _) => !ids.contains(id));
    if (!ids.contains(_maximizedWindowId)) _maximizedWindowId = null;
  }

  void _onUrlSubmit(String input, [String? tabId]) {
    final url = BrowserUrlResolver.resolveUrl(input);
    final id = tabId ?? ref.read(browserTabProvider).activeTab.id;
    final controller = ref
        .read(browserWebViewRegistryProvider)
        .controllerFor(id);
    if (controller != null) {
      controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    } else {
      ref.read(browserTabProvider.notifier).updateTabById(id, url: url);
    }
  }

  // La última pestaña vuelve a Inicio sin perder su controlador registrado.
  void _closeTab(String tabId) {
    final state = ref.read(browserTabProvider);
    final registry = ref.read(browserWebViewRegistryProvider);
    _minimizedWindowIds.remove(tabId);
    if (_maximizedWindowId == tabId) _maximizedWindowId = null;
    if (state.tabs.length > 1) {
      _instanceKeys.remove(tabId);
      registry.removeTab(tabId);
    } else {
      registry.resumeTab(tabId);
    }
    ref.read(browserTabProvider.notifier).closeTab(tabId);
  }

  void _setMode(BrowserDisplayMode mode) => _mutate(() {
    _displayMode = mode;
    if (mode == BrowserDisplayMode.focused) {
      final id = ref.read(browserTabProvider).activeTabId;
      _minimizedWindowIds.remove(id);
      ref.read(browserWebViewRegistryProvider).resumeTab(id);
    }
  });

  void _selectTab(String id, {bool focus = false}) {
    ref.read(browserWebViewRegistryProvider).resumeTab(id);
    _minimizedWindowIds.remove(id);
    ref.read(browserTabProvider.notifier).selectTab(id);
    if (focus) _setMode(BrowserDisplayMode.focused);
  }

  void _toggleMinimize(String id) => _mutate(() {
    final registry = ref.read(browserWebViewRegistryProvider);
    if (_minimizedWindowIds.remove(id)) {
      registry.resumeTab(id);
    } else {
      _minimizedWindowIds.add(id);
      registry.pauseTab(id);
      _displayMode = BrowserDisplayMode.verticalStack;
    }
  });

  void _toggleMaximize(String id) => _mutate(() {
    _maximizedWindowId = _maximizedWindowId == id ? null : id;
    _displayMode = BrowserDisplayMode.verticalStack;
    if (_maximizedWindowId != null) {
      ref.read(browserWebViewRegistryProvider).resumeTab(id);
    }
  });

  void _toggleAll(BrowserTabState state) => _mutate(() {
    final registry = ref.read(browserWebViewRegistryProvider);
    final restore = _minimizedWindowIds.length >= state.tabs.length;
    if (restore) {
      _minimizedWindowIds.clear();
      for (final tab in state.tabs) {
        registry.resumeTab(tab.id);
      }
    } else {
      _minimizedWindowIds.addAll(state.tabs.map((tab) => tab.id));
      for (final tab in state.tabs) {
        registry.pauseTab(tab.id);
      }
    }
  });

  void _openOptionsMenu(BrowserTabModel tab) {
    BrowserOptionsLauncher.show(
      context: context,
      ref: ref,
      tab: tab,
      isDesktopMode: _isDesktopMode,
      isDarkModeWeb: _isDarkModeWeb,
      onNavigate: (url) => _onUrlSubmit(url, tab.id),
      onToggleCarousel: () => _setMode(
        _displayMode == BrowserDisplayMode.carousel3D
            ? BrowserDisplayMode.focused
            : BrowserDisplayMode.carousel3D,
      ),
      onZoomChanged: (zoom) {
        if (mounted) {
          ref
              .read(browserTabProvider.notifier)
              .updateTabById(tab.id, zoomLevel: zoom);
        }
      },
      onToggleDesktopMode: () =>
          _mutate(() => _isDesktopMode = !_isDesktopMode),
      onToggleDarkModeWeb: () =>
          _mutate(() => _isDarkModeWeb = !_isDarkModeWeb),
      onFindInPage: () => _mutate(() => _showFindInPage = true),
    );
  }
}
