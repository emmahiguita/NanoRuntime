// conversation_structured_extractor.dart
//
// QUÉ HACE:
// Extractor de datos estructurados e inteligencia comercial post-conversación.
//
// CÓMO FUNCIONA:
// 1. Genera prompts acotados con JSON Schema para modelos LLM (LanExecutor o Cloud).
// 2. Parsea respuestas LLM tolerando bloques de código markdown y JSON malformado.
// 3. Provee un extractor determinista de respaldo basado en regex y señales léxicas
//    que opera a coste $0, latencia < 2ms y sin dependencias de red o GPU.
//
// POR QUÉ:
// Droxy fuerza llamadas cloud caras para RAG extraction. Nano implementa arquitectura
// híbrida resiliente: extracción determinista instantánea + enriquecimiento LLM opcional.

library;

import 'dart:convert';
import '../business_facts.dart';
import '../../messaging/canonical_message.dart';
import 'conversation_intelligence_profile.dart';

class ConversationStructuredExtractor {
  const ConversationStructuredExtractor();

  static final RegExp _budgetRegex = RegExp(
    r'(?:\$|\bUSD|\bMXN|\bCOP|\bEUR)?\s*(\d{1,6}(?:[.,]\d{1,2})?)\s*(usd|mxn|cop|eur|pesos|dólares|dolares)?\b',
    caseSensitive: false,
  );

  static const _urgencyTokens = {
    'urgente', 'urgencia', 'hoy mismo', 'lo antes posible', 'asap', 'inmediato', 'ya'
  };

  static const _humanTokens = {
    'humano', 'asesor', 'persona', 'operador', 'agente', 'representante'
  };

  static const _objectionTokens = {
    'caro', 'costoso', 'presupuesto', 'descuento', 'rebaja', 'demora', 'tardan'
  };

  static const _painTokens = {
    'problema', 'no funciona', 'falla', 'urgencia', 'necesito ayuda', 'dañado', 'roto'
  };

  /// Construye el prompt con esquema JSON estricto para extracción con LLM.
  String buildExtractionPrompt(List<CanonicalMessage> messages) {
    final buffer = StringBuffer(
      'Analiza la siguiente conversación y extrae la inteligencia comercial en formato JSON puro:\n'
      '{\n'
      '  "leadQuality": "hot" | "warm" | "cold" | "unqualified",\n'
      '  "budgetMentioned": number | null,\n'
      '  "currency": string | null,\n'
      '  "urgent": boolean,\n'
      '  "humanHandoffRequested": boolean,\n'
      '  "productsOfInterest": string[],\n'
      '  "painPoints": string[],\n'
      '  "objections": string[],\n'
      '  "nextRecommendedAction": string,\n'
      '  "confidenceScore": number\n'
      '}\n\n'
      'Historial:\n',
    );
    for (final m in messages.take(20)) {
      final role = m.direction == CanonicalMessageDirection.outbound ? 'Nano' : 'Cliente';
      buffer.writeln('$role: ${m.body}');
    }
    return buffer.toString();
  }

  /// Parsea la respuesta del LLM aislando bloques JSON incluso con formato markdown.
  ConversationIntelligenceProfile parseLlmResponse(
    String rawResponse, {
    required String conversationId,
    ConversationIntelligenceProfile? fallback,
  }) {
    try {
      var clean = rawResponse.trim();
      if (clean.contains('```json')) {
        clean = clean.split('```json')[1].split('```')[0].trim();
      } else if (clean.contains('```')) {
        clean = clean.split('```')[1].split('```')[0].trim();
      }
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        clean = clean.substring(start, end + 1);
      }
      final map = (jsonDecode(clean) as Map).cast<String, dynamic>();
      map['conversationId'] = conversationId;
      return ConversationIntelligenceProfile.fromJson(map);
    } catch (_) {
      return fallback ?? ConversationIntelligenceProfile.initial(conversationId);
    }
  }

  /// Extractor determinista y resiliente de coste $0 y latencia < 2ms.
  ConversationIntelligenceProfile extractDeterministic({
    required String conversationId,
    required List<CanonicalMessage> messages,
    BusinessFacts? facts,
  }) {
    final fullText = messages.map((m) => m.body.toLowerCase()).join(' ');
    double? budget;
    String? currency;

    final budgetMatch = _budgetRegex.firstMatch(fullText);
    if (budgetMatch != null) {
      final numStr = budgetMatch.group(1)?.replaceAll(',', '.');
      budget = double.tryParse(numStr ?? '');
      currency = budgetMatch.group(2)?.toUpperCase();
    }

    final urgent = _urgencyTokens.any((t) => fullText.contains(t));
    final human = _humanTokens.any((t) => fullText.contains(t));
    final objections = _objectionTokens.where((t) => fullText.contains(t)).toList();
    final painPoints = _painTokens.where((t) => fullText.contains(t)).toList();

    final products = <String>[];
    if (facts != null) {
      for (final p in facts.products) {
        if (p.isAvailable && fullText.contains(p.name.toLowerCase())) {
          products.add(p.name);
        }
      }
    }

    final LeadQuality quality;
    if (budget != null || (urgent && products.isNotEmpty)) {
      quality = LeadQuality.hot;
    } else if (products.isNotEmpty || human || messages.length >= 3) {
      quality = LeadQuality.warm;
    } else if (messages.isNotEmpty) {
      quality = LeadQuality.cold;
    } else {
      quality = LeadQuality.unqualified;
    }

    final action = switch (quality) {
      LeadQuality.hot => human
          ? 'Escalar a asesor humano con máxima prioridad (Lead Caliente)'
          : 'Enviar cotización formal o enlace de pago para ${products.isNotEmpty ? products.first : "el pedido"}',
      LeadQuality.warm => products.isNotEmpty
          ? 'Compartir ficha técnica o catálogo de ${products.join(", ")}'
          : 'Profundizar en la necesidad del cliente con preguntas guiadas',
      LeadQuality.cold => 'Enviar mensaje de reactivación suave con catálogo general',
      LeadQuality.unqualified => 'Marcar como lead no cualificado o descartar',
    };

    return ConversationIntelligenceProfile(
      conversationId: conversationId,
      leadQuality: quality,
      budgetMentioned: budget,
      currency: currency,
      urgent: urgent,
      humanHandoffRequested: human,
      productsOfInterest: products,
      painPoints: painPoints,
      objections: objections,
      nextRecommendedAction: action,
      confidenceScore: budget != null || products.isNotEmpty ? 0.9 : 0.7,
      extractedAt: DateTime.now(),
    );
  }
}
