/// QUÉ: contrato de hechos externos/temporales del turno personal.
/// CÓMO: dominio recibe evidencia y disponibilidad, sin conocer HTTP ni Android.
/// POR QUÉ: el redactor depende de una abstracción, no de un proveedor de clima.
abstract interface class PersonalLiveContext {
  Future<PersonalLiveEvidence> resolve(
    String message,
    List<String> recentInbound, {
    String scopeId = '',
  });
}

/// Datos, no respuestas: el modelo redacta; la disponibilidad limita el envío.
final class PersonalLiveEvidence {
  const PersonalLiveEvidence({
    this.block = '',
    this.weatherRequested = false,
    this.weatherAvailable = false,
  });
  final String block;
  final bool weatherRequested;
  final bool weatherAvailable;
}
