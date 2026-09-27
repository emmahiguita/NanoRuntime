/// Señales gramaticales conservadoras para orientar el prompt del Agente Personal.
/// La inferencia nunca decide por sí sola a quién pertenece un hecho.
library;

final class SpanishGrammarAnalysis {
  const SpanishGrammarAnalysis({
    required this.tense,
    required this.grammaticalPerson,
    required this.temporalAspect,
  });

  final String tense;
  final String grammaticalPerson;
  final String temporalAspect;
}

abstract final class SpanishGrammarAnalyzer {
  static final _pastAdverb = RegExp(
    r'\b(ayer|anoche|antes|hace\s+(?:poco|mucho|\d+)|la\s+semana\s+pasada|el\s+mes\s+pasado|el\s+a[nñ]o\s+pasado)\b',
    unicode: true,
  );
  static final _futureAdverb = RegExp(
    r'\b(ma[nñ]ana|luego|despu[eé]s|m[aá]s\s+tarde|pronto|la\s+pr[oó]xima\s+semana)\b',
    unicode: true,
  );
  static final _preterite = RegExp(
    r'\b(fui|fuiste|fue|fuimos|fueron|estuve|estuviste|estuvo|estuvimos|estuvieron|tuve|tuviste|tuvo|tuvimos|tuvieron|hice|hiciste|hizo|hicimos|hicieron|dije|dijiste|dijo|dijimos|dijeron|vi|viste|vio|vimos|vieron|di|diste|dio|dimos|dieron|puse|pusiste|puso|pusimos|pusieron|quise|quisiste|quiso|quisimos|quisieron|pude|pudiste|pudo|pudimos|pudieron|vine|viniste|vino|vinimos|vinieron|compr[eé]|pag[uú]e|instal[eé]|prob[eé]|habl[eé]|confirm[eé]|mand[eé]|llam[eé]|termin[eé]|estudi[eé]|acept[eé]|llegu[eé]|qued[eé]|trabaj[eé]|visit[eé]|respond[ií]|escrib[ií]|le[ií]|com[ií]|viv[ií]|sal[ií]|volv[ií]|ped[ií]|recib[ií]|abr[ií]|vend[ií]|decid[ií]|sent[ií]|cambi[eé]|dorm[ií]|[\p{L}]+(?:aste|iste|aron|ieron))\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _imperfect = RegExp(
    r'\b[\p{L}]+(?:aba|abas|ábamos|aban|ía|ías|íamos|ían)\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _presentPerfect = RegExp(
    r'\b(he|has|ha|hemos|han)\s+[\p{L}]+(?:ado|ido|to|so|cho)\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _pluperfect = RegExp(
    r'\b(hab[ií]a|hab[ií]as|hab[ií]amos|hab[ií]an)\s+[\p{L}]+(?:ado|ido|to|so|cho)\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _futureSimple = RegExp(
    r'\b[\p{L}]+(?:ar[eé]|er[eé]|ir[eé]|ar[aá]s|er[aá]s|ir[aá]s|ar[aá]|er[aá]|ir[aá]|aremos|eremos|iremos|ar[aá]n|er[aá]n|ir[aá]n|har[eé]|dir[eé]|ser[eé]|estar[eé]|tendr[eé]|podr[eé]|querr[eé]|pondr[eé]|saldr[eé]|vendr[eé])\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _futurePeriphrasis = RegExp(
    r'\b(voy|vas|va|vamos|van)\s+a\s+[\p{L}]+\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _conditional = RegExp(
    r'\b[\p{L}]+(?:ar[ií]a|er[ií]a|ir[ií]a|ar[ií]as|er[ií]as|ir[ií]as|ar[ií]amos|er[ií]amos|ir[ií]amos|ar[ií]an|er[ií]an|ir[ií]an)\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _present = RegExp(
    r'\b(soy|estoy|tengo|quiero|puedo|voy|hago|digo|s[eé]|conozco|prefiero|necesito|salgo|vengo|pido|duermo|pongo|doy|compro|pago|instalo|pruebo|hablo|confirmo|mando|llamo|termino|estudio|acepto|llego|quedo|trabajo|visito|respondo|escribo|leo|como|vivo|vuelvo|recibo|abro|vendo|decido|siento|cambio|est[aá]s|tienes|quieres|puedes|vas|haces|sabes|dices|vienes|tenemos|somos|estamos|vamos|queremos|podemos|hacemos)\b',
    unicode: true,
    caseSensitive: false,
  );

