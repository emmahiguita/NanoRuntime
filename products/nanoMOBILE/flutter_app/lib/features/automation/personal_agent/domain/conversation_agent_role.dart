// conversation_agent_role.dart
//
// QUÉ HACE:
// Define el rol de especialización conversacional del turno (personal, sales, support, general)
// y el algoritmo de enrutamiento determinista `routeConversationAgent`.
//
// CÓMO FUNCIONA:
// - Evalúa en estricto orden de prioridad: corrección > identidad > rechazo > soporte > WhatsApp Business >
//   intención comercial (producto + hechos) > saludo puro > turnos dependientes > respuestas cortas > general.
// - Re-exporta los tokens y clasificadores de mensajes para mantener retrocompatibilidad total del 100%.
//
// POR QUÉ:
// Aplica Clean Architecture y modularidad estricta garantizando que el archivo tenga < 190 líneas.

library;

import '../../engine/business/business_facts.dart';
import '../../engine/business/fact_selector.dart'
    show normalizeText, selectFactsForMessage, tokenizeText;
import '../../engine/messaging/conv_turn_state.dart'
    show contextSignalsFor, greetingTokens;
import 'conversation_agent_message_classifier.dart';
import 'conversation_agent_tokens.dart';

export 'conversation_agent_message_classifier.dart';
export 'conversation_agent_tokens.dart';

/// Especialización que atiende el turno conversacional.
enum ConversationAgentRole {
  personal,
  sales,
  support,
  general,
}

/// Resultado de enrutamiento del turno: rol asignado, trazas y flags de intención.
final class ConversationAgentRouting {
  final ConversationAgentRole role;
  final List<String> reasons;
  final bool commercialIntent;
  final bool pendingReply;

  const ConversationAgentRouting({
    required this.role,
    required this.reasons,
    this.commercialIntent = false,
    this.pendingReply = false,
  });
}

