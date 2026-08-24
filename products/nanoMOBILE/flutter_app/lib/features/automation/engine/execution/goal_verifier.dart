/// GoalVerifier — responde "¿el objetivo del usuario quedó REALMENTE
/// cumplido?" (TASK SUCCESS), distinto de ActionVerifier.
///
/// R0: una UI que contiene la palabra "Bluetooth" no demuestra que el switch
/// esté activado. La verificación puede exigir package y checked state.
library;

import 'agent_executor.dart';
import '../perception/nano_selector.dart';
import '../perception/selector_engine.dart';

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

  const GoalExpectation({
    this.expectedPackage,
    this.visibleText,
    this.absentText,
    this.checkedSelector,
    this.expectedChecked,
  }) : assert(
         (checkedSelector == null) == (expectedChecked == null),
         'checkedSelector y expectedChecked deben declararse juntos.',
       );

  bool get hasCriteria =>
      (expectedPackage != null && expectedPackage!.isNotEmpty) ||
      visibleText != null ||
      absentText != null ||
      checkedSelector != null;
}

class GoalVerifier {
  GoalVerifier({required AgentExecutor executor, NanoSelectorEngine? engine})
    : _executor = executor,
      _engine = engine ?? NanoSelectorEngine();

  final AgentExecutor _executor;
  final NanoSelectorEngine _engine;

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

    final snap = await _executor.snapshot();
    if (snap == null) {
      return const GoalVerification(
        GoalStatus.notSatisfied,
        'Sin snapshot final (canal off): el objetivo no es verificable.',
      );
    }

    final expectedPackage = expectation.expectedPackage;
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

    return const GoalVerification(
      GoalStatus.satisfied,
      'Objetivo cumplido: expectativa verificada contra el estado final real.',
    );
  }
}
