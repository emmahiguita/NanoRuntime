// commercial_conversation_state_store.dart
//
// QUÉ HACE:
// Almacén persistente en SQLite de estados comerciales de conversación.
//
// CÓMO FUNCIONA:
// - Persiste atómicamente el estado del embudo, carrito y slots por conversationId.
// - Aplica fail-closed: si el registro no existe o está corrupto, inicia un estado limpio.
//
// POR QUÉ:
// Sobrevive a reinicios de Android, cierres de la app o interrupciones de red.

library;

import 'dart:convert';
import '../../storage/automation_db_store_client.dart';
import 'commercial_conversation_state.dart';

class CommercialConversationStateStore {
  const CommercialConversationStateStore();

  static const String _sectionPrefix = 'business_conv_state_';

  String _sectionFor(String conversationId) => '$_sectionPrefix$conversationId';

  /// Carga el estado de una conversación o retorna uno inicializado si es nueva.
  Future<CommercialConversationState> load(String conversationId) async {
    try {
      final raw = await AutomationDbStoreClient.instance.section(
        _sectionFor(conversationId),
      );
      if (raw == null || raw.isEmpty) {
        return CommercialConversationState(
          conversationId: conversationId,
          lastInteraction: DateTime.now(),
        );
      }
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return CommercialConversationState.fromJson(map);
    } catch (_) {
      return CommercialConversationState(
        conversationId: conversationId,
        lastInteraction: DateTime.now(),
      );
    }
  }

  /// Guarda atómicamente el estado actualizado.
  Future<bool> save(CommercialConversationState state) async {
    try {
      final encoded = jsonEncode(state.toJson());
      return await AutomationDbStoreClient.instance.putSection(
        _sectionFor(state.conversationId),
        encoded,
      );
    } catch (_) {
      return false;
    }
  }

  /// Limpia el estado tras completarse la compra o cerrarse la conversación.
  Future<bool> clear(String conversationId) async {
    try {
      return await AutomationDbStoreClient.instance.putSection(
        _sectionFor(conversationId),
        '',
      );
    } catch (_) {
      return false;
    }
  }
}