/// Enrutador determinista del agente conversacional por turno.
ConversationAgentRouting routeConversationAgent({
  required String messageText,
  required BusinessFacts facts,
  required bool hasRelationship,
  required bool hasActiveProduct,
  String ownerName = '',
  bool hasPendingQuestion = false,
  bool isBusinessChannel = false,
}) {
  final reasons = <String>[];
  final normalized = normalizeText(messageText);
  final tokens = tokenizeText(normalized);
  final signals = contextSignalsFor(messageText, facts);
  final factsSelection = selectFactsForMessage(messageText, facts);
  final hasBusinessFactsMatch = factsSelection.isNotEmpty && !facts.isEmpty;

  final hasExplicitCommercialSignal =
      (signals.explicitProduct && tokens.any(commercialIntentTokens.contains)) ||
      hasBusinessFactsMatch ||
      tokens.any((t) => t == 'servicio' || t == 'servicios' || t == 'cotizar' || t == 'cotizacion' || t == 'catalogo' || t == 'comprar' || t == 'pedido');

  final commercialIntent = hasExplicitCommercialSignal;

  if (correctionPhrases.any(normalized.contains)) {
    reasons.add('corrección del cliente (meta-conversación)');
    return ConversationAgentRouting(role: ConversationAgentRole.personal, reasons: reasons);
  }

  if (!isBusinessChannel) {
    final ownerToken = ownerName.trim().split(' ').first.toLowerCase();
    if (ownerToken.length >= 3 && tokens.contains(ownerToken)) {
      reasons.add('menciona al dueño por nombre (identidad)');
      return ConversationAgentRouting(
        role: ConversationAgentRole.personal,
        reasons: reasons,
        commercialIntent: commercialIntent,
      );
    }
  }

  if (tokens.contains('no') &&
      (tokens.contains('quiero') || tokens.contains('necesito')) &&
      tokens.any((t) => t.startsWith('ayud'))) {
    reasons.add('rechazo de ayuda (social)');
    return ConversationAgentRouting(role: ConversationAgentRole.personal, reasons: reasons);
  }

  if (supportPhrases.any(normalized.contains)) {
    reasons.add('queja o problema de pedido');
    return ConversationAgentRouting(role: ConversationAgentRole.support, reasons: reasons);
  }

  // REGLA CRÍTICA NANO NEGOCIO: Saludos aislados NUNCA activan modo comercial ni ventas.
  if (isGreetingLikeMessage(messageText)) {
    reasons.add(isBusinessChannel
        ? 'saludo en canal comercial (sin solicitud de producto/servicio)'
        : 'saludo puro (social)');
    return ConversationAgentRouting(
      role: isBusinessChannel ? ConversationAgentRole.general : ConversationAgentRole.personal,
      reasons: reasons,
      commercialIntent: false,
    );
  }

  // ACTIVACIÓN NANO NEGOCIO: Solo cuando hay solicitud real de producto, servicio o datos comerciales.
  if (hasExplicitCommercialSignal) {
    reasons.add(hasBusinessFactsMatch
        ? 'consulta sobre datos/hechos del negocio'
        : 'solicitud de producto/servicio');
    return ConversationAgentRouting(role: ConversationAgentRole.sales, reasons: reasons, commercialIntent: true);
  }

  if (isBusinessChannel) {
    reasons.add('canal comercial WhatsApp Business');
    return ConversationAgentRouting(role: ConversationAgentRole.sales, reasons: reasons, commercialIntent: true);
  }

  if (signals.explicitProduct) {
    reasons.add(productMentionedWithoutCommerce);
  }

  if (hasActiveProduct && (signals.reference || signals.dependent)) {
    reasons.add('referencia o respuesta corta sobre el producto activo');
    return ConversationAgentRouting(role: ConversationAgentRole.sales, reasons: reasons, commercialIntent: commercialIntent);
  }

  if (hasPendingQuestion && tokens.isNotEmpty && tokens.length <= 3 && !commercialIntent) {
    if (signals.explicitProduct) {
      reasons.add('elección de producto respondiendo la pregunta pendiente');
      return ConversationAgentRouting(role: ConversationAgentRole.sales, reasons: reasons, commercialIntent: commercialIntent);
    }
    reasons.add('respuesta a la pregunta pendiente de Nano');
    return ConversationAgentRouting(role: ConversationAgentRole.personal, reasons: reasons, commercialIntent: commercialIntent, pendingReply: true);
  }

  final allCasual = tokens.isNotEmpty && tokens.length <= 3 && tokens.every((t) => greetingTokens.contains(t) || socialCasualTokens.contains(t));
  if (allCasual) {
    reasons.add('social casual corto');
    return ConversationAgentRouting(role: ConversationAgentRole.personal, reasons: reasons, commercialIntent: commercialIntent);
  }

  if (isLooseLaughterMessage(messageText)) {
    reasons.add('risa (patrón desordenado)');
    return ConversationAgentRouting(role: ConversationAgentRole.personal, reasons: reasons, commercialIntent: commercialIntent);
  }

  if (tokens.any(socialReactionTokens.contains)) {
    reasons.add('reacción social (continuación)');
    return ConversationAgentRouting(role: ConversationAgentRole.personal, reasons: reasons, commercialIntent: commercialIntent);
  }

  final familyMention = tokens.any(familyTokens.contains) && tokens.any(presenceVerbs.contains);
  if (familyMention) {
    reasons.add('familia del dueño con verbo de presencia');
    return ConversationAgentRouting(role: ConversationAgentRole.personal, reasons: reasons, commercialIntent: commercialIntent);
  }

  if (hasRelationship) {
    reasons.add('relación registrada sin señal comercial');
    return ConversationAgentRouting(role: ConversationAgentRole.personal, reasons: reasons, commercialIntent: commercialIntent);
  }

  reasons.add('sin señales específicas');
  return ConversationAgentRouting(role: ConversationAgentRole.general, reasons: reasons, commercialIntent: commercialIntent);
}
