// commercial_action_parser.dart
//
// QUÉ HACE:
// Parser robusto y tolerante a fallos para transformar la respuesta generada
// por el SLM o expresiones regulares en instancias de `CommercialStructuredAction`.
//
// CÓMO FUNCIONA:
// - Intenta decodificación JSON directa.
// - Si el modelo produce texto con bloques markdown ```json ... ```, extrae el bloque.
// - Aplica fail-closed: si el formato es inválido, retorna `EscalateToHumanAction`.
//
// POR QUÉ:
// Evita excepciones no controladas y garantiza que el flujo siempre reciba una acción tipada.

library;

import 'dart:convert';
import 'commercial_structured_action.dart';

class CommercialActionParser {
  const CommercialActionParser();

  /// Parsea una cadena de texto a `CommercialStructuredAction`.
  CommercialStructuredAction parse(String rawOutput) {
    final cleaned = rawOutput.trim();
    if (cleaned.isEmpty) {
      return const EscalateToHumanAction(
        reason: 'Salida de modelo vacía',
      );
    }

    try {
      final jsonMap = _extractJsonMap(cleaned);
      if (jsonMap != null) {
        return _fromMap(jsonMap);
      }
    } catch (_) {
      // Fallback a escalamiento si hay error de formato
    }

    return EscalateToHumanAction(
      reason: 'No se pudo estructurar la acción comercial',
      customerInquiry: cleaned.length > 100 ? cleaned.substring(0, 100) : cleaned,
    );
  }

  Map<String, dynamic>? _extractJsonMap(String text) {
    if (text.startsWith('{') && text.endsWith('}')) {
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    }

    // Buscar bloque de código ```json ... ```
    final match = RegExp(r'```(?:json)?\s*(\{.*?\})\s*```', dotAll: true).firstMatch(text);
    if (match != null) {
      final rawJson = match.group(1)!;
      return (jsonDecode(rawJson) as Map).cast<String, dynamic>();
    }

    // Buscar cualquier substring delimitado por llaves { ... }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      final substring = text.substring(start, end + 1);
      return (jsonDecode(substring) as Map).cast<String, dynamic>();
    }

    return null;
  }

  CommercialStructuredAction _fromMap(Map<String, dynamic> map) {
    final action = (map['action'] as String?)?.toLowerCase().trim() ?? '';
    return switch (action) {
      'price_query' => PriceQueryAction.fromJson(map),
      'stock_query' => StockQueryAction.fromJson(map),
      'catalog_query' => CatalogQueryAction.fromJson(map),
      'add_to_cart' => AddToCartAction.fromJson(map),
      'payment_claim' => PaymentClaimAction.fromJson(map),
      'policy_query' => PolicyQueryAction.fromJson(map),
      'escalate_to_human' => EscalateToHumanAction.fromJson(map),
      _ => EscalateToHumanAction(
          reason: 'Acción comercial no reconocida: $action',
        ),
    };
  }
}
