part of 'voice_runtime.dart';

/// Orquesta la sesión de voz (estado + conversación) sobre el MISMO agente.
/// `resolveGoal` convierte el transcript final en un goal del AutomationCoordinator
/// (inyectado; no usa LLM aquí). No ejecuta por sí mismo: delega al coordinador.
class VoiceSessionManager {
  VoiceSessionManager({
    required SpeechRecognitionBackend recognition,
    required SpeechSynthesisBackend synthesis,
    WakeWordDetector? wakeWord,
    required Future<String?> Function(String transcript) resolveGoal,
    this.followUpWindow = const Duration(seconds: 8),
    this.listenTimeout = const Duration(seconds: 15),
  }) : _recognition = recognition,
       _synthesis = synthesis,
       _wakeWord = wakeWord,
       _resolveGoal = resolveGoal;

  final SpeechRecognitionBackend _recognition;
  final SpeechSynthesisBackend _synthesis;
  final WakeWordDetector? _wakeWord;
  final Future<String?> Function(String transcript) _resolveGoal;
  final Duration followUpWindow;

  /// Timeout defensivo de escucha: si el reconocedor no devuelve (se cuelga),
  /// se aborta el turno en vez de quedar escuchando indefinidamente.
  final Duration listenTimeout;

  final _stateController = StreamController<VoiceSessionState>.broadcast();
  Timer? _followUpTimer;
  bool _disposed = false;
  Object? _owner;
  int _revision = 0;

  /// Identifica quién inició la captura/locución actual; no concede permisos.
  bool isOwnedBy(Object owner) => !_disposed && identical(_owner, owner);

  /// Invalida resultados anteriores antes de iniciar otra operación de voz.
  int _claim(Object? owner) {
    _owner = owner;
    return ++_revision;
  }

  final VoiceConversationContext context = VoiceConversationContext();

  /// A16 — estado del mundo conversacional (entidades grounded con evidencia).
  final ConversationalWorldState world = ConversationalWorldState();
  final GroundingResolver _grounding = const GroundingResolver();

  /// Resuelve un pronombre/referencia ("respóndele", "esa app") a la entidad
  /// grounded activa. null = ambiguo/sin evidencia (el llamador pide aclaración).
  String? resolveReference(String reference) =>
      _grounding.resolve(reference, world);

  Stream<VoiceSessionState> get states => _stateController.stream;
  VoiceSessionState _state = VoiceSessionState.idle;
  VoiceSessionState get state => _state;
  void _set(VoiceSessionState s) {
    _state = s;
    if (!_disposed) _stateController.add(s);
  }

  /// Push-to-talk: escucha UNA vez, resuelve y devuelve el turno (sin hablar).
  /// Si Nano estaba hablando, interrumpe primero (barge-in cooperativo).
  Future<VoiceTurn?> pushToTalk({Object? owner}) async {
    if (_disposed) return null;
    _followUpTimer?.cancel();
    if (_state == VoiceSessionState.speaking) {
      final stopping = bargeIn(owner: owner);
      final stoppingRevision = _revision;
      await stopping;
      if (_disposed || stoppingRevision != _revision) return null;
    }
    final revision = _claim(owner);
    if (context.isStale) context.clear();
    if (world.isStale) world.clear();
    _set(VoiceSessionState.listening);
    final sw = Stopwatch()..start();
    final String? transcript;
    try {
      transcript = await _recognition.listen().timeout(
        listenTimeout,
        onTimeout: () async {
          // Abandonar solo el Future deja el recognizer nativo vivo. El puerto
          // cancela el recurso real y resuelve su MethodChannel pendiente.
          if (revision == _revision) await _recognition.cancel();
          return null;
        },
      );
    } on ExecutionCancelled {
      if (revision == _revision) _set(VoiceSessionState.idle);
      return null;
    }
    if (_disposed || revision != _revision) return null;
    sw.stop();
    sttLatencyMs = sw.elapsedMilliseconds;
    debugPrint(
      '[voice] pushToTalk: ${sw.elapsedMilliseconds}ms, '
      'transcript="${transcript ?? ''}"',
    );
    if (transcript == null || transcript.trim().isEmpty) {
      _set(VoiceSessionState.idle);
      return null;
    }
    _set(VoiceSessionState.processing);
    final goal = await _resolveGoal(transcript);
    if (_disposed || revision != _revision) return null;
    context.lastUtterance = transcript;
    context.activeGoal = goal;
    context.touch();
    _set(VoiceSessionState.idle);
    return VoiceTurn(transcript: transcript, resolvedGoal: goal);
  }

  /// Habla una respuesta y queda escuchando follow-up (bounded).
  Future<void> respond(String text, {Object? owner}) =>
      _respondOwned(text, _claim(owner));

  /// Espera hasta que el TTS termine de hablar (bounded). Los saludos de
  /// apertura usan [respond] + esta espera antes del primer [pushToTalk]:
  /// sin ella, el micrófono se abre mientras Nano aún habla (captaría su
  /// propia voz o el audio se solaparía con la locución).
  ///
  /// VOICE-PRO-01 — fin confirmado con DOS muestras consecutivas de silencio:
  /// entre chunks encolados el motor puede reportar isSpeaking=false durante
  /// una micro-pausa; una sola muestra cortaba la espera a destiempo.
  /// [isCancelled] opcional: el llamador aborta la espera (p. ej. la sesión
  /// dejó de esperar follow-up o el usuario detuvo la conversación).
  Future<void> waitForSpeechEnd({
    Duration timeout = const Duration(seconds: 30),
    bool Function()? isCancelled,
  }) => _waitForSpeechEnd(timeout: timeout, isCancelled: isCancelled);

  /// VOICE-NATURAL-01 — turno completo de conversación continua: habla la
  /// respuesta, espera a que el TTS termine de hablar (sin que el micrófono
  /// capture la propia voz de Nano) y, si la sesión sigue en espera de
  /// follow-up (no cancelada), vuelve a escuchar el siguiente turno.
  Future<VoiceTurn?> respondAndListen(String text, {Object? owner}) =>
      _respondAndListenOwned(text, owner: owner);

  /// A16 — telemetría de voz (sección 19): latencias observadas de STT/TTS.
  int sttLatencyMs = 0;
  int ttsLatencyMs = 0;

  /// Barge-in: el usuario interrumpe la respuesta en curso.
  Future<void> bargeIn({Object? owner}) => _bargeInOwned(_claim(owner));

  // ── Ciclo de vida (start/stop + modo asistente) ──────────────────────────

  /// true si la sesión no está idle.
  bool get isActive => _state != VoiceSessionState.idle;

  bool _assistantMode = false;
  bool get isAssistantMode => _assistantMode;

  /// Inicia la sesión de voz (push-to-talk): deja al manager listo para
  /// [pushToTalk]. Idempotente.
  Future<void> start() => _startSession();

  /// Detiene la sesión por completo: interrumpe habla, apaga síntesis y vuelve
  /// a idle. No cierra el stream (reutilizable entre turnos).
  Future<void> stop({Object? owner}) => _stopSession(owner: owner);

  /// Modo asistente: activa el wake word (si hay detector) para escucha pasiva.
  Future<void> startAssistant() => _startAssistant();

  /// Detiene el modo asistente: apaga el wake word y detiene la sesión.
  Future<void> stopAssistant() => _stopAssistant();

  /// Libera la sesión global; cada interfaz solo debe detener sus recursos propios.
  Future<void> dispose() => _disposeSession();
}
