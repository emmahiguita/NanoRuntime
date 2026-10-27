// canonical_context_builder.dart
//
// QUÉ HACE:
// Construye el contexto canónico acotado del modelo (mensajes recientes, resumen,
// hechos persistentes, reporte exacto de cobertura/huecos e inteligencia comercial).
//
// CÓMO FUNCIONA:
// - Consulta los últimos mensajes de [CanonicalMessageStore] y su cobertura temporal.
// - Ejecuta [ConversationCoverageAnalyzer] para consolidar ventanas y detectar huecos.
// - Ejecuta [ConversationStructuredExtractor] para enriquecer el contexto con calificación
//   de lead, presupuesto, urgencia y objeciones detectadas.
//
// POR QUÉ:
// Completa los Puntos 4 y 9: el modelo recibe evidencia estructurada, acotada en
// caracteres y consciente de huecos históricos sin volcar todo el DOM.

library;

import '../business/business_facts.dart';
import '../business/intelligence/conversation_intelligence_profile.dart';
import '../business/intelligence/conversation_structured_extractor.dart';
import 'canonical_message.dart';
import 'canonical_message_store.dart';
import 'conversation_coverage_analyzer.dart';

final class CanonicalConversationContext {
  final String promptBlock;
  final List<CanonicalMessage> recentMessages;
  final List<ConversationCoverage> coverage;
  final ConversationCoverageReport coverageReport;
  final ConversationIntelligenceProfile intelligenceProfile;
  final bool hasKnownGaps;
  // Distingue un almacén vacío de filas rechazadas por falta de evidencia.
  // Así el respaldo legacy no vuelve a introducir mensajes en cuarentena.
  final bool hasStoredMessages;

  const CanonicalConversationContext({
    required this.promptBlock,
    required this.recentMessages,
    required this.coverage,
    required this.coverageReport,
    required this.intelligenceProfile,
    required this.hasKnownGaps,
    this.hasStoredMessages = false,
  });
}

final class CanonicalContextBuilder {
  final CanonicalMessageStore store;
  final ConversationCoverageAnalyzer coverageAnalyzer;
  final ConversationStructuredExtractor structuredExtractor;

  const CanonicalContextBuilder({
    required this.store,
    this.coverageAnalyzer = const ConversationCoverageAnalyzer(),
    this.structuredExtractor = const ConversationStructuredExtractor(),
  });

  Future<CanonicalConversationContext> build({
    required String conversationId,
    String historicalSummary = '',
    Iterable<String> persistentFacts = const [],
    BusinessFacts? businessFacts,
    int recentLimit = 24,
    int maxChars = 6000,
  }) async {
    final messages = await store.list(
      conversationId,
      limit: recentLimit.clamp(1, 60),
    );
    final coverage = await store.coverage(conversationId);
    final report = coverageAnalyzer.analyze(coverage);
    // SQLite ya devuelve ascendente; ordenar explícitamente mantiene el
    // contrato también con otros adaptadores sin invertir la conversación.
    // La misma cuarentena del panel se aplica al prompt: un legado no verificado
    // no debe convertirse en un hecho recordado por el modelo.
    final webMessageId = RegExp(r'^(true|false)_.+');
    final verified = messages
        .where(
          (message) =>
              message.provider != CanonicalMessageProvider.whatsappWeb ||
              (message.rawMetadata['source'] == 'dom_verified_v1' &&
                  webMessageId.hasMatch(message.providerMessageId)),
        )
        .toList();
    final chronological = [...verified]
      ..sort((a, b) => a.occurredAtMs.compareTo(b.occurredAtMs));
    final intel = structuredExtractor.extractDeterministic(
      conversationId: conversationId,
      messages: chronological,
      facts: businessFacts,
    );

    final buffer = StringBuffer('<CONTEXTO_CANONICO>\n');
    if (verified.length != messages.length) {
      buffer.writeln(
        'Cobertura parcial: se omitieron registros Web heredados sin verificación.',
      );
    }
    if (historicalSummary.trim().isNotEmpty) {
      buffer.writeln('Resumen: ${historicalSummary.trim()}');
    }
    final facts = persistentFacts
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(20);
    if (facts.isNotEmpty) {
      buffer.writeln('Hechos:\n- ${facts.join('\n- ')}');
    }
    buffer.writeln(report.toPromptSummary());
    if (intel.leadQuality != LeadQuality.unqualified) {
      buffer.writeln(
        'Inteligencia: lead=${intel.leadQuality.name}'
        '${intel.budgetMentioned != null ? ', presupuesto=${intel.budgetMentioned} ${intel.currency ?? ''}'.trimRight() : ''}'
        '${intel.urgent ? ', urgente=si' : ''}'
        '${intel.objections.isNotEmpty ? ', objeciones=${intel.objections.join('/')}' : ''}',
      );
    }
    buffer.writeln('Mensajes recientes:');
    // Prioriza el final de la conversación bajo el presupuesto; después vuelve
    // al orden cronológico. Antes un mensaje largo antiguo excluía los recientes.
    const closing = '</CONTEXTO_CANONICO>';
    final budget = maxChars.clamp(256, 12000);
    final prefix = buffer.toString();
    final header = prefix.length > budget ~/ 2
        ? prefix.substring(0, budget ~/ 2)
        : prefix;
    var remaining = budget - header.length - closing.length;
    final lines = <String>[];
    for (final message in chronological.reversed) {
      final speaker = switch (message.direction) {
        // Observado como saliente no demuestra que lo haya escrito la IA.
        CanonicalMessageDirection.outbound => 'Cuenta',
        CanonicalMessageDirection.inbound =>
          message.sender.isEmpty ? 'Contacto' : message.sender,
        CanonicalMessageDirection.unknown => 'Desconocido',
      };
      final media = message.mediaType.isEmpty ? '' : ' [${message.mediaType}]';
      final line = '$speaker$media: ${message.body}\n';
      if (remaining <= 0) break;
      final selected = line.length > remaining
          ? '${line.substring(0, remaining - 1)}\n'
          : line;
      lines.add(selected);
      remaining -= selected.length;
    }
    final promptBlock = '$header${lines.reversed.join()}$closing';

    return CanonicalConversationContext(
      promptBlock: promptBlock,
      recentMessages: verified,
      coverage: coverage,
      coverageReport: report,
      intelligenceProfile: intel,
      hasKnownGaps: report.hasKnownGaps || verified.length != messages.length,
      hasStoredMessages: messages.isNotEmpty,
    );
  }
}

final canonicalContextBuilder = CanonicalContextBuilder(
  store: canonicalMessageStore,
);
