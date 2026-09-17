import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/features/automation/engine/execution/action_verifier.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_result.dart';
import 'package:nanoai/features/automation/engine/governance/nano_sensitive_data_policy.dart';
import 'package:nanoai/features/automation/engine/mcp/adaptive_swipe_calculator.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_client_port.dart';
import 'package:nanoai/features/automation/engine/mcp/mobile_automation_executor.dart';
import 'package:nanoai/features/automation/engine/mcp/mobile_automation_mcp_client.dart';
import 'package:nanoai/features/automation/engine/mcp/mobile_gesture_executor.dart';
import 'package:nanoai/features/automation/engine/memory/nano_transcript_ledger.dart';
import 'package:nanoai/features/automation/engine/perception/composite_locator.dart';
import 'package:nanoai/features/automation/engine/perception/nano_selector.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';

class FakeRuntimeApi extends NanoRuntimeApi {
  FakeRuntimeApi({
    this.tapOk = true,
    this.swipeOk = true,
    this.launchOk = true,
    this.statusConnected = true,
  });

  bool tapOk;
  bool swipeOk;
  bool launchOk;
  bool statusConnected;

  @override
  Future<bool> agentTapAt(int x, int y, {int durationMs = 50}) async => tapOk;

  @override
  Future<bool> agentSwipe(int startX, int startY, int endX, int endY, {int durationMs = 300}) async => swipeOk;

  @override
  Future<bool> agentLaunchPackage(String packageName) async => launchOk;

  @override
  Future<Map<String, dynamic>?> agentStatus() async => {'connected': statusConnected};

  @override
  Future<Map<String, dynamic>?> agentDumpAtomicSnapshot({bool includeScreenshot = false}) async => {
        'package': 'com.test.app',
        'nodes': <Map<String, dynamic>>[],
        'windows': <Map<String, dynamic>>[],
      };
}

class FakeAgentExecutor implements AgentExecutor {
  FakeAgentExecutor({this.currentSnapshot});

  NanoSnapshot? currentSnapshot;

  @override
  Future<NanoSnapshot?> snapshot() async => currentSnapshot;

  @override
  Future<ResolveOutcome> resolve(NanoSelector selector) async =>
      const ResolveOutcome(status: ResolveStatus.notFound, candidates: [], reason: 'Not found');

  @override
  Future<AgentExecutionResult> tap(NanoSelector selector) async => const AgentExecutionResult.ok();

  @override
  Future<AgentExecutionResult> setText(NanoSelector selector, String text) async => const AgentExecutionResult.ok();
}

class FakeAgentVerifier implements AgentVerifier {
  FakeAgentVerifier({required this.outcome});

  VerificationOutcome outcome;

  @override
  Future<VerificationOutcome> verify(ActionExpectation expectation, {NanoSnapshot? preSnapshot}) async => outcome;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyNode = NanoNode(
    index: 0,
    depth: 0,
    id: 'com.test:id/btn',
    type: 'android.widget.Button',
    text: 'Confirmar',
    description: '',
    clickable: true,
    editable: false,
    scrollable: false,
    checked: false,
    focusable: true,
    focused: false,
    visible: true,
    enabled: true,
    bounds: NanoBounds(left: 100, top: 200, right: 300, bottom: 250),
  );

  final testSnap = NanoSnapshot(package: 'com.test.app', nodes: [dummyNode]);

  group('Nano Mobile: Separacion estricta EXECUTED != VERIFIED', () {
    test('Tap despachado con exito pero verificacion fallida reporta fallo en MCP y Ledger', () async {
      final fakeApi = FakeRuntimeApi(tapOk: true);
      final fakeExec = FakeAgentExecutor(currentSnapshot: testSnap);
      final fakeVerifier = FakeAgentVerifier(
        outcome: const VerificationOutcome(status: VerificationStatus.notVerified, reason: 'Pantalla no cambio'),
      );
      final ledger = NanoTranscriptLedger();

      final gestureExec = MobileGestureExecutor(
        api: fakeApi,
        executor: fakeExec,
        verifier: fakeVerifier,
        ledger: ledger,
        locator: NanoCompositeLocator(),
      );

      final result = await gestureExec.tap({'text': 'Confirmar'});

      expect(result.status, McpOperationStatus.failed);
      expect(result.structuredContent?['executionOk'], isTrue);
      expect(result.structuredContent?['verificationOk'], isFalse);

      expect(ledger.totalSteps, 1);
      final step = ledger.allSteps.first;
      expect(step.executionOk, isTrue);
      expect(step.verificationOk, isFalse);
      expect(step.succeeded, isFalse);
    });

    test('LaunchApp con intent OK pero app no llega a primer plano es rechazado', () async {
      final fakeApi = FakeRuntimeApi(launchOk: true);
      final fakeExec = FakeAgentExecutor(currentSnapshot: testSnap);
      final fakeVerifier = FakeAgentVerifier(
        outcome: const VerificationOutcome(status: VerificationStatus.wrongPackage, reason: 'Permanecio en launcher'),
      );
      final ledger = NanoTranscriptLedger();

      final autoExec = MobileAutomationExecutor(
        api: fakeApi,
        executor: fakeExec,
        verifier: fakeVerifier,
        ledger: ledger,
        locator: NanoCompositeLocator(),
      );

      final result = await autoExec.launchApp({'packageName': 'com.target.app'});

      expect(result.status, McpOperationStatus.failed);
      expect(result.structuredContent?['executionOk'], isTrue);
      expect(result.structuredContent?['verificationOk'], isFalse);
      expect(ledger.allSteps.first.succeeded, isFalse);
    });
  });

