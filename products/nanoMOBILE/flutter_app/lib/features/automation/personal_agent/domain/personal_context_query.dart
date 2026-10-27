/// Pide evidencia personal; incluye disponibilidad sin afirmar actividad por intuición.
bool needsPersonalContextFacts(String text) => RegExp(
  r'\b(?:nombre|llamas|apodo|ocupaci[oó]n|profesi[oó]n|dedicas|perfil|biograf[ií]a|'
  r'vives|cumpleaños|recuerdas|acuerdas|preferencia|prefieres|trabajas|familia|'
  r'agenda|horario|ocupad[oa]|libre|disponible|sales|saldras|saldrás|trabajo|hoy|mañana|hora)\b',
  caseSensitive: false,
).hasMatch(text);
