import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';

void main() {
  test('requestTimeout override cancels a stalled local generation', () async {
    final paths = <String>[];
    final httpClient = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/cancel')) {
        return http.Response('{"cancelled":true}', 200);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return http.Response('{"content":"late"}', 200);
    });
    final engine = LLMEngineClient(
      baseUrl: 'http://127.0.0.1:8080',
      timeout: const Duration(seconds: 5),
      client: httpClient,
    );

    await expectLater(
      engine.generate(
        prompt: 'test',
        requestTimeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<LLMEngineException>()),
    );
    expect(paths, contains('/completion'));
    expect(paths, contains('/cancel'));

    httpClient.close();
  });
}
