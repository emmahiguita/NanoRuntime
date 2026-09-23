/// QUÉ HACE:
/// Administra y persiste el estado conversacional del cliente (memoria de productos,
/// preguntas pendientes y hebras multitema activas).
///
/// CÓMO FUNCIONA:
/// Exporta los modelos y compuertas de gating. [ConversationStateNotifier] procesa
/// cada turno para actualizar el producto consultado, detectar preguntas abiertas
/// que esperan respuesta del usuario, y actualizar hebras de obligaciones activas.
///
/// POR QUÉ:
/// Permite que Nano mantenga coherencia conversacional a lo largo de múltiples turnos,
/// sabiendo exactamente si hay una compra en curso, qué información falta y qué
/// se confirmó, todo con persistencia determinista en base de datos.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../business/business_facts.dart';
import '../business/fact_selector.dart';
import '../storage/automation_db_store_client.dart';
import 'conv_turn_state_models.dart';

export 'conv_turn_state_gating.dart';
export 'conv_turn_state_models.dart';

/// Almacenamiento persistente del estado conversacional en AutomationDbStore.
class ConversationStateStore {
  const ConversationStateStore();
  static const section = 'convstate';

  Future<Map<String, ClientContextEntry>> load() async {
    try {
      final raw = await AutomationDbStoreClient.instance.section(section);
      if (raw == null || raw.isEmpty) return const {};
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return {
        for (final e in map.entries)
          e.key: ClientContextEntry.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          ),
      };
    } on Object {
      return const {};
    }
  }

  Future<bool> save(Map<String, ClientContextEntry> state) =>
      AutomationDbStoreClient.instance.putSection(
        section,
        jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}),
      );
}

/// Gestor de estado conversacional con Riverpod.
final class ConversationStateNotifier
    extends StateNotifier<Map<String, ClientContextEntry>> {
  ConversationStateNotifier(this._store) : super(const {});

  final ConversationStateStore _store;
  Future<void>? _loading;

  Future<void> get ready => _loading ??= _load();

  Future<void> _load() async {
    try {
      state = await _store.load();
    } on Object catch (_) {}
  }

  /// Registra el turno conversacional y actualiza el hilo de intenciones.
  Future<void> recordTurn({
    required String conversationId,
    required String userText,
    required String nanoReply,
    required BusinessFacts facts,
    bool correction = false,
    List<ClientTopicThread> newThreads = const [],
  }) async {
    if (conversationId.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = state[conversationId];
    final selection = selectFactsForMessage(userText, facts);

    final product = correction
        ? null
        : selection.products.isEmpty
        ? existing?.product
        : ClientProductContext(
            name: selection.products.first.name,
            details: selection.products.first.details,
            priceLabel: selection.products.first.priceLabel,
            atMs: now,
          );

    final pendingQuestion = _pendingQuestionFrom(nanoReply);
    final entry = ClientContextEntry(
      product: product,
      pendingQuestion: pendingQuestion,
      pendingKind: _pendingKindFor(pendingQuestion),
      openThreads: correction
          ? const []
          : newThreads.isNotEmpty
          ? newThreads
          : existing?.openThreads ?? const [],
      topicStatus: correction
          ? ''
          : _topicStatusFor(
              userText,
              hasProductMatch: selection.products.isNotEmpty,
              previous: existing?.topicStatus ?? '',
            ),
      atMs: now,
    );
    state = {...state, conversationId: entry};
    await _store.save(state);
  }

  static String _pendingQuestionFrom(String nanoReply) {
    final reply = nanoReply.trim();
    if (!reply.contains('?')) return '';
    final asked = normalizeText(reply).split('?').first.toLowerCase();
    if (_courtesyQuestions.any(asked.contains)) return '';
    if (!_expectationTokens.any(asked.contains)) return '';
    return reply.length <= 160 ? reply : reply.substring(0, 160);
  }

  static const Set<String> _courtesyQuestions = {
    'en que puedo ayudarte', 'como estas', 'como te va', 'no te parece',
    'que necesitas', 'te ayudo', 'que tal',
  };

  static const List<String> _expectationTokens = [
    'quieres', 'cuantos', 'cuantas', 'talla', 'color', 'fecha', 'confirma',
    'confirmo', 'deseas', 'te gustaria', 'cantidad', 'cuando', 'donde',
    'cuanto', 'reviso', 'te envio', 'que dia', 'te parece', 'prefieres',
    'prefieren', 'medida', 'medidas', 'numero', 'numeros', 'direccion',
    'hora', 'horario', 'entrega',
  ];

  static const Set<String> _confirmExpectationTokens = {
    'quieres', 'deseas', 'confirma', 'confirmo', 'te gustaria', 'reviso',
    'te envio', 'te parece',
  };

  static const Set<String> _valueExpectationTokens = {
    'cuantos', 'cuantas', 'talla', 'color', 'fecha', 'cantidad', 'cuando',
    'donde', 'cuanto', 'que dia', 'prefieres', 'prefieren', 'medida',
    'medidas', 'numero', 'numeros', 'direccion', 'hora', 'horario', 'entrega',
  };

  static String _pendingKindFor(String pendingQuestion) {
    final q = normalizeText(pendingQuestion);
    if (_confirmExpectationTokens.any(q.contains)) return 'confirm';
    if (_valueExpectationTokens.any(q.contains)) return 'value';
    return '';
  }

  static String _topicStatusFor(
    String userText, {
    required bool hasProductMatch,
    required String previous,
  }) {
    if (hasProductMatch) return 'active';
    final tokens = tokenizeText(normalizeText(userText));
    if (tokens.contains('gracias') || tokens.contains('perfecto')) {
      return 'resolved';
    }
    return previous;
  }
}

final conversationStateStoreProvider = Provider<ConversationStateStore>(
  (ref) => const ConversationStateStore(),
);

final conversationStateNotifierProvider = StateNotifierProvider<
  ConversationStateNotifier,
  Map<String, ClientContextEntry>
>((ref) {
  final notifier = ConversationStateNotifier(
    ref.watch(conversationStateStoreProvider),
  );
  notifier.ready;
  return notifier;
});
