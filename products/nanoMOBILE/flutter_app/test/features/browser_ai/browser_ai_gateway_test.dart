import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser_ai/application/browser_ai_provider_registry.dart';
import 'package:nanoai/features/browser_ai/domain/browser_ai_query.dart';
import 'package:nanoai/features/browser_ai/domain/browser_ai_response.dart';

void main() {
  group('Browser AI Gateway — Pruebas de Registro y Dominio', () {
    test('BrowserAiProviderRegistry: Carga proveedores base por defecto', () {
      final registry = BrowserAiProviderRegistry();
      final all = registry.allProviders;

      expect(all.length, equals(5));
      expect(registry.getProvider('chatgpt'), isNotNull);
      expect(registry.getProvider('gemini'), isNotNull);
      expect(registry.getProvider('claude'), isNotNull);
      expect(registry.getProvider('deepseek'), isNotNull);
      expect(registry.getProvider('mistral'), isNotNull);
    });

    test('BrowserAiProviderRegistry: Resuelve proveedor adecuado según URL', () {
      final registry = BrowserAiProviderRegistry();

      final gpt = registry.providerForUrl(Uri.parse('https://chatgpt.com/c/123'));
      expect(gpt?.id, equals('chatgpt'));

      final gemini = registry.providerForUrl(Uri.parse('https://gemini.google.com/app'));
      expect(gemini?.id, equals('gemini'));

      final claude = registry.providerForUrl(Uri.parse('https://claude.ai/new'));
      expect(claude?.id, equals('claude'));

      final deepseek = registry.providerForUrl(Uri.parse('https://chat.deepseek.com/'));
      expect(deepseek?.id, equals('deepseek'));
    });

    test('BrowserAiQuery: Modela consultas con valores predeterminados y copyWith', () {
      final query = BrowserAiQuery(prompt: 'Explica Clean Architecture');

      expect(query.providerId, equals('auto'));
      expect(query.timeout.inSeconds, equals(45));

      final customized = query.copyWith(providerId: 'deepseek', timeout: const Duration(seconds: 60));
      expect(customized.providerId, equals('deepseek'));
      expect(customized.timeout.inSeconds, equals(60));
    });

    test('BrowserAiResponse: Modela respuestas exitosas y de acción requerida', () {
      final success = BrowserAiResponse.success(
        providerId: 'gemini',
        content: 'Respuesta generada.',
        duration: const Duration(milliseconds: 1200),
      );
      expect(success.isCompleted, isTrue);
      expect(success.needsUserAction, isFalse);

      final action = BrowserAiResponse.userActionRequired(
        providerId: 'chatgpt',
        reason: 'Resolver CAPTCHA de Cloudflare',
        duration: const Duration(milliseconds: 300),
      );
      expect(action.isCompleted, isFalse);
      expect(action.needsUserAction, isTrue);
      expect(action.error, contains('CAPTCHA'));
    });
  });
}
