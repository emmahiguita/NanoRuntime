/// QUÉ: separa consultas meteorológicas de relatos y preguntas sobre su fuente.
/// CÓMO: amplía vocabulario meteorológico (clima, tiempo, temperatura, lluvia, etc.) y detecta ciudad explícita.
/// POR QUÉ: permite responder de forma factual consultas cotidianas en español natural.
abstract final class WeatherRequest {
  static String fold(String text) => text
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');

  static bool mentionsWeather(String text) => RegExp(
    r'\b(?:clima|tiempo|temperatura|pronostico|meteorologico|meteorologia|grados)\b|'
    r'\b(?:llueve|llover|llovera|llueva|lloviendo|lluvia|llovizna|chubasco|tormenta|granizo|nieve|nevando)\b|'
    r'\b(?:hace|hara|haciendo|siente|sintiendo)\s+(?:frio|calor|sol|viento|fresco)\b|'
    r'\b(?:nublado|soleado|caluroso|fresco|despejado|ventoso|humedo|humedad)\b',
  ).hasMatch(fold(text));

  static bool isSourceQuestion(String text) => RegExp(
    r'\b(?:como\s+sabes|por\s+que\s+dices|de\s+donde\s+(?:sabes|sacaste|sale|viene))\b',
  ).hasMatch(fold(text));

  static bool isQuery(String text) {
    if (!mentionsWeather(text) || isSourceQuestion(text)) return false;
    for (final match in RegExp(r'[^¿.!?]+[.!?]?').allMatches(text)) {
      final sentence = match.group(0)!;
      if (!mentionsWeather(sentence)) continue;
      if (sentence.trim().endsWith('?')) return true;
      final value = fold(sentence).trim();
      if (RegExp(
            r'\b(?:consulta|revisa|busca|dime|dame|averigua|sabes|sabras|cuenta|cuentame|informame|muestrame|darme|decirme|saber|ver|conocer)\b',
          ).hasMatch(value) ||
          RegExp(
            r'^(?:que|como|cual|cuanto|cuanta|llueve|llovera|esta\s+lloviendo|va\s+a\s+llover|habra\s+lluvia|hay\s+sol|hace\s+frio|hace\s+calor|el\s+clima|el\s+tiempo|clima|tiempo|temperatura)\b',
          ).hasMatch(value)) {
        return true;
      }
    }
    return false;
  }

  // Extrae solo una ciudad declarada; nunca envía el mensaje completo al servicio.
  static String? explicitCity(String text) {
    if (!mentionsWeather(text)) return null;
    for (final prefix in [
      r'\ben\s+',
      r'\bpara\s+',
      r'\bclima\s+de\s+',
      r'\bclima\s+en\s+',
      r'\btiempo\s+en\s+',
      r'\btiempo\s+de\s+',
      r'\btemperatura\s+en\s+',
      r'\btemperatura\s+de\s+',
      r'\bpronostico\s+de\s+',
      r'\bpronostico\s+para\s+',
      r'\bpronostico\s+en\s+',
      r'\bde\s+',
    ]) {
      final match = RegExp(
        '$prefix([a-záéíóúüñ][a-záéíóúüñ ,.-]{1,64})',
        caseSensitive: false,
      ).firstMatch(text);
      if (match == null) continue;
      final city = match
          .group(1)!
          .split(
            RegExp(
              r'\b(?:ahora|hoy|mañana|manana|son|a\s+las|y|pero|por\s+fa|por\s+favor|gracias|please)\b',
              caseSensitive: false,
            ),
          )
          .first
          .replaceAll(RegExp(r'[ ,.?!-]+$'), '')
          .trim();
      if (city.isEmpty ||
          city.split(' ').length > 6 ||
          RegExp(
            r'\b(?:mi|tu|su|aqui|aca|alla|casa|ubicacion|este|esta|momento|tiempo|clima|dia|hoy|mañana|manana)\b',
          ).hasMatch(fold(city))) {
        continue;
      }
      return city;
    }
    return null;
  }
}
