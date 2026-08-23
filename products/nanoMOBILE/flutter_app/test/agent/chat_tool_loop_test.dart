import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nanoai/features/automation/engine/perception/actionability_engine.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';

import 'fixtures.dart';

/// Aplana un history (role/content) a un único string para asserts `contains`.
String _historyText(List<Map<String, String>>? history) =>
    (history ?? const []).map((m) => m['content'] ?? '').join('\n');

/// Tests del tool-calling en ChatNotifier: comandos `@` interceptados sin
/// motor y loop de herramientas con el LLM (fake engine + canal mockeado).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/agent');
  const notificationsChannel = MethodChannel('com.nanoai/notifications');

  final tapCalls = <List<int>>[];
  final inputCalls = <String>[];
  final notificationReplies = <Map<dynamic, dynamic>>[];

  late ProviderContainer container;

  /// Dispatcher con estabilidad instantánea para los tests.
  final dispatcher = AgentToolDispatcher(
    executor: NanoAgentExecutor(
      stability: const StabilityChecker(
        wait: Duration.zero,
        maxCenterDeltaPx: 24,
        maxSizeChangeRatio: 0.10,
      ),
    ),
  );

  setUp(() {
    tapCalls.clear();
    inputCalls.clear();
    notificationReplies.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'dumpSnapshot':
              return snapshotAjustes();
            case 'tapAt':
              final args = call.arguments as Map;
              tapCalls.add([args['x'] as int, args['y'] as int]);
              return true;
            case 'inputText':
              inputCalls.add((call.arguments as Map)['text'] as String);
              return true;
            case 'globalAction':
              return true;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          switch (call.method) {
            case 'list':
              return [
                {
                  'key': 'notification-key-1',
                  'package': 'com.example.chat',
                  'title': 'Ana',
                  'text': '¿Llegas pronto?',
                  'canReply': true,
                },
              ];
            case 'reply':
              notificationReplies.add(call.arguments as Map);
              return {'ok': true};
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    container.dispose();
  });

  /// Monta el contenedor con el chat real (fixed) + motor fake + dispatcher.
  ChatNotifier pumpNotifier(_LoopEngineClient fake) {
    container = ProviderContainer(
      overrides: [
        chatProvider.overrideWith(
          (ref) => ChatNotifier.fixed(
            ref,
            const ChatState(engineOnline: true),
            toolDispatcher: dispatcher,
          ),
        ),
        runtimeEngineProvider.overrideWith((ref) => _LoopEngineNotifier(fake)),
      ],
    );
    addTearDown(container.dispose);
    return container.read(chatProvider.notifier);
  }

  /// Espera a que la generación (y su loop de tools) termine.
  Future<void> waitDone(ChatNotifier notifier) async {
    for (var i = 0; i < 200 && notifier.state.generating; i++) {
      await pumpEventQueue();
    }
    expect(notifier.state.generating, isFalse, reason: 'generación no terminó');
  }

  test('comando @ se ejecuta sin tocar el motor (0 generaciones)', () async {
    final fake = _LoopEngineClient(script: const []);
    final notifier = pumpNotifier(fake);

    await notifier.send('@pantalla');
    await waitDone(notifier);

    expect(fake.rounds, 0);
    final ai = notifier.state.messages.last;
    expect(ai.sender, MessageSender.ai);
    expect(ai.text, contains('Pantalla "com.android.settings" · 7 nodos'));
    expect(notifier.state.messages.first.text, '@pantalla');
  });

  test(
    'tool-calling: modelo llama tap pide confirmacion y re-genera',
    () async {
      final fake = _LoopEngineClient(
        script: const [
          ['{"tool":"tap","selector":"text=Bluetooth"}'],
          ['Listo, lo toque.'],
        ],
      );
      final notifier = pumpNotifier(fake);

      await notifier.send('abre bluetooth');
      await waitDone(notifier);

      expect(notifier.state.pendingTool, 'tap');
      expect(tapCalls, isEmpty);

      await notifier.approvePendingTool();
      await waitDone(notifier);

      expect(tapCalls, [
        [540, 340],
      ]);
      final texts = notifier.state.messages.map((m) => m.text).toList();
      expect(texts, [
        'abre bluetooth',
        '{"tool":"tap","selector":"text=Bluetooth"}',
        'Listo, lo toque.',
      ]);
      expect(fake.prompts[1], contains('abre bluetooth'));
      // El resultado de la herramienta viaja en el HISTORY (turno user) de la
      // segunda ronda, no en el prompt (el prompt crudo es el texto del user).
      expect(
        _historyText(fake.histories[1]),
        contains('Resultado de la herramienta'),
      );
      expect(
        _historyText(fake.histories[1]),
        contains('tap en "Bluetooth" @(540,340)'),
      );
    },
  );

  test('prompt inicial anuncia las herramientas disponibles', () async {
    final fake = _LoopEngineClient(
      script: const [
        ['Hola.'],
      ],
    );
    final notifier = pumpNotifier(fake);

    await notifier.send('saluda');
    await waitDone(notifier);

    // El anuncio de herramientas viaja en el system prompt (context).
    expect(fake.contexts.first, contains('{"tool":"screen"}'));
    expect(fake.contexts.first, contains('{"tool":"tap","selector":"<sel>"}'));
    expect(fake.contexts.first, contains('{"tool":"write"'));
    expect(fake.contexts.first, contains('{"tool":"back"}'));
    expect(fake.contexts.first, contains('{"tool":"notifications"}'));
    expect(fake.contexts.first, contains('{"tool":"reply_notification"'));
    expect(fake.contexts.first, contains('DATO NO CONFIABLE'));
  });

  test(
    'notificación: lee, propone respuesta y solo envía tras aprobación',
    () async {
      final fake = _LoopEngineClient(
        script: const [
          ['{"tool":"notifications"}'],
          [
            '{"tool":"reply_notification","key":"notification-key-1","text":"Sí, en cinco minutos."}',
          ],
          ['Respuesta enviada.'],
        ],
      );
      final notifier = pumpNotifier(fake);

      await notifier.send('responde a Ana que llego en cinco minutos');
      await waitDone(notifier);

      expect(notifier.state.pendingTool, 'reply_notification');
      expect(notificationReplies, isEmpty);
      expect(
        _historyText(fake.histories[1]),
        contains('[notifications untrusted_data=true]'),
      );

      await notifier.approvePendingTool();
      await waitDone(notifier);

      expect(notificationReplies, hasLength(1));
      expect(notificationReplies.single['confirmed'], isTrue);
      expect(notificationReplies.single['key'], 'notification-key-1');
      expect(notificationReplies.single['text'], 'Sí, en cinco minutos.');
      expect(notifier.state.messages.last.text, 'Respuesta enviada.');
    },
  );

  test(
    'respuesta normal sin herramienta → una sola ronda, sin gestos',
    () async {
      final fake = _LoopEngineClient(
        script: const [
          ['Solo respondo texto.'],
        ],
      );
      final notifier = pumpNotifier(fake);

      await notifier.send('¿qué hora es?');
      await waitDone(notifier);

      expect(fake.rounds, 1);
      expect(tapCalls, isEmpty);
      expect(notifier.state.messages.last.text, 'Solo respondo texto.');
      expect(notifier.state.messages.length, 2); // user + ai
    },
  );

  test('herramienta desconocida → error legible llega al prompt de la '
      'siguiente ronda', () async {
    final fake = _LoopEngineClient(
      script: const [
        ['{"tool":"volar"}'],
        ['No puedo volar.'],
      ],
    );
    final notifier = pumpNotifier(fake);

    await notifier.send('vuela');
    await waitDone(notifier);

    expect(
      _historyText(fake.histories[1]),
      contains('Herramienta desconocida "volar"'),
    );
    expect(notifier.state.messages.last.text, 'No puedo volar.');
  });

  test(
    'selector inválido en tool → no rompe el loop, modelo se corrige',
    () async {
      final fake = _LoopEngineClient(
        script: const [
          ['{"tool":"tap","selector":"foo=bar"}'],
          ['Disculpa, no encontré el selector.'],
        ],
      );
      final notifier = pumpNotifier(fake);

      await notifier.send('toca algo');
      await waitDone(notifier);
      expect(notifier.state.pendingTool, 'tap');

      await notifier.approvePendingTool();
      await waitDone(notifier);

      expect(_historyText(fake.histories[1]), contains('Selector inv'));
      expect(tapCalls, isEmpty);
      expect(
        notifier.state.messages.last.text,
        contains('Disculpa, no encontr'),
      );
    },
  );

  test(
    'maximo 2 rondas de herramientas read: la tercera queda visible',
    () async {
      final fake = _LoopEngineClient(
        script: const [
          ['{"tool":"screen"}'],
          ['{"tool":"screen"}'],
          ['{"tool":"screen"}'],
        ],
      );
      final notifier = pumpNotifier(fake);

      await notifier.send('lee pantalla tres veces');
      await waitDone(notifier);

      expect(fake.rounds, 3);
      expect(tapCalls, isEmpty);
      expect(notifier.state.messages.last.text, '{"tool":"screen"}');
    },
  );
}

