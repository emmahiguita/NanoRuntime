import 'nano_operating_tier.dart';
import 'universal_capability_detector.dart';

/// Mecanismo de ejecución resuelto para una tarea u operación en Nano.
enum ExecutionMechanism {
  /// Intent estándar de Android, canal de sistema o Broadcast.
  nativeAndroid('Intent / Sistema Nativo'),

  /// Inyección de gestos o lectura estructural mediante [AccessibilityService].
  accessibility('Servicio de Accesibilidad'),

  /// Comandos shell autorizados mediante cliente ADB inalámbrico local.
  adb('ADB Inalámbrico Local'),

  /// Llamadas privilegiadas a servicios del sistema mediante Shizuku (UID 2000).
  shizuku('Servicio Shizuku (Shell)'),

  /// Ejecución aislada en subsistema Linux local (proot / termux).
  linux('Subsistema Linux Local');

  final String description;
  const ExecutionMechanism(this.description);
}

/// Decisión de resolución de ejecución técnica con trazabilidad de fallback.
class ExecutionResolution {
  final ExecutionMechanism mechanism;
  final bool isDegraded;
  final String rationale;

  const ExecutionResolution({
    required this.mechanism,
    this.isDegraded = false,
    required this.rationale,
  });
}

/// Resolutor universal de mecanismos de ejecución con degradación elegante.
///
/// Principios SOLID:
/// - SRP: Responsabilidad exclusiva de seleccionar el mejor mecanismo viable.
/// - OCP: Permite añadir nuevos mecanismos sin romper las automatizaciones existentes.
class UniversalExecutionResolver {
  const UniversalExecutionResolver();

  /// Resuelve el mecanismo de ejecución óptimo evaluando el snapshot del dispositivo.
  ExecutionResolution resolve({
    required String actionType,
    required UniversalDeviceSnapshot snapshot,
    bool requiresElevatedPrivilege = false,
    bool requiresVisualCapture = false,
  }) {
    // 1. Si la acción requiere privilegios elevados (gestión de paquetes, congelar apps, etc.)
    if (requiresElevatedPrivilege) {
      if (snapshot.shizukuActive) {
        return const ExecutionResolution(
          mechanism: ExecutionMechanism.shizuku,
          rationale: 'Ejecutando mediante Shizuku autorizado (UID 2000).',
        );
      }
      if (snapshot.adbActive) {
        return const ExecutionResolution(
          mechanism: ExecutionMechanism.adb,
          rationale: 'Fallback a ADB inalámbrico local.',
        );
      }
      // Degradación elegante: no abortar; degradar a Intent o informar al usuario
      return const ExecutionResolution(
        mechanism: ExecutionMechanism.nativeAndroid,
        isDegraded: true,
        rationale: 'Privilegios elevados no activos. Degradando a flujo estándar de Intent.',
      );
    }

    // 2. Si la acción interactúa con la interfaz de usuario externa
    if (actionType == 'ui_interaction' || actionType == 'screen_read') {
      if (snapshot.accessibilityActive) {
        return const ExecutionResolution(
          mechanism: ExecutionMechanism.accessibility,
          rationale: 'Interacción guiada por AccessibilityService.',
        );
      }
      return const ExecutionResolution(
        mechanism: ExecutionMechanism.nativeAndroid,
        isDegraded: true,
        rationale: 'Accesibilidad no concedida. Degradando a navegación básica por Intent.',
      );
    }

    // 3. Si la acción solicita captura visual
    if (requiresVisualCapture && !snapshot.canCaptureScreenshot) {
      return const ExecutionResolution(
        mechanism: ExecutionMechanism.accessibility,
        isDegraded: true,
        rationale: 'Captura visual no soportada por SDK (<30). Fallback a árbol accesible.',
      );
    }

    // 4. Mecanismo por defecto: Android estándar universal
    return const ExecutionResolution(
      mechanism: ExecutionMechanism.nativeAndroid,
      rationale: 'Operación resuelta mediante componentes estándar de Android.',
    );
  }

  /// Evalúa si el nivel operativo del dispositivo permite una tarea específica.
  bool isTierSufficient(
    NanoOperatingTier currentTier,
    NanoOperatingTier minimumRequired,
  ) {
    return currentTier.satisfies(minimumRequired);
  }
}
