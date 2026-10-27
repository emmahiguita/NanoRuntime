// conversation_intelligence_store.dart
//
// QUÉ HACE:
// Almacén persistente en SQLite de perfiles de inteligencia comercial.
//
// CÓMO FUNCIONA:
// - Persiste atómicamente el perfil de calificación de lead y variables estructuradas
//   bajo la clave con prefijo `business_intel_<conversationId>`.
// - Soporta carga asíncrona, guardado y eliminación en caso de descarte.
//
// POR QUÉ:
// Asegura que las calificaciones comerciales sobrevivan reinicios y estén disponibles
// para los filtros de Inbox, CRM y despachador de campañas de seguimiento.

library;

import 'dart:convert';
import '../../storage/automation_db_store_client.dart';
import 'conversation_intelligence_profile.dart';

class ConversationIntelligenceStore {
  const ConversationIntelligenceStore();

  static const String _sectionPrefix = 'business_intel_';

  String _sectionFor(String conversationId) => '$_sectionPrefix$conversationId';

  /// Carga el perfil de inteligencia de una conversación o uno inicial si no existe.
  Future<ConversationIntelligenceProfile> load(String conversationId) async {
    try {
      final raw = await AutomationDbStoreClient.instance.section(
        _sectionFor(conversationId),
      );
      if (raw == null || raw.isEmpty) {
        return ConversationIntelligenceProfile.initial(conversationId);
      }
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return ConversationIntelligenceProfile.fromJson(map);
    } catch (_) {
      return ConversationIntelligenceProfile.initial(conversationId);
    }
  }

  /// Guarda atómicamente el perfil de inteligencia actualizado.
  Future<bool> save(ConversationIntelligenceProfile profile) async {
    try {
      final encoded = jsonEncode(profile.toJson());
      return await AutomationDbStoreClient.instance.putSection(
        _sectionFor(profile.conversationId),
        encoded,
      );
    } catch (_) {
      return false;
    }
  }

  /// Elimina o vacía el perfil de inteligencia de la conversación.
  Future<bool> delete(String conversationId) async {
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
