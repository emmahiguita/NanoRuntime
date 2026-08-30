/// Diferencia explicable entre la situación observada y el destino deseado.
library;

import '../perception/current_situation.dart';
import 'navigation_goal.dart';

enum SituationDimension { packageName, surface, entity }

enum SituationComparison { match, mismatch, unknown }

/// Resultado factual de comparar una sola dimensión de navegación.
final class SituationDifference {
  const SituationDifference._({
    required this.dimension,
    required this.comparison,
    required this.currentValue,
    required this.targetValue,
  });

  final SituationDimension dimension;
  final SituationComparison comparison;
  final String? currentValue;
  final String targetValue;

  String get explanation {
    final current = currentValue == null ? '<unknown>' : '"$currentValue"';
    return '${dimension.name}: ${comparison.name} '
        'current=$current target="$targetValue"';
  }
}

/// Comparación inmutable `WHERE I AM ↔ WHERE I NEED TO BE`.
final class SituationDiff {
  SituationDiff._({
    required this.current,
    required this.target,
    required List<SituationDifference> differences,
  }) : differences = List.unmodifiable(differences);

  factory SituationDiff.between(
    CurrentSituation current,
    NavigationGoal target,
  ) {
    final differences = <SituationDifference>[
      SituationDifference._(
        dimension: SituationDimension.packageName,
        comparison: _compare(current.packageName, target.targetPackage),
        currentValue: _known(current.packageName),
        targetValue: target.targetPackage,
      ),
      SituationDifference._(
        dimension: SituationDimension.surface,
        comparison: current.surfaceKind == CurrentSurfaceKind.unknown
            ? SituationComparison.unknown
            : _compare(current.surfaceKind.name, target.targetSurface.name),
        currentValue: current.surfaceKind == CurrentSurfaceKind.unknown
            ? null
            : current.surfaceKind.name,
        targetValue: target.targetSurface.name,
      ),
      if (target.targetEntity case final targetEntity?)
        SituationDifference._(
          dimension: SituationDimension.entity,
          comparison: _compareEntity(current.entity, targetEntity),
          currentValue: current.entity,
          targetValue: targetEntity,
        ),
    ];
    return SituationDiff._(
      current: current,
      target: target,
      differences: differences,
    );
  }

  final CurrentSituation current;
  final NavigationGoal target;
  final List<SituationDifference> differences;

  bool get matchesTarget => differences.every(
    (difference) => difference.comparison == SituationComparison.match,
  );

  bool get hasMismatch => differences.any(
    (difference) => difference.comparison == SituationComparison.mismatch,
  );

  bool get needsMoreEvidence => differences.any(
    (difference) => difference.comparison == SituationComparison.unknown,
  );

  String get explanation =>
      differences.map((difference) => difference.explanation).join('; ');

  static SituationComparison _compare(String? current, String target) {
    final knownCurrent = _known(current);
    if (knownCurrent == null) return SituationComparison.unknown;
    return knownCurrent == target
        ? SituationComparison.match
        : SituationComparison.mismatch;
  }

  static SituationComparison _compareEntity(String? current, String target) {
    final knownCurrent = _known(current);
    if (knownCurrent == null) return SituationComparison.unknown;
    return navigationEntityKey(knownCurrent) == navigationEntityKey(target)
        ? SituationComparison.match
        : SituationComparison.mismatch;
  }

  static String? _known(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
