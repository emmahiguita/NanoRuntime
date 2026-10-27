part of 'conversation_decision_engine.dart';

// QUÉ HACE: Detecta si la respuesta repite innecesariamente el nombre del contacto.
// CÓMO FUNCIONA: Normaliza ambos textos y aplica el mismo descuento de confianza.
// POR QUÉ: Evita un tono artificial sin bloquear una respuesta por un solo nombre.
double _repeatedContactNamePenalty({
  required String senderName,
  required String reply,
  required List<String> reasons,
}) {
  if (senderName.trim().isEmpty) return 0;
  final name = ConversationDecisionGuards.fold(senderName.trim());
  if (name.length < 3) return 0;
  final matches = RegExp(
    '\\b${RegExp.escape(name)}\\b',
  ).allMatches(ConversationDecisionGuards.fold(reply)).length;
  if (matches < 2) return 0;
  reasons.add('nombre del contacto repetido sin función ($matches×)');
  return 0.15;
}