  group('Nano Mobile: AdaptiveSwipeCalculator geometrico sin coordenadas fijas', () {
    test('calcula coordenadas dentro del contenedor scrollable identificado', () {
      const scrollContainer = NanoNode(
        index: 0,
        depth: 0,
        id: 'com.test:id/recycler',
        type: 'androidx.recyclerview.widget.RecyclerView',
        text: '',
        description: '',
        clickable: false,
        editable: false,
        scrollable: true,
        checked: false,
        focusable: true,
        focused: false,
        visible: true,
        enabled: true,
        bounds: NanoBounds(left: 0, top: 400, right: 1080, bottom: 1600),
      );

      final snap = NanoSnapshot(package: 'com.test.app', nodes: [scrollContainer]);
      final coords = AdaptiveSwipeCalculator.calculate(direction: 'up', snapshot: snap);

      expect(coords.startX, 540);
      expect(coords.endX, 540);
      expect(coords.startY, greaterThan(coords.endY));
      expect(coords.startY, lessThanOrEqualTo(1600));
      expect(coords.endY, greaterThanOrEqualTo(400));
    });

    test('se adapta a distintas resoluciones de pantalla', () {
      const tabletNode = NanoNode(
        index: 0,
        depth: 0,
        id: 'root',
        type: 'FrameLayout',
        text: '',
        description: '',
        clickable: false,
        editable: false,
        scrollable: false,
        checked: false,
        focusable: false,
        focused: false,
        visible: true,
        enabled: true,
        bounds: NanoBounds(left: 0, top: 0, right: 1600, bottom: 2560),
      );

      final tabletSnap = NanoSnapshot(package: 'com.tablet.app', nodes: [tabletNode]);
      final tabletCoords = AdaptiveSwipeCalculator.calculate(direction: 'down', snapshot: tabletSnap);

      expect(tabletCoords.startX, 800);
      expect(tabletCoords.endX, 800);
      expect(tabletCoords.startY, lessThan(tabletCoords.endY));
    });
  });

  group('Nano Mobile: NanoSensitiveDataPolicy y Proteccion en Ledger', () {
    test('redacta contrasenas y OTPs para proteger el historial y logs', () {
      const secret = 'ClaveUltraSecreta!2026';
      final redacted = NanoSensitiveDataPolicy.redact(secret);

      expect(redacted, isNot(contains(secret)));
      expect(redacted, contains('[REDACTADO: 22 caracteres]'));
    });

    test('detecta nodos sensibles por id o tipo', () {
      const passNode = NanoNode(
        index: 0,
        depth: 0,
        id: 'com.bank:id/password_input',
        type: 'android.widget.EditText',
        text: '',
        description: 'Contrasena de acceso',
        clickable: true,
        editable: true,
        scrollable: false,
        checked: false,
        focusable: true,
        focused: false,
        visible: true,
        enabled: true,
        bounds: NanoBounds(left: 100, top: 500, right: 900, bottom: 600),
      );

      expect(NanoSensitiveDataPolicy.isSensitiveNode(passNode), isTrue);
    });
  });

  group('Nano Mobile: Handshake real en connect() de MobileAutomationMcpClient', () {
    test('retorna unavailable cuando el servicio de accesibilidad esta desconectado', () async {
      final fakeApi = FakeRuntimeApi(statusConnected: false);
      final client = MobileAutomationMcpClient(api: fakeApi);

      final result = await client.connect();

      expect(result.status, McpOperationStatus.unavailable);
      expect(client.state, McpConnectionState.failed);
      expect(result.metadata['binderActive'], isFalse);
    });

    test('retorna success cuando el servicio esta activo y responde al snapshot', () async {
      final fakeApi = FakeRuntimeApi(statusConnected: true);
      final fakeExec = FakeAgentExecutor(currentSnapshot: testSnap);
      final client = MobileAutomationMcpClient(
        api: fakeApi,
        executor: fakeExec,
      );

      final result = await client.connect();

      expect(result.status, McpOperationStatus.success);
      expect(client.state, McpConnectionState.connected);
      expect(result.metadata['binderActive'], isTrue);
      expect(result.metadata['package'], 'com.test.app');
    });
  });
}
