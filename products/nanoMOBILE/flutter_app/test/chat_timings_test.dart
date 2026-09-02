import 'dart:async';

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

  test('LLMEngineClient parsea heartbeat de fase y timings del SSE', () async {
    final mock = MockClient((request) async {
      return http.Response(
        'data: {"heartbeat":true,"phase":"model_loading"}\n\n'
        'data: {"content":"hola","stop":false}\n\n'
        'data: {"content":"","stop":true,"timings":{"ttft_ms":100,'
        '"prefill_ms":50,"total_tokens":8,"generated_tokens":3,'
        '"decode_tok_s":12.5,"total_ms":240}}\n\n',
        200,
      );
    });
    final client = LLMEngineClient(
      baseUrl: 'http://127.0.0.1:8080',
      client: mock,
      streamClientFactory: () => mock,
    );

    final result = client.generateStream(prompt: 'hola');
    final tokens = <LLMStreamToken>[];
    await for (final t in result.stream) {
      tokens.add(t);
    }

    // Primer frame: heartbeat con fase.
    expect(tokens.first.phase, 'model_loading');
    expect(tokens.first.content, isEmpty);
    // Último frame: stop con timings.
    final last = tokens.last;
    expect(last.stop, isTrue);
    expect(last.timings, isNotNull);
    expect(last.timings!['decode_tok_s'], 12.5);
    expect(last.timings!['prefill_ms'], 50);
  });

  test('ChatNotifier consume fase de carga y timings por turno', () async {
    final client = _TimingEngineClient();
    final container = ProviderContainer(
      overrides: [
        chatProvider.overrideWith(
          (ref) => ChatNotifier.fixed(ref, const ChatState(engineOnline: true)),
        ),
        runtimeEngineProvider.overrideWith(
          (ref) => _TimingEngineNotifier(client),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier);

    final sendFuture = notifier.send('hola');
    await pumpEventQueue();

    // Heartbeat de carga → chip CARGANDO (connection loadingModel).
    client.controller.add(
      const LLMStreamToken(content: '', stop: false, phase: 'model_loading'),
    );
    await pumpEventQueue();
    expect(notifier.state.connection, ModelConnectionState.loadingModel);

    // Token + frame final con timings.
    client.controller.add(const LLMStreamToken(content: 'hola', stop: false));
    client.controller.add(
      const LLMStreamToken(
        content: '',
        stop: true,
        timings: {
          'ttft_ms': 100,
          'prefill_ms': 50,
          'total_tokens': 5,
          'generated_tokens': 1,
          'decode_tok_s': 12.5,
          'total_ms': 90,
        },
      ),
    );
    await client.controller.close();
    await sendFuture;

    expect(notifier.state.connection, ModelConnectionState.ready);
    expect(notifier.state.lastTurnMetrics, isNotNull);
    expect(notifier.state.lastTurnMetrics!.decodeTokS, 12.5);
    expect(notifier.state.lastTurnMetrics!.prefillMs, 50);
  });
}

/// Fake con stream manual para controlar el timing de heartbeat/tokens.
class _TimingEngineClient extends LLMEngineClient {
  final StreamController<LLMStreamToken> controller =
      StreamController<LLMStreamToken>();

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
    return (
      stream: controller.stream,
      client: http.Client(),
      requestId: requestId ?? LLMEngineClient.newRequestId(),
    );
  }
}

class _TimingEngineNotifier extends RuntimeEngineNotifier {
  _TimingEngineNotifier(this._client) : super(NanoRuntimeApi.instance);

  final _TimingEngineClient _client;

  @override
  LLMEngineClient get client => _client;

  @override
  Future<bool> ensureReady({String? modelPath}) async => true;
}
