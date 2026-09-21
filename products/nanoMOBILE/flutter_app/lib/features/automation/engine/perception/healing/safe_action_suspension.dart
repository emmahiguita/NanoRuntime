// safe_action_suspension.dart
//
// Mecanismo de suspensión segura ante incertidumbre visual o actualización crítica de apps.
// - ¿Qué hace?: Detiene la ejecución antes de tocar la pantalla si la interfaz cambió
//   y la confianza de auto-reparación no supera el umbral de seguridad (0.75).
// - ¿Cómo funciona?: Construye un reporte estructurado con el paquete, el elemento esperado
//   y los candidatos ambiguos presentes en el ScreenGraph, evitando clics a ciegas.
// - ¿Por qué?: Respeta la premisa central de NanoRuntime ("Supervivencia > Velocidad"):
//   nunca ejecutar una acción destructiva o equivocada en apps de terceros ante rediseños.

library;

import '../semantic/nano_ui_object.dart';
import '../surface_profiles.dart';

/// Resultado estructurado de una suspensión preventiva segura.
final class SafeActionSuspension {
  const SafeActionSuspension({
    required this.packageName,
    required this.targetKind,
    required this.reason,
    required this.confidence,
    this.candidates = const [],
    required this.timestamp,
  });

  final String packageName;
  final SurfaceElementKind targetKind;
  final String reason;
  final double confidence;
  final List<NanoUiObject> candidates;
  final DateTime timestamp;

  /// Mensaje explicativo amigable para el usuario y para el diario de ejecución.
  String get explanation {
    final candidateSummary = candidates.isEmpty
        ? 'sin controles candidatos visibles'
        : '${candidates.length} candidato(s): ${candidates.map((c) => c.label.isNotEmpty ? c.label : c.role.name).join(', ')}';
    return '[SuspensionSegura] Se pausó la acción sobre "$packageName" (${targetKind.name}): '
        '$reason. Confianza: ${(confidence * 100).toStringAsFixed(1)}% (< 75%). '
        'Estado detectado: $candidateSummary.';
  }

  @override
  String toString() => explanation;
}
