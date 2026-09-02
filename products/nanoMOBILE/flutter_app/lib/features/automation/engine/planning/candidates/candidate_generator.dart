/// CandidateActionGenerator (A6) — agrega la salida de los providers.
///
/// Responsabilidad: providers → flatten → dedup por [CandidateId] → CandidateSet.
/// SIN ranking, SIN ejecución, SIN política, SIN LLM. Un provider que falla se
/// aísla (no destruye el set) pero se registra tipado (no `catch (_) {}`).
library;

import 'candidate_action.dart';
import 'candidate_provider.dart';
import 'candidate_set.dart';

/// Conflicto de payload: mismo [CandidateId] con payload distinto.
class CandidateConflict implements Exception {
  final CandidateId id;
  const CandidateConflict(this.id);

  @override
  String toString() => 'CandidateConflict(${id.value})';
}

/// Fallo tipado de un provider durante la generación.
class CandidateProviderFailure {
  final String providerId;
  final Object error;
  const CandidateProviderFailure(this.providerId, this.error);

  @override
  String toString() => 'CandidateProviderFailure($providerId): $error';
}

class CandidateGenerationResult {
  final CandidateSet candidates;
  final List<CandidateProviderFailure> failures;

  const CandidateGenerationResult({
    required this.candidates,
    required this.failures,
  });
}

class CandidateActionGenerator {
  CandidateActionGenerator(this._providers);

  final List<CandidateProvider> _providers;

  Future<CandidateGenerationResult> generate(CandidateRequest request) async {
    final all = <CandidateAction>[];
    final failures = <CandidateProviderFailure>[];
    for (final provider in _providers) {
      try {
        all.addAll(await provider.provide(request));
      } catch (e) {
        failures.add(CandidateProviderFailure(provider.id, e));
      }
    }
    final deduped = _dedupById(all, failures);
    return CandidateGenerationResult(
      candidates: CandidateSet(deduped),
      failures: failures,
    );
  }

  List<CandidateAction> _dedupById(
    List<CandidateAction> candidates,
    List<CandidateProviderFailure> failures,
  ) {
    final byId = <CandidateId, CandidateAction>{};
    final out = <CandidateAction>[];
    for (final c in candidates) {
      final existing = byId[c.id];
      if (existing != null) {
        if (candidatePayloadKey(existing) != candidatePayloadKey(c)) {
          failures.add(
            CandidateProviderFailure('generator', CandidateConflict(c.id)),
          );
        }
        continue; // duplicado benigno (mismo payload) o conflicto registrado
      }
      byId[c.id] = c;
      out.add(c);
    }
    return out;
  }
}
