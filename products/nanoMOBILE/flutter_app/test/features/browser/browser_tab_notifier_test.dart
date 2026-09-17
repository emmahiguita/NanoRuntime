import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';

void main() {
  group('BrowserTabNotifier', () {
    late BrowserTabNotifier notifier;

    setUp(() {
      notifier = BrowserTabNotifier(
        const BrowserTabState(
          tabs: [
            BrowserTabModel(
              id: 'tab_default',
              url: BrowserUrlResolver.homePageUrl,
              title: 'Inicio',
            ),
          ],
          activeTabId: 'tab_default',
        ),
      );
    });

    test('arranca con una pestaña por defecto en Inicio', () {
      final state = notifier.state;
      expect(state.tabs.length, equals(1));
      expect(state.activeTab.url, equals(BrowserUrlResolver.homePageUrl));
    });

    test('permite añadir pestañas y cambiarse a la nueva pestaña automáticamente', () {
      final tabId = notifier.addTab(initialUrl: 'https://github.com');
      final state = notifier.state;

      expect(state.tabs.length, equals(2));
      expect(state.activeTabId, equals(tabId));
      expect(state.activeTab.url, equals('https://github.com'));
    });

    test('permite seleccionar y cambiar entre pestañas abiertas', () {
      final initialId = notifier.state.activeTabId;
      final secondId = notifier.addTab(initialUrl: 'https://openai.com');

      expect(notifier.state.activeTabId, equals(secondId));

      notifier.selectTab(initialId);
      expect(notifier.state.activeTabId, equals(initialId));
    });

    test('al cerrar una pestaña cambia a la pestaña adyacente', () {
      final tab2 = notifier.addTab(initialUrl: 'https://site2.com');
      final tab3 = notifier.addTab(initialUrl: 'https://site3.com');

      expect(notifier.state.tabs.length, equals(3));
      expect(notifier.state.activeTabId, equals(tab3));

      notifier.closeTab(tab3);

      expect(notifier.state.tabs.length, equals(2));
      expect(notifier.state.activeTabId, equals(tab2));
    });

    test('si solo queda una pestaña y se cierra, se resetea a inicio', () {
      final tabId = notifier.state.activeTabId;
      notifier.updateActiveTab(url: 'https://custom.com', title: 'Custom');

      notifier.closeTab(tabId);

      expect(notifier.state.tabs.length, equals(1));
      expect(notifier.state.activeTab.url, equals(BrowserUrlResolver.homePageUrl));
    });
  });
}
