// conversation_memory_obligations.dart
//
// QUÉ HACE:
// Manejo de obligaciones pendientes, temas activos y registro de intervenciones manuales por conversación.
//
// CÓMO FUNCIONA:
// - Gestiona listas acotadas (máximo 10) de obligaciones no resueltas por scopeId.
// - Registra timestamps de intervención manual del usuario para evitar sobreescritura de respuestas.
// - Notifica la persistencia cuando cambian las obligaciones o el estado conversacional.
//
// POR QUÉ:
// Mantiene el tamaño de archivos estrictamente menor a 200 líneas cumpliendo el principio de Responsabilidad Única (SRP).

part of 'conversation_memory.dart';

mixin _MemoryObligationsMixin {
  final Map<String, List<String>> _obligationsByConversation = {};
  final Map<String, String> _topicByConversation = {};
  final Map<String, int> _manualAtByConversation = {};

  String _scopeFor(String conversationId);
  void _persistStateFor(String conversationId);
  void _markDirty();

  void addUnresolvedObligation(String convId, String obl) {
    if (convId.isEmpty || obl.trim().isEmpty) return;
    final clean = obl.trim();
    final scopeId = _scopeFor(convId);
    final list = _obligationsByConversation.putIfAbsent(scopeId, () => []);
    if (!list.contains(clean)) {
      list.add(clean);
      if (list.length > 10) list.removeAt(0);
      _persistStateFor(convId);
      _markDirty();
    }
  }

  void resolveObligations(String convId, List<String> resolved) {
    if (convId.isEmpty || resolved.isEmpty) return;
    final list = _obligationsByConversation[_scopeFor(convId)];
    if (list != null && list.isNotEmpty) {
      list.removeWhere(resolved.contains);
      _persistStateFor(convId);
      _markDirty();
    }
  }

  void clearObligations(String convId) {
    if (convId.isEmpty) return;
    final scopeId = _scopeFor(convId);
    if (_obligationsByConversation.containsKey(scopeId)) {
      _obligationsByConversation[scopeId]?.clear();
      _persistStateFor(convId);
      _markDirty();
    }
  }

  void recordManualIntervention(String convId, int atMs) {
    if (convId.isEmpty) return;
    _manualAtByConversation[_scopeFor(convId)] = atMs;
    _persistStateFor(convId);
    _markDirty();
  }
}
