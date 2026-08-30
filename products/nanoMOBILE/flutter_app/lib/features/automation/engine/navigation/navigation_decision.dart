/// Decisión atómica producida por el navegador de Automation.
library;

import 'situation_diff.dart';

enum NavigationDecisionStatus { arrived, act, needsMoreEvidence }

enum NavigationActionKind { launchPackage, tap, write, back }

/// Una única acción externa posible. Nunca representa una secuencia.
final class NavigationAction {
  NavigationAction._(
    this.kind, {
    String? packageName,
    String? selector,
    String? text,
  }) : packageName = _known(packageName),
       selector = _known(selector),
       text = _known(text) {
    final valid = switch (kind) {
      NavigationActionKind.launchPackage =>
        this.packageName != null && this.selector == null && this.text == null,
      NavigationActionKind.tap =>
        this.packageName == null && this.selector != null && this.text == null,
      NavigationActionKind.write =>
        this.packageName == null && this.selector != null && this.text != null,
      NavigationActionKind.back =>
        this.packageName == null && this.selector == null && this.text == null,
    };
    if (!valid) {
      throw ArgumentError('Payload inválido para ${kind.name}.');
    }
  }

  factory NavigationAction.launchPackage(String packageName) =>
      NavigationAction._(
        NavigationActionKind.launchPackage,
        packageName: packageName,
      );

  factory NavigationAction.tap(String selector) =>
      NavigationAction._(NavigationActionKind.tap, selector: selector);

  factory NavigationAction.write(String selector, String text) =>
      NavigationAction._(
        NavigationActionKind.write,
        selector: selector,
        text: text,
      );

  factory NavigationAction.back() =>
      NavigationAction._(NavigationActionKind.back);

  final NavigationActionKind kind;
  final String? packageName;
  final String? selector;
  final String? text;

  static String? _known(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

/// Resultado explicable del Navigator. [action] existe únicamente para `act`.
final class NavigationDecision {
  NavigationDecision._({
    required this.status,
    required this.diff,
    required this.reason,
    this.action,
  }) {
    if ((status == NavigationDecisionStatus.act) != (action != null)) {
      throw ArgumentError(
        'Una decisión act requiere exactamente una acción; las demás ninguna.',
      );
    }
  }

  factory NavigationDecision.arrived(SituationDiff diff) =>
      NavigationDecision._(
        status: NavigationDecisionStatus.arrived,
        diff: diff,
        reason: 'destino observado: ${diff.explanation}',
      );

  factory NavigationDecision.act({
    required SituationDiff diff,
    required NavigationAction action,
    required String reason,
  }) => NavigationDecision._(
    status: NavigationDecisionStatus.act,
    diff: diff,
    reason: '$reason; ${diff.explanation}',
    action: action,
  );

  factory NavigationDecision.needsMoreEvidence(
    SituationDiff diff,
    String reason,
  ) => NavigationDecision._(
    status: NavigationDecisionStatus.needsMoreEvidence,
    diff: diff,
    reason: '$reason; ${diff.explanation}',
  );

  final NavigationDecisionStatus status;
  final SituationDiff diff;
  final String reason;
  final NavigationAction? action;
}
