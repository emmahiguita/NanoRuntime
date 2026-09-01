/// Intención determinista y acotada para una interacción UI genérica:
/// abrir una app conocida y activar un elemento nombrado por el usuario.
///
/// No produce paquetes, selectores ni coordenadas. Esos datos deben salir del
/// catálogo instalado y de la observación Accessibility inmediatamente previa.
library;

final class GenericUiIntent {
  const GenericUiIntent({this.app = '', this.target = ''});

  final String app;
  final String target;

  bool get isComplete => app.isNotEmpty && target.isNotEmpty;
}

final class GenericUiFillIntent {
  const GenericUiFillIntent({this.app = '', this.target = '', this.text = ''});

  final String app;
  final String target;
  final String text;

  bool get isComplete => app.isNotEmpty && target.isNotEmpty && text.isNotEmpty;
}

/// Composición acotada de dos mutaciones observables. [actionTarget] revela la
/// siguiente superficie y [fieldTarget] puede omitirse únicamente cuando esa
/// nueva superficie contiene un solo campo editable.
final class GenericUiComposeIntent {
  const GenericUiComposeIntent({
    this.app = '',
    this.actionTarget = '',
    this.fieldTarget = '',
    this.text = '',
  });

  final String app;
  final String actionTarget;
  final String fieldTarget;
  final String text;

  bool get isComplete =>
      app.isNotEmpty && actionTarget.isNotEmpty && text.isNotEmpty;
}

/// Intención de búsqueda independiente de la aplicación concreta.
///
/// Mantiene nombre de app y consulta como datos semánticos. La resolución de
/// package, campo y acción de envío sigue perteneciendo al catálogo y a la
/// observación Accessibility inmediatamente anterior a cada acción.
final class GenericSearchIntent {
  const GenericSearchIntent({this.app = '', this.query = ''});

  final String app;
  final String query;

  bool get hasQuery => query.isNotEmpty;
}

final class GenericUiIntentParser {
  const GenericUiIntentParser();

  /// Formas soportadas:
  /// - "Abre Google Chrome y busca Nano AI"
  /// - "Busca Nano AI en Google Chrome"
  /// - "Search for Nano AI in Chrome"
  /// - "Busca Nano AI" (opera sobre la superficie actual).
  ///
  /// Es la gramática única consumida por planner y orquestador. Esto evita que
  /// un plan válido termine ejecutándose con query vacía o con el nombre de la
  /// app incluido accidentalmente en el texto.
  GenericSearchIntent parseSearch(String goal) {
    final source = goal.trim();
    if (source.isEmpty) return const GenericSearchIntent();

    final openThenSearch = RegExp(
      r'(?:^|[;,]\s*|\b)'
      r'(?:abre|abrir|ve\s+a|ir\s+a|entra\s+a|entra\s+en|open)\s+'
      r'(.+?)(?:\s*,\s*|\s+(?:y|e|and|then)\s+)'
      r'(?:busca|buscar|b[uú]scame|buscarme|search(?:\s+for)?|find)\s+'
      r'(.+?)\s*[.!?]*$',
      caseSensitive: false,
    ).firstMatch(source);
    if (openThenSearch != null) {
      return GenericSearchIntent(
        app: _clean(openThenSearch.group(1)),
        query: _cleanPayload(openThenSearch.group(2)),
      );
    }

    final searchInApp = RegExp(
      r'(?:^|[;,]\s*|\b)'
      r'(?:busca|buscar|b[uú]scame|buscarme|search(?:\s+for)?|find)\s+'
      r'(.+?)\s+(?:en|dentro\s+de|in|on)\s+(.+?)\s*[.!?]*$',
      caseSensitive: false,
    ).firstMatch(source);
    if (searchInApp != null) {
      return GenericSearchIntent(
        query: _cleanPayload(searchInApp.group(1)),
        app: _clean(searchInApp.group(2)),
      );
    }

    final currentSurfaceSearch = RegExp(
      r'(?:^|[;,]\s*|\b)'
      r'(?:busca|buscar|b[uú]scame|buscarme|search(?:\s+for)?|find)\s+'
      r'(.+?)\s*[.!?]*$',
      caseSensitive: false,
    ).firstMatch(source);
    return GenericSearchIntent(
      query: _cleanPayload(currentSurfaceSearch?.group(1)),
    );
  }

  GenericUiIntent parse(String goal) {
    final match = RegExp(
      r'(?:^|[;,]\s*|\b)'
      r'(?:abre|abrir|ve\s+a|ir\s+a|entra\s+a|entra\s+en|open)\s+'
      r'(.+?)(?:\s*,\s*|\s+(?:y|e|and|then)\s+)'
      r'(?:toca|tocar|pulsa|pulsar|selecciona|seleccionar|elige|elegir|'
      r'haz\s+clic\s+en|click|tap|select|choose)\s+'
      r'(?:(?:el|la|los|las|the)\s+)?(.+?)\s*[.!?]*$',
      caseSensitive: false,
    ).firstMatch(goal.trim());
    if (match == null) return const GenericUiIntent();

    return GenericUiIntent(
      app: _clean(match.group(1)),
      target: _clean(match.group(2)),
    );
  }

