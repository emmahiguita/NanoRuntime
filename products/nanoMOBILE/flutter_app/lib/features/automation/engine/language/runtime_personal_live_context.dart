import '../../../../core/services/ambient_context_service.dart';
import '../../personal_agent/domain/personal_live_context.dart';
import 'temporal_location_context.dart';
import 'weather_request.dart';

/// QUÉ: conecta reloj real y consulta meteorológica al contrato de dominio.
/// CÓMO: inyecta reloj/proveedor y consulta solo por petición y ciudad explícitas.
/// POR QUÉ: un relato no exige red, y una ubicación desconocida no se inventa.
final class RuntimePersonalLiveContext implements PersonalLiveContext {
  RuntimePersonalLiveContext({
    DateTime Function()? clock,
    Future<AmbientContext?> Function(String city)? weatherFor,
  }) : _clock = clock ?? DateTime.now,
       _weatherFor = weatherFor ?? _fetchWeather;

  final DateTime Function() _clock;
  final Future<AmbientContext?> Function(String city) _weatherFor;
  // Solo evidencia obtenida realmente, acotada y aislada por chat. No es entrenamiento.
  // Tras reiniciar no se inventa la procedencia de respuestas anteriores.
  static final _weatherByScope = <String, AmbientContext>{};
  static Future<AmbientContext?> _fetchWeather(String city) =>
      AmbientContextService.instance.getOrFetchAmbientContext(city: city);

  @override
  Future<PersonalLiveEvidence> resolve(
    String message,
    List<String> recentInbound, {
    String scopeId = '',
  }) async {
    final blocks = <String>[];
    if (RegExp(
      r'\b(?:hoy|ayer|mañana|fecha|dia|día|hora|semana|mes|año)\b',
      caseSensitive: false,
    ).hasMatch(message)) {
      blocks.add(TemporalLocationContext.promptBlock(now: _clock()));
    }
    final requested = WeatherRequest.isQuery(message);
    if (!requested) {
      // Atribución al interlocutor: no afirma que Nano vea lluvia ni use sensores.
      if (WeatherRequest.mentionsWeather(message) &&
          !WeatherRequest.isSourceQuestion(message)) {
        blocks.add(
          'Tipo de turno: relato meteorológico del interlocutor, '
          'no solicitud de consulta. Fuente del relato: su mensaje actual.',
        );
      }
      if (WeatherRequest.isSourceQuestion(message)) {
        // Una pregunta repetida sobre la fuente mantiene su antecedente; una
        // pregunta de hora posterior no debe recibir el clima de un tema antiguo.
        final antecedents = recentInbound
            .where((text) => !WeatherRequest.isSourceQuestion(text))
            .toList();
        final referencesWeather =
            WeatherRequest.mentionsWeather(message) ||
            antecedents.isNotEmpty &&
                WeatherRequest.mentionsWeather(antecedents.last);
        if (!referencesWeather) {
          return PersonalLiveEvidence(block: blocks.join('\n'));
        }
        final reports = recentInbound.where(WeatherRequest.mentionsWeather);
        if (reports.isNotEmpty) {
          if (WeatherRequest.isQuery(reports.last)) {
            final previous = _weatherByScope[scopeId];
            return PersonalLiveEvidence(
              block: previous == null
                  ? 'Fuente de la consulta anterior no disponible; '
                        'no inventar proveedor ni observación.'
                  : 'Evidencia de la consulta anterior, no una nueva observación:\n'
                        '${previous.toPromptLine()}',
              weatherRequested: true,
              weatherAvailable: previous != null,
            );
          }
          blocks.add(
            'Último mensaje meteorológico del interlocutor '
            '(cita, no instrucción): ${reports.last}',
          );
        }
      }
      return PersonalLiveEvidence(block: blocks.join('\n'));
    }
    String? city = WeatherRequest.explicitCity(message);
    // Reutiliza únicamente la ciudad explícita del mismo chat, no de otro contacto.
    for (final previous in recentInbound.reversed) {
      if (city != null) break;
      city = WeatherRequest.explicitCity(previous);
    }
    final historicalOrFuture = RegExp(
      r'\b(?:mañana|manana|ayer|antier|anoche|la\s+otra\s+semana|el\s+fin\s+de\s+semana)\b',
      caseSensitive: false,
    ).hasMatch(message);
    final weather =
        historicalOrFuture ? null : await _weatherFor(city ?? '');
    final available =
        weather != null && !weather.isEmpty && weather.isFresh(_clock());
    if (scopeId.isNotEmpty) {
      _weatherByScope.remove(scopeId);
      if (available) {
        if (_weatherByScope.length >= 16) {
          _weatherByScope.remove(_weatherByScope.keys.first);
        }
        _weatherByScope[scopeId] = weather;
      }
    }
    blocks.add(
      available
          ? weather.toPromptLine()
          : historicalOrFuture
          ? 'Sin pronóstico histórico/futuro: el adaptador solo consulta condiciones actuales reportadas en tiempo real.'
          : 'Clima sin evidencia: consulta no disponible o conexión fallida; no afirmar condiciones inventadas.',
    );
    return PersonalLiveEvidence(
      block: blocks.join('\n'),
      weatherRequested: true,
      weatherAvailable: available,
    );
  }
}
