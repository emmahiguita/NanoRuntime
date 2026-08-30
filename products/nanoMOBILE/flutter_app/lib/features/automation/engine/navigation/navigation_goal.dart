/// Destino semántico de una navegación de Automation.
library;

import '../perception/current_situation.dart';

/// Declara dónde debe terminar la navegación, nunca cómo llegar allí.
final class NavigationGoal {
  NavigationGoal({
    required String targetPackage,
    required this.targetSurface,
    String? targetEntity,
  }) : targetPackage = targetPackage.trim(),
       targetEntity = _normalizeEntity(targetEntity) {
    if (this.targetPackage.isEmpty) {
      throw ArgumentError.value(
        targetPackage,
        'targetPackage',
        'El destino debe identificar un paquete.',
      );
    }
    if (targetSurface == CurrentSurfaceKind.unknown) {
      throw ArgumentError.value(
        targetSurface,
        'targetSurface',
        'unknown no es un destino de navegación verificable.',
      );
    }
  }

  final String targetPackage;
  final CurrentSurfaceKind targetSurface;

  /// Identidad semántica opcional dentro de la superficie (contacto, item,
  /// perfil). Es un objetivo; solo [CurrentSituation] exige evidencia observada.
  final String? targetEntity;

  static String? _normalizeEntity(String? value) {
    final normalized = value == null ? null : normalizeNavigationEntity(value);
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
