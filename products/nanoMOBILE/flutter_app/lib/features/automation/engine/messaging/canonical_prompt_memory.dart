import 'package:flutter/foundation.dart' show debugPrint;

import '../notifications/notification_object.dart';
import 'canonical_context_builder.dart';
import 'canonical_message.dart';
import 'conversation_memory_models.dart';
import 'prompt_history_quality.dart';

/// QUÉ: adapta mensajes canónicos al contrato que ya consume la inferencia.
/// CÓMO: una lectura acotada, sin mezclar RAM/SQL legacy ni fusionar por nombre.
/// POR QUÉ: comprensión, historial nativo y prompt deben usar la misma evidencia.
abstract final class CanonicalPromptMemory {
  static Future<ConversationMemory?> load({
    required String conversationId,
    required NotificationObject notification,
    ConversationMemory? previous,
  }) async {
    final CanonicalConversationContext context;
    try {
      context = await canonicalContextBuilder
          .build(conversationId: conversationId, recentLimit: 60)
          .timeout(const Duration(milliseconds: 1200));
    } on Object catch (error) {
      // El respaldo queda en el llamador; no lanza otra lectura canónica lenta.
      debugPrint('[ctx:canonical] unavailable=${error.runtimeType}');
      return null;
    }
    if (!context.hasStoredMessages && context.recentMessages.isEmpty) {
      return null;
    }

    final stamp = notification.messageTimestamp > 0
        ? notification.messageTimestamp
        : notification.postTime;
    final entries = <ConversationMemoryEntry>[];
    final seen = <String>{};
    var omitted = false;
    for (final message in context.recentMessages) {
      // Identidad exacta: no recupera otro chat por título o cercanía temporal.
      if (message.conversationId != conversationId ||
          message.occurredAtMs <= 0) {
        omitted = true;
        continue;
      }
      // El turno actual entra completo aparte. No borra otro «sí» cercano:
      // exige instante y contenido exactos y autor en conversaciones grupales.
      final isCurrent =
          message.direction == CanonicalMessageDirection.inbound &&
          ((stamp > 0 &&
                  message.occurredAtMs == stamp &&
                  message.body.trim() == notification.sourceText.trim() &&
                  (!notification.isGroup ||
                      message.sender == notification.sender)) ||
              notification.sourceFragments.any(
                (fragment) => fragment.matches(
                  message.body,
                  message.occurredAtMs,
                  message.sender,
                  group: notification.isGroup,
                ),
              ));
      if (isCurrent) continue;
      if (stamp > 0 && message.occurredAtMs > stamp) {
        omitted = true;
        continue;
      }
      final kind = _kind(message);
      if (kind == null) {
        // Un efecto desconocido no demuestra que se haya despachado texto.
        omitted = true;
        continue;
      }
      if (!seen.add('${message.provider.name}:${message.id}')) continue;
      final body = message.body.trim();
      final media = message.mediaType.trim();
      if (body.isEmpty && media.isEmpty) continue;
      entries.add(
        ConversationMemoryEntry(
          kind: kind,
          text: [
            if (body.isNotEmpty) body,
            if (media.isNotEmpty)
              '[Adjunto $media observado; contenido no interpretado]',
          ].join('\n'),
          sender: message.sender,
          atMs: message.occurredAtMs,
          eventId: message.id,
        ),
      );
    }
    entries.sort((a, b) => a.atMs.compareTo(b.atMs));
    final usableEntries = PromptHistoryQuality.filter(entries);
    omitted = omitted || usableEntries.length != entries.length;
    // La cobertura observada y la ventana enviada al modelo son cosas distintas.
    // Incluso cobertura completa no significa que todo el historial quepa aquí.
    final notice = [
      context.coverageReport.toPromptSummary(),
      'Contexto: ventana reciente canónica acotada; no es todo el historial.',
      if (context.hasKnownGaps || omitted)
        'Hay huecos o registros omitidos; no supongas lo que falta.',
      if (entries.any(
        (e) => e.kind == ConversationMemoryEntryKind.outboundDispatched,
      ))
        'Hay respuestas despachadas con entrega sin confirmar; no supongas que el contacto las recibió.',
    ].join('\n');
    debugPrint('[ctx:canonical] source=canonical entries=${entries.length}');
    return ConversationMemory(
      conversationId: conversationId,
      scopeId: previous?.scopeId ?? conversationId,
      agentId: previous?.agentId,
      entries: List.unmodifiable(usableEntries),
      lastAtMs: entries.isEmpty ? 0 : entries.last.atMs,
      lastManualInterventionMs: previous?.lastManualInterventionMs,
      canonicalHistory: true,
      historyNotice: notice,
    );
  }

  /// Distingue mensaje observado de envío pendiente; no inventa entrega/leído.
  static ConversationMemoryEntryKind? _kind(CanonicalMessage message) =>
      switch ((message.direction, message.deliveryState)) {
        (CanonicalMessageDirection.inbound, 'observed' || 'received') =>
          ConversationMemoryEntryKind.inbound,
        (CanonicalMessageDirection.outbound, 'verified') =>
          ConversationMemoryEntryKind.outboundVerified,
        (CanonicalMessageDirection.outbound, 'dispatched') =>
          ConversationMemoryEntryKind.outboundDispatched,
        (
          CanonicalMessageDirection.outbound,
          'observed' || 'manual' || 'sent' || 'delivered' || 'read',
        ) =>
          ConversationMemoryEntryKind.outboundObservedManual,
        _ => null,
      };
}
