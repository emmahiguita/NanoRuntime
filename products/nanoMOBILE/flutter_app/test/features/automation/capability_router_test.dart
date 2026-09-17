import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/capability_router.dart';
import 'package:nanoai/features/automation/engine/execution/tool_call.dart';

void main() {
  group('CapabilityRouter (Prioridad Multisuperficie Nano)', () {
    test('Prioridad 1: MCP / API directa', () {
      const router = CapabilityRouter();
      const call = ToolCall(tool: 'mcp.read', args: {'key': 'test'});

      final decision = router.route(call);

      expect(decision.primarySurface, equals(AutomationSurface.apiMcp));
      expect(decision.confidence, equals(1.0));
      expect(decision.rationale, contains('MCP/API'));
    });

    test('Prioridad 2: Operación Linux semántica por tool name (nano.linux.fs.list)', () {
      final router = CapabilityRouter(isLinuxAvailable: () => true);
      const call = ToolCall(tool: 'nano.linux.fs.list', args: {'path': '/tmp'});

      final decision = router.route(call);

      expect(decision.primarySurface, equals(AutomationSurface.linux));
      expect(decision.confidence, greaterThanOrEqualTo(0.95));
      expect(decision.fallbackSurfaces, contains(AutomationSurface.androidAccessibility));
    });

    test('Prioridad 2: Detección de intención Linux en objetivo del usuario', () {
      final router = CapabilityRouter(isLinuxAvailable: () => true);
      const call = ToolCall(tool: 'action', args: {});

      final decision = router.route(
        call,
        userGoal: 'Descarga el repo de git, compila el código y busca el archivo APK',
      );

      expect(decision.primarySurface, equals(AutomationSurface.linux));
      expect(decision.rationale, contains('Linux'));
    });

    test('Prioridad 3: Browser DOM cuando se requiere interacción web', () {
      final router = CapabilityRouter(isLinuxAvailable: () => true, isBrowserAvailable: () => true);
      const call = ToolCall(tool: 'web.search', args: {'query': 'docs'});

      final decision = router.route(call, userGoal: 'https://docs.flutter.dev');

      expect(decision.primarySurface, equals(AutomationSurface.browserDom));
      expect(decision.rationale, contains('DOM'));
    });

    test('Prioridad 4: Android Accessibility cuando no es Linux ni Web', () {
      final router = CapabilityRouter(
        isLinuxAvailable: () => true,
        isBrowserAvailable: () => true,
        isAccessibilityAvailable: () => true,
      );
      const call = ToolCall(tool: 'tap', selector: 'Ajustes');

      final decision = router.route(call, userGoal: 'Abre la app de Ajustes y activa Bluetooth');

      expect(decision.primarySurface, equals(AutomationSurface.androidAccessibility));
      expect(decision.rationale, contains('Accessibility Tree'));
      expect(decision.fallbackSurfaces, contains(AutomationSurface.ocrVision));
    });

    test('Prioridad 5 y 6: Fallback a OCR/Visión si Accessibility está apagada', () {
      final router = CapabilityRouter(
        isLinuxAvailable: () => false,
        isBrowserAvailable: () => false,
        isAccessibilityAvailable: () => false,
      );
      const call = ToolCall(tool: 'tap', args: {'x': 100, 'y': 200});

      final decision = router.route(call);

      expect(decision.primarySurface, equals(AutomationSurface.ocrVision));
      expect(decision.fallbackSurfaces, contains(AutomationSurface.coordinates));
    });
  });
}
