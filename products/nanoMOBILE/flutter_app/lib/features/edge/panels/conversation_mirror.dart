/// WA-MIRROR-01 — ConversationMirror: espejo de SOLO LECTURA de una
/// conversación sobre [ConversationMemoryStore] (+ LLM local opcional para
/// el resumen). Supera la limitación de no leer historial de WhatsApp
/// usando únicamente lo que Nano ya observa legalmente: eventos de
/// notificación en memoria + ScreenGraph (lo visible en pantalla).
/// NUNCA scraping del almacén de la app de mensajería.
///
/// Honestidad dura (misma de WA-MEM-08):
/// - Cada entrada conserva su [ConversationMemoryEntryKind] real:
///   outboundDispatched / effectUnknown jamás se presentan como "enviado".
/// - Resumen con LLM local bajo contrato estricto tipo Koog: salida
///   malformada (JSON, vacía, fuera de límite) o motor caído → abstain →
///   resumen determinista factual. Nunca inventa contenido.
/// - Cero escritura: el mirror no toca el store ni ningún canal.
///
/// Adaptación del plan (misma de EDGE-03): el overlay es Flutter-free, así
/// que el mirror produce DATOS (no Widgets); la presentación es del
/// consumidor. `search` devuelve [ConversationSearchHit] (entrada + score)
/// en lugar de la entrada cruda: el ranking es transparente.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/llm_engine_client.dart'
    show LLMEngineClient;
import 'package:nanoai/core/services/runtime_engine.dart'
    show runtimeEngineProvider;
import 'package:nanoai/features/automation/engine/agent_dependencies.dart'
    show conversationMemoryStoreProvider;
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_memory.dart';

import 'conversation_search.dart';

/// Vista factual del historial de una conversación: entradas + conteos por
/// kind. Nada se maquilla: el consumidor ve la honestidad tal cual.
final class ConversationMirrorData {
  const ConversationMirrorData({
    required this.conversationId,
    required this.entries,
    required this.lastAtMs,
    required this.inboundCount,
    required this.outboundVerifiedCount,
    required this.outboundDispatchedCount,
    required this.effectUnknownCount,
  });

  final String conversationId;

  /// Entradas en orden cronológico (las más recientes al final).
  final List<ConversationMemoryEntry> entries;
  final int lastAtMs;
  final int inboundCount;
  final int outboundVerifiedCount;
  final int outboundDispatchedCount;
  final int effectUnknownCount;

  bool get isEmpty => entries.isEmpty;
}

/// Resumen de la conversación. [llmGenerated] distingue el texto del modelo
/// del fallback determinista: honestidad de ORIGEN, no solo de contenido.
final class ConversationSummary {
  const ConversationSummary({required this.text, required this.llmGenerated});

  final String text;
  final bool llmGenerated;
}

/// Espejo de solo lectura. [llm] opcional (DIP): sin motor, el resumen es
/// determinista factual. Nunca lanza: toda degradación es un resultado
/// tipado (datos vacíos / resumen determinista), jamás una excepción.
final class ConversationMirror {
  const ConversationMirror({required this.store, this.llm});

  final ConversationMemoryStore store;
  final LLMEngineClient? llm;

  static const _search = ConversationSearch();

  /// Historial de la conversación identificada por [key]. Sin memoria
  /// observada devuelve datos vacíos (honesto), no null.
  Future<ConversationMirrorData> load(ConversationKey key) async {
    final memory = store.memoryFor(key.id);
    if (memory == null) {
      return ConversationMirrorData(
        conversationId: key.id,
        entries: const [],
        lastAtMs: 0,
        inboundCount: 0,
        outboundVerifiedCount: 0,
        outboundDispatchedCount: 0,
        effectUnknownCount: 0,
      );
    }
    return _data(memory);
  }

  /// Resumen acotado. LLM local si está disponible; si el modelo se abstiene
  /// (malformado) o el motor está caído, cae al resumen determinista
  /// factual. Ambos caminos devuelven texto; [ConversationSummary.llmGenerated]
  /// dice cuál fue.
  Future<ConversationSummary> summarize(ConversationKey key) async {
    final memory = store.memoryFor(key.id);
    if (memory == null || memory.isEmpty) {
      return const ConversationSummary(
        text: 'Sin conversación observada.',
        llmGenerated: false,
      );
    }
    final client = llm;
    if (client != null) {
      final fromLlm = await _tryLlm(client, memory);
      if (fromLlm != null) return fromLlm;
    }
    return ConversationSummary(
      text: _deterministicSummary(memory),
      llmGenerated: false,
    );
  }

  /// Búsqueda local sobre la memoria (sin LLM): [ConversationSearch].
  Future<List<ConversationSearchHit>> search(
    ConversationKey key,
    String query,
  ) async {
    final memory = store.memoryFor(key.id);
    if (memory == null) return const [];
    return _search.search(memory, query);
  }

