import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nanoai/core/services/api_provider_service.dart';
import 'package:nanoai/core/services/execution_budget.dart';

class _PendingClient extends http.BaseClient {
  final started = Completer<void>();
  final result = Completer<http.StreamedResponse>();
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!started.isCompleted) started.complete();
    return result.future;
  }

  @override
  void close() {
    closed = true;
    if (!result.isCompleted)
      result.completeError(StateError('request cancelled'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  const config = ApiProviderConfig(
    provider: ApiProviderKind.groq,
    model: 'test-model',
    baseUrl: 'https://api.groq.com/openai/v1',
    hasApiKey: true,
  );

  test(
    'La migración une claves sin sobrescribir el modelo configurado',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'nano_cloud_groq_keys': 'old-a,old-b',
        'nanoai.api.credential.v1.groq': 'old-a\ncurrent',
        'nanoai.api.config.v1.groq.model': 'custom-model',
      });
      final store = ApiProviderSettingsStore();
      await Future.wait([store.migrateLegacyKeys(), store.migrateLegacyKeys()]);
      expect(await store.readApiKeys(ApiProviderKind.groq), [
        'old-a',
        'current',
        'old-b',
      ]);
      expect(
        (await store.loadForProvider(ApiProviderKind.groq)).model,
        'custom-model',
      );
      await store.deleteApiKey(ApiProviderKind.groq);
      expect(
        await ApiProviderSettingsStore().readApiKeys(ApiProviderKind.groq),
        isEmpty,
      );
      expect(
        await const FlutterSecureStorage().read(key: 'nano_cloud_groq_keys'),
        'old-a,old-b',
      );
    },
  );

  test('El Hub y la generación leen la misma clave guardada', () async {
    final store = ApiProviderSettingsStore();
    await store.save(config, apiKey: 'first,second,first');
    final service = ApiProviderChatService(
      store: store,
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer first');
        return http.Response(
          '{"choices":[{"message":{"content":"Hola"}}]}',
          200,
        );
      }),
    );
    expect(await service.generate(prompt: 'saludo'), 'Hola');
    expect(await store.readApiKeys(ApiProviderKind.groq), ['first', 'second']);
    service.close();
  });

  test('Importar una clave no reemplaza un modelo elegido previamente sin clave', () async {
    FlutterSecureStorage.setMockInitialValues({
      'nano_cloud_gemini_keys': 'legacy-key',
      'nanoai.api.config.v1.gemini.model': 'my-model',
    });
    final store = ApiProviderSettingsStore();
    expect((await store.loadForProvider(ApiProviderKind.gemini)).model, 'my-model');
  });

  test('Cerrar el cliente cancela una solicitud en vuelo', () async {
    final client = _PendingClient();
    final service = ApiProviderChatService(
      store: ApiProviderSettingsStore(),
      client: client,
    );
    final request = service.generate(
      prompt: 'hola',
      configOverride: config,
      apiKeyOverride: 'test',
    );
    final assertion = expectLater(
      request,
      throwsA(isA<ApiProviderException>()),
    );
    await client.started.future;
    service.close();
    await assertion;
    expect(client.closed, isTrue);
    await expectLater(
      service.generate(prompt: 'otro'),
      throwsA(isA<ApiProviderException>()),
    );
  });

  test(
    'La cancelación del presupuesto cierra solo la solicitud registrada',
    () async {
      final client = _PendingClient();
      final service = ApiProviderChatService(
        store: ApiProviderSettingsStore(),
        client: client,
      );
      final budget = ExecutionBudget(const Duration(seconds: 5));
      final request = budget.run(
        () => service.generate(
          prompt: 'hola',
          configOverride: config,
          apiKeyOverride: 'test',
        ),
      );
      final assertion = expectLater(
        request,
        throwsA(isA<ApiProviderException>()),
      );
      await client.started.future;
      budget.cancel();
      await assertion;
      expect(client.closed, isTrue);
      service.close();
    },
  );
}
