import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LLMEngineClient — request_id y cancelación', () {
    test(
      'generateStream incluye request_id en el body y cancelRequest emite POST /cancel',
      () async {
        final requests = <http.Request>[];

        // MockClient registra cada request y responde un SSE que termina de
        // inmediato (un único frame stop). El mismo mock sirve como client
        // compartido (cancelRequest) y como fábrica del client de streaming.
        final mock = MockClient((request) async {
          requests.add(request);
          return http.Response('data: {"content":"","stop":true}\n\n', 200);
        });

        final client = LLMEngineClient(
          baseUrl: 'http://127.0.0.1:8080',
          timeout: const Duration(seconds: 5),
          client: mock,
          streamClientFactory: () => mock,
        );

        final result = client.generateStream(prompt: 'hola');
        final stream = result.stream;
        final requestId = result.requestId;
        await for (final _ in stream) {}

        final completion = requests.singleWhere(
          (r) => r.url.path == '/completion',
        );
        final body = jsonDecode(completion.body) as Map<String, dynamic>;
        expect(body['request_id'], requestId);
        expect(requestId, isNotEmpty);

        final confirmed = await client.cancelRequest(requestId);
        expect(confirmed, isTrue);
        final cancel = requests.lastWhere((r) => r.url.path == '/cancel');
        expect(cancel.method, 'POST');
        expect(jsonDecode(cancel.body)['request_id'], requestId);
      },
    );

    test('generateStream autogenera request_id único por turno', () async {
      final mock = MockClient((request) async {
        return http.Response('data: {"content":"","stop":true}\n\n', 200);
      });
      final client = LLMEngineClient(
        baseUrl: 'http://127.0.0.1:8080',
        timeout: const Duration(seconds: 5),
        client: mock,
        streamClientFactory: () => mock,
      );

      final a = client.generateStream(prompt: 'uno');
      final b = client.generateStream(prompt: 'dos');
      await a.stream.drain<void>();
      await b.stream.drain<void>();

      expect(a.requestId, isNotEmpty);
      expect(b.requestId, isNotEmpty);
      expect(a.requestId, isNot(equals(b.requestId)));
    });

    test(
      'cancelRequest devuelve false si el server responde 404 (ya terminada)',
      () async {
        final mock = MockClient((request) async {
          return http.Response('not found', 404);
        });
        final client = LLMEngineClient(
          baseUrl: 'http://127.0.0.1:8080',
          timeout: const Duration(seconds: 5),
          client: mock,
        );

        // 404 = request ya terminado: no es un fallo, se trata como "sin efecto".
        final result = await client.cancelRequest('req-404');
        expect(result, isFalse);
      },
    );
  });

  group('ChatNotifier — stop() durante streaming (R6)', () {
    test(
      'stop() deja generating=false, limpia streamingText y permite reenviar',
      () async {
        final client = _ManualEngineClient();
        final container = ProviderContainer(
          overrides: [
            chatProvider.overrideWith(
              (ref) => ChatNotifier.fixed(
                ref,
                const ChatState(engineOnline: true),
              ),
            ),
            runtimeEngineProvider.overrideWith(
              (ref) => _ManualEngineNotifier(client),
            ),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(chatProvider.notifier);

        // Lanza el envío sin await: queda esperando tokens del stream manual.
        final sendFuture = notifier.send('cuéntame algo');
        await pumpEventQueue();

        // Un token llega → generando sigue activo y hay texto en buffer.
        client.controllers.first.add(
          const LLMStreamToken(content: 'hola', stop: false),
        );
        await pumpEventQueue();
        expect(notifier.state.generating, isTrue);

        // STOP a mitad de streaming.
        notifier.stop();
        await pumpEventQueue();
        expect(notifier.state.generating, isFalse);
        expect(notifier.state.streamingText, isEmpty);
        // El cancel cooperativo (POST /cancel) se emitió con el request activo.
        expect(client.cancelledRequestIds, isNotEmpty);

        // Cierra el stream manual para que el sendFuture pendiente termine.
        await client.controllers.first.close();
        await sendFuture;

        // Siguiente send() debe funcionar sin heredar estado roto. Emitimos
        // un frame stop para que la ronda cierre de forma natural.
        final sendFuture2 = notifier.send('otra cosa');
        await pumpEventQueue();
        client.controllers.last.add(
          const LLMStreamToken(content: '', stop: true),
        );
        await client.controllers.last.close();
        await pumpEventQueue();
        await sendFuture2;

        expect(notifier.state.generating, isFalse);
        // user1 + user2 + ai2 (el turno cancelado no agrega mensaje ai).
        expect(notifier.state.messages.length, greaterThanOrEqualTo(3));
      },
    );
  });
}

/// Fake de engine con stream manual: cada `generateStream` crea un
/// [StreamController] que el test controla token a token. Permite simular un
/// stream abierto (sin `stop:true`) para ejercitar `stop()` a mitad.
class _ManualEngineClient extends LLMEngineClient {
  final List<StreamController<LLMStreamToken>> controllers = [];
  final List<String> cancelledRequestIds = [];

  @override
  Future<bool> cancelRequest(String requestId) async {
    cancelledRequestIds.add(requestId);
    return true;
  }

  @override
  ({Stream<LLMStreamToken> stream, http.Client client, String requestId})
      generateStream({
    required String prompt,
    double temperature = 0.7,
    double topP = 0.9,
    int maxTokens = 256,
    String? sessionId,
    String? context,
    List<Map<String, String>>? history,
    String? requestId,
  }) {
    final controller = StreamController<LLMStreamToken>();
    controllers.add(controller);
    return (
      stream: controller.stream,
      client: http.Client(),
      requestId: requestId ?? LLMEngineClient.newRequestId(),
    );
  }
}

class _ManualEngineNotifier extends RuntimeEngineNotifier {
  _ManualEngineNotifier(this._client) : super(NanoRuntimeApi.instance);

  final _ManualEngineClient _client;

  @override
  LLMEngineClient get client => _client;

  @override
  Future<bool> ensureReady({String? modelPath}) async => true;
}
