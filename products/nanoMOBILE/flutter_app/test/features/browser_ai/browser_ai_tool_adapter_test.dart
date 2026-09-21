import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/browser_ai_tool_adapter.dart';
import 'package:nanoai/features/automation/engine/execution/tool_call.dart';
import 'package:nanoai/features/automation/engine/execution/tool_outcome.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/browser_ai/application/browser_ai_gateway.dart';
import 'package:nanoai/features/browser_ai/domain/browser_ai_query.dart';
import 'package:nanoai/features/browser_ai/domain/browser_ai_response.dart';

class FakeBrowserAiGateway implements BrowserAiGateway {
  BrowserAiResponse nextResponse = BrowserAiResponse.success(
    providerId: 'gemini',
    content: 'Respuesta simulada exitosa',
    duration: const Duration(seconds: 1),
  );
  bool openTabResult = true;

  @override
  Future<BrowserAiResponse> query(BrowserAiQuery query) async => nextResponse;

  @override
  Future<List<Map<String, dynamic>>> listProviders() async => [
        {'id': 'chatgpt', 'name': 'ChatGPT', 'hasTab': true, 'isLoggedIn': true},
        {'id': 'gemini', 'name': 'Gemini', 'hasTab': false, 'isLoggedIn': false},
      ];

  @override
  Future<bool> openProviderTab(String providerId) async => openTabResult;
}

void main() {
  group('BrowserAiToolAdapter — Pruebas de Integración con AgentToolDispatcher', () {
    late FakeBrowserAiGateway fakeGateway;
    late BrowserAiToolAdapter adapter;

    setUp(() {
      fakeGateway = FakeBrowserAiGateway();
      adapter = BrowserAiToolAdapter(fakeGateway);
    });

    test('browser.ai.providers: Lista los proveedores en formato JSON legible', () async {
      const call = ToolCall(tool: 'browser.ai.providers');
      final outcome = await adapter.execute(call);

      expect(outcome.verdict, equals(PolicyVerdict.allow));
      expect(outcome.executionStatus, equals(ToolExecutionStatus.completed));
      expect(outcome.feedback, contains('ChatGPT'));
      expect(outcome.feedback, contains('Gemini'));
    });

    test('browser.ai.open: Abre pestaña y devuelve éxito', () async {
      const call = ToolCall(tool: 'browser.ai.open', args: {'provider': 'gemini'});
      final outcome = await adapter.execute(call);

      expect(outcome.verdict, equals(PolicyVerdict.allow));
      expect(outcome.executionStatus, equals(ToolExecutionStatus.completed));
      expect(outcome.feedback, contains('Pestaña de gemini abierta'));
    });

    test('browser.ai.ask: Rechaza llamadas con prompt vacío', () async {
      const call = ToolCall(tool: 'browser.ai.ask', args: {'prompt': ''});
      final outcome = await adapter.execute(call);

      expect(outcome.verdict, equals(PolicyVerdict.denied));
      expect(outcome.executionStatus, equals(ToolExecutionStatus.failed));
      expect(outcome.feedback, contains('no puede estar vacío'));
    });

    test('browser.ai.ask: Retorna respuesta completada exitosamente', () async {
      const call = ToolCall(
        tool: 'browser.ai.ask',
        args: {'prompt': 'Explica el patrón Gateway', 'provider': 'gemini'},
      );
      final outcome = await adapter.execute(call);

      expect(outcome.verdict, equals(PolicyVerdict.allow));
      expect(outcome.executionStatus, equals(ToolExecutionStatus.completed));
      expect(outcome.feedback, equals('Respuesta simulada exitosa'));
    });

    test('browser.ai.ask: Retorna needsConfirmation si se requiere intervención de usuario', () async {
      fakeGateway.nextResponse = BrowserAiResponse.userActionRequired(
        providerId: 'chatgpt',
        reason: 'Resolver CAPTCHA de Cloudflare',
        duration: const Duration(seconds: 1),
      );

      const call = ToolCall(
        tool: 'browser.ai.ask',
        args: {'prompt': 'Consulta', 'provider': 'chatgpt'},
      );
      final outcome = await adapter.execute(call);

      expect(outcome.verdict, equals(PolicyVerdict.needsConfirmation));
      expect(outcome.executionStatus, equals(ToolExecutionStatus.completedUnverified));
      expect(outcome.feedback, contains('CAPTCHA'));
    });

    test('browser.ai.get_response: Retorna el estado actual de la sesión', () async {
      const call = ToolCall(tool: 'browser.ai.get_response', args: {'provider': 'chatgpt'});
      final outcome = await adapter.execute(call);

      expect(outcome.verdict, equals(PolicyVerdict.allow));
      expect(outcome.executionStatus, equals(ToolExecutionStatus.completed));
      expect(outcome.feedback, contains('Activa'));
    });
  });
}
