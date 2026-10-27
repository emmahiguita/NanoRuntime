part of 'whatsapp_web_feed_provider.dart';

final _webPreviewPersistenceProvider =
    Provider.autoDispose<_WebPreviewPersistence>((ref) {
      final writer = _WebPreviewPersistence();
      ref.onDispose(writer.close);
      return writer;
    });

/// QUÉ: persiste previews Web con un solo recorrido activo y memoria acotada.
/// CÓMO: compara por chat y conserva un único snapshot pendiente mientras escribe.
/// POR QUÉ: cada emisión DOM antes iniciaba otro bucle completo sobre SQLite.
/// Los previews son evidencia parcial; el historial completo tiene su lector propio.
final class _WebPreviewPersistence {
  final _saved = <String, String>{};
  List<WhatsAppWebConversationSummary>? _pending;
  bool _running = false;
  bool _closed = false;

  void add(List<WhatsAppWebConversationSummary> items) {
    if (_closed) return;
    _pending = items;
    if (!_running) unawaited(_drain());
  }

  void close() {
    _closed = true;
    _pending = null;
    _saved.clear();
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (!_closed && _pending != null) {
        final items = _pending!;
        _pending = null;
        for (final item in items) {
          if (_closed) break;
          if (item.lastAtMs <= 0 || item.lastMessage.trim().isEmpty ||
              !WhatsAppWebMessageFilter.allows(
                conversationId: item.id,
                displayName: item.displayName,
                lastMessage: item.lastMessage,
              )) {
            continue;
          }
          final summary = _toConversationItem(item);
          final signature = jsonEncode([
            item.lastAtMs,
            item.lastMessage,
            item.displayName,
          ]);
          if (_saved[summary.conversationId] == signature) continue;
          try {
            await canonicalMessageStore.upsert(
              CanonicalMessage.observed(
                conversationId: summary.conversationId,
                provider: CanonicalMessageProvider.whatsappWeb,
                body: item.lastMessage,
                occurredAtMs: item.lastAtMs,
                sender: item.displayName,
                // Un preview no prueba quién escribió; no lo atribuye al contacto.
                direction: CanonicalMessageDirection.unknown,
                rawMetadata: {'source': 'visible_chat_preview'},
              ),
            );
            if (_closed) break;
            await canonicalMessageStore.recordCoverage(
              conversationId: summary.conversationId,
              provider: CanonicalMessageProvider.whatsappWeb,
              fromMs: item.lastAtMs,
              toMs: item.lastAtMs,
              gapBefore: true,
            );
            if (_closed) break;
            // Cache LRU pequeña: no retiene todos los chats visitados por sesión.
            _saved.remove(summary.conversationId);
            _saved[summary.conversationId] = signature;
            if (_saved.length > 200) _saved.remove(_saved.keys.first);
          } catch (error) {
            debugPrint(
              '[canonical:web] fallo de persistencia: ${error.runtimeType}',
            );
          }
        }
      }
    } finally {
      _running = false;
    }
  }
}
