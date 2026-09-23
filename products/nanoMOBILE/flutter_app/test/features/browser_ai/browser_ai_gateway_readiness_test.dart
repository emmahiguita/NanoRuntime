import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser_ai/application/browser_ai_gateway.dart';

void main() {
  group('BrowserAiGateway readiness', () {
    test('termina en cuanto la sesión está disponible', () async {
      var checks = 0;

      final ready = await BrowserAiGateway.waitUntilLoggedIn(
        () async => ++checks == 3,
        retryDelays: const [Duration.zero, Duration.zero, Duration.zero],
      );

      expect(ready, isTrue);
      expect(checks, 3);
    });

    test('agota solo los reintentos configurados', () async {
      var checks = 0;

      final ready = await BrowserAiGateway.waitUntilLoggedIn(() async {
        checks++;
        return false;
      }, retryDelays: const [Duration.zero, Duration.zero, Duration.zero]);

      expect(ready, isFalse);
      expect(checks, 4);
    });
  });
}
