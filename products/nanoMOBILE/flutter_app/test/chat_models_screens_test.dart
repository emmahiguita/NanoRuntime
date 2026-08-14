import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/providers/dashboard_provider.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/features/chat/presentation/screens/chat_screen.dart';
import 'package:nanoai/features/models/application/models_notifier.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/application/models_state.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import 'package:nanoai/features/models/presentation/screens/models_screen.dart';

/// Pruebas de las pantallas Chat y Modelos (identidad visual de Inicio).
///
/// Los datos vienen SIEMPRE de los providers reales (`ChatNotifier.fixed` /
/// `ModelsNotifier.fixed`). No se inyecta ningún valor ficticio en la UI:
/// lo que el estado no expone, la pantalla no lo muestra.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size physicalSize = const Size(1080, 1920),
    double devicePixelRatio = 3.0,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  LocalModel model({
    String id = 'qwen-1.5b',
    String name = 'Qwen 2.5 1.5B',
    String quant = 'Q4_K_M',
    double sizeGb = 1.2,
    double ramGb = 2.0,
    ModelDownloadState downloadState = ModelDownloadState.notInstalled,
    double progress = 0,
    String? error,
    bool active = false,
  }) {
    return LocalModel(
      id: id,
      name: name,
      params: '1.5B',
      quant: quant,
      sizeGb: sizeGb,
      ramGb: ramGb,
      fileName: 'qwen-1.5b-$quant.gguf',
      description: 'Multilingüe, ligero',
      template: ChatTemplate.qwen,
      downloadState: downloadState,
      progress: progress,
      url: 'https://example.invalid/$id.gguf',
      sha256: 'e3b0c44298fc1c149afbf4c8996fb924',
      error: error,
      active: active,
      loading: false,
    );
  }

  group('ChatScreen', () {
    testWidgets('muestra mensajes de usuario y asistente', (tester) async {
      final now = DateTime(2026, 8, 13, 10, 30);
      final chatState = ChatState(
        engineOnline: true,
        messages: [
          ChatMessage(
            id: '1',
            sender: MessageSender.user,
            text: 'Hola NanoAI',
            timestamp: now,
          ),
          ChatMessage(
            id: '2',
            sender: MessageSender.ai,
            text: 'Hola, ¿en qué te ayudo?',
            timestamp: now.add(const Duration(minutes: 1)),
          ),
        ],
      );

      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith(
            (ref) => ChatNotifier.fixed(ref, chatState),
          ),
        ],
      );

      expect(find.text('Hola NanoAI'), findsOneWidget);
      expect(find.text('Hola, ¿en qué te ayudo?'), findsOneWidget);
      // Etiqueta del modelo: 'Sin modelo' se presenta como 'modelo local'.
      expect(find.textContaining('modelo local'), findsWidgets);
    });

    testWidgets('motor detenido: badge DETENIDO y compositor desactivado', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith(
            (ref) =>
                ChatNotifier.fixed(ref, const ChatState(engineOnline: false)),
          ),
        ],
      );

      expect(find.text('DETENIDO'), findsOneWidget);
      expect(find.text('El motor local está detenido'), findsOneWidget);
      // Botón de enviar desactivado sin motor.
      final sendButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded),
      );
      expect(sendButton.onPressed, isNull);
    });

    testWidgets('motor conectado: badge LOCAL y compositor activo', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith(
            (ref) =>
                ChatNotifier.fixed(ref, const ChatState(engineOnline: true)),
          ),
        ],
      );

      expect(find.text('LOCAL'), findsOneWidget);
      expect(find.text('¿En qué puedo ayudarte?'), findsOneWidget);
      final sendButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded),
      );
      expect(sendButton.onPressed, isNotNull);
    });

    testWidgets('enviar inserta el mensaje del usuario y detener para la '
        'generación', (tester) async {
      final fakeClient = _FakeEngineClient();

      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith(
            (ref) =>
                ChatNotifier.fixed(ref, const ChatState(engineOnline: true)),
          ),
          runtimeEngineProvider.overrideWith(
            (ref) => _FakeEngineNotifier(fakeClient),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'Cuéntame algo');
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // El mensaje del usuario se insertó y la generación está en curso
      // (burbuja streaming + botón stop).
      expect(find.text('Cuéntame algo'), findsOneWidget);
      expect(
        find.widgetWithIcon(IconButton, Icons.stop_rounded),
        findsOneWidget,
      );

      // Token parcial visible en la burbuja streaming.
      fakeClient.emit(const LLMStreamToken(content: 'Claro,', stop: false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Claro,'), findsOneWidget);

      // Detener con el botón stop real (notifier.stop).
      await tester.tap(find.widgetWithIcon(IconButton, Icons.stop_rounded));
      await tester.pump();
      expect(find.widgetWithIcon(IconButton, Icons.stop_rounded), findsNothing);

      await fakeClient.close();
    });

    testWidgets('320x568 sin overflow', (tester) async {
      await pumpScreen(
        tester,
        const ChatScreen(),
        physicalSize: const Size(960, 1704),
        overrides: [
          chatProvider.overrideWith(
            (ref) => ChatNotifier.fixed(
              ref,
              ChatState(
                engineOnline: true,
                messages: List.generate(
                  12,
                  (index) => ChatMessage(
                    id: '$index',
                    sender: index.isEven
                        ? MessageSender.user
                        : MessageSender.ai,
                    text:
                        'Mensaje $index con algo de contenido para medir el '
                        'ancho de la burbuja en pantalla pequeña.',
                    timestamp: DateTime(2026, 8, 13, 10, index),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

      expect(tester.takeException(), isNull, reason: 'sin overflow a 320x568');
      expect(find.text('LOCAL'), findsOneWidget);
    });

    testWidgets('estado vacío no muestra mensajes simulados', (tester) async {
      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith(
            (ref) =>
                ChatNotifier.fixed(ref, const ChatState(engineOnline: true)),
          ),
        ],
      );

      // Sin burbujas: el texto de sugerencia existe, pero ningún mensaje.
      expect(find.text('Hola'), findsNothing);
      expect(find.textContaining('¿En qué puedo ayudarte?'), findsOneWidget);
    });

    testWidgets('sin barra de navegación inferior', (tester) async {
      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith(
            (ref) =>
                ChatNotifier.fixed(ref, const ChatState(engineOnline: true)),
          ),
        ],
      );

      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('micrófono no disponible: snackbar honesto, no crash', (
      tester,
    ) async {
      // Mock del canal real del plugin: initialize responde `false`
      // (reconocimiento no disponible en este device).
      const micChannel = MethodChannel('plugin.csdcorp.com/speech_to_text');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        micChannel,
        (call) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(micChannel, null),
      );

      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith(
            (ref) =>
                ChatNotifier.fixed(ref, const ChatState(engineOnline: true)),
          ),
        ],
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.mic_none_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('Reconocimiento de voz no disponible'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Expirar el SnackBar para no dejar timers pendientes.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('adjuntar con error del picker: snackbar honesto, no crash', (
      tester,
    ) async {
      // Mock del canal real del plugin: el picker falla con PlatformException
      // (ej. SAF denegado). El error real se reporta, no se inventa texto.
      const pickerChannel = MethodChannel(
        'miguelruivo.flutter.plugins.filepicker',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pickerChannel,
        (call) async => throw PlatformException(code: 'SAF_DENIED'),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(pickerChannel, null),
      );

      await pumpScreen(
        tester,
        const ChatScreen(),
        overrides: [
          chatProvider.overrideWith(
            (ref) =>
                ChatNotifier.fixed(ref, const ChatState(engineOnline: true)),
          ),
        ],
      );

      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.attach_file_rounded),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('No se pudo leer el archivo'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('ModelsScreen', () {
    testWidgets('modelo activo muestra ACTIVO y check', (tester) async {
      final state = ModelsState(
        models: [
          model(downloadState: ModelDownloadState.installed, active: true),
        ],
      );

      await pumpScreen(
        tester,
        const ModelsScreen(),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, state),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(ref, const DashboardState()),
          ),
        ],
      );

      expect(find.text('ACTIVO'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('1 instalados · 1.2 GB'), findsOneWidget);
    });

    testWidgets('modelo instalado muestra INSTALADO y botón Usar', (
      tester,
    ) async {
      final state = ModelsState(
        models: [
          model(downloadState: ModelDownloadState.installed, active: false),
        ],
      );

      await pumpScreen(
        tester,
        const ModelsScreen(),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, state),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(ref, const DashboardState()),
          ),
        ],
      );

      expect(find.text('INSTALADO'), findsOneWidget);
      expect(find.text('Usar'), findsOneWidget);
    });

    testWidgets('modelo disponible muestra DISPONIBLE y Descargar', (
      tester,
    ) async {
      final state = ModelsState(
        models: [model(downloadState: ModelDownloadState.notInstalled)],
      );

      await pumpScreen(
        tester,
        const ModelsScreen(),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, state),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(ref, const DashboardState()),
          ),
        ],
      );

      expect(find.text('DISPONIBLE'), findsOneWidget);
      expect(find.text('Descargar'), findsOneWidget);
      // Sin modelos instalados: resumen sin dato inventado.
      expect(find.text('0 instalados · —'), findsOneWidget);
    });

    testWidgets('descarga en curso muestra progreso y cancelación', (
      tester,
    ) async {
      final state = ModelsState(
        models: [
          model(downloadState: ModelDownloadState.downloading, progress: 0.4),
        ],
      );

      await pumpScreen(
        tester,
        const ModelsScreen(),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, state),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(ref, const DashboardState()),
          ),
        ],
      );

      expect(find.text('DESCARGANDO'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('error de descarga muestra ERROR y Reintentar', (tester) async {
      final state = ModelsState(
        models: [
          model(
            downloadState: ModelDownloadState.failed,
            error: 'SHA256 no coincide',
          ),
        ],
      );

      await pumpScreen(
        tester,
        const ModelsScreen(),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, state),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(ref, const DashboardState()),
          ),
        ],
      );

      expect(find.text('ERROR'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('SHA256 no coincide'), findsOneWidget);
    });

    testWidgets('catálogo vacío no muestra modelos simulados', (tester) async {
      await pumpScreen(
        tester,
        const ModelsScreen(),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, const ModelsState()),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(ref, const DashboardState()),
          ),
        ],
      );

      expect(find.text('0 instalados · —'), findsOneWidget);
      expect(find.text('Descargar'), findsNothing);
      expect(find.text('Usar'), findsNothing);
      expect(find.text('Espacio usado por modelos: —'), findsOneWidget);
    });

    testWidgets('320x568 sin overflow con varios modelos', (tester) async {
      final state = ModelsState(
        models: [
          model(downloadState: ModelDownloadState.installed, active: true),
          model(
            id: 'deepseek-1.5b',
            name: 'DeepSeek-R1 1.5B',
            quant: 'Q8_0',
            sizeGb: 1.7,
            downloadState: ModelDownloadState.downloading,
            progress: 0.6,
          ),
          model(
            id: 'llama-3b',
            name: 'Llama 3.2 3B',
            quant: 'Q4_K_M',
            sizeGb: 2.1,
            downloadState: ModelDownloadState.failed,
            error: 'Conexión interrumpida',
          ),
        ],
      );

      await pumpScreen(
        tester,
        const ModelsScreen(),
        physicalSize: const Size(960, 1704),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, state),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(ref, const DashboardState()),
          ),
        ],
      );

      expect(tester.takeException(), isNull, reason: 'sin overflow a 320x568');
      expect(find.text('ACTIVO'), findsOneWidget);

      // La barra de escaneo del storage ocupa espacio: la segunda y tercera
      // card quedan fuera del viewport en 320x568. Hacer scroll (mismo
      // patrón que ya usaba para la tercera card).
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(find.text('DESCARGANDO'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);
    });

    testWidgets('modelo no compatible por RAM real: chip y sin descarga', (
      tester,
    ) async {
      final state = ModelsState(
        models: [
          // Requiere 7 GB de RAM, el device reporta 3.9 GB libres: NO COMPATIBLE.
          model(
            id: 'big-7b',
            name: 'Big Model 7B',
            ramGb: 7.0,
            downloadState: ModelDownloadState.notInstalled,
          ),
          // El instalado se queda INSTALADO aunque la RAM libre baje.
          model(
            id: 'big-installed',
            name: 'Big Model Instalado',
            ramGb: 7.0,
            downloadState: ModelDownloadState.installed,
          ),
        ],
      );

      await pumpScreen(
        tester,
        const ModelsScreen(),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, state),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(
              ref,
              const DashboardState(ramTotalGb: 8.0, ramFreeGb: 3.9),
            ),
          ),
        ],
      );

      expect(find.text('NO COMPATIBLE'), findsOneWidget);
      expect(find.text('INSTALADO'), findsOneWidget);
      // El requisito y la RAM libre real del dashboard, sin datos inventados.
      expect(
        find.textContaining('Requiere 7 GB de RAM libre (hay 3.9)'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
      // El incompatible no ofrece descarga; el instalado sí 'Usar'.
      expect(find.text('Descargar'), findsNothing);
      expect(find.text('Usar'), findsOneWidget);
    });

    testWidgets('sin datos de RAM del dashboard: no se marca incompatible', (
      tester,
    ) async {
      final state = ModelsState(
        models: [
          model(ramGb: 7.0, downloadState: ModelDownloadState.notInstalled),
        ],
      );

      await pumpScreen(
        tester,
        const ModelsScreen(),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, state),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(ref, const DashboardState()),
          ),
        ],
      );

      // ramTotalGb == 0: sin medición real, sin juicio — se queda DISPONIBLE.
      expect(find.text('DISPONIBLE'), findsOneWidget);
      expect(find.text('NO COMPATIBLE'), findsNothing);
      expect(find.text('Descargar'), findsOneWidget);
    });

    testWidgets('pie con almacenamiento real del device', (tester) async {
      final state = ModelsState(
        models: [
          model(downloadState: ModelDownloadState.installed, sizeGb: 1.2),
        ],
      );

      await pumpScreen(
        tester,
        const ModelsScreen(),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, state),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(
              ref,
              const DashboardState(storageTotalGb: 256.0, storageFreeGb: 209.0),
            ),
          ),
        ],
      );

      expect(find.textContaining('1.2 GB usados por modelos'), findsOneWidget);
      expect(find.textContaining('209 GB libres'), findsOneWidget);
      // La barra usa la proporción real usado/(usado+libre).
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('sin barra de navegación inferior', (tester) async {
      await pumpScreen(
        tester,
        const ModelsScreen(),
        overrides: [
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, const ModelsState()),
          ),
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(ref, const DashboardState()),
          ),
        ],
      );

      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });
  });
}

/// Cliente de inferencia fake: stream de tokens controlado por el test.
class _FakeEngineClient extends LLMEngineClient {
  final StreamController<LLMStreamToken> _controller =
      StreamController<LLMStreamToken>();

  void emit(LLMStreamToken token) => _controller.add(token);

  Future<void> close() => _controller.close();

  @override
  ({Stream<LLMStreamToken> stream, http.Client client}) generateStream({
    required String prompt,
    double temperature = 0.7,
    double topP = 0.9,
    int maxTokens = 256,
  }) {
    return (stream: _controller.stream, client: http.Client());
  }
}

/// Notifier fake del motor: `ensureReady` siempre listo y el cliente es el
/// fake. Así `ChatNotifier.send` llega a `_generate` sin tocar canales
/// nativos ni red real.
class _FakeEngineNotifier extends RuntimeEngineNotifier {
  _FakeEngineNotifier(this._fakeClient) : super(NanoRuntimeApi.instance);

  final _FakeEngineClient _fakeClient;

  @override
  LLMEngineClient get client => _fakeClient;

  @override
  Future<bool> ensureReady({String? modelPath}) async => true;
}