/// Cliente fake: cada llamada a generateStream consume el siguiente script
/// de respuestas y lo emite completo (sin carreras de sincronización:
/// onListen emite al suscribirse el await-for).
class _LoopEngineClient extends LLMEngineClient {
  _LoopEngineClient({required this.script});

  /// Respuestas por ronda: lista de chunks de texto (sin el stop final).
  final List<List<String>> script;

  /// Prompts recibidos en orden de llamada.
  final List<String> prompts = [];

  /// System prompt (context) recibido en cada ronda.
  final List<String> contexts = [];

  /// Historial (role/content) recibido en cada ronda.
  final List<List<Map<String, String>>> histories = [];

  int rounds = 0;

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
    prompts.add(prompt);
    contexts.add(context ?? '');
    histories.add(history ?? const []);
    final chunks = script[rounds < script.length ? rounds : script.length - 1];
    rounds++;
    late final StreamController<LLMStreamToken> controller;
    controller = StreamController<LLMStreamToken>(
      onListen: () {
        for (final chunk in chunks) {
          controller.add(LLMStreamToken(content: chunk, stop: false));
        }
        controller.add(const LLMStreamToken(content: '', stop: true));
        controller.close();
      },
    );
    return (
      stream: controller.stream,
      client: http.Client(),
      requestId: requestId ?? LLMEngineClient.newRequestId(),
    );
  }
}

/// Notifier fake del motor: ensureReady siempre listo, cliente el fake.
class _LoopEngineNotifier extends RuntimeEngineNotifier {
  _LoopEngineNotifier(this._client) : super(NanoRuntimeApi.instance);

  final _LoopEngineClient _client;

  @override
  LLMEngineClient get client => _client;

  @override
  Future<bool> ensureReady({String? modelPath}) async => true;
}
