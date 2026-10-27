part of 'notification_event_router.dart';

// QUÉ: aplaza la admisión cuando Android impide inferencia por calor.
// CÓMO: consulta la misma API que el compositor, antes de reclamar el inbox,
// marcar snapshots o reservar deduplicación. No confirma eventos pendientes.
// POR QUÉ: confirmar un turno sin respuesta hacía perder su recuperación.
extension NotificationEventRouterThermal on NotificationEventRouter {
  Future<bool> _canAdmitThermally(String source) async {
    final status = await LanguageAssistService().thermalStatus();
    if (_sub == null) return false;
    // CRITICAL+ bloquea todo. SEVERE degrada: admite solo modelos livianos;
    // la puerta nativa (InferenceThermalGuard) decide por peso del paquete.
    // ColorOS marca SEVERE permanente con piel a 45°C (falso positivo OEM).
    if (status >= 4) {
      // Una traza por transición evita inundar logcat cada veinte segundos.
      if (!_thermalDeferred) {
        NotificationEventTrace.stage(
          'thermal',
          source: source,
          outcome: 'deferred_before_admission',
          detail: 'status=$status inbox=unacknowledged',
        );
      }
      _thermalDeferred = true;
      return false;
    }
    if (_thermalDeferred) {
      NotificationEventTrace.stage(
        'thermal',
        source: source,
        outcome: 'resumed',
        detail: 'status=$status',
      );
    }
    _thermalDeferred = false;
    // -1 significa API no disponible, no una temperatura normal medida.
    // Se conserva la política existente; el compositor sigue comprobándola.
    return true;
  }
}
