import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';
import 'package:nanoai/features/automation/engine/model/automation_model_resolver.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selection.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selector.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_set.dart';

AutomationModelResolver resolver({
  AutomationModelMode mode = AutomationModelMode.sameAsChat,
  String? chat = '/models/chat.gguf',
  String? auto = '/models/auto.gguf',
}) => AutomationModelResolver(
  mode: () => mode,
  chatModelPath: () => chat,
  automationModelPath: () => auto,
);

void main() {
  group('AutomationModelResolver', () {
    test('deterministicOnly → llmAllowed=false y sin modelPath', () {
      final r = resolver(mode: AutomationModelMode.deterministicOnly).resolveFor(
        AutomationModelRole.draftWriter,
      );
      expect(r.llmAllowed, isFalse);
      expect(r.modelPath, isNull);
    });

    test('sameAsChat → usa el modelo del chat', () {
      final r = resolver().resolveFor(AutomationModelRole.selector);
      expect(r.llmAllowed, isTrue);
      expect(r.modelPath, '/models/chat.gguf');
    });

    test('specificModel → usa el modelo de automation', () {
      final r = resolver(mode: AutomationModelMode.specificModel).resolveFor(
        AutomationModelRole.planner,
      );
      expect(r.llmAllowed, isTrue);
      expect(r.modelPath, '/models/auto.gguf');
    });

    test('modelo ausente → llmAllowed=false (degradación honesta)', () {
      final r = resolver(
        mode: AutomationModelMode.specificModel,
        auto: null,
      ).resolveFor(AutomationModelRole.draftWriter);
      expect(r.llmAllowed, isFalse);
    });
  });

  group('ModelGatedCandidateSelector', () {
    test('llmAllowed=false → ambigüedad preservada SIN llamar al modelo', () async {
      var called = false;
      final gated = ModelGatedCandidateSelector(
        inner: _FakeSelector(() {
          called = true;
          return Future.value(AmbiguousCandidates(const [], 'x'));
        }),
        resolver: resolver(mode: AutomationModelMode.deterministicOnly),
      );
      final result = await gated.select(
        CandidateSelectionRequest(goal: 'x', candidates: CandidateSet([])),
      );
      expect(result, isA<AmbiguousCandidates>());
      expect(called, isFalse);
    });

    test('llmAllowed=true → delega al selector interno', () async {
      var called = false;
      final gated = ModelGatedCandidateSelector(
        inner: _FakeSelector(() {
          called = true;
          return Future.value(AmbiguousCandidates(const [], 'x'));
        }),
        resolver: resolver(),
      );
      await gated.select(
        CandidateSelectionRequest(goal: 'x', candidates: CandidateSet([])),
      );
      expect(called, isTrue);
    });
  });
}

class _FakeSelector implements CandidateSelector {
  _FakeSelector(this._fn);
  final Future<CandidateSelection> Function() _fn;
  @override
  Future<CandidateSelection> select(CandidateSelectionRequest request) => _fn();
}
