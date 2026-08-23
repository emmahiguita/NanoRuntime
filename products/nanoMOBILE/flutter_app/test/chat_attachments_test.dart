import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nanoai/features/automation/engine/perception/actionability_engine.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/chat/presentation/screens/chat_screen.dart';

/// Tests del core del chat: adjuntos reales (chips + inyección al prompt
/// del motor) y ruptura del deadlock de envío con motor apagado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const agentChannel = MethodChannel('com.nanoai/agent');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Mock del canal de agente: los tool-calls (`{"tool":"screen"}`) se
    // ejecutan sin Android real (patrón de test/agent/chat_tool_loop_test.dart).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(agentChannel, (call) async {
          switch (call.method) {
            case 'dumpSnapshot':
              // Snapshot NO vacío: con nodes vacíos el executor reintenta con
              // delays reales que la zona FakeAsync de los tests nunca avanza.
              return {
                'package': 'com.android.settings',
                'nodes': [
                  {
                    'id': 'android:id/content',
                    'type': 'android.widget.FrameLayout',
                    'text': '',
                    'desc': '',
                    'clickable': false,
                    'editable': false,
                    'scrollable': false,
                    'checked': false,
                    'focusable': false,
                    'focused': false,
                    'visible': true,
                    'enabled': true,
                    'bounds': [0, 0, 1080, 2400],
                    'depth': 0,
                  },
                ],
              };
            case 'tapAt':
              return true;
            case 'inputText':
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
        .setMockMethodCallHandler(agentChannel, null);
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: screen,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('ChatNotifier — adjuntos', () {
    late ProviderContainer container;

    tearDown(() => container.dispose());

    /// Dispatcher con estabilidad instantánea: en la zona FakeAsync de los
    /// tests un wait real nunca avanza y la generación colgaría.
    final dispatcher = AgentToolDispatcher(
      executor: NanoAgentExecutor(
        stability: const StabilityChecker(wait: Duration.zero),
      ),
    );

    ChatNotifier pumpNotifier(_FakeEngineClient fake) {
      container = ProviderContainer(
        overrides: [
          chatProvider.overrideWith(
            (ref) => ChatNotifier.fixed(
              ref,
              const ChatState(engineOnline: true),
              toolDispatcher: dispatcher,
            ),
          ),
          runtimeEngineProvider.overrideWith(
            (ref) => _FakeEngineNotifier(fake),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(chatProvider.notifier);
    }

    Future<void> waitDone(ChatNotifier notifier) async {
      for (var i = 0; i < 200 && notifier.state.generating; i++) {
        await pumpEventQueue();
      }
      expect(
        notifier.state.generating,
        isFalse,
        reason: 'generación no terminó',
      );
    }

    test('addAttachment agrega; duplicado por nombre reemplaza', () {
      final notifier = pumpNotifier(_FakeEngineClient(script: const []));

      notifier.addAttachment(
        const ChatAttachment(name: 'notas.md', content: 'hola'),
      );
      notifier.addAttachment(
        const ChatAttachment(name: 'log.txt', content: 'error 1'),
      );
      notifier.addAttachment(
        const ChatAttachment(name: 'notas.md', content: 'hola v2'),
      );

      expect(notifier.state.attachments, hasLength(2));
      final notas = notifier.state.attachments.singleWhere(
        (a) => a.name == 'notas.md',
      );
      expect(notas.content, 'hola v2');
    });

    test('máximo 3 adjuntos: el cuarto desplaza al más antiguo', () {
      final notifier = pumpNotifier(_FakeEngineClient(script: const []));

      for (final name in ['a.txt', 'b.txt', 'c.txt', 'd.txt']) {
        notifier.addAttachment(ChatAttachment(name: name, content: name));
      }

      expect(notifier.state.attachments, hasLength(3));
      expect(notifier.state.attachments.first.name, 'b.txt');
      expect(notifier.state.attachments.last.name, 'd.txt');
    });

    test('removeAttachment quita por nombre', () {
      final notifier = pumpNotifier(_FakeEngineClient(script: const []));

      notifier.addAttachment(const ChatAttachment(name: 'a.txt', content: '1'));
      notifier.removeAttachment('a.txt');

      expect(notifier.state.attachments, isEmpty);
    });

    test(
      'send inyecta contenido real al prompt y consume los adjuntos',
      () async {
        final fake = _FakeEngineClient(
          script: const [
            ['Resumen listo.'],
          ],
        );
        final notifier = pumpNotifier(fake);

        notifier.addAttachment(
          const ChatAttachment(name: 'notas.md', content: 'Datos reales 123'),
        );
        await notifier.send('resume esto');
        await waitDone(notifier);

        // El motor recibió el contenido REAL del adjunto en el prompt.
        expect(fake.prompts.single, contains('[Adjunto: notas.md]'));
        expect(fake.prompts.single, contains('Datos reales 123'));
        expect(fake.prompts.single, contains('[Fin de adjunto]'));
        expect(fake.prompts.single, contains('resume esto'));
        // Los adjuntos se consumen: no se reenvían en el siguiente mensaje.
        expect(notifier.state.attachments, isEmpty);
      },
    );

    test('adjunto no se repite en rondas de herramienta', () async {
      final fake = _FakeEngineClient(
        script: const [
          ['{"tool":"screen"}'],
          ['Respuesta final.'],
        ],
      );
      final notifier = pumpNotifier(fake);

      notifier.addAttachment(
        const ChatAttachment(name: 'x.txt', content: 'contenido único'),
      );
      await notifier.send('analiza');
      await waitDone(notifier);

      expect(fake.prompts, hasLength(2));
      expect(fake.prompts.first, contains('[Adjunto: x.txt]'));
      expect(fake.prompts.last, isNot(contains('[Adjunto: x.txt]')));
    });

    test('mensaje user persiste attachmentNames sin contenido', () async {
      final fake = _FakeEngineClient(
        script: const [
          ['ok'],
        ],
      );
      final notifier = pumpNotifier(fake);

      notifier.addAttachment(
        const ChatAttachment(name: 'secreto.txt', content: 'contenido'),
      );
      await notifier.send('mira el adjunto');
      await waitDone(notifier);

      final userMsg = notifier.state.messages.first;
      expect(userMsg.attachmentNames, ['secreto.txt']);

      // Round-trip JSON: nombres sobreviven, contenido nunca se persiste.
      final restored = ChatMessage.fromJson(userMsg.toJson());
      expect(restored.attachmentNames, ['secreto.txt']);
      expect(userMsg.toJson().containsKey('attachmentContent'), isFalse);
      expect(notifier.state.attachments, isEmpty);
    });
  });

  group('ChatNotifier — deadlock de envío', () {
    late ProviderContainer container;

    tearDown(() => container.dispose());

    test('refreshEngine arranca el motor con el modelo instalado', () async {
      final fake = _FakeEngineClient(script: const []);
      final engine = _FakeEngineNotifier(fake);
      container = ProviderContainer(
        overrides: [
          chatProvider.overrideWith(
            (ref) => ChatNotifier.fixed(
              ref,
              const ChatState(
                activeModel: 'Qwen',
                activeModelPath: '/storage/qwen.gguf',
              ),
            ),
          ),
          runtimeEngineProvider.overrideWith((ref) => engine),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(chatProvider.notifier);

      await notifier.refreshEngine();

      expect(engine.ensureReadyCalls, ['/storage/qwen.gguf']);
    });
  });

  group('ChatScreen — chips y composer', () {
    testWidgets('composer habilitado con modelo instalado y motor apagado', (
      tester,
    ) async {
      const state = ChatState(
        engineOnline: false,
        activeModel: 'Qwen 2.5 1.5B',
        activeModelPath: '/storage/qwen.gguf',
      );

      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith((ref) => ChatNotifier.fixed(ref, state)),
        ],
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isTrue);
      expect(find.textContaining('Escribe un mensaje'), findsOneWidget);
    });

    testWidgets('composer bloqueado sin modelo y sin motor', (tester) async {
      const state = ChatState(engineOnline: false);

      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith((ref) => ChatNotifier.fixed(ref, state)),
        ],
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('chips de adjunto visibles y quitar los elimina', (
      tester,
    ) async {
      const state = ChatState(
        engineOnline: true,
        attachments: [
          ChatAttachment(name: 'notas.md', content: 'contenido'),
          ChatAttachment(name: 'log.txt', content: 'otro'),
        ],
      );

      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith((ref) => ChatNotifier.fixed(ref, state)),
        ],
      );

      expect(find.text('notas.md'), findsOneWidget);
      expect(find.text('log.txt'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();

      expect(find.text('notas.md'), findsNothing);
      expect(find.text('log.txt'), findsOneWidget);
    });

    testWidgets('mensaje user con adjuntos muestra los nombres en la burbuja', (
      tester,
    ) async {
      final state = ChatState(
        engineOnline: true,
        messages: [
          ChatMessage(
            id: '1',
            sender: MessageSender.user,
            text: 'mira esto',
            timestamp: DateTime(2026, 8, 14, 9, 0),
            attachmentNames: const ['notas.md', 'log.txt'],
          ),
        ],
      );

      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith((ref) => ChatNotifier.fixed(ref, state)),
        ],
      );

      expect(find.text('mira esto'), findsOneWidget);
      expect(find.text('notas.md'), findsOneWidget);
      expect(find.text('log.txt'), findsOneWidget);
    });

    testWidgets('adjuntar → enviar llega al motor con el contenido real', (
      tester,
    ) async {
      final fake = _FakeEngineClient(
        script: const [
          ['listo'],
        ],
      );
      final engine = _FakeEngineNotifier(fake);
      const state = ChatState(
        engineOnline: true,
        attachments: [
          ChatAttachment(name: 'datos.txt', content: '42 es la respuesta'),
        ],
      );

      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith((ref) => ChatNotifier.fixed(ref, state)),
          runtimeEngineProvider.overrideWith((ref) => engine),
        ],
      );

      await tester.enterText(find.byType(TextField), 'analiza los datos');
      // El composer habilita el envío con texto: un frame para que _hasText
      // se refleje en el InkWell antes del tap.
      await tester.pump();
      await tester.tap(find.byTooltip('Enviar'));
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(fake.prompts.single, contains('42 es la respuesta'));
      expect(fake.prompts.single, contains('analiza los datos'));
      // El chip del composer se consumió tras el envío; el nombre persiste
      // en la burbuja del mensaje user (attachmentNames), no como adjunto
      // pendiente.
      expect(find.text('datos.txt'), findsOneWidget);
    });
  });
}

/// Cliente fake: emite el script completo al suscribirse (patrón de
/// `test/agent/chat_tool_loop_test.dart`).
class _FakeEngineClient extends LLMEngineClient {
  _FakeEngineClient({required this.script});

  final List<List<String>> script;
  final List<String> prompts = [];
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

/// Notifier fake del motor: registra ensureReady y sirve el cliente fake.
class _FakeEngineNotifier extends RuntimeEngineNotifier {
  _FakeEngineNotifier(this._client) : super(NanoRuntimeApi.instance);

  final _FakeEngineClient _client;
  final List<String?> ensureReadyCalls = [];

  @override
  LLMEngineClient get client => _client;

  @override
  Future<bool> ensureReady({String? modelPath}) async {
    ensureReadyCalls.add(modelPath);
    return true;
  }
}