  static final _firstSingular = RegExp(
    r'\b(yo|soy|estoy|tengo|quiero|puedo|voy|hago|digo|s[eé]|conozco|prefiero|necesito|salgo|vengo|pido|duermo|pongo|doy|compro|pago|instalo|pruebo|hablo|confirmo|mando|llamo|termino|estudio|acepto|llego|quedo|trabajo|visito|respondo|escribo|leo|como|vivo|vuelvo|recibo|abro|vendo|decido|siento|cambio|fui|estuve|tuve|hice|dije|vi|di|vine|puse|supe|quise|pude|compr[eé]|pag[uú]e|instal[eé]|prob[eé]|habl[eé]|confirm[eé]|mand[eé]|llam[eé]|termin[eé]|estudi[eé]|acept[eé]|llegu[eé]|qued[eé]|trabaj[eé]|visit[eé]|respond[ií]|escrib[ií]|le[ií]|com[ií]|viv[ií]|sal[ií]|volv[ií]|ped[ií]|recib[ií]|abr[ií]|vend[ií]|decid[ií]|sent[ií]|cambi[eé]|dorm[ií]|he\s+[\p{L}]+(?:ado|ido|to|so|cho))\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _firstPlural = RegExp(
    r'\b(nosotros|nosotras|somos|estamos|tenemos|queremos|podemos|vamos|hacemos|fuimos|estuvimos|tuvimos|hicimos|dijimos|vimos|dimos|vinimos|pusimos|[\p{L}]+(?:amos|emos|imos))\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _secondSingular = RegExp(
    r'\b(t[uú]|usted|est[aá]s|tienes|quieres|puedes|vas|haces|sabes|dices|vienes|fuiste|estuviste|tuviste|hiciste|dijiste|viste|compraste|pagaste|hablaste|confirmaste|mandaste|llamaste|terminaste|[\p{L}]+(?:aste|iste))\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _secondPlural = RegExp(
    r'\b(ustedes|vosotros|vosotras|[\p{L}]+(?:asteis|isteis))\b',
    unicode: true,
    caseSensitive: false,
  );
  static final _thirdPerson = RegExp(
    r'\b(él|ella|ellos|ellas)\b',
    unicode: true,
    caseSensitive: false,
  );

  static SpanishGrammarAnalysis analyze(String rawText) {
    final text = rawText.trim().toLowerCase();
    if (text.isEmpty) {
      return const SpanishGrammarAnalysis(
        tense: 'indeterminado',
        grammaticalPerson: 'indeterminada',
        temporalAspect: 'indeterminado',
      );
    }

    final pluperfect = _pluperfect.hasMatch(text);
    final presentPerfect = _presentPerfect.hasMatch(text);
    final futureSimple = _futureSimple.hasMatch(text);
    final futurePeriphrasis = _futurePeriphrasis.hasMatch(text);
    final conditional = _conditional.hasMatch(text);
    final imperfect = _imperfect
        .allMatches(text)
        .any(
          (match) => !const {
            'día',
            'días',
            'vía',
            'guía',
            'tía',
          }.contains(match.group(0)),
        );
    final pastVerb =
        pluperfect || presentPerfect || imperfect || _preterite.hasMatch(text);
    final pastAnchor = _pastAdverb.hasMatch(text);
    final futureVerb = futureSimple || futurePeriphrasis;
    final futureAnchor = _futureAdverb.hasMatch(text);
    final isPast = pastVerb || pastAnchor;
    final isFuture = futureVerb || futureAnchor;
    final tense = isPast && isFuture
        ? 'mixto'
        : isPast
        ? 'pasado'
        : isFuture
        ? 'futuro'
        : conditional
        ? 'condicional'
        : _present.hasMatch(text)
        ? 'presente'
        : 'indeterminado';

    final aspect = isPast && isFuture
        ? 'pasado_y_futuro'
        : pluperfect
        ? 'pluscuamperfecto'
        : presentPerfect
        ? 'pretérito_perfecto_compuesto'
        : futurePeriphrasis
        ? 'perífrasis_ir_a_infinitivo'
        : futureSimple
        ? 'futuro_simple'
        : conditional
        ? 'condicional'
        : imperfect && _preterite.hasMatch(text)
        ? 'imperfecto_y_pretérito'
        : imperfect
        ? 'imperfecto'
        : _preterite.hasMatch(text)
        ? 'pretérito'
        : pastAnchor
        ? 'anclaje_temporal_pasado'
        : futureAnchor
        ? 'anclaje_temporal_futuro'
        : _present.hasMatch(text)
        ? 'presente'
        : 'indeterminado';

    return SpanishGrammarAnalysis(
      tense: tense,
      grammaticalPerson: _person(text),
      temporalAspect: aspect,
    );
  }

  static String _person(String text) {
    final firstSingular = _firstSingular.hasMatch(text);
    final firstPlural = _firstPlural.hasMatch(text);
    final secondSingular = _secondSingular.hasMatch(text);
    final secondPlural = _secondPlural.hasMatch(text);
    final third = _thirdPerson.hasMatch(text);
    final groups = <String>{
      if (firstSingular) 'primera_persona_singular',
      if (firstPlural) 'primera_persona_plural',
      if (secondSingular) 'segunda_persona_singular',
      if (secondPlural) 'segunda_persona_plural',
      if (third) 'tercera_persona_explicita',
    };
    if (groups.length > 1) return 'mixta';
    return groups.isEmpty ? 'indeterminada' : groups.first;
  }
}
