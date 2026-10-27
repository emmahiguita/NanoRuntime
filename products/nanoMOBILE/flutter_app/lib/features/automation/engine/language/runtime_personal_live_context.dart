import '../../../../core/services/ambient_context_service.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../personal_agent/application/personal_intent_router.dart';
import '../../personal_agent/domain/conversation_agent_message_classifier.dart'
    show isLiveStateQuestion;
import '../../personal_agent/domain/personal_daily_agenda.dart';
import '../../personal_agent/domain/owner_declared_context.dart';
import '../../personal_agent/domain/personal_intent.dart';
import '../../personal_agent/domain/personal_live_context.dart';
import '../conversation/understanding_frame.dart';
import '../mcp/whatsapp_mcp_delta_sync.dart';
import 'temporal_location_context.dart';
import 'weather_request.dart';

/// Recupera reloj y clima solicitados para el turno. Agenda y otros chats
/// requieren un consumidor privado del dueño que habilite su acceso.
/// El contacto no recibe datos ajenos por mencionar una palabra temporal.
final class RuntimePersonalLiveContext implements PersonalLiveContext {
  RuntimePersonalLiveContext({
    DateTime Function()? clock,
    Future<AmbientContext?> Function(String city)? weatherFor,
    Future<AmbientContext?> Function()? deviceWeatherFor,
    Future<Map<String, String>> Function()? ownerFactsFor,
    // Solo un consumidor privado del dueño puede habilitar agenda/otros chats.
    // El escritor de respuestas a contactos conserva false.
    this.allowOwnerPrivateContext = false,
    this.allowDeclaredAgenda = false,
  }) : _clock = clock ?? DateTime.now,
       _weatherFor = weatherFor ?? _fetchWeather,
       _deviceWeatherFor =
           deviceWeatherFor ??
           AmbientContextService.instance.getOrFetchForDevice,
       _ownerFactsFor = ownerFactsFor ?? _defaultOwnerFacts;

  final DateTime Function() _clock;
  final Future<AmbientContext?> Function(String city) _weatherFor;
  final Future<AmbientContext?> Function() _deviceWeatherFor;
  final Future<Map<String, String>> Function() _ownerFactsFor;
  final bool allowOwnerPrivateContext;
  // Solo el calendario que el dueño habilitó para sus contactos, sin otros chats.
  final bool allowDeclaredAgenda;
  static final _weatherByScope = <String, AmbientContext>{};

  static Future<AmbientContext?> _fetchWeather(String city) =>
      AmbientContextService.instance.getOrFetchAmbientContext(city: city);

  /// Obtiene los hechos y el cronograma guardados en el perfil `'owner'`.
  static Future<Map<String, String>> _defaultOwnerFacts() async {
    try {
      final personas = await PersonaRepository.instance.listPersonas();
      final owner = personas.where((p) => p.personaKey == 'owner').firstOrNull;
      return owner?.facts ?? const {};
    } catch (_) {
      return const {};
    }
  }

