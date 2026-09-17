import 'browser_url_resolver.dart';

class BrowserTabModel {
  final String id;
  final String url;
  final String title;
  final String? faviconUrl;
  final bool isLoading;
  final double progress;
  final bool canGoBack;
  final bool canGoForward;
  final bool isSecure;
  final double zoomLevel;

  const BrowserTabModel({
    required this.id,
    required this.url,
    this.title = 'Nueva Pestaña',
    this.faviconUrl,
    this.isLoading = false,
    this.progress = 0.0,
    this.canGoBack = false,
    this.canGoForward = false,
    this.isSecure = true,
    this.zoomLevel = 1.0,
  });

  String get displayHost => BrowserUrlResolver.extractHost(url);

  BrowserTabModel copyWith({
    String? id,
    String? url,
    String? title,
    String? faviconUrl,
    bool? isLoading,
    double? progress,
    bool? canGoBack,
    bool? canGoForward,
    bool? isSecure,
    double? zoomLevel,
  }) {
    return BrowserTabModel(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      isSecure: isSecure ?? this.isSecure,
      zoomLevel: zoomLevel ?? this.zoomLevel,
    );
  }
}
