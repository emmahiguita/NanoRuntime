/// Textos editables del agente; los datos variables siguen viniendo del negocio.
final class BusinessResponseTemplates {
  const BusinessResponseTemplates({this.phrases = const {}});

  static const greeting = 'greeting';
  static const greetingPrefix = 'greetingPrefix';
  static const salesClosing = 'salesClosing';
  static const productMatch = 'productMatch';
  static const productCatalog = 'productCatalog';
  static const humanHandoff = 'humanHandoff';
  static const missingFacts = 'missingFacts';
  static const unknownMessage = 'unknownMessage';

  /// Valores iniciales tomados de las frases que el agente ya usa hoy.
  static const editorDefaults = <String, String>{
    greeting:
        '¡Hola! Gracias por escribir a {negocio}. Cuéntanos qué necesitas; podemos orientarte sobre productos, envíos o pagos.',
    greetingPrefix: '¡Hola! Te damos la bienvenida a {negocio}.',
    salesClosing: '¿En qué más te podemos ayudar?',
    productMatch: 'Según el catálogo registrado: {productos}.',
    productCatalog: 'En nuestro catálogo manejamos: {productos}.',
    humanHandoff:
        'Claro. Un asesor debe continuar esta conversación para ayudarte personalmente.',
    missingFacts:
        'No tengo confirmado {datos}. ¿Quieres que te comunique con un asesor?',
    unknownMessage:
        'No entendí del todo la consulta. ¿Puedes contarme qué necesitas o prefieres hablar con un asesor?',
  };

  /// Limita variables al contexto real que el motor puede completar.
  static const supportedVariables = <String, Set<String>>{
    greeting: {'negocio'},
    greetingPrefix: {'negocio'},
    salesClosing: {},
    productMatch: {'productos'},
    productCatalog: {'productos'},
    humanHandoff: {},
    missingFacts: {'datos'},
    unknownMessage: {'motivo'},
  };

  final Map<String, String> phrases;

  /// Restaura una edición guardada sin sustituir los valores predeterminados.
  factory BusinessResponseTemplates.fromJson(Object? json) {
    if (json is! Map) return const BusinessResponseTemplates();
    return BusinessResponseTemplates(
      phrases: Map.unmodifiable({
        for (final entry in json.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      }),
    );
  }

  /// Devuelve la frase editada con variables reales, o null para conservar lógica actual.
  String? render(String key, Map<String, String> variables) {
    final source = phrases[key]?.trim();
    if (source == null || source.isEmpty) return null;
    var result = source;
    for (final entry in variables.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  /// Encuentra variables no admitidas antes de guardar, para evitar texto sin resolver.
  List<String> invalidVariables(String key, String phrase) {
    final allowed = supportedVariables[key] ?? const <String>{};
    return [
      for (final match in RegExp(r'\{([^{}]+)\}').allMatches(phrase))
        if (!allowed.contains(match.group(1))) match.group(1)!,
    ];
  }

  /// Serializa solo cambios de usuario; no duplica frases base en la base de datos.
  Map<String, String> toJson() => Map.unmodifiable(phrases);
}