  /// Resuelve la evidencia viva verificada que acompañará al mensaje actual.
  ///
  /// - **QUÉ HACE:** Construye el bloque de texto para `<CONTEXTO DEL TURNO>`.
  /// - **CÓMO FUNCIONA:** Combina el análisis de [UnderstandingFrame], la hora
  ///   y fecha reales, el cronograma diario, los WhatsApp pendientes en SQLite
  ///   y el clima bajo demanda.
  /// - **POR QUÉ:** Garantiza que LiteRT-LM tenga datos reales antes de redactar.
  @override
  Future<PersonalLiveEvidence> resolve(
    String message,
    List<String> recentInbound, {
    String scopeId = '',
  }) async {
    final now = _clock();
    final blocks = <String>[];
    final understandingFrame = UnderstandingFrame.analyze(
      conversationId: scopeId,
      rawText: message,
      recentInboundInSameChat: recentInbound,
    );
    // El marco heurístico orienta la recuperación, pero no se inyecta como
    // una orden de confirmar tareas: el texto real y sus autores van aparte.

    final intent = PersonalIntentRouter.route(message);
    // Estado breve vigente: se usa también en mensajes no reconocidos por regex.
    final declaredFacts = allowOwnerPrivateContext || allowDeclaredAgenda
        ? await _ownerFactsFor()
        : const <String, String>{};
    final needsTemporalOrSchedule =
        isLiveStateQuestion(message) ||
        understandingFrame.discourseAct ==
            UnderstandingDiscourseAct.followUpReference ||
        intent == PersonalIntent.currentTime ||
        intent == PersonalIntent.currentDate ||
        intent == PersonalIntent.nanoDailyPlan ||
        intent == PersonalIntent.userDailyPlan ||
        intent == PersonalIntent.userPendingTasks ||
        RegExp(
          r'\b(?:hoy|ayer|mañana|manana|fecha|dia|día|hora|semana|mes|año|almorzaste|almorzando|comiste|cenaste|trabajando|haces|haciendo|estas|estás|vas\s+a\s+hacer|pendiente|pendientes|whatsapp|mensajes|escribio|escribió|salir|salimos|vamos|fiesta|invito|disponible|puedes\s+venir)\b',
          caseSensitive: false,
        ).hasMatch(message);

    if (needsTemporalOrSchedule) {
      blocks.add(TemporalLocationContext.promptBlock(now: now));
    }
    final state = OwnerDeclaredContext.status(declaredFacts, now);
    if (state.isNotEmpty) {
      blocks.add('Estado declarado hoy por el dueño: $state');
    }
    if (!needsTemporalOrSchedule && state.isEmpty) {
      final current = OwnerDeclaredContext.currentBlock(declaredFacts, now);
      if (current.isNotEmpty) blocks.add(current);
    }
    if (needsTemporalOrSchedule &&
        (allowOwnerPrivateContext || allowDeclaredAgenda)) {
      final ownerFacts = declaredFacts;
      final scheduleDate =
          RegExp(
            r'\b(?:mañana|manana)\b',
            caseSensitive: false,
          ).hasMatch(message)
          ? DateTime(now.year, now.month, now.day + 1)
          : now;
      final agendaBlock = PersonalDailyAgenda.promptBlock(
        ownerFacts,
        now,
        date: scheduleDate,
      );
      if (agendaBlock.isNotEmpty) {
        blocks.add(agendaBlock);
      } else if (intent == PersonalIntent.userDailyPlan ||
          intent == PersonalIntent.userPendingTasks) {
        blocks.add(
          'Cronograma del usuario hoy: sin horario ni tareas registradas para hoy.',
        );
      }
    }
    if (needsTemporalOrSchedule && allowOwnerPrivateContext) {
      final pendingBlock =
          await WhatsAppMcpDeltaSync.buildPendingSummaryBlock();
      if (pendingBlock.isNotEmpty) {
        blocks.add(pendingBlock);
      }
    }

    if (!WeatherRequest.isQuery(message)) {
      _appendPassiveWeatherContext(message, recentInbound, scopeId, blocks);
      return PersonalLiveEvidence(block: blocks.join('\n'));
    }
    return _resolveActiveWeatherQuery(message, recentInbound, scopeId, blocks);
  }

  /// Añade contexto cuando el interlocutor comenta el clima sin pedir consulta.
  void _appendPassiveWeatherContext(
    String message,
    List<String> recentInbound,
    String scopeId,
    List<String> blocks,
  ) {
    if (WeatherRequest.mentionsWeather(message) &&
        !WeatherRequest.isSourceQuestion(message)) {
      blocks.add(
        'Tipo de turno: relato meteorológico del interlocutor, '
        'no solicitud de consulta. Fuente del relato: su mensaje actual.',
      );
      return;
    }
    if (!WeatherRequest.isSourceQuestion(message)) return;
    final reports = recentInbound.where(WeatherRequest.mentionsWeather);
    if (reports.isEmpty) return;
    if (WeatherRequest.isQuery(reports.last)) {
      final previous = _weatherByScope[scopeId];
      blocks.add(
        previous == null
            ? 'Fuente de la consulta anterior no disponible; no inventar proveedor.'
            : 'Evidencia de la consulta anterior:\n${previous.toPromptLine()}',
      );
      return;
    }
    blocks.add(
      'Último mensaje meteorológico del interlocutor (cita): ${reports.last}',
    );
  }

  /// Ejecuta la consulta meteorológica real cuando el usuario lo solicita.
  Future<PersonalLiveEvidence> _resolveActiveWeatherQuery(
    String message,
    List<String> recentInbound,
    String scopeId,
    List<String> blocks,
  ) async {
    String? city = WeatherRequest.explicitCity(message);
    for (final previous in recentInbound.reversed) {
      if (city != null) break;
      city = WeatherRequest.explicitCity(previous);
    }
    final historicalOrFuture = RegExp(
      r'\b(?:mañana|manana|ayer|antier|anoche|la\s+otra\s+semana|el\s+fin\s+de\s+semana)\b',
      caseSensitive: false,
    ).hasMatch(message);
    final weather = historicalOrFuture
        ? null
        : city == null
        ? await _deviceWeatherFor()
        : await _weatherFor(city);
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
          ? 'Sin pronóstico histórico/futuro: solo condiciones actuales en tiempo real.'
          : 'Clima sin evidencia: consulta no disponible; no inventar condiciones.',
    );
    return PersonalLiveEvidence(
      block: blocks.join('\n'),
      weatherRequested: true,
      weatherAvailable: available,
    );
  }
}
