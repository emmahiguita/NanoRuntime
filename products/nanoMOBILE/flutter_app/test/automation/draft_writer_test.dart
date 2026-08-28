import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';
import 'package:nanoai/features/automation/engine/model/automation_model_resolver.dart';
import 'package:nanoai/features/automation/engine/model/draft_writer.dart';

AutomationModelResolver _resolver(AutomationModelMode mode, {String? path}) =>
    AutomationModelResolver(
      mode: () => mode,
      chatModelPath: () => path,
      automationModelPath: () => path,
    );

void main() {
  final client = LLMEngineClient(baseUrl: 'http://127.0.0.1:1');

  test('deterministicOnly → DraftUnavailable (0 LLM)', () async {
    final w = RuntimeAutomationDraftWriter(
      resolver: _resolver(AutomationModelMode.deterministicOnly),
      client: client,
      ensureReady: (_) async => true,
    );
    final r = await w.generate(const DraftRequest(instruction: 'algo amable'));
    expect(r, isA<DraftUnavailable>());
  });

  test('sin modelo → DraftUnavailable', () async {
    final w = RuntimeAutomationDraftWriter(
      resolver: _resolver(AutomationModelMode.specificModel, path: null),
      client: client,
      ensureReady: (_) async => true,
    );
    final r = await w.generate(const DraftRequest(instruction: 'hola'));
    expect(r, isA<DraftUnavailable>());
  });

  test('sin instrucción → DraftRejected', () async {
    final w = RuntimeAutomationDraftWriter(
      resolver: _resolver(AutomationModelMode.sameAsChat),
      client: client,
      ensureReady: (_) async => true,
    );
    final r = await w.generate(const DraftRequest(instruction: '  '));
    expect(r, isA<DraftRejected>());
  });
}
