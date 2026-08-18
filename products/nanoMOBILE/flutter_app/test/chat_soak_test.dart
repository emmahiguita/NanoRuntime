import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

  test(
    '30 turnos de conversación sin crash ni corrupción de estado (R12)',
    () async {
      final client = _SoakEngineClient();
      final container = ProviderContainer(
        overrides: [
          chatProvider.overrideWith(
            (ref) => ChatNotifier.fixed(
              ref,
              const ChatState(engineOnline: true),
            ),
          ),
          runtimeEngineProvider.overrideWith(
            (ref) => _SoakEngineNotifier(client),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(chatProvider.notifier);
      final sid0 = notifier.sessionId;

      for (var i = 0; i < 30; i++) {
        await notifier.send('turno $i');
        await pumpEventQueue();
        expect(
          notifier.state.generating,
          isFalse,
          reason: 'el turno $i debe terminar sin quedar colgado',
        );
      }

      // 30 user + 30 ai = 60 mensajes, sin tool pendiente ni sesión rotada.
      expect(notifier.state.messages.length, 60);
      expect(notifier.state.pendingTool, isNull);
      expect(notifier.sessionId, sid0, reason: 'la sesión no rota sin cambio de modelo');
    },
  );
}

/// Fake determinista: cada turno emite un texto y un frame stop de inmediato.
class _SoakEngineClient extends LLMEngineClient {
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
      stream: Stream<LLMStreamToken>.fromIterable(const [
        LLMStreamToken(content: 'respuesta', stop: false),
        LLMStreamToken(content: '', stop: true),
      ]),
      client: http.Client(),
      requestId: requestId ?? LLMEngineClient.newRequestId(),
    );
  }
}

class _SoakEngineNotifier extends RuntimeEngineNotifier {
  _SoakEngineNotifier(this._client) : super(NanoRuntimeApi.instance);

  final _SoakEngineClient _client;

  @override
  LLMEngineClient get client => _client;

  @override
  Future<bool> ensureReady({String? modelPath}) async => true;
}
