part of 'pragmatic_fast_path.dart';

/// Algoritmo de selección determinista y anti-repetición para respuestas fast-path.
///
/// **QUÉ HACE:**
/// Selecciona una respuesta entre candidatos posibles garantizando variedad natural
/// sin repetir el último mensaje saliente inmediato.
///
/// **CÓMO FUNCIONA:**
/// Genera un hash pseudoaleatorio estable a partir de `(conversationId, minuteBucket)`,
/// descarta `lastOutboundText` si hay alternativas y añade hasta 3 sugerencias.
///
/// **POR QUÉ:**
/// Elimina respuestas robóticas repetitivas y mantiene variedad conversacional
/// sin requerir almacenamiento mutable en base de datos.
extension _CandidateSelector on PragmaticFastPath {
  ({String reply, List<String> suggestions}) _selectCandidate(
    List<String> pool,
    String conversationId,
    String? lastOutboundText,
  ) {
    if (pool.isEmpty) {
      return (
        reply: 'Todo bien por acá.',
        suggestions: const ['Todo bien por acá.'],
      );
    }

    final minuteBucket = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final seed = (conversationId.hashCode ^ minuteBucket).abs();

    final available = pool
        .where((c) => c.trim() != lastOutboundText?.trim())
        .toList();
    final listToUse = available.isNotEmpty ? available : pool;

    final selected = listToUse[seed % listToUse.length];
    final suggestions = <String>[selected];
    for (final c in pool) {
      if (!suggestions.contains(c) && suggestions.length < 3) {
        suggestions.add(c);
      }
    }
    return (reply: selected, suggestions: suggestions);
  }
}
