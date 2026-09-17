import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/memory/nano_transcript_ledger.dart';
import 'package:nanoai/features/automation/engine/perception/composite_locator.dart';
import 'package:nanoai/features/automation/engine/perception/nano_selector.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/mcp/mobile_automation_mcp_client.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_client_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nano Mobile Automation: NanoTranscriptLedger & StepSummarizer', () {
    test('registra pasos cronológicos y calcula éxito correctamente', () {
      final ledger = NanoTranscriptLedger(maxOperativeWindow: 2);

      final s1 = ledger.recordStep(
        actionName: 'launch_app',
        actionDescription: 'Lanzar Ajustes',
        executionOk: true,
        verificationOk: true,
      );

      expect(s1.stepIndex, 1);
      expect(s1.succeeded, isTrue);
      expect(ledger.totalSteps, 1);
      expect(ledger.allSteps.first.actionName, 'launch_app');
    });

    test('aplica poda estricta de snapshots pesados fuera de la ventana operativa', () {
      final ledger = NanoTranscriptLedger(maxOperativeWindow: 2);

      final dummySnap = NanoSnapshot(
        package: 'com.android.settings',
        nodes: const [
          NanoNode(
            index: 0,
            depth: 0,
            id: 'btn',
            type: 'android.widget.Button',
            text: 'Batería',
            description: '',
            clickable: true,
            editable: false,
            scrollable: false,
            checked: false,
            focusable: true,
            focused: false,
            visible: true,
            enabled: true,
            bounds: NanoBounds(left: 10, top: 10, right: 100, bottom: 50),
          ),
        ],
      );

      final p1 = ledger.recordStep(
        actionName: 'step1',
        actionDescription: 'Acción 1',
        executionOk: true,
        verificationOk: true,
        postSnapshot: dummySnap,
      );

      final p2 = ledger.recordStep(
        actionName: 'step2',
        actionDescription: 'Acción 2',
        executionOk: true,
        verificationOk: true,
        postSnapshot: dummySnap,
      );

      expect(p1.isPruned, isFalse);
      expect(p2.isPruned, isFalse);

      final p3 = ledger.recordStep(
        actionName: 'step3',
        actionDescription: 'Acción 3',
        executionOk: true,
        verificationOk: true,
        postSnapshot: dummySnap,
      );

      expect(ledger.totalSteps, 3);
      expect(p1.isPruned, isTrue);
      expect(p1.snapshot, isNull);
      expect(p2.isPruned, isFalse);
      expect(p3.isPruned, isFalse);
      expect(ledger.operativeWindow.length, 2);
    });

    test('buildContextSummary produce un sumario textual estructurado sin bloating', () {
      final ledger = NanoTranscriptLedger(maxOperativeWindow: 2);

      ledger.recordStep(
        actionName: 'launch_app',
        actionDescription: 'com.android.settings',
        executionOk: true,
        verificationOk: true,
        targetLabel: 'Ajustes',
      );

      ledger.recordStep(
        actionName: 'tap',
        actionDescription: 'Pulsar Batería',
        executionOk: true,
        verificationOk: false,
        targetLabel: 'Batería',
      );

      final summary = ledger.buildContextSummary();
      expect(summary, contains('Historial Estructurado'));
      expect(summary, contains('[✓] Paso 1 (launch_app)'));
      expect(summary, contains('[✗] Paso 2 (tap)'));
    });
  });

  group('Nano Mobile Automation: NanoCompositeLocator (Dynamic-First)', () {
    late NanoSnapshot testSnapshot;

    setUp(() {
      testSnapshot = NanoSnapshot(
        package: 'com.whatsapp',
        nodes: const [
          NanoNode(
            index: 0,
            depth: 0,
            id: 'com.whatsapp:id/send',
            type: 'android.widget.ImageButton',
            text: '',
            description: 'Enviar',
            clickable: true,
            editable: false,
            scrollable: false,
            checked: false,
            focusable: true,
            focused: false,
            visible: true,
            enabled: true,
            bounds: NanoBounds(left: 900, top: 1800, right: 1000, bottom: 1900),
          ),
          NanoNode(
            index: 1,
            depth: 0,
            id: 'com.whatsapp:id/entry',
            type: 'android.widget.EditText',
            text: 'Escribe un mensaje',
            description: '',
            clickable: true,
            editable: true,
            scrollable: false,
            checked: false,
            focusable: true,
            focused: false,
            visible: true,
            enabled: true,
            bounds: NanoBounds(left: 100, top: 1800, right: 880, bottom: 1900),
          ),
        ],
      );
    });

    test('Prioridad 1: Resuelve por ResourceId unívoco dinámico', () {
      final locator = NanoCompositeLocator();
      final res = locator.locate(
        selector: const NanoSelector(resourceId: 'com.whatsapp:id/send'),
        snapshot: testSnapshot,
      );

      expect(res.isResolved, isTrue);
      expect(res.strategy, LocatorStrategy.dynamicResourceId);
      expect(res.tapCoordinates, (950, 1850));
      expect(res.confidence, 1.0);
    });

    test('Prioridad 2: Resuelve por semántica de texto cuando no hay ID', () {
      final locator = NanoCompositeLocator();
      final res = locator.locate(
        selector: const NanoSelector(text: 'Escribe un mensaje'),
        snapshot: testSnapshot,
      );

      expect(res.isResolved, isTrue);
      expect(res.strategy, LocatorStrategy.semanticText);
      expect(res.tapCoordinates, (490, 1850));
    });

    test('Prioridad 4: Resuelve por OCR visual si falla accesibilidad pero hay detección OCR', () {
      final locator = NanoCompositeLocator();
      const ocrList = [
        VisualOcrElement(
          text: 'Buscar chat',
          bounds: NanoBounds(left: 50, top: 120, right: 400, bottom: 180),
        ),
      ];

      final res = locator.locate(
        selector: const NanoSelector(text: 'Buscar chat'),
        snapshot: testSnapshot,
        ocrElements: ocrList,
      );

      expect(res.isResolved, isTrue);
      expect(res.strategy, LocatorStrategy.visualOcr);
      expect(res.tapCoordinates, (225, 150));
      expect(res.confidence, 0.75);
    });

    test('Prioridad 5: Fallback a coordenadas explícitas cuando no hay coincidencia dinámica ni visual', () {
      final locator = NanoCompositeLocator();
      final res = locator.locate(
        selector: const NanoSelector(text: 'Elemento Inexistente'),
        snapshot: testSnapshot,
        fallbackCoordinates: (300, 600),
      );

      expect(res.isResolved, isTrue);
      expect(res.strategy, LocatorStrategy.coordinateFallback);
      expect(res.tapCoordinates, (300, 600));
      expect(res.confidence, 0.5);
    });
  });

  group('Nano Mobile Automation: MobileAutomationMcpClient', () {
    test('expone las herramientas MCP estandarizadas con anotaciones de idempotencia', () async {
      final client = MobileAutomationMcpClient();
      expect(client.descriptor.id, 'nano.mobile');

      final tools = await client.listTools();
      final names = tools.map((t) => t.name).toList();

      expect(names, contains('observe'));
      expect(names, contains('tap'));
      expect(names, contains('type'));
      expect(names, contains('swipe'));
      expect(names, contains('press_key'));
      expect(names, contains('launch_app'));
      expect(names, contains('verify'));
      expect(names, contains('get_ledger_history'));

      // Invariante Nano: observe y verify son readOnly & idempotent
      final observeTool = tools.firstWhere((t) => t.name == 'observe');
      expect(observeTool.annotations.readOnlyHint, isTrue);
      expect(observeTool.annotations.idempotentHint, isTrue);

      // tap es mutante (no idempotent, no read-only)
      final tapTool = tools.firstWhere((t) => t.name == 'tap');
      expect(tapTool.annotations.readOnlyHint, isFalse);
      expect(tapTool.annotations.idempotentHint, isFalse);
    });

    test('get_ledger_history reporta el historial correctamente', () async {
      final ledger = NanoTranscriptLedger();
      ledger.recordStep(
        actionName: 'test_action',
        actionDescription: 'Prueba unitaria',
        executionOk: true,
        verificationOk: true,
      );

      final client = MobileAutomationMcpClient(ledger: ledger);
      final res = await client.callTool(
        const McpToolCall(
          serverId: 'nano.mobile',
          toolName: 'get_ledger_history',
        ),
      );

      expect(res.success, isTrue);
      expect(res.structuredContent?['totalSteps'], 1);
      expect(res.message, contains('test_action'));
    });
  });
}
