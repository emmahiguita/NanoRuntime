import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BrowserSurfaceHost { embedded, fullscreen }

/// Coordinates which surface is allowed to mount the native WebViews.
///
/// Keeping this exclusive prevents Home and the fullscreen route from owning
/// two platform views for the same tab during a route transition.
class BrowserSurfaceNotifier extends StateNotifier<BrowserSurfaceHost> {
  BrowserSurfaceNotifier() : super(BrowserSurfaceHost.embedded);

  void showEmbedded() => state = BrowserSurfaceHost.embedded;

  void showFullscreen() => state = BrowserSurfaceHost.fullscreen;
}

final browserSurfaceProvider =
    StateNotifierProvider<BrowserSurfaceNotifier, BrowserSurfaceHost>(
      (ref) => BrowserSurfaceNotifier(),
    );
