/// QUÉ HACE:
/// Respuesta tipada devuelta por el cliente del agente de navegación.
///
/// CÓMO FUNCIONA:
/// Modela el estado de éxito/error, contenido textual, proveedor solicitado
/// y backend real utilizado (puente, motor local o navegador nativo).
///
/// POR QUÉ:
/// Desacopla la representación de datos de la implementación de red (SRP).
class ReverseAgentResponse {
  final bool ok;
  final String provider;
  final String response;
  final String? error;
  final String source;
  final String requestedProvider;
  final String actualProvider;
  final String actualBackend;

  const ReverseAgentResponse({
    required this.ok,
    required this.provider,
    required this.response,
    this.error,
    this.source = 'bridge',
    this.requestedProvider = '',
    this.actualProvider = '',
    this.actualBackend = 'remote_provider',
  });

  factory ReverseAgentResponse.failure(
    String provider,
    String error, {
    String actualBackend = 'none',
  }) {
    return ReverseAgentResponse(
      ok: false,
      provider: provider,
      response: '',
      error: error,
      source: 'error',
      requestedProvider: provider,
      actualProvider: '',
      actualBackend: actualBackend,
    );
  }

  factory ReverseAgentResponse.fromJson(Map<String, dynamic> json) {
    final prov = json['provider'] as String? ?? 'unknown';
    return ReverseAgentResponse(
      ok: json['ok'] == true,
      provider: prov,
      response: json['response'] as String? ?? '',
      error: json['error'] as String?,
      source: json['source'] as String? ?? 'bridge',
      requestedProvider: json['requested_provider'] as String? ?? prov,
      actualProvider: json['actual_provider'] as String? ?? prov,
      actualBackend: json['actual_backend'] as String? ?? 'remote_provider',
    );
  }
}
