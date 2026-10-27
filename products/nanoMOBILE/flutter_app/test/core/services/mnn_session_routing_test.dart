import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/services/litert_inference_adapter.dart';
import 'package:nanoai/core/services/mnn_inference_adapter.dart';
import 'package:nanoai/core/services/routed_llm_engine_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('com.nanoai/mnn');
  const events = MethodChannel('com.nanoai/mnn_events');
  const path = '/test/Qwen2.5-Omni-3B-MNN';
  final calls = <Map<Object?, Object?>>[];
  late MnnInferenceAdapter mnn;
  late RoutedLlmEngineClient client;

  setUp(() async {
    calls.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(methods, (call) async {
      switch (call.method) {
        case 'status':
          return {'loaded': true, 'modelPath': path};
        case 'generate':
          calls.add(Map<Object?, Object?>.from(call.arguments as Map));
          return {'generated_tokens': 0, 'decode_tok_s': 0.0};
        default:
          return true;
      }
    });
    mnn = MnnInferenceAdapter();
    await mnn.initialize(modelPath: path);
    client = RoutedLlmEngineClient(
      llama: LLMEngineClient(),
      liteRt: LiteRtInferenceAdapter(),
      mnn: mnn,
      useLiteRt: () => false,
      useMnn: () => true,
    );
  });

  tearDown(() async {
    await mnn.release();
    mnn.dispose();
    await Future<void>.delayed(Duration.zero);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  test(
    'Generación y streaming conservan sesión e historial hasta MNN',
    () async {
      await client.generate(
        prompt: 'Pregunta A',
        sessionId: 'personal/chat-a',
        history: const [
          {'role': 'user', 'content': 'Dato A'},
        ],
      );
      final stream = client.generateStream(
        prompt: 'Pregunta B',
        sessionId: 'personal/chat-b',
      );
      await stream.stream.drain<void>();
      stream.client.close();
      expect(calls.map((call) => call['sessionId']), [
        'personal/chat-a',
        'personal/chat-b',
      ]);
      expect(calls.first['history'], [
        {'role': 'user', 'content': 'Dato A'},
      ]);
    },
  );
}
