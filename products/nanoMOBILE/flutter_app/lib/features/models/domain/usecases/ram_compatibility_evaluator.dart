/// Evaluador de compatibilidad de memoria RAM del dispositivo (SRP & OCP).
library;

enum CompatibilityLevel {
  optimal,
  viable,
  tight,
  oomRisk,
}

class RamCompatibilityReport {
  final CompatibilityLevel level;
  final String label;
  final String description;
  final double ramRatio;
  final double requiredRamGb;
  final double deviceTotalRamGb;

  const RamCompatibilityReport({
    required this.level,
    required this.label,
    required this.description,
    required this.ramRatio,
    required this.requiredRamGb,
    required this.deviceTotalRamGb,
  });

  bool get isSafe => level == CompatibilityLevel.optimal || level == CompatibilityLevel.viable;
}

abstract final class RamCompatibilityEvaluator {
  static RamCompatibilityReport evaluate({
    required double requiredRamGb,
    required double deviceTotalRamGb,
  }) {
    final total = deviceTotalRamGb > 0 ? deviceTotalRamGb : 8.0;
    final ratio = (requiredRamGb / total).clamp(0.0, 1.0);

    if (ratio <= 0.50) {
      return RamCompatibilityReport(
        level: CompatibilityLevel.optimal,
        label: 'ÓPTIMO',
        description: '✓ Ejecución óptima y ligera en CPU ARM.',
        ramRatio: ratio,
        requiredRamGb: requiredRamGb,
        deviceTotalRamGb: total,
      );
    } else if (ratio <= 0.75) {
      return RamCompatibilityReport(
        level: CompatibilityLevel.viable,
        label: 'VIABLE',
        description: '✓ Inferencia viable con suficiente margen para el sistema operativo.',
        ramRatio: ratio,
        requiredRamGb: requiredRamGb,
        deviceTotalRamGb: total,
      );
    } else if (ratio <= 0.90) {
      return RamCompatibilityReport(
        level: CompatibilityLevel.tight,
        label: 'AJUSTADO',
        description: '⚠ Uso intensivo de RAM; se recomienda cerrar apps en segundo plano.',
        ramRatio: ratio,
        requiredRamGb: requiredRamGb,
        deviceTotalRamGb: total,
      );
    } else {
      return RamCompatibilityReport(
        level: CompatibilityLevel.oomRisk,
        label: 'RIESGO OOM',
        description: '⛔ Riesgo de cierre por falta de memoria (Out-of-Memory).',
        ramRatio: ratio,
        requiredRamGb: requiredRamGb,
        deviceTotalRamGb: total,
      );
    }
  }
}
