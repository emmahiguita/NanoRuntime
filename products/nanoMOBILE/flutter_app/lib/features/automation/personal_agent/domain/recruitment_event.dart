// recruitment_event.dart
//
// QUÉ HACE:
// Modela la extracción estructurada de ofertas laborales, procesos de selección
// y citaciones a pruebas técnicas (PeakU, Computrabajo, LinkedIn, Indeed).
//
// CÓMO FUNCIONA:
// - Analiza texto crudo y extrae plataforma, puesto de trabajo, fase, acción requerida y enlaces.
// - Discierne si es un avance de fase (ej. "has pasado el primer filtro") o vacante cerrada.
// - Evita inventar fechas o detalles no presentes en el mensaje original.
//
// POR QUÉ:
// Transforma mensajes de reclutamiento en eventos procesables por el asistente
// para que el usuario actúe sin emitir respuestas autónomas indeseadas.

library;

class RecruitmentEvent {
  final String platform;
  final String position;
  final String stage;
  final String actionRequired;
  final String? url;
  final String rawText;
  final bool isClosed;

  const RecruitmentEvent({
    required this.platform,
    required this.position,
    required this.stage,
    required this.actionRequired,
    this.url,
    required this.rawText,
    this.isClosed = false,
  });

  static final _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+|www\.[^\s]+)',
    caseSensitive: false,
  );

  /// Extrae un [RecruitmentEvent] a partir del texto de un mensaje, o null si no es reclutamiento.
  static RecruitmentEvent? extract(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();

    final isPeakU = lower.contains('peaku') || lower.contains('peaku.co');
    final isCompuTrabajo = lower.contains('computrabajo');
    final isLinkedIn = lower.contains('linkedin');
    final isJobProcess = lower.contains('gracias por aplicar') ||
        lower.contains('has pasado el primer filtro') ||
        lower.contains('completar las pruebas') ||
        lower.contains('tu aplicacion') ||
        lower.contains('tu aplicación') ||
        lower.contains('proceso de seleccion') ||
        lower.contains('proceso de selección') ||
        lower.contains('vacante ha sido cerrada') ||
        lower.contains('ofertas laborales') ||
        lower.contains('entrevista de trabajo') ||
        lower.contains('entrevista laboral') ||
        lower.contains('prueba tecnica') ||
        lower.contains('prueba técnica');

    if (!isJobProcess && !isPeakU && !isCompuTrabajo) {
      return null;
    }

    // 1. Detección de Plataforma
    final platform = isPeakU
        ? (isCompuTrabajo ? 'PeakU / CompuTrabajo' : 'PeakU')
        : (isCompuTrabajo ? 'CompuTrabajo' : (isLinkedIn ? 'LinkedIn' : 'Reclutamiento'));

    // 2. Extracción de Posición / Cargo
    String position = 'Oferta de Empleo';
    final applyMatch = RegExp(
      r'aplicar\s+a\s+([^,.\n!]+?)(?:\s+en\s+computrabajo|\s+el\s+\d|\s+en\s+peaku|\s*[,.\n!])',
      caseSensitive: false,
    ).firstMatch(t);
    if (applyMatch != null && applyMatch.group(1) != null) {
      position = applyMatch.group(1)!.trim();
    } else {
      final forMatch = RegExp(r'para\s+([A-ZÁÉÍÓÚ][\w\s\-–]+?)(?:\s*[,.\n!])').firstMatch(t);
      if (forMatch != null && forMatch.group(1) != null) {
        position = forMatch.group(1)!.trim();
      }
    }

    // 3. Extracción de URLs
    final urls = _urlRegex.allMatches(t).map((m) => m.group(0)!).toList();
    final url = urls.isNotEmpty ? urls.first.replaceFirst(RegExp(r'[.,;!?]+$'), '') : null;

    // 4. Determinación de Fase y Acción
    final isClosed = lower.contains('vacante ha sido cerrada') || lower.contains('ha sido cerrada');
    final isFirstFilter = lower.contains('has pasado el primer filtro') ||
        lower.contains('primer filtro') ||
        lower.contains('completar las pruebas');

    final stage = isClosed
        ? 'Vacante Cerrada'
        : (isFirstFilter ? 'Primer Filtro Superado' : 'Proceso de Selección Activo');

    final actionRequired = isClosed
        ? 'Revisar nuevas vacantes en el canal'
        : (lower.contains('completar las pruebas')
            ? 'Completar pruebas técnicas en plataforma'
            : (lower.contains('entrevista') ? 'Coordinar entrevista laboral' : 'Revisar estado de postulación'));

    return RecruitmentEvent(
      platform: platform,
      position: position,
      stage: stage,
      actionRequired: actionRequired,
      url: url,
      rawText: t,
      isClosed: isClosed,
    );
  }
}
