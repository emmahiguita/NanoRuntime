part of 'notification_draft_writer.dart';

// QUÉ HACE: Declara el resultado tipado y la interfaz de escritura del borrador.
/// Fuente de borrador contextual. null = no se puede redactar hoy.
///
/// PERSONA-CORE-01 — devuelve el resultado COMPLETO, no solo el texto: el
/// entendimiento estructurado (intent/requiresAction/missingFacts) acompaña
/// al reply para que el DecisionEngine decida con señales verificables en
/// vez de descartarlas justo antes de necesitarlas.
typedef NotificationDraftSource =
    Future<NotificationDraftResult?> Function(NotificationObject notification);

/// Resultado del borrador contextual: reply listo para enviar + entendimiento
/// tipado que lo produjo.
final class NotificationDraftResult {
  /// Entendimiento estructurado del mensaje. Con el escalón de JSON roto
  /// (salida recortada por maxTokens) los campos no-reply quedan vacíos:
  /// honesto, jamás se inventa intent ni requiresAction.
  final ConversationUnderstanding understanding;

  /// Texto listo para enviar (recortado a 2000 chars; el reply del
  /// [understanding] queda SIN recortar para que la decisión vea el texto
  /// completo del modelo).
  final String reply;

  const NotificationDraftResult({
    required this.understanding,
    required this.reply,
  });

  bool get hasReply => reply.isNotEmpty;
}
