// conversation_intelligence_profile.dart
//
// QUÉ HACE:
// Modelo inmutable de datos estructurados e inteligencia comercial post-conversación.
//
// CÓMO FUNCIONA:
// - Encapsula la calificación de lead (hot, warm, cold, unqualified), presupuesto
//   mencionado, urgencia, objeciones, puntos de dolor y próxima acción recomendada.
// - Serializa a JSON y deserializa de forma segura y tolerante a fallos.
//
// POR QUÉ:
// Droxy y los CRM empresariales extraen variables estructuradas de los chats.
// Nano necesita persistir este perfil de inteligencia comercial para alimentar
// el embudo de ventas, filtros de bandeja unificada y follow-ups automatizados.

library;

/// Calidad o temperatura del lead según su probabilidad de conversión.
enum LeadQuality {
  hot,
  warm,
  cold,
  unqualified;

  static LeadQuality fromString(String? val) {
    return switch (val?.toLowerCase().trim()) {
      'hot' || 'caliente' || 'alta' => LeadQuality.hot,
      'warm' || 'tibio' || 'media' => LeadQuality.warm,
      'cold' || 'frio' || 'baja' => LeadQuality.cold,
      _ => LeadQuality.unqualified,
    };
  }
}

/// Snapshot estructurado del análisis de una conversación.
final class ConversationIntelligenceProfile {
  final String conversationId;
  final LeadQuality leadQuality;
  final double? budgetMentioned;
  final String? currency;
  final bool urgent;
  final bool humanHandoffRequested;
  final List<String> productsOfInterest;
  final List<String> painPoints;
  final List<String> objections;
  final String nextRecommendedAction;
  final double confidenceScore;
  final DateTime extractedAt;

  const ConversationIntelligenceProfile({
    required this.conversationId,
    this.leadQuality = LeadQuality.unqualified,
    this.budgetMentioned,
    this.currency,
    this.urgent = false,
    this.humanHandoffRequested = false,
    this.productsOfInterest = const [],
    this.painPoints = const [],
    this.objections = const [],
    this.nextRecommendedAction = '',
    this.confidenceScore = 0.0,
    required this.extractedAt,
  });

  /// Factory inicial para conversaciones sin análisis previo.
  factory ConversationIntelligenceProfile.initial(String conversationId) {
    return ConversationIntelligenceProfile(
      conversationId: conversationId,
      extractedAt: DateTime.now(),
    );
  }

  ConversationIntelligenceProfile copyWith({
    String? conversationId,
    LeadQuality? leadQuality,
    double? budgetMentioned,
    String? currency,
    bool? urgent,
    bool? humanHandoffRequested,
    List<String>? productsOfInterest,
    List<String>? painPoints,
    List<String>? objections,
    String? nextRecommendedAction,
    double? confidenceScore,
    DateTime? extractedAt,
  }) {
    return ConversationIntelligenceProfile(
      conversationId: conversationId ?? this.conversationId,
      leadQuality: leadQuality ?? this.leadQuality,
      budgetMentioned: budgetMentioned ?? this.budgetMentioned,
      currency: currency ?? this.currency,
      urgent: urgent ?? this.urgent,
      humanHandoffRequested:
          humanHandoffRequested ?? this.humanHandoffRequested,
      productsOfInterest: productsOfInterest ?? this.productsOfInterest,
      painPoints: painPoints ?? this.painPoints,
      objections: objections ?? this.objections,
      nextRecommendedAction:
          nextRecommendedAction ?? this.nextRecommendedAction,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      extractedAt: extractedAt ?? this.extractedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'conversationId': conversationId,
    'leadQuality': leadQuality.name,
    'budgetMentioned': budgetMentioned,
    'currency': currency,
    'urgent': urgent,
    'humanHandoffRequested': humanHandoffRequested,
    'productsOfInterest': productsOfInterest,
    'painPoints': painPoints,
    'objections': objections,
    'nextRecommendedAction': nextRecommendedAction,
    'confidenceScore': confidenceScore,
    'extractedAt': extractedAt.toIso8601String(),
  };

  factory ConversationIntelligenceProfile.fromJson(Map<String, dynamic> json) {
    return ConversationIntelligenceProfile(
      conversationId: (json['conversationId'] as String?) ?? '',
      leadQuality: LeadQuality.fromString(json['leadQuality'] as String?),
      budgetMentioned: (json['budgetMentioned'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      urgent: (json['urgent'] as bool?) ?? false,
      humanHandoffRequested: (json['humanHandoffRequested'] as bool?) ?? false,
      productsOfInterest:
          (json['productsOfInterest'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      painPoints:
          (json['painPoints'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      objections:
          (json['objections'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      nextRecommendedAction:
          (json['nextRecommendedAction'] as String?) ?? '',
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
      extractedAt:
          DateTime.tryParse((json['extractedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
