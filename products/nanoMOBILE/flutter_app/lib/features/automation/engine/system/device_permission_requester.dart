/// DevicePermissionRequester — solicitud ORGANIZADA de los permisos del agente.
///
/// Centraliza el "cómo se solicita" cada permiso (Accesibilidad, Notificaciones,
/// Shizuku). El estado REAL lo aporta el SystemGraph (probes factuales); aquí
/// solo viven los gestos de solicitud, nunca una simulación de éxito. Tras
/// solicitar, el llamador re-sondea el graph (invalidate) para reflejar el
/// estado real al volver.
library;

import 'package:nanoai/core/services/nano_runtime_api.dart';

import 'capability_availability.dart';
import 'system_capability.dart';
import 'system_graph.dart';

class DevicePermissionRequester {
  const DevicePermissionRequester();

  /// Solicita en secuencia los permisos que faltan según el [graph] factual.
  ///
  /// Orden: Accesibilidad → Notificaciones → Shizuku (solo si instalado y sin
  /// autorizar; el dialogo de Shizuku es el emparejamiento). Cada uno es una
  /// acción física del usuario (ajuste/diálogo); no se fabrica éxito.
  Future<void> requestAllMissing(SystemGraph graph) async {
    final api = NanoRuntimeApi.instance;

    if (!graph
        .availabilityOf(SystemCapability.observeAccessibility)
        .isAvailable) {
      await api.openAccessibilitySettings();
    }
    if (!graph.availabilityOf(SystemCapability.readNotifications).isAvailable) {
      await api.openNotificationAccessSettings();
    }
    final shizuku = graph.availabilityOf(SystemCapability.shizuku);
    if (shizuku.state == CapabilityAvailabilityKind.requiresUserEnablement) {
      await api.shizukuRequestPermission();
    }
  }
}
