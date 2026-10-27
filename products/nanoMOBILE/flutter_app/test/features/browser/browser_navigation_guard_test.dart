import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser/domain/tiktok_web_policy.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_web_identity_coordinator.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_webview_navigation_guard.dart';

class FakeInAppWebViewController extends Fake implements InAppWebViewController {
  bool stoppedLoading = false;
  WebUri? currentUrl;

  @override
  Future<void> stopLoading() async {
    stoppedLoading = true;
  }

  @override
  Future<WebUri?> getUrl() async => currentUrl;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BrowserWebViewNavigationGuard', () {
    late FakeInAppWebViewController controller;
    late List<String> externalPrompts;
    late List<Uri> launchedIntents;
    bool appInstalled = false;

    setUp(() {
      controller = FakeInAppWebViewController();
      externalPrompts = [];
      launchedIntents = [];
      appInstalled = false;
    });

    BrowserWebViewNavigationGuard createGuard(
      BuildContext context,
      WidgetRef ref, {
      ExternalAppBehavior behavior = ExternalAppBehavior.stayInWeb,
    }) {
      return BrowserWebViewNavigationGuard(
        context: () => context,
        ref: ref,
        isAlive: () => true,
        identity: BrowserWebIdentityCoordinator(
          isAlive: () => true,
          userDesktopMode: () => false,
        ),
        onExternalPrompt: (url) {
          externalPrompts.add(url);
        },
        externalAppLauncher: (uri) async {
          if (appInstalled) {
            launchedIntents.add(uri);
            return true;
          }
          return false;
        },
        externalAppBehavior: () => behavior,
      );
    }

