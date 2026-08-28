/// GoalContext — intención TIPADA extraída de un objetivo en lenguaje natural.
///
/// SRP: el parsing vive aquí (GoalContextParser), separado del orquestador y de
/// los handlers. Un solo lugar sabe cómo leer "abre X y busca Y" / "escríbele a
/// Z: mensaje" / "abre el segundo resultado".
library;

import '../planning/message_intent_parser.dart';

class GoalContext {
  final String appName;
  final String target;
  final String draft;

  /// T2.9 — query de búsqueda ("abre YouTube y busca X").
  final String query;

  /// T2.9-select — ordinal del resultado (null = no expresado).
  final int? resultOrdinal;

  /// T2.9-select — texto objetivo del resultado ('' = no expresado).
  final String resultText;

  const GoalContext({
    this.appName = '',
    this.target = '',
    this.draft = '',
    this.query = '',
    this.resultOrdinal,
    this.resultText = '',
  });
}

class GoalContextParser {
  const GoalContextParser();

  GoalContext parse(String goal) {
    final g = goal.toLowerCase();

    // App: "abre X" / "ve a X" / "ir a X" / "entra a X" o "… en X" (búsqueda).
    final appMatch = RegExp(
      r'(?:abre|abrir|ve a|ir a|entra a|entra en)\s+(\w+)',
    ).firstMatch(g);
    final enAppMatch = RegExp(r'en\s+(\w+)\s*$').firstMatch(g);
    var appName = appMatch?.group(1) ?? '';
    if (enAppMatch != null) appName = enAppMatch.group(1)!;

    // Query: "busca X…" — se recorta del ORIGINAL para conservar el case.
    var query = '';
    final buscaIdx = g.indexOf('busca');
    if (buscaIdx >= 0) {
      query = goal.substring(buscaIdx + 'busca'.length).trim();
      if (enAppMatch != null) {
        query = query
            .replaceAll(RegExp(r'\s+en\s+\w+\s*$', caseSensitive: false), '')
            .trim();
      }
    }

    // Target/draft (mensajería) vía MessageIntentParser (":" y " que ").
    final intent = const MessageIntentParser().parse(goal);

    return GoalContext(
      appName: appName,
      target: intent.recipient,
      draft: intent.message,
      query: query,
      resultOrdinal: _parseResultOrdinal(g),
      resultText: _parseResultText(goal),
    );
  }

  /// Ordinal determinista: "primero"=1, "segundo"=2, "resultado 3", "de arriba"=1.
  int? _parseResultOrdinal(String g) {
    const words = {
      'primero': 1,
      'primer': 1,
      'primera': 1,
      'segundo': 2,
      'segunda': 2,
      'tercero': 3,
      'tercer': 3,
      'tercera': 3,
      'cuarto': 4,
      'cuarta': 4,
      'quinto': 5,
      'quinta': 5,
    };
    for (final e in words.entries) {
      if (g.contains(e.key)) return e.value;
    }
    final nMatch = RegExp(r'resultado\s+(\d+)').firstMatch(g);
    if (nMatch != null) return int.tryParse(nMatch.group(1)!);
    if (g.contains('de arriba')) return 1;
    return null;
  }

  /// Texto objetivo: "que dice X" / "dice X". Se recorta del ORIGINAL para
  /// conservar el case ("NanoRuntime").
  String _parseResultText(String goal) {
    final m = RegExp(r'dice\s+(.+)$', caseSensitive: false).firstMatch(goal);
    return m?.group(1)?.trim() ?? '';
  }
}
