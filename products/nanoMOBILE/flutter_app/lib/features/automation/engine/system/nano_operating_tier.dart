/// Niveles operativos de Nano AI (Clean Architecture).
///
/// Define los tres tiers de capacidades según los privilegios autorizados en
/// cualquier dispositivo Android (Samsung, OPPO, Xiaomi, Pixel, Motorola, etc.).
/// Principio: Nano siempre funciona en modo [normal] sin exigir ADB ni Shizuku.
library;

/// Tier operativo factual de Nano en el dispositivo.
enum NanoOperatingTier {
  /// Modo básico universal: no requiere opciones de desarrollador ni Shizuku.
  /// Incluye: Accesibilidad, Notificaciones, Intents, Navegador, Archivos y Alarmas.
  normal('Nano Normal', 'Accesibilidad, notificaciones, intents y navegador.'),

  /// Modo desarrollador: requiere depuración inalámbrica local o ADB habilitado.
  /// Incluye: ADB inalámbrico local, diagnósticos profundos, inspección de apps y pruebas UI.
  developer('Nano Developer', 'ADB inalámbrico, diagnósticos de sistema e inspección de apps.'),

  /// Modo avanzado: requiere servicio Shizuku emparejado y activo.
  /// Incluye: Operaciones con identidad shell (UID 2000), gestión de paquetes sin root.
  advanced('Nano Advanced', 'Servicios Shizuku, gestión de paquetes y control de procesos.');

  final String displayName;
  final String description;

  const NanoOperatingTier(this.displayName, this.description);

  /// Indica si el tier actual satisface el tier requerido [requiredTier].
  bool satisfies(NanoOperatingTier requiredTier) {
    return index >= requiredTier.index;
  }
}

/// Descriptor de capacidades agregadas por nivel operativo.
class OperatingTierDescriptor {
  final NanoOperatingTier tier;
  final List<String> availableFeatures;
  final List<String> missingPrerequisites;

  const OperatingTierDescriptor({
    required this.tier,
    required this.availableFeatures,
    this.missingPrerequisites = const [],
  });

  bool get isFullyConfigured => missingPrerequisites.isEmpty;
}
