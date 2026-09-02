/// GoalVerifier — responde "¿el objetivo del usuario quedó REALMENTE
/// cumplido?" (TASK SUCCESS), distinto de ActionVerifier.
///
/// R0: una UI que contiene la palabra "Bluetooth" no demuestra que el switch
/// esté activado. La verificación puede exigir package y checked state.
library;

import 'agent_executor.dart';
import '../perception/nano_selector.dart';
import '../perception/selector_engine.dart';
import 'platform_verification.dart';

enum GoalStatus { satisfied, notSatisfied, unverified }

class GoalVerification {
  final GoalStatus status;
  final String reason;

  const GoalVerification(this.status, this.reason);
}

class GoalExpectation {
  final String? expectedPackage;
  final String? visibleText;
  final String? absentText;
  final NanoSelector? checkedSelector;
  final bool? expectedChecked;

  /// A14.5.4 — postcondiciones de ESTADO SEMÁNTICO (el objetivo real, no solo
  /// "llegué al destino"). Se evalúan contra el lector de estado de plataforma.
  final List<PlatformPredicate> statePredicates;

  const GoalExpectation({
    this.expectedPackage,
    this.visibleText,
    this.absentText,
    this.checkedSelector,
    this.expectedChecked,
    this.statePredicates = const [],
  }) : assert(
         (checkedSelector == null) == (expectedChecked == null),
         'checkedSelector y expectedChecked deben declararse juntos.',
       );

  bool get hasCriteria =>
      (expectedPackage != null && expectedPackage!.isNotEmpty) ||
      visibleText != null ||
      absentText != null ||
      checkedSelector != null ||
      statePredicates.isNotEmpty;
}

class GoalVerifier {
  GoalVerifier({
    required AgentExecutor executor,
    NanoSelectorEngine? engine,
    PlatformStateReader? stateReader,
    this.packageSettleAttempts = 5,
    this.packageSettleDelay = const Duration(milliseconds: 200),
  }) : _executor = executor,
       _engine = engine ?? NanoSelectorEngine(),
       _stateReader = stateReader;

  final AgentExecutor _executor;
  final NanoSelectorEngine _engine;
  final PlatformStateReader? _stateReader;

  /// Los Intents Android devuelven control antes de que Accessibility publique
  /// la nueva ventana. Reintentar solo el package esperado evita un falso
  /// negativo sin convertir una ejecución fallida en éxito.
  final int packageSettleAttempts;
  final Duration packageSettleDelay;

  Future<GoalVerification> verify(
    String goal, {
    required bool planCompleted,
    GoalExpectation? expectation,
  }) async {
    if (!planCompleted) {
      return const GoalVerification(
        GoalStatus.notSatisfied,
        'El plan no completó: se detuvo en un paso sin verificar. '
        'El objetivo no puede declararse cumplido.',
      );
    }

    if (expectation == null || !expectation.hasCriteria) {
      return const GoalVerification(
        GoalStatus.unverified,
        'Plan completo y verificado paso a paso; sin expectativa de objetivo '
        'declarada no hay comprobación final.',
      );
    }

    var snap = await _executor.snapshot();
    if (snap == null) {
      return const GoalVerification(
        GoalStatus.notSatisfied,
        'Sin snapshot final (canal off): el objetivo no es verificable.',
      );
    }

    final expectedPackage = expectation.expectedPackage;
    if (expectedPackage != null && expectedPackage.isNotEmpty) {
      for (
        var attempt = 1;
        snap!.package != expectedPackage && attempt < packageSettleAttempts;
        attempt++
      ) {
        await Future<void>.delayed(packageSettleDelay);
        final next = await _executor.snapshot();
        if (next != null) snap = next;
      }
    }
    if (expectedPackage != null &&
        expectedPackage.isNotEmpty &&
        snap.package != expectedPackage) {
      return GoalVerification(
        GoalStatus.notSatisfied,
        'Package final esperado "$expectedPackage", real "${snap.package}".',
      );
    }

    final visibleTexts = snap.nodes.map((n) => n.text).toSet();

    if (expectation.visibleText != null) {
      final needle = expectation.visibleText!.toLowerCase();
      final found = visibleTexts.any((t) => t.toLowerCase().contains(needle));
      if (!found) {
        return GoalVerification(
          GoalStatus.notSatisfied,
          'El objetivo exige "$needle" visible al final, pero no está en el '
          'estado real: NO se declara éxito.',
        );
      }
    }

    if (expectation.absentText != null) {
      final needle = expectation.absentText!.toLowerCase();
      final stillThere = visibleTexts.any(
        (t) => t.toLowerCase().contains(needle),
      );
      if (stillThere) {
        return GoalVerification(
          GoalStatus.notSatisfied,
          'El objetivo exige que "$needle" NO esté, pero sigue visible: '
          'el objetivo no se cumplió.',
        );
      }
    }

    final checkedSelector = expectation.checkedSelector;
    if (checkedSelector != null) {
      final resolved = _engine.resolve(checkedSelector, snap);
      if (!resolved.isResolved || resolved.best == null) {
        return GoalVerification(
          GoalStatus.notSatisfied,
          'No se pudo resolver de forma unívoca el control cuyo estado '
          '`checked` debía verificarse: ${resolved.reason}',
        );
      }
      final actual = resolved.best!.node.checked;
      if (actual != expectation.expectedChecked) {
        return GoalVerification(
          GoalStatus.notSatisfied,
          'El control "${resolved.best!.node.label}" tiene checked=$actual; '
          'se esperaba checked=${expectation.expectedChecked}.',
        );
      }
    }

    // A14.5.4 — estado semántico: el objetivo no se cumple por "llegar al
    // destino"; se cumple cuando el ESTADO real coincide con lo pedido.
    if (expectation.statePredicates.isNotEmpty) {
      final reader = _stateReader;
      if (reader == null) {
        return const GoalVerification(
          GoalStatus.unverified,
          'El objetivo declara estado semántico pero no hay lector de estado.',
        );
      }
      final pr = await evaluateAllOf(expectation.statePredicates, reader);
      if (pr is PlatformPredicateUnsatisfied) {
        return GoalVerification(
          GoalStatus.notSatisfied,
          'Estado semántico NO cumplido: ${pr.reason}',
        );
      }
      if (pr is PlatformPredicateUnavailable) {
        return GoalVerification(
          GoalStatus.unverified,
          'Estado semántico no observable: ${pr.reason}',
        );
      }
    }

    return const GoalVerification(
      GoalStatus.satisfied,
      'Objetivo cumplido: expectativa verificada contra el estado final real.',
    );
  }
}
