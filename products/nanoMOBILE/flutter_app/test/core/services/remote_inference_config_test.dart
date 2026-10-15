import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nanoai/core/services/remote_inference_config.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('RemoteInferenceConfig & Store', () {
    test('loads default configuration when empty', () async {
      final config = await RemoteInferenceSettingsStore.load();
      expect(config.target, InferenceExecutionTarget.onDevice);
      expect(config.isRemote, false);
      expect(config.serverUrl, 'http://127.0.0.1:8080');
      expect(config.apiKey, '');
    });

    test('saves and loads remote PC configuration with secure key', () async {
      await RemoteInferenceSettingsStore.save(
        target: InferenceExecutionTarget.remotePc,
        serverUrl: 'http://192.168.1.150:8080',
        apiKey: 'secret-token-xyz',
      );

      final loaded = await RemoteInferenceSettingsStore.load();
      expect(loaded.target, InferenceExecutionTarget.remotePc);
      expect(loaded.isRemote, true);
      expect(loaded.serverUrl, 'http://192.168.1.150:8080');
      expect(loaded.apiKey, 'secret-token-xyz');
    });

    test('RemoteInferenceNotifier updates state on config change', () async {
      final notifier = RemoteInferenceNotifier();
      // Esperar microtask de carga inicial
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await notifier.updateConfig(
        target: InferenceExecutionTarget.remotePc,
        serverUrl: 'http://100.64.0.1:8080',
        apiKey: 'tailscale-key',
      );

      expect(notifier.state.isRemote, true);
      expect(notifier.state.serverUrl, 'http://100.64.0.1:8080');
      expect(notifier.state.apiKey, 'tailscale-key');
    });
  });

  group('LLMEngineClient with Remote Auth Headers', () {
    test('sends Authorization and X-Nano-API-Key headers when apiKey is present', () async {
      Map<String, String>? capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        if (request.url.path == '/health') {
          return http.Response('{"status":"ok"}', 200);
        }
        return http.Response('{"status":"ok"}', 200);
      });

      final client = LLMEngineClient(
        baseUrl: 'http://192.168.1.150:8080',
        apiKey: 'my-custom-bearer-token',
        client: mockClient,
      );

      final ok = await client.isOnline(attempts: 1);
      expect(ok, true);
      expect(capturedHeaders?['Authorization'], 'Bearer my-custom-bearer-token');
      expect(capturedHeaders?['X-Nano-API-Key'], 'my-custom-bearer-token');
    });

    test('updateEndpoint updates baseUrl and apiKey dynamically', () async {
      Map<String, String>? capturedHeaders;
      String? capturedUrl;

      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        capturedUrl = request.url.toString();
        return http.Response('{"status":"ok"}', 200);
      });

      final client = LLMEngineClient(
        baseUrl: 'http://127.0.0.1:8080',
        client: mockClient,
      );

      client.updateEndpoint(
        baseUrl: 'http://10.0.0.5:9000',
        apiKey: 'new-key-123',
      );

      expect(client.baseUrl, 'http://10.0.0.5:9000');
      expect(client.apiKey, 'new-key-123');

      await client.isOnline(attempts: 1);
      expect(capturedUrl, 'http://10.0.0.5:9000/health');
      expect(capturedHeaders?['Authorization'], 'Bearer new-key-123');
    });
  });
}
