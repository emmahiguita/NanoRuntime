// conversation_obligation.dart
//
// QUÉ HACE:
// Representa una obligación conversacional atómica (pregunta, solicitud de hecho,
// acción o confirmación) extraída del mensaje de un turno en WhatsApp o mensajería.
//
// CÓMO FUNCIONA:
// Cada turno compuesto ("¿Tienen el negro, cuánto vale y mandan a Bello?") se descompone
// en múltiples [TurnObligation]. Cada una posee un tópico, una entidad opcional,
// y un estado de cobertura (`answered`, `clarifying`, `pending`).
//
// POR QUÉ:
// Evita el error arquitectónico de colapsar mensajes multi-intención en un solo "intent"
// genérico, permitiendo verificar si la respuesta cubre o aclara todas las partes.

library;

/// Estado de resolución de una obligación del turno.
enum ObligationStatus {
  /// Respondida con certeza factual a partir de la memoria o hechos del negocio.
  answered,

  /// No resuelta de inmediato, pero el agente la está aclarando activamente con una pregunta honesta.
  clarifying,

  /// Omitida o desatendida en la respuesta propuesta (alerta de riesgo conversacional).
  pending,
}

/// Clasificación semántica del tipo de obligación.
enum ObligationKind {
  /// Consulta sobre producto, catálogo, stock o disponibilidad.
  availability,

  /// Consulta sobre precio, costos, métodos de pago o valor monetario.
  pricing,

  /// Consulta sobre logística, tiempos de entrega, cobertura geográfica o despacho.
  logistics,

  /// Pregunta general sobre políticas, horarios o ubicación física.
  information,

  /// Petición explícita de realizar una acción (apartar, enviar, registrar).
  actionRequest,

  /// Saludo, cortesía, despedida o interacción social.
  social,
}

/// Representación inmutable de una obligación conversacional individual.
final class TurnObligation {
  /// Tópico descriptivo corto (ej. "precio_samsung", "envio_bello").
  final String topic;

  /// Tipo de obligación inferido.
  final ObligationKind kind;

  /// Entidad o parámetro asociado si existe (ej. "Samsung negro", "Bello").
  final String? targetEntity;

  /// Estado de cobertura de esta obligación en la respuesta actual.
  final ObligationStatus status;

  /// Hecho faltante necesario para responderla si no pudo ser cubierta.
  final String? missingFact;

  const TurnObligation({
    required this.topic,
    required this.kind,
    this.targetEntity,
    this.status = ObligationStatus.pending,
    this.missingFact,
  });

  /// Indica si la obligación fue resuelta o aclarada honestamente (no ignorada).
  bool get isCovered =>
      status == ObligationStatus.answered ||
      status == ObligationStatus.clarifying;

  /// Deserializa desde JSON tolerante devuelto por el modelo o parser.
  factory TurnObligation.fromJson(Map<String, dynamic> json) {
    final rawKind = (json['kind'] as String?)?.toLowerCase().trim() ?? '';
    final kind = switch (rawKind) {
      'pricing' || 'precio' => ObligationKind.pricing,
      'logistics' || 'envio' || 'entrega' => ObligationKind.logistics,
      'availability' || 'stock' || 'disponible' => ObligationKind.availability,
      'action' || 'accion' => ObligationKind.actionRequest,
      'social' || 'saludo' => ObligationKind.social,
      _ => ObligationKind.information,
    };

    final rawStatus = (json['status'] as String?)?.toLowerCase().trim() ?? '';
    final status = switch (rawStatus) {
      'answered' || 'respondida' || 'resuelta' => ObligationStatus.answered,
      'clarifying' || 'aclarando' || 'preguntando' =>
        ObligationStatus.clarifying,
      _ => ObligationStatus.pending,
    };

    return TurnObligation(
      topic: (json['topic'] as String?)?.trim() ?? 'consulta_general',
      kind: kind,
      targetEntity: (json['targetEntity'] as String?)?.trim(),
      status: status,
      missingFact: (json['missingFact'] as String?)?.trim(),
    );
  }

  /// Serializa a mapa JSON para persistencia o trazabilidad de auditoría.
  Map<String, Object?> toJson() => {
    'topic': topic,
    'kind': kind.name,
    if (targetEntity != null) 'targetEntity': targetEntity,
    'status': status.name,
    if (missingFact != null) 'missingFact': missingFact,
  };
}