  static ConversationMirrorData _data(ConversationMemory memory) {
    var inbound = 0;
    var verified = 0;
    var dispatched = 0;
    var uncertain = 0;
    for (final entry in memory.entries) {
      switch (entry.kind) {
        case ConversationMemoryEntryKind.inbound:
          inbound++;
        case ConversationMemoryEntryKind.outboundVerified:
          verified++;
        case ConversationMemoryEntryKind.outboundDispatched:
          dispatched++;
        case ConversationMemoryEntryKind.effectUnknown:
          uncertain++;
      }
    }
    return ConversationMirrorData(
      conversationId: memory.conversationId,
      entries: memory.entries,
      lastAtMs: memory.lastAtMs,
      inboundCount: inbound,
      outboundVerifiedCount: verified,
      outboundDispatchedCount: dispatched,
      effectUnknownCount: uncertain,
    );
  }

  /// Contrato estricto: prompt acotado (máx 30 entradas, texto truncado),
  /// temperatura 0, respuesta en prosa ≤ 400 chars. Salida vacía, JSON (el
  /// modelo copió datos en vez de resumir) o excepción → null → abstain.
  Future<ConversationSummary?> _tryLlm(
    LLMEngineClient client,
    ConversationMemory memory,
  ) async {
    final String text;
    try {
      final result = await client.generate(
        prompt: _buildPrompt(memory),
        temperature: 0.0,
        maxTokens: 96,
      );
      text = result.text.trim();
    } on Object {
      return null; // motor caído: abstención silenciosa, nunca lanza
    }
    if (text.isEmpty || text.length > 400) return null;
    try {
      jsonDecode(text);
      return null; // JSON = contrato violado (el mirror pide prosa)
    } on FormatException {
      // prosa libre: válida
    }
    return ConversationSummary(text: text, llmGenerated: true);
  }

  String _buildPrompt(ConversationMemory memory) {
    final lines = memory.entries.take(30).map((entry) {
      final snippet = entry.text.length > 160
          ? '${entry.text.substring(0, 160)}…'
          : entry.text;
      final who = entry.sender.isEmpty ? 'Nano' : entry.sender;
      return '- [${entry.kind.name}] $who: $snippet';
    }).join('\n');
    return 'Resume la siguiente conversación de mensajería en MÁXIMO 3 '
        'líneas de prosa. NO inventes mensajes que no aparezcan en el '
        'historial; si es ambiguo, dilo.\n'
        'Etiquetas: inbound = mensaje entrante observado; '
        'outboundVerified = envío verificado de Nano; '
        'outboundDispatched = envío despachado SIN verificar; '
        'effectUnknown = efecto incierto.\n'
        'Historial:\n$lines\n'
        'Responde SOLO con la prosa del resumen, sin JSON ni formato.';
  }

  /// Fallback factual tras abstain: conteos por kind + última entrada.
  /// Derivación determinista de la memoria — cero invención.
  static String _deterministicSummary(ConversationMemory memory) {
    var inbound = 0;
    var verified = 0;
    var dispatched = 0;
    var uncertain = 0;
    for (final entry in memory.entries) {
      switch (entry.kind) {
        case ConversationMemoryEntryKind.inbound:
          inbound++;
        case ConversationMemoryEntryKind.outboundVerified:
          verified++;
        case ConversationMemoryEntryKind.outboundDispatched:
          dispatched++;
        case ConversationMemoryEntryKind.effectUnknown:
          uncertain++;
      }
    }
    final last = memory.last;
    final lastLine = last == null
        ? ''
        : ' · Último (${_timeOf(last.atMs)}): '
              '${_kindLabel(last.kind)} "${_snippet(last.text)}"';
    return '${memory.entries.length} mensajes observados'
        ' ($inbound entrantes, $verified envíos verificados,'
        ' $dispatched despachados sin verificar,'
        ' $uncertain de efecto incierto)$lastLine.';
  }

  static String _kindLabel(ConversationMemoryEntryKind kind) => switch (kind) {
    ConversationMemoryEntryKind.inbound => 'entrante',
    ConversationMemoryEntryKind.outboundVerified => 'envío verificado',
    ConversationMemoryEntryKind.outboundDispatched => 'despachado sin verificar',
    ConversationMemoryEntryKind.effectUnknown => 'efecto incierto',
  };

  static String _snippet(String text) =>
      text.length <= 60 ? text : '${text.substring(0, 60)}…';

  static String _timeOf(int atMs) {
    final t = DateTime.fromMillisecondsSinceEpoch(atMs);
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Mirror de producción: store compartido del módulo + cliente del motor
/// local. Sin motor arrancado el resumen es determinista (honesto).
final conversationMirrorProvider = Provider<ConversationMirror>((ref) {
  final engineClient = ref.read(runtimeEngineProvider.notifier).client;
  return ConversationMirror(
    store: ref.watch(conversationMemoryStoreProvider),
    llm: engineClient,
  );
});