  /// "Abre Chrome y escribe \"OpenAI\" en el campo Buscar". El texto y el
  /// nombre del campo siguen siendo intención; el selector se obtiene después
  /// desde Accessibility. Las comillas son preferidas para payloads que
  /// contienen la preposición "en".
  GenericUiFillIntent parseFill(String goal) {
    final source = goal.trim();
    final quoted = RegExp(
      r'(?:^|[;,]\s*|\b)'
      r'(?:abre|abrir|ve\s+a|ir\s+a|entra\s+a|entra\s+en|open)\s+'
      r'(.+?)'
      r'\s*,?\s+(?:y|e|and|then)\s+'
      r'(?:escribe|escribir|introduce|introducir|ingresa|ingresar|pon|'
      r'write|type|enter)\s+["“](.+?)["”]\s+'
      r'(?:en|dentro\s+de|into|in)\s+'
      r'(?:(?:el|la|los|las|the)\s+)?'
      r'(?:(?:campo|field|input|cuadro)\s+)?(.+?)\s*[.!?]*$',
      caseSensitive: false,
    ).firstMatch(source);
    final match =
        quoted ??
        RegExp(
          r'(?:^|[;,]\s*|\b)'
          r'(?:abre|abrir|ve\s+a|ir\s+a|entra\s+a|entra\s+en|open)\s+'
          r'(.+?)'
          r'\s*,?\s+(?:y|e|and|then)\s+'
          r'(?:escribe|escribir|introduce|introducir|ingresa|ingresar|pon|'
          r'write|type|enter)\s+(.+?)\s+'
          r'(?:en\s+(?:(?:el|la|los|las)\s+)?|into\s+|in\s+)'
          r'(?:(?:campo|field|input|cuadro)\s+)?(.+?)\s*[.!?]*$',
          caseSensitive: false,
        ).firstMatch(source);
    if (match == null) return const GenericUiFillIntent();

    return GenericUiFillIntent(
      app: _clean(match.group(1)),
      text: _cleanPayload(match.group(2)),
      target: _clean(match.group(3)),
    );
  }

  /// "Abre Facebook, toca ¿Qué estás pensando? y escribe \"Prueba Nano\"".
  /// La acción final de publicar/enviar queda deliberadamente fuera del plan.
  GenericUiComposeIntent parseCompose(String goal) {
    final source = goal.trim();
    final quoted = RegExp(
      r'(?:^|[;,]\s*|\b)'
      r'(?:abre|abrir|ve\s+a|ir\s+a|entra\s+a|entra\s+en|open)\s+'
      r'(.+?)'
      r'\s*,?\s+(?:y|e|and|then)\s+'
      r'(?:toca|tocar|pulsa|pulsar|selecciona|seleccionar|elige|elegir|'
      r'haz\s+clic\s+en|click|tap|select|choose)\s+'
      r'(?:(?:el|la|los|las|the)\s+)?'
      r'(.+?)(?:\s*,\s*|\s+(?:y|e|and|then)\s+)'
      r'(?:escribe|escribir|introduce|introducir|ingresa|ingresar|pon|'
      r'write|type|enter)\s+["“](.+?)["”]'
      r'(?:\s+(?:en|dentro\s+de|into|in)\s+'
      r'(?:(?:el|la|los|las|the)\s+)?'
      r'(?:(?:campo|field|input|cuadro)\s+)?(.+?))?\s*[.!?]*$',
      caseSensitive: false,
    ).firstMatch(source);
    final match =
        quoted ??
        RegExp(
          r'(?:^|[;,]\s*|\b)'
          r'(?:abre|abrir|ve\s+a|ir\s+a|entra\s+a|entra\s+en|open)\s+'
          r'(.+?)(?:\s*,\s*|\s+(?:y|e|and|then)\s+)'
          r'(?:toca|tocar|pulsa|pulsar|selecciona|seleccionar|elige|elegir|'
          r'haz\s+clic\s+en|click|tap|select|choose)\s+'
          r'(?:(?:el|la|los|las|the)\s+)?'
          r'(.+?)(?:\s*,\s*|\s+(?:y|e|and|then)\s+)'
          r'(?:escribe|escribir|introduce|introducir|ingresa|ingresar|pon|'
          r'write|type|enter)\s*:\s*(.+?)\s*[.!?]*$',
          caseSensitive: false,
        ).firstMatch(source);
    if (match == null) return const GenericUiComposeIntent();

    return GenericUiComposeIntent(
      app: _clean(match.group(1)),
      actionTarget: _clean(match.group(2)),
      text: _cleanPayload(match.group(3)),
      fieldTarget: match.groupCount >= 4 ? _clean(match.group(4)) : '',
    );
  }

  String _clean(String? value) => (value ?? '')
      .trim()
      .replaceAll(RegExp(r'^[\s,;:¿¡]+|[\s,;:.!?¿¡]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  String _cleanPayload(String? value) {
    var result = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (result.length >= 2) {
      const pairs = {'"': '"', '“': '”', '‘': '’', "'": "'"};
      final closing = pairs[result[0]];
      if (closing != null && result.endsWith(closing)) {
        result = result.substring(1, result.length - 1).trim();
      }
    }
    return result;
  }
}
