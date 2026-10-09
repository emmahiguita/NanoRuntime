/// QUÉ: establece español latinoamericano neutral, sin respuestas prefabricadas.
/// CÓMO: comparte instrucciones y valida la salida, no modifica lo recibido.
/// POR QUÉ: entender lenguaje informal no exige copiar regionalismos al responder.
abstract final class PersonalLanguagePolicy {
  static const instructions =
      'Usa español latinoamericano neutral, claro y educado. '
      'No uses vocativos ni jerga regional como parce, wey, güey o qué onda. '
      'Comprende risas y lenguaje informal sin copiar esas expresiones.';

  // Se rechaza una salida incompatible; nunca se sustituye por otra frase fija.
  static bool accepts(String text) => !RegExp(
    r'\b(?:parce|parcero|parcera|wey|g[uü]ey|que\s+onda)\b',
    caseSensitive: false,
  ).hasMatch(text.replaceAll('é', 'e').replaceAll('É', 'E'));
}
