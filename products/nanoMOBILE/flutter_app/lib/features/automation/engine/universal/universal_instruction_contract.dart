/// QUÉ HACE:
/// Define el contrato semántico universal de instrucciones para Nano AI Mobile,
/// integrando el dominio de operación, modo de ejecución, referencias deícticas y obligaciones.
///
/// CÓMO FUNCIONA:
/// Captura la comprensión holística del mensaje del usuario a través de las 12 áreas
/// (chat, terminal, data studio, business, etc.), discerniendo si se resuelve conversando,
/// mediante acciones en segundo plano o de forma híbrida.
///
/// POR QUÉ:
/// Desacopla la interpretación de la orden de los ejecutores concretos (Clean Architecture),
/// garantizando que el sistema sepa exactamente qué se resolvió, qué falta y qué falló.
library;

import 'universal_instruction_obligation.dart';

export 'universal_instruction_obligation.dart';

/// Dominios operativos universales soportados por Nano Mobile.
enum InstructionDomain {
  chat,
  personal,
  business,
  terminal,
  dataStudio,
  browser,
  voice,
  android,
  automations,
  memory,
  tools,
}

/// Modo de resolución determinado por el Cerebro Universal.
enum InstructionExecutionMode {
  /// Se resuelve exclusivamente mediante diálogo o conocimiento.
  conversationalOnly,

  /// Requiere ejecución de herramientas o mutación de estado en el dispositivo.
  actionOnly,

  /// Resuelve parte conversando y parte ejecutando acciones reales.
  hybrid,
}

/// Referencia contextual o deíctica identificada en el mensaje ("ese Excel", "el anterior").
final class DeicticReference {
  final String phrase;
  final String category; // 'file', 'table', 'command', 'contact', 'product'
  final String? resolvedValue;

  const DeicticReference({
    required this.phrase,
    required this.category,
    this.resolvedValue,
  });

  bool get isResolved => resolvedValue != null && resolvedValue!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'phrase': phrase,
    'category': category,
    'resolvedValue': resolvedValue,
  };

  factory DeicticReference.fromJson(Map<String, dynamic> json) =>
      DeicticReference(
        phrase: (json['phrase'] as String?) ?? '',
        category: (json['category'] as String?) ?? 'file',
        resolvedValue: json['resolvedValue'] as String?,
      );
}

/// Contrato semántico completo de una instrucción para el runtime.
final class UniversalInstructionContract {
  final String rawInstruction;
  final InstructionDomain domain;
  final InstructionExecutionMode executionMode;
  final String primaryGoal;
  final List<DeicticReference> deicticReferences;
  final List<UniversalObligation> obligations;

  const UniversalInstructionContract({
    required this.rawInstruction,
    required this.domain,
    required this.executionMode,
    required this.primaryGoal,
    this.deicticReferences = const [],
    this.obligations = const [],
  });

  bool get allObligationsResolved =>
      obligations.isNotEmpty && obligations.every((o) => o.isCovered);

  bool get hasFailedObligations => obligations.any((o) => o.isFailed);

  bool get requiresUserConfirmation =>
      obligations.any((o) => o.requiresAuthorization && !o.isResolved);

  List<String> get resolvedSummaries => [
    for (final o in obligations)
      if (o.status == ObligationExecutionStatus.completed)
        '${o.title}: ${o.resultSnippet.isNotEmpty ? o.resultSnippet : "Completado"}',
  ];

  List<String> get pendingSummaries => [
    for (final o in obligations)
      if (o.status == ObligationExecutionStatus.pending ||
          o.status == ObligationExecutionStatus.inProgress ||
          o.status == ObligationExecutionStatus.blockedWaitingAuth)
        o.missingRequirement.isNotEmpty
            ? '${o.title} (falta: ${o.missingRequirement})'
            : o.title,
  ];

  List<String> get failureSummaries => [
    for (final o in obligations)
      if (o.status == ObligationExecutionStatus.failed)
        '${o.title}: ${o.resultSnippet.isNotEmpty ? o.resultSnippet : "Error al procesar"}',
  ];

  UniversalInstructionContract copyWith({
    String? rawInstruction,
    InstructionDomain? domain,
    InstructionExecutionMode? executionMode,
    String? primaryGoal,
    List<DeicticReference>? deicticReferences,
    List<UniversalObligation>? obligations,
  }) {
    return UniversalInstructionContract(
      rawInstruction: rawInstruction ?? this.rawInstruction,
      domain: domain ?? this.domain,
      executionMode: executionMode ?? this.executionMode,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      deicticReferences: deicticReferences ?? this.deicticReferences,
      obligations: obligations ?? this.obligations,
    );
  }

  factory UniversalInstructionContract.fromJson(Map<String, dynamic> json) {
    final rawRefs = json['deicticReferences'];
    final refs = <DeicticReference>[
      if (rawRefs is List)
        for (final r in rawRefs)
          if (r is Map) DeicticReference.fromJson(r.cast<String, dynamic>()),
    ];

    final rawObls = json['obligations'];
    final obls = <UniversalObligation>[
      if (rawObls is List)
        for (final o in rawObls)
          if (o is Map) UniversalObligation.fromJson(o.cast<String, dynamic>()),
    ];

    return UniversalInstructionContract(
      rawInstruction: (json['rawInstruction'] as String?) ?? '',
      domain: InstructionDomain.values.firstWhere(
        (e) => e.name == json['domain'],
        orElse: () => InstructionDomain.chat,
      ),
      executionMode: InstructionExecutionMode.values.firstWhere(
        (e) => e.name == json['executionMode'],
        orElse: () => InstructionExecutionMode.hybrid,
      ),
      primaryGoal: (json['primaryGoal'] as String?) ?? '',
      deicticReferences: refs,
      obligations: obls,
    );
  }

  Map<String, dynamic> toJson() => {
    'rawInstruction': rawInstruction,
    'domain': domain.name,
    'executionMode': executionMode.name,
    'primaryGoal': primaryGoal,
    'deicticReferences': deicticReferences.map((r) => r.toJson()).toList(),
    'obligations': obligations.map((o) => o.toJson()).toList(),
  };
}
