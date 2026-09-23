/// QUÉ HACE:
/// Modela las obligaciones atómicas secuenciales de una instrucción compleja
/// en el Cerebro Universal de Nano (fases, permisos, entidad objetivo y estado de resolución).
///
/// CÓMO FUNCIONA:
/// Cada solicitud compuesta (ej: "revisa el Excel, dime agotados, actualiza catálogo y avísame")
/// se descompone en múltiples [UniversalObligation], clasificadas por fase de ejecución y tipo de acción,
/// permitiendo rastrear el progreso hasta la finalización completa.
///
/// POR QUÉ:
/// Evita que el agente abandone la tarea a mitad de camino o confunda una orden compuesta
/// con una simple respuesta conversacional, garantizando verificabilidad bajo SOLID y < 200 líneas.
library;

/// Fases secuenciales del ciclo de vida de una instrucción compleja.
enum ObligationPhase {
  /// Descubrimiento o resolución de referencias (ej: localizar archivo o tabla).
  discovery,

  /// Consulta, filtrado o lectura de datos sin efectos secundarios.
  readQuery,

  /// Modificación de estado persistente que puede requerir confirmación previa.
  mutation,

  /// Verificación de condiciones de alerta o anomalías lógicas.
  anomalyVerification,

  /// Generación del reporte o respuesta final al usuario.
  reporting,
}

/// Tipo de acción concreta que ejecuta la obligación.
enum ObligationActionKind {
  /// Inspección o parseo de datos (Excel, CSV, SQLite, archivos).
  inspectData,

  /// Ejecución técnica en shell/terminal/Linux.
  executeCommand,

  /// Mutación de base de datos o catálogo comercial.
  updateState,

  /// Búsqueda o extracción semántica web en navegador.
  browseWeb,

  /// Comprobación analítica de regla o condición de alerta.
  verifyCondition,

  /// Notificación de síntesis al usuario.
  notifyUser,
}

/// Estado de ejecución de la obligación individual.
enum ObligationExecutionStatus {
  pending,
  inProgress,
  completed,
  failed,
  blockedWaitingAuth,
}

/// Representación inmutable de una obligación en el Cerebro Universal.
final class UniversalObligation {
  final String id;
  final String title;
  final ObligationPhase phase;
  final ObligationActionKind actionKind;
  final String targetEntity;
  final bool requiresAuthorization;
  final ObligationExecutionStatus status;
  final String resultSnippet;
  final String missingRequirement;

  const UniversalObligation({
    required this.id,
    required this.title,
    required this.phase,
    required this.actionKind,
    this.targetEntity = '',
    this.requiresAuthorization = false,
    this.status = ObligationExecutionStatus.pending,
    this.resultSnippet = '',
    this.missingRequirement = '',
  });

  bool get isResolved =>
      status == ObligationExecutionStatus.completed ||
      status == ObligationExecutionStatus.blockedWaitingAuth;

  bool get isCovered => isResolved;

  bool get isFailed => status == ObligationExecutionStatus.failed;

  UniversalObligation copyWith({
    String? id,
    String? title,
    ObligationPhase? phase,
    ObligationActionKind? actionKind,
    String? targetEntity,
    bool? requiresAuthorization,
    ObligationExecutionStatus? status,
    String? resultSnippet,
    String? missingRequirement,
  }) {
    return UniversalObligation(
      id: id ?? this.id,
      title: title ?? this.title,
      phase: phase ?? this.phase,
      actionKind: actionKind ?? this.actionKind,
      targetEntity: targetEntity ?? this.targetEntity,
      requiresAuthorization: requiresAuthorization ?? this.requiresAuthorization,
      status: status ?? this.status,
      resultSnippet: resultSnippet ?? this.resultSnippet,
      missingRequirement: missingRequirement ?? this.missingRequirement,
    );
  }

  factory UniversalObligation.fromJson(Map<String, dynamic> json) =>
      UniversalObligation(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        phase: ObligationPhase.values.firstWhere(
          (e) => e.name == json['phase'],
          orElse: () => ObligationPhase.readQuery,
        ),
        actionKind: ObligationActionKind.values.firstWhere(
          (e) => e.name == json['actionKind'],
          orElse: () => ObligationActionKind.inspectData,
        ),
        targetEntity: (json['targetEntity'] as String?) ?? '',
        requiresAuthorization: json['requiresAuthorization'] == true,
        status: ObligationExecutionStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ObligationExecutionStatus.pending,
        ),
        resultSnippet: (json['resultSnippet'] as String?) ?? '',
        missingRequirement: (json['missingRequirement'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'phase': phase.name,
    'actionKind': actionKind.name,
    'targetEntity': targetEntity,
    'requiresAuthorization': requiresAuthorization,
    'status': status.name,
    'resultSnippet': resultSnippet,
    'missingRequirement': missingRequirement,
  };
}
