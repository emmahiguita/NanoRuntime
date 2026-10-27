// QUÉ HACE: acceso SQLite a ejemplos de conversación y estilo.
// CÓMO: usa el canal nativo tipado, pagina resultados y conserva el scope.
// POR QUÉ: mantiene separado el repositorio de perfiles y evita duplicar lógica.

part of 'persona_repository.dart';

extension PersonaRepositoryExamples on PersonaRepository {
  /// Añade un ejemplo de estilo o un par entrante → respuesta.
  Future<bool> addExample({
    required String personaKey,
    required String body,
    String incomingText = '',
    Map<String, String> tone = const {},
    String source = '',
  }) async {
    try {
      final rowId = await PersonaRepository._channel
          .invokeMethod<num>('exampleAdd', {
            'personaKey': personaKey,
            'body': body,
            'incomingText': incomingText,
            'toneJson': jsonEncode(tone),
            'source': source,
          });
      return (rowId ?? -1) >= 0;
    } on Object catch (error) {
      debugPrint('[persona] addExample falló: $error');
      return false;
    }
  }

  /// Lee ejemplos más recientes con paginación opcional por scope.
  Future<List<PersonaExample>> listExamples({
    int limit = 200,
    int offset = 0,
    String? scopeKey,
  }) async {
    try {
      final rows = await PersonaRepository._channel
          .invokeListMethod<dynamic>('exampleList', {
            'limit': limit,
            'offset': offset,
            if (scopeKey != null) 'scopeKey': scopeKey,
          })
          .timeout(const Duration(seconds: 10));
      return [
        for (final row in rows ?? const [])
          if (row is Map) PersonaExample.fromRow(row.cast<dynamic, dynamic>()),
      ];
    } on Object catch (error) {
      debugPrint('[persona] listExamples falló: $error');
      rethrow;
    }
  }

  Future<bool> deleteExample(int id) async {
    try {
      return await PersonaRepository._channel.invokeMethod<bool>(
            'exampleDelete',
            {'id': id},
          ) ??
          false;
    } on Object catch (error) {
      debugPrint('[persona] deleteExample falló: $error');
      return false;
    }
  }

  Future<void> updateExample(
    PersonaExample example, {
    String? body,
    String? incomingText,
    Map<String, String>? tone,
    String? scopeKey,
  }) async {
    final updated = await PersonaRepository._channel
        .invokeMethod<bool>('exampleUpdate', {
          'id': example.id,
          'body': body ?? example.body,
          'incomingText': incomingText ?? example.incomingText,
          'toneJson': jsonEncode(tone ?? example.tone),
          if (scopeKey != null) 'scopeKey': scopeKey,
        })
        .timeout(const Duration(seconds: 10));
    if (updated != true) throw StateError('No se pudo actualizar el ejemplo.');
  }

  /// Busca por FTS4 el contexto más parecido al mensaje actual.
  Future<List<PersonaExample>> searchExamples(
    String query, {
    int limit = 4,
    String scopeKey = 'owner',
    String roleKey = 'role:personal',
  }) async {
    try {
      final rows = await PersonaRepository._channel.invokeListMethod<dynamic>(
        'exampleSearch',
        {
          'query': query,
          'limit': limit,
          'scopeKey': scopeKey,
          'roleKey': roleKey,
        },
      );
      return [
        for (final row in rows ?? const [])
          if (row is Map) PersonaExample.fromRow(row.cast<dynamic, dynamic>()),
      ];
    } on Object catch (error) {
      debugPrint('[persona] searchExamples falló: $error');
      return const [];
    }
  }
}
