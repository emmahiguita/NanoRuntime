part of 'meta_inbox_controller.dart';

/// Confirma escritura antes de permitir avanzar el cursor; conserva autor?a.
extension _MetaInboxPersistence on MetaInboxController {
  Future<void> _persistCanonical(MetaInboxMessage event) async {
    final atMs =
        event.providerTime?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;
    final account = _scope;
    if (account == null || account.isEmpty) return;
    final conversationId =
        'meta/${Uri.encodeComponent(account)}/${Uri.encodeComponent(event.peerId)}';
    final observed = CanonicalMessage.observed(
      conversationId: conversationId,
      provider: CanonicalMessageProvider.metaCloud,
      providerMessageId: event.wamid,
      body: event.text ?? event.caption ?? '',
      mediaType: event.type ?? '',
      occurredAtMs: atMs,
      sender: event.isOutbound ? 'Cuenta' : event.peerId,
      direction: event.isOutbound
          ? CanonicalMessageDirection.outbound
          : CanonicalMessageDirection.inbound,
      rawMetadata: {
        'sequence': event.sequence,
        'source': event.source,
        'accountId': account,
        'sourceChatId': event.peerId,
        'evidenceLevel': 'source_observed',
        'complete': true,
      },
    );
    final saved = await canonicalMessageStore.upsert(
      CanonicalMessage.fromPlatformMap({
        ...observed.toPlatformMap(),
        'deliveryState': event.deliveryState,
      }),
    );
    if (!saved) throw StateError('No se pudo guardar el historial local.');
    final covered = await canonicalMessageStore.recordCoverage(
      conversationId: conversationId,
      provider: CanonicalMessageProvider.metaCloud,
      fromMs: atMs,
      toMs: atMs,
      gapBefore: nextBefore != null,
    );
    if (!covered) throw StateError('No se pudo confirmar la cobertura local.');
  }
}
