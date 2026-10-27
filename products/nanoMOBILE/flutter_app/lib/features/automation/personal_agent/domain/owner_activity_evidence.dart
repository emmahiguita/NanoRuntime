/// QUÉ: contrasta afirmaciones propias con las actividades vigentes declaradas.
/// CÓMO: separa preguntas y sujeto; compara categorías, no cualquier agenda activa.
/// POR QUÉ: «¿estás comiendo?» no afirma que el dueño coma, y trabajo no es almuerzo.
abstract final class OwnerActivityEvidence {
  static String fold(String text) => text
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  static const _categories = {
    'trabajo': r'\b(?:trabaj\w*|program\w*)\b',
    'almuerzo': r'\b(?:almorz\w*|almuerz\w*)\b',
    'desayuno': r'\bdesayun\w*\b',
    'cena': r'\bcen(?:a|ando|ar)\b',
    'comida': r'\b(?:comiendo|comer|comida)\b',
    'estudio': r'\bestudi\w*\b',
    'ejercicio': r'\b(?:entren\w*|gimnasio|gym)\b',
    'descanso': r'\b(?:durmiendo|dormir|descans\w*)\b',
    'conduccion': r'\b(?:manej\w*|conduci\w*)\b',
    'oficina': r'\ben (?:la )?oficina\b',
  };

  static Set<String> claims(String reply) {
    final text = fold(reply)
        .replaceAll(RegExp(r'¿[^?]*\?'), '')
        .replaceAll(RegExp(r'(?:^|(?<=[.!]))[^¿?.!]*\?'), '');
    final claims = <String>{};
    for (final clause in text.split(RegExp(r'[.!;\n]'))) {
      final c = clause.trim();
      if (RegExp(
            r'\b(?:tu|usted|el|ella|ellos|mi amigo|mi amiga)\b',
          ).hasMatch(c) &&
          !RegExp(r'\b(?:estoy|ando|yo)\b').hasMatch(c)) {
        continue;
      }
      if (RegExp(
        r'\b(?:no estoy|no ando|si estuviera|cuando este|podria|voy a)\b',
      ).hasMatch(c)) {
        continue;
      }
      final own =
          RegExp(r'\b(?:estoy|ando|yo|me encuentro)\b').hasMatch(c) ||
          c.split(RegExp(r'\s+')).length <= 4;
      if (!own) continue;
      for (final item in _categories.entries) {
        if (RegExp(item.value).hasMatch(c)) claims.add(item.key);
      }
    }
    return claims;
  }

  static bool supports(String reply, Iterable<String> active) {
    // Una preferencia negativa («hoy no trabajo») no prueba una actividad.
    // Conservamos solo cláusulas afirmativas; el modelo aún recibe el estado
    // completo y puede explicar sus límites sin convertirlo en un compromiso.
    final text = active
        .expand((label) => fold(label).split(RegExp(r'[.!;\n]')))
        .where(
          (clause) =>
              !RegExp(r'\b(?:no|sin|ma[ñn]ana|despues|luego)\b').hasMatch(clause),
        )
        .join(' ');
    return claims(reply).every((category) {
      if (category == 'comida') {
        return RegExp(
          r'\b(?:com\w*|almuerz\w*|almorz\w*|desayun\w*|cena\w*)\b',
        ).hasMatch(text);
      }
      return RegExp(_categories[category]!).hasMatch(text);
    });
  }
}
