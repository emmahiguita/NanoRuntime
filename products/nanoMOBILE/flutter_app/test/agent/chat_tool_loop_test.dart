import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nanoai/core/agent/actionability_engine.dart';
import 'package:nanoai/core/agent/agent_executor.dart';
import 'package:nanoai/core/agent/agent_tool_dispatcher.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';

import 'fixtures.dart';

/// Tests del tool-calling en ChatNotifier: comandos `@` interceptados sin
/// motor y loop de herramientas con el LLM (fake engine + canal mockeado).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/agent');

  final tapCalls = <List<int>>[];
  final inputCalls = <String>[];

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
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
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
    expect(ai.text, contains('✅ Pantalla "com.android.settings" · 7 nodos'));
    expect(notifier.state.messages.first.text, '@pantalla');
  });

  test('tool-calling: modelo llama tap → se ejecuta y re-genera con el '
      'resultado', () async {
    final fake = _LoopEngineClient(
      script: const [
        ['{"tool":"tap","selector":"text=Bluetooth"}'],
        ['Listo, lo toqué.'],
      ],
    );
    final notifier = pumpNotifier(fake);

    await notifier.send('abre bluetooth');
    await waitDone(notifier);

    // El gesto se ejecutó de verdad por el canal.
    expect(tapCalls, [
      [540, 340]
    ]);
    // Mensajes: user, llamada JSON visible (trace), respuesta final.
    final texts = notifier.state.messages.map((m) => m.text).toList();
    expect(texts, [
      'abre bluetooth',
      '{"tool":"tap","selector":"text=Bluetooth"}',
      'Listo, lo toqué.',
    ]);
    // El prompt de la ronda 2 incluye el resultado real de la herramienta.
    expect(fake.prompts[1], contains('Resultado de la herramienta'));
    expect(fake.prompts[1], contains('✅ tap en "Bluetooth" @(540,340)'));
  });

  test('prompt inicial anuncia las herramientas disponibles', () async {
    final fake = _LoopEngineClient(
      script: const [
        ['Hola.'],
      ],
    );
    final notifier = pumpNotifier(fake);

    await notifier.send('saluda');
    await waitDone(notifier);

    expect(fake.prompts.first, contains('{"tool":"screen"}'));
    expect(fake.prompts.first, contains('{"tool":"tap","selector":"<sel>"}'));
    expect(fake.prompts.first, contains('{"tool":"write"'));
    expect(fake.prompts.first, contains('{"tool":"back"}'));
  });

  test('respuesta normal sin herramienta → una sola ronda, sin gestos',
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
  });

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

    expect(fake.prompts[1], contains('Herramienta desconocida "volar"'));
    expect(notifier.state.messages.last.text, 'No puedo volar.');
  });

  test('selector inválido en tool → no rompe el loop, modelo se corrige',
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

    expect(fake.prompts[1], contains('Selector inválido "foo=bar"'));
    expect(tapCalls, isEmpty);
    expect(notifier.state.messages.last.text, 'Disculpa, no encontré el selector.');
  });

  test('máximo 2 rondas de herramientas: la tercera llamada se muestra tal '
      'cual, sin ejecutar', () async {
    final fake = _LoopEngineClient(
      script: const [
        ['{"tool":"tap","selector":"text=Bluetooth"}'],
        ['{"tool":"tap","selector":"text=Bluetooth"}'],
        ['{"tool":"tap","selector":"text=Bluetooth"}'],
      ],
    );
    final notifier = pumpNotifier(fake);

    await notifier.send('toca tres veces');
    await waitDone(notifier);

    // 3 generaciones (2 tools + 1 final sin ejecutar) y solo 2 gestos.
    expect(fake.rounds, 3);
    expect(tapCalls.length, 2);
    expect(
      notifier.state.messages.last.text,
      '{"tool":"tap","selector":"text=Bluetooth"}',
    );
  });
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

  int rounds = 0;

  @override
  ({Stream<LLMStreamToken> stream, http.Client client}) generateStream({
    required String prompt,
    double temperature = 0.7,
    double topP = 0.9,
    int maxTokens = 256,
  }) {
    prompts.add(prompt);
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
    return (stream: controller.stream, client: http.Client());
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
