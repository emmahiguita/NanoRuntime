import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/browser_tab_model.dart';
import '../domain/browser_url_resolver.dart';

/// QUÉ HACE:
/// Estado y notificador reactivo para la gestión de pestañas del navegador web.
/// 
/// CÓMO FUNCIONA:
/// Mantiene la lista inmutable de pestañas ([BrowserTabModel]), la pestaña activa
/// y provee métodos para crear, cerrar, seleccionar, reordenar por drag y actualizar propiedades.
/// 
/// POR QUÉ:
/// Centraliza la fuente de verdad de navegación cumpliendo SOLID, inmutabilidad de Riverpod
/// y manteniéndose estrictamente menor a 180 líneas de código.
class BrowserTabState {
  final List<BrowserTabModel> tabs;
  final String activeTabId;

  const BrowserTabState({required this.tabs, required this.activeTabId});

  BrowserTabModel get activeTab {
    return tabs.firstWhere(
      (t) => t.id == activeTabId,
      orElse: () => tabs.isNotEmpty ? tabs.first : const BrowserTabModel(id: 'default', url: BrowserUrlResolver.homePageUrl),
    );
  }

  BrowserTabState copyWith({List<BrowserTabModel>? tabs, String? activeTabId}) {
    return BrowserTabState(tabs: tabs ?? this.tabs, activeTabId: activeTabId ?? this.activeTabId);
  }
}

class BrowserTabNotifier extends StateNotifier<BrowserTabState> {
  static int _counter = 1;
  static String _generateId() => 'tab_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  BrowserTabNotifier([BrowserTabState? initialState])
      : super(initialState ?? const BrowserTabState(
          tabs: [
            BrowserTabModel(id: 'tab_google', url: 'https://www.google.com', title: 'Google'),
            BrowserTabModel(id: 'tab_youtube', url: 'https://m.youtube.com', title: 'YouTube'),
            BrowserTabModel(id: 'tab_deepseek', url: 'https://chat.deepseek.com', title: 'DeepSeek'),
            BrowserTabModel(id: 'tab_chatgpt', url: 'https://chat.openai.com', title: 'ChatGPT'),
            BrowserTabModel(id: 'tab_wikipedia', url: 'https://es.wikipedia.org', title: 'Wikipedia'),
          ],
          activeTabId: 'tab_google',
        ));

  String addTab({String? initialUrl}) {
    final newId = _generateId();
    final url = BrowserUrlResolver.resolveUrl(initialUrl ?? BrowserUrlResolver.homePageUrl);
    final newTab = BrowserTabModel(id: newId, url: url, title: BrowserUrlResolver.extractHost(url));
    state = state.copyWith(tabs: [...state.tabs, newTab], activeTabId: newId);
    return newId;
  }

  /// Reordena una pestaña en la lista mediante drag-and-drop (arrastrar a primera, última o intermedia).
  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.tabs.length) return;
    if (newIndex < 0 || newIndex > state.tabs.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
    final updatedTabs = List<BrowserTabModel>.from(state.tabs);
    final item = updatedTabs.removeAt(oldIndex);
    updatedTabs.insert(newIndex, item);
    state = state.copyWith(tabs: updatedTabs);
  }

  void closeTab(String tabId) {
    if (state.tabs.length <= 1) {
      final current = state.activeTab;
      updateTabById(current.id, url: BrowserUrlResolver.homePageUrl, title: 'Inicio - Google', progress: 0.0, isLoading: false);
      return;
    }
    final newTabs = state.tabs.where((t) => t.id != tabId).toList();
    String newActiveId = state.activeTabId;
    if (state.activeTabId == tabId) {
      final closedIndex = state.tabs.indexWhere((t) => t.id == tabId);
      final nextIndex = (closedIndex >= newTabs.length) ? newTabs.length - 1 : closedIndex;
      newActiveId = newTabs[nextIndex].id;
    }
    state = state.copyWith(tabs: newTabs, activeTabId: newActiveId);
  }

  void selectTab(String tabId) {
    if (state.tabs.any((t) => t.id == tabId)) {
      state = state.copyWith(activeTabId: tabId);
    }
  }

  void updateActiveTab({
    String? url, String? title, String? faviconUrl, bool? isLoading,
    double? progress, bool? canGoBack, bool? canGoForward, bool? isSecure, double? zoomLevel,
  }) {
    updateTabById(state.activeTabId, url: url, title: title, faviconUrl: faviconUrl,
      isLoading: isLoading, progress: progress, canGoBack: canGoBack, canGoForward: canGoForward, isSecure: isSecure, zoomLevel: zoomLevel);
  }

  void updateTabById(String tabId, {
    String? url, String? title, String? faviconUrl, bool? isLoading,
    double? progress, bool? canGoBack, bool? canGoForward, bool? isSecure, double? zoomLevel,
  }) {
    final updatedTabs = state.tabs.map((t) {
      if (t.id == tabId) {
        final newUrl = url ?? t.url;
        return t.copyWith(
          url: newUrl,
          title: title ?? (url != null ? BrowserUrlResolver.extractHost(url) : t.title),
          faviconUrl: faviconUrl ?? t.faviconUrl,
          isLoading: isLoading ?? t.isLoading,
          progress: progress ?? t.progress,
          canGoBack: canGoBack ?? t.canGoBack,
          canGoForward: canGoForward ?? t.canGoForward,
          isSecure: isSecure ?? BrowserUrlResolver.isSecure(newUrl),
          zoomLevel: zoomLevel ?? t.zoomLevel,
        );
      }
      return t;
    }).toList();
    state = state.copyWith(tabs: updatedTabs);
  }
}

final browserTabProvider = StateNotifierProvider<BrowserTabNotifier, BrowserTabState>((ref) => BrowserTabNotifier());
