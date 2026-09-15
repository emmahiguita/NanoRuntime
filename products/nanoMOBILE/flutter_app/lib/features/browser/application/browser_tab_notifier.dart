import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/browser_tab_model.dart';
import '../domain/browser_url_resolver.dart';

class BrowserTabState {
  final List<BrowserTabModel> tabs;
  final String activeTabId;

  const BrowserTabState({
    required this.tabs,
    required this.activeTabId,
  });

  BrowserTabModel get activeTab {
    return tabs.firstWhere(
      (t) => t.id == activeTabId,
      orElse: () => tabs.isNotEmpty
          ? tabs.first
          : const BrowserTabModel(id: 'default', url: BrowserUrlResolver.homePageUrl),
    );
  }

  BrowserTabState copyWith({
    List<BrowserTabModel>? tabs,
    String? activeTabId,
  }) {
    return BrowserTabState(
      tabs: tabs ?? this.tabs,
      activeTabId: activeTabId ?? this.activeTabId,
    );
  }
}

class BrowserTabNotifier extends StateNotifier<BrowserTabState> {
  static int _counter = 1;

  static String _generateId() =>
      'tab_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  BrowserTabNotifier()
      : super(
          const BrowserTabState(
            tabs: [
              BrowserTabModel(
                id: 'tab_initial',
                url: BrowserUrlResolver.homePageUrl,
                title: 'Inicio - Google',
              ),
            ],
            activeTabId: 'tab_initial',
          ),
        );

  String addTab({String? initialUrl}) {
    final newId = _generateId();
    final url = BrowserUrlResolver.resolveUrl(initialUrl ?? BrowserUrlResolver.homePageUrl);
    final newTab = BrowserTabModel(
      id: newId,
      url: url,
      title: BrowserUrlResolver.extractHost(url),
    );

    state = state.copyWith(
      tabs: [...state.tabs, newTab],
      activeTabId: newId,
    );
    return newId;
  }

  void closeTab(String tabId) {
    if (state.tabs.length <= 1) {
      // Si sólo queda una pestaña, la reseteamos a inicio en lugar de destruirla
      final current = state.activeTab;
      updateTabById(
        current.id,
        url: BrowserUrlResolver.homePageUrl,
        title: 'Inicio - Google',
        progress: 0.0,
        isLoading: false,
      );
      return;
    }

    final newTabs = state.tabs.where((t) => t.id != tabId).toList();
    String newActiveId = state.activeTabId;

    if (state.activeTabId == tabId) {
      final closedIndex = state.tabs.indexWhere((t) => t.id == tabId);
      final nextIndex = (closedIndex >= newTabs.length) ? newTabs.length - 1 : closedIndex;
      newActiveId = newTabs[nextIndex].id;
    }

    state = state.copyWith(
      tabs: newTabs,
      activeTabId: newActiveId,
    );
  }

  void selectTab(String tabId) {
    if (state.tabs.any((t) => t.id == tabId)) {
      state = state.copyWith(activeTabId: tabId);
    }
  }

  void updateActiveTab({
    String? url,
    String? title,
    String? faviconUrl,
    bool? isLoading,
    double? progress,
    bool? canGoBack,
    bool? canGoForward,
    bool? isSecure,
  }) {
    updateTabById(
      state.activeTabId,
      url: url,
      title: title,
      faviconUrl: faviconUrl,
      isLoading: isLoading,
      progress: progress,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
      isSecure: isSecure,
    );
  }

  void updateTabById(
    String tabId, {
    String? url,
    String? title,
    String? faviconUrl,
    bool? isLoading,
    double? progress,
    bool? canGoBack,
    bool? canGoForward,
    bool? isSecure,
  }) {
    final updatedTabs = state.tabs.map((t) {
      if (t.id == tabId) {
        final newUrl = url ?? t.url;
        final secure = isSecure ?? BrowserUrlResolver.isSecure(newUrl);
        return t.copyWith(
          url: newUrl,
          title: title ?? (url != null ? BrowserUrlResolver.extractHost(url) : t.title),
          faviconUrl: faviconUrl ?? t.faviconUrl,
          isLoading: isLoading ?? t.isLoading,
          progress: progress ?? t.progress,
          canGoBack: canGoBack ?? t.canGoBack,
          canGoForward: canGoForward ?? t.canGoForward,
          isSecure: secure,
        );
      }
      return t;
    }).toList();

    state = state.copyWith(tabs: updatedTabs);
  }
}

final browserTabProvider =
    StateNotifierProvider<BrowserTabNotifier, BrowserTabState>((ref) {
  return BrowserTabNotifier();
});
