/// AutomationModelResolver (T4.2) — resuelve qué modelo usar para un rol, sin
/// crear un segundo motor. Automation obtiene inferencia SOLO vía
/// RuntimeEngineNotifier/LLMEngineClient (el mismo del Chat).
///
/// `deterministicOnly` → llmAllowed=false SIEMPRE (0 llamadas). `sameAsChat` →
/// usa el modelo activo del Chat. `specificModel` → usa el modelPath configurado.
/// Si no hay modelo (path vacío) → llmAllowed=false (degradación honesta).
library;

import '../planning/candidates/candidate_selection.dart';
import '../planning/candidates/candidate_selector.dart';
import 'automation_model.dart';

/// Veredicto de resolución: qué modelo y si el LLM está permitido para el rol.
class AutomationModelResolution {
  final AutomationModelMode mode;
  final String? modelPath;
  final AutomationModelRole role;
  final bool llmAllowed;

  const AutomationModelResolution({
    required this.mode,
    required this.modelPath,
    required this.role,
    required this.llmAllowed,
  });
}

class AutomationModelResolver {
  AutomationModelResolver({
    required AutomationModelMode Function() mode,
    required String? Function() chatModelPath,
    required String? Function() automationModelPath,
  }) : _mode = mode,
       _chatModelPath = chatModelPath,
       _automationModelPath = automationModelPath;

  final AutomationModelMode Function() _mode;
  final String? Function() _chatModelPath;
  final String? Function() _automationModelPath;

  AutomationModelResolution resolveFor(AutomationModelRole role) {
    final m = _mode();
    switch (m) {
      case AutomationModelMode.deterministicOnly:
        return AutomationModelResolution(
          mode: m,
          modelPath: null,
          role: role,
          llmAllowed: false,
        );
      case AutomationModelMode.sameAsChat:
        final p = _chatModelPath();
        return AutomationModelResolution(
          mode: m,
          modelPath: p,
          role: role,
          llmAllowed: _nonEmpty(p),
        );
      case AutomationModelMode.specificModel:
        final p = _automationModelPath();
        return AutomationModelResolution(
          mode: m,
          modelPath: p,
          role: role,
          llmAllowed: _nonEmpty(p),
        );
    }
  }

  bool _nonEmpty(String? p) => p != null && p.isNotEmpty;
}

/// Decorador que hace que un [CandidateSelector] respete la resolución de
/// modelo: si el LLM no está permitido (deterministicOnly o sin modelo),
/// preserva la ambigüedad SIN llamar al modelo (0 LLM, degradación honesta).
class ModelGatedCandidateSelector implements CandidateSelector {
  ModelGatedCandidateSelector({required this.inner, required this.resolver});

  final CandidateSelector inner;
  final AutomationModelResolver resolver;

  @override
  Future<CandidateSelection> select(CandidateSelectionRequest request) async {
    final res = resolver.resolveFor(AutomationModelRole.selector);
    if (!res.llmAllowed) {
      return AmbiguousCandidates(
        request.candidates.items,
        'sin LLM para selección (modo ${res.mode.name})',
      );
    }
    return inner.select(request);
  }
}
