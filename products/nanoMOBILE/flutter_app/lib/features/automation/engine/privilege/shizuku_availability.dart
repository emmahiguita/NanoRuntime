/// ShizukuAvailability (A14.3) — detección FACTUAL de disponibilidad de Shizuku.
///
/// Responde SOLO: ¿Shizuku está compilado/instalado/binder vivo/Nano autorizado?
/// NO ejecuta shell, NO acciones privilegiadas, NO pide permiso automáticamente.
/// `available` != `authorized` != `action authorized by user` != `safe` !=
/// `executed`. Backend real (dependencia rikka) es futuro; A14.3 provee el seam
/// y un provider default `unsupported`.
library;

/// Estado tipado de disponibilidad (no un `bool` plano).
enum ShizukuStatus {
  unsupported,
  notInstalled,
  serviceUnavailable,
  permissionRequired,
  available,
}

class ShizukuAvailability {
  final ShizukuStatus status;
  final String reason;

  const ShizukuAvailability(this.status, this.reason);

  bool get isAvailable => status == ShizukuStatus.available;
}

/// Contrato de disponibilidad factual de Shizuku (DIP).
abstract interface class ShizukuAvailabilityProvider {
  Future<ShizukuAvailability> status();
}

/// Provider por defecto: sin dependencia Shizuku integrada → `unsupported`.
/// NO finge disponibilidad. Se reemplaza cuando exista el backend real.
class UnsupportedShizukuAvailabilityProvider
    implements ShizukuAvailabilityProvider {
  const UnsupportedShizukuAvailabilityProvider();

  @override
  Future<ShizukuAvailability> status() async => const ShizukuAvailability(
    ShizukuStatus.unsupported,
    'Sin backend Shizuku (dependencia no integrada).',
  );
}
