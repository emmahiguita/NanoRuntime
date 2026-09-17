import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser/application/browser_surface_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';

void main() {
  group('Browser native surface persistence', () {
    test('reuses one keep-alive identity for the same tab', () {
      final registry = BrowserWebViewRegistry();

      final first = registry.keepAliveFor('tab-a');
      final second = registry.keepAliveFor('tab-a');
      final other = registry.keepAliveFor('tab-b');

      expect(identical(first, second), isTrue);
      expect(identical(first, other), isFalse);
    });

    test('allows only one presentation host at a time', () {
      final notifier = BrowserSurfaceNotifier();

      expect(notifier.state, BrowserSurfaceHost.embedded);
      notifier.showFullscreen();
      expect(notifier.state, BrowserSurfaceHost.fullscreen);
      notifier.showEmbedded();
      expect(notifier.state, BrowserSurfaceHost.embedded);
    });
  });
}
