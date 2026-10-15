/// Contexto acotado del modelo: reciente + resumen + hechos, nunca todo el DOM.
library;

import 'canonical_message.dart';
import 'canonical_message_store.dart';

final class CanonicalConversationContext {
  final String promptBlock;
  final List<CanonicalMessage> recentMessages;
  final List<ConversationCoverage> coverage;
  final bool hasKnownGaps;

  const CanonicalConversationContext({
    required this.promptBlock,
    required this.recentMessages,
    required this.coverage,
    required this.hasKnownGaps,
  });
}

final class CanonicalContextBuilder {
  final CanonicalMessageStore store;
  const CanonicalContextBuilder({required this.store});

  Future<CanonicalConversationContext> build({
    required String conversationId,
    String historicalSummary = '',
    Iterable<String> persistentFacts = const [],
    int recentLimit = 24,
    int maxChars = 6000,
  }) async {
    final messages = await store.list(
      conversationId,
      limit: recentLimit.clamp(1, 60),
    );
    final coverage = await store.coverage(conversationId);
    final gaps = coverage.isEmpty || coverage.any((item) => item.gapBefore);
    final buffer = StringBuffer('<CONTEXTO_CANONICO>\n');
    if (historicalSummary.trim().isNotEmpty) {
      buffer.writeln('Resumen: ${historicalSummary.trim()}');
    }
    final facts = persistentFacts
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(20);
    if (facts.isNotEmpty) buffer.writeln('Hechos:\n- ${facts.join('\n- ')}');
    buffer.writeln(
      gaps
          ? 'Cobertura: parcial; existen huecos conocidos.'
          : 'Cobertura: continua en la ventana registrada.',
    );
    buffer.writeln('Mensajes recientes:');
    for (final message in messages.reversed) {
      final speaker = switch (message.direction) {
        CanonicalMessageDirection.outbound => 'Nano',
        CanonicalMessageDirection.inbound =>
          message.sender.isEmpty ? 'Contacto' : message.sender,
        CanonicalMessageDirection.unknown => 'Desconocido',
      };
      final media = message.mediaType.isEmpty ? '' : ' [${message.mediaType}]';
      final line = '$speaker$media: ${message.body}';
      if (buffer.length + line.length + 22 > maxChars) break;
      buffer.writeln(line);
    }
    buffer.write('</CONTEXTO_CANONICO>');
    return CanonicalConversationContext(
      promptBlock: buffer.toString(),
      recentMessages: messages,
      coverage: coverage,
      hasKnownGaps: gaps,
    );
  }
}

final canonicalContextBuilder = CanonicalContextBuilder(
  store: canonicalMessageStore,
);