    testWidgets('allowsLoad permite URLs web normales y bloquea URLs privadas', (tester) async {
      late BrowserWebViewNavigationGuard guard;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                guard = createGuard(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      // 1. Navegación web normal a TikTok
      final allowedWeb = guard.allowsLoad(
        controller,
        'https://www.tiktok.com/@daniela/video/7695306632284228885',
      );
      expect(allowedWeb, isTrue);
      expect(controller.stoppedLoading, isFalse);

      // 2. Loopback local -> bloqueado
      final allowedLocal = guard.allowsLoad(
        controller,
        'http://127.0.0.1:8080/completion',
      );
      expect(allowedLocal, isFalse);
      expect(controller.stoppedLoading, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Bloqueado por Firewall'), findsOneWidget);

      // Cerrar modal
      await tester.tap(find.text('ENTENDIDO'));
      await tester.pumpAndSettle();

      // 3. Red privada -> bloqueado
      controller.stoppedLoading = false;
      final allowedPrivate = guard.allowsLoad(
        controller,
        'http://192.168.1.1',
      );
      expect(allowedPrivate, isFalse);
      expect(controller.stoppedLoading, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Bloqueado por Firewall'), findsOneWidget);
      await tester.tap(find.text('ENTENDIDO'));
      await tester.pumpAndSettle();

      // 4. Custom app scheme snssdk1340 -> cancela carga web SIN modal de firewall
      controller.stoppedLoading = false;
      final allowedTikTokApp = guard.allowsLoad(
        controller,
        'snssdk1340://aweme/detail/7695306632284228885',
      );
      expect(allowedTikTokApp, isFalse);
      expect(controller.stoppedLoading, isTrue);
      await tester.pumpAndSettle();
      // NO debe mostrar modal de firewall para app scheme
      expect(find.text('Bloqueado por Firewall'), findsNothing);
    });

    testWidgets('TikTok Web intenta snssdk1340:// sin gesto -> cancela silenciosamente y mantiene web', (tester) async {
      late BrowserWebViewNavigationGuard guard;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                guard = createGuard(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.currentUrl = WebUri('https://www.tiktok.com/@daniela/video/123');

      final action = NavigationAction(
        request: URLRequest(
          url: WebUri('snssdk1340://aweme/detail/7695306632284228885?utm_source=tiktokweb'),
        ),
        hasGesture: false,
        isForMainFrame: true,
      );

      final policy = await guard.shouldOverrideUrlLoading(controller, action);
      expect(policy, equals(NavigationActionPolicy.CANCEL));
      expect(launchedIntents, isEmpty);
      expect(externalPrompts, isEmpty);

      await tester.pumpAndSettle();
      expect(find.text('Bloqueado por Firewall'), findsNothing);
    });

    testWidgets('STAY_IN_WEB (default): gesto del usuario NO lanza TikTok -> permanece en web', (tester) async {
      appInstalled = true;
      late BrowserWebViewNavigationGuard guard;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                guard = createGuard(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.currentUrl = WebUri('https://www.tiktok.com/@daniela');

      final action = NavigationAction(
        request: URLRequest(
          url: WebUri('snssdk1340://aweme/detail/7695306632284228885'),
        ),
        hasGesture: true,
        isForMainFrame: true,
      );

      final policy = await guard.shouldOverrideUrlLoading(controller, action);
      expect(policy, equals(NavigationActionPolicy.CANCEL));
      expect(launchedIntents, isEmpty);
      // STAY_IN_WEB jamás produce un diálogo "Abrir TikTok"
      expect(externalPrompts, isEmpty);

      await tester.pumpAndSettle();
      expect(find.text('Bloqueado por Firewall'), findsNothing);
    });

    testWidgets('ALLOW_EXPLICIT: gesto del usuario lanza TikTok -> lanza Intent', (tester) async {
      appInstalled = true;
      late BrowserWebViewNavigationGuard guard;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                guard = createGuard(
                  context,
                  ref,
                  behavior: ExternalAppBehavior.allowExplicit,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.currentUrl = WebUri('https://www.tiktok.com/@daniela');

      final action = NavigationAction(
        request: URLRequest(
          url: WebUri('snssdk1340://aweme/detail/7695306632284228885'),
        ),
        hasGesture: true,
        isForMainFrame: true,
      );

      final policy = await guard.shouldOverrideUrlLoading(controller, action);
      expect(policy, equals(NavigationActionPolicy.CANCEL));
      expect(launchedIntents.length, equals(1));
      expect(launchedIntents.first.scheme, equals('snssdk1340'));

      await tester.pumpAndSettle();
      expect(find.text('Bloqueado por Firewall'), findsNothing);
    });

    testWidgets('ASK: gesto del usuario pregunta antes de abrir TikTok', (tester) async {
      appInstalled = true;
      late BrowserWebViewNavigationGuard guard;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                guard = createGuard(
                  context,
                  ref,
                  behavior: ExternalAppBehavior.ask,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.currentUrl = WebUri('https://www.tiktok.com/@daniela');

      final action = NavigationAction(
        request: URLRequest(
          url: WebUri('snssdk1340://aweme/detail/7695306632284228885'),
        ),
        hasGesture: true,
        isForMainFrame: true,
      );

      final policy = await guard.shouldOverrideUrlLoading(controller, action);
      expect(policy, equals(NavigationActionPolicy.CANCEL));
      expect(launchedIntents, isEmpty);
      expect(externalPrompts.length, equals(1));

      await tester.pumpAndSettle();
    });

    testWidgets('Usuario pulsa "Abrir en app" sin TikTok instalado -> permanece en web sin firewall', (tester) async {
      appInstalled = false;
      late BrowserWebViewNavigationGuard guard;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                guard = createGuard(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.currentUrl = WebUri('https://www.tiktok.com/@daniela');

      final action = NavigationAction(
        request: URLRequest(
          url: WebUri('snssdk1340://aweme/detail/7695306632284228885'),
        ),
        hasGesture: true,
        isForMainFrame: true,
      );

      final policy = await guard.shouldOverrideUrlLoading(controller, action);
      expect(policy, equals(NavigationActionPolicy.CANCEL));
      expect(launchedIntents, isEmpty);

      await tester.pumpAndSettle();
      expect(find.text('Bloqueado por Firewall'), findsNothing);
    });

    testWidgets('Página arbitraria no confiable intenta snssdk1340:// -> no lanza automáticamente', (tester) async {
      appInstalled = true;
      late BrowserWebViewNavigationGuard guard;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                guard = createGuard(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.currentUrl = WebUri('https://sitio-malicioso.example');

      final action = NavigationAction(
        request: URLRequest(
          url: WebUri('snssdk1340://aweme/detail/7695306632284228885'),
        ),
        hasGesture: false,
        isForMainFrame: true,
      );

      final policy = await guard.shouldOverrideUrlLoading(controller, action);
      expect(policy, equals(NavigationActionPolicy.CANCEL));
      expect(launchedIntents, isEmpty);

      await tester.pumpAndSettle();
      expect(find.text('Bloqueado por Firewall'), findsNothing);
    });

    testWidgets('Navegación normal en TikTok Web se permite con NavigationActionPolicy.ALLOW', (tester) async {
      late BrowserWebViewNavigationGuard guard;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                guard = createGuard(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.currentUrl = WebUri('https://www.tiktok.com');

      final action = NavigationAction(
        request: URLRequest(
          url: WebUri('https://www.tiktok.com/@creator/video/12345'),
        ),
        hasGesture: true,
        isForMainFrame: true,
      );

      final policy = await guard.shouldOverrideUrlLoading(controller, action);
      expect(policy, equals(NavigationActionPolicy.ALLOW));
    });

    testWidgets('https://*.tiktokv.com es web normal: ALLOW sin prompts ni app externa', (tester) async {
      appInstalled = true;
      late BrowserWebViewNavigationGuard guard;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                guard = createGuard(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.currentUrl = WebUri('https://www.tiktok.com');

      final action = NavigationAction(
        request: URLRequest(
          url: WebUri(
            'https://app-va.tiktokv.com/redirect/?redirect_url=snssdk1233%3A%2F%2Faweme',
          ),
        ),
        hasGesture: true,
        isForMainFrame: true,
      );

      final policy = await guard.shouldOverrideUrlLoading(controller, action);
      expect(policy, equals(NavigationActionPolicy.ALLOW));
      expect(launchedIntents, isEmpty);
      expect(externalPrompts, isEmpty);

      await tester.pumpAndSettle();
      expect(find.text('Bloqueado por Firewall'), findsNothing);
    });

    testWidgets('Intento de navegación a IP privada 192.168.1.1 se cancela y muestra firewall', (tester) async {
      late BrowserWebViewNavigationGuard guard;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                guard = createGuard(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.currentUrl = WebUri('https://www.tiktok.com');

      final action = NavigationAction(
        request: URLRequest(
          url: WebUri('http://192.168.1.1/admin'),
        ),
        hasGesture: false,
        isForMainFrame: true,
      );

      final policy = await guard.shouldOverrideUrlLoading(controller, action);
      expect(policy, equals(NavigationActionPolicy.CANCEL));

      await tester.pumpAndSettle();
      expect(find.text('Bloqueado por Firewall'), findsOneWidget);
    });
  });
}
