part of 'pragmatic_fast_path.dart';

extension _PragmaticIntentExtraction on PragmaticFastPath {
  bool _hasCommercialOrCommandSignal(String normalized, Set<String> tokens) {
    // Las consultas de hardware (batería/dispositivo) usan palabras como "cuánta", "tienes",
    // pero son hechos de dispositivo, no compras ni catálogo comercial.
    final isHardwareInquiry =
        normalized.contains('bateria') ||
        normalized.contains('cuanta carga') ||
        normalized.contains('nivel de carga');

    if (!isHardwareInquiry && tokens.any(commercialIntentTokens.contains)) {
      return true;
    }
    if (supportPhrases.any(normalized.contains)) return true;
    if (correctionPhrases.any(normalized.contains)) return true;

    // Comandos de automatización / terminal
    if (normalized.startsWith('abre ') ||
        normalized.startsWith('ejecuta ') ||
        normalized.startsWith('programa ') ||
        normalized.startsWith('crea una regla') ||
        normalized.startsWith('abrir ') ||
        normalized.startsWith('toma una captura')) {
      return true;
    }
    return false;
  }

  /// Extrae todos los intentos lingüísticos presentes en el mensaje.
  Set<ConversationIntent> _extractIntents(
    String normalized,
    Set<String> tokens,
  ) {
    final intents = <ConversationIntent>{};

    // Saludo
    const greetingWords = {
      'hola',
      'holas',
      'buenas',
      'buenos',
      'hey',
      'oe',
      'ey',
      'saludos',
      'ola',
      'hol',
      'oli',
      'holi',
      'quiubo',
      'hubo',
    };
    if (tokens.any(greetingWords.contains) ||
        normalized.contains('buen dia') ||
        normalized.contains('buenos dias') ||
        normalized.contains('buenas tardes') ||
        normalized.contains('buenas noches') ||
        normalized.contains('que mas') ||
        normalized.contains('q mas') ||
        normalized.contains('que hubo') ||
        normalized.contains('q hubo')) {
      intents.add(ConversationIntent.greeting);
    }

    // Pregunta de bienestar / social check-in
    if (normalized.contains('como estas') ||
        normalized.contains('como te va') ||
        normalized.contains('como vas') ||
        normalized.contains('que tal') ||
        normalized.contains('como va todo') ||
        normalized.contains('como andas') ||
        normalized.contains('como te encuentras') ||
        normalized.contains('como te ha ido') ||
        normalized.contains('que cuentas') ||
        normalized.contains('que me cuentas') ||
        normalized.contains('todo bien?') ||
        normalized.contains('todo bien ?')) {
      intents.add(ConversationIntent.askWellbeing);
    }

    // Respuesta de bienestar del usuario ("bien", "todo bien", "aquí tranquilo")
    if (normalized.contains('todo bien') ||
        normalized.contains('muy bien') ||
        normalized.contains('super bien') ||
        normalized.contains('excelente') ||
        normalized.contains('tranqui') ||
        normalized.contains('por aca bien') ||
        normalized.contains('aqui bien') ||
        (tokens.contains('bien') &&
            !normalized.contains('como') &&
            !normalized.contains('que tal'))) {
      intents.add(ConversationIntent.userWellbeing);
    }

    // Aclaración / Reaseguro de bienestar ("ya te dije que estoy bien", "te dije que bien", "ya te dije")
    if (normalized.contains('ya te dije') ||
        normalized.contains('te dije que bien') ||
        normalized.contains('te dije que estoy bien') ||
        normalized.contains('te acabo de decir')) {
      intents.add(ConversationIntent.wellbeingClarification);
    }

    // Pregunta recíproca ("y tú", "y vos", "y usted", "qué tal tú")
    if (normalized.contains('y tu') ||
        normalized.contains('y vos') ||
        normalized.contains('y usted') ||
        normalized.contains('que tal tu') ||
        normalized.contains('y ti') ||
        normalized.contains('y tu que') ||
        normalized.contains('y vos que') ||
        normalized.contains('que tal vos')) {
      intents.add(ConversationIntent.reciprocalQuestion);
    }

    // Pregunta sobre actividad actual o planes ("qué haces", "qué vas a hacer", "vas a salir", "en qué andas")
    if (normalized.contains('que haces') ||
        normalized.contains('que haciendo') ||
        normalized.contains('que estas haciendo') ||
        normalized.contains('que haras') ||
        normalized.contains('haras hoy') ||
        normalized.contains('que haran') ||
        normalized.contains('que vas hacer') ||
        normalized.contains('que vas a hacer') ||
        normalized.contains('que va a hacer') ||
        normalized.contains('que va hacer') ||
        normalized.contains('vas hacer') ||
        normalized.contains('vas a hacer') ||
        normalized.contains('vamos a salir') ||
        normalized.contains('vas a salir') ||
        normalized.contains('sale hoy') ||
        normalized.contains('que planes') ||
        normalized.contains('en que andas') ||
        normalized.contains('que cuentas') ||
        normalized.contains('que te cuentas') ||
        normalized.contains('que hay de nuevo') ||
        normalized.contains('que tienes pensado') ||
        normalized.contains('que vas a hacer hoy') ||
        normalized.contains('que vas hacer hoy') ||
        normalized.contains('en que trabajas') ||
        normalized.contains('que se cuenta')) {
      intents.add(ConversationIntent.askActivity);
    }

    // Pregunta sobre el día ("qué tal va tu día", "cómo va tu día")
    if (normalized.contains('tu dia') ||
        normalized.contains('el dia') ||
        normalized.contains('como va el dia') ||
        normalized.contains('como pinta el dia') ||
        normalized.contains('que tal va el dia')) {
      intents.add(ConversationIntent.askDay);
    }

    // Pregunta sobre entrenamiento / ejercicio / gym
    if (normalized.contains('entren') ||
        normalized.contains('gym') ||
        normalized.contains('gimnasio') ||
        normalized.contains('ejercicio')) {
      intents.add(ConversationIntent.askTraining);
    }

    // Intención de rap / rimas / improvisación
    if (normalized.contains('rapear') ||
        normalized.contains('rapeo') ||
        normalized.contains('rimas') ||
        normalized.contains('rimar') ||
        normalized.contains('improvisar') ||
        normalized.contains('freestyle') ||
        normalized.contains('tirar rimas') ||
        normalized.contains('unas rimas') ||
        normalized.contains('batalla de rap') ||
        normalized.contains('batalla de gallos')) {
      intents.add(ConversationIntent.askRap);
    }

    // Intención de invitación directa a plan o salir ("vamos a", "¿vamos?", "te invito", "quieres ir", "caes hoy")
    if (normalized.contains('vamos a') ||
        normalized.contains('vamos ?') ||
        normalized.contains('vamos?') ||
        normalized == 'vamos' ||
        normalized.contains('te invito') ||
        normalized.contains('quieres ir') ||
        normalized.contains('queres ir') ||
        normalized.contains('caes hoy') ||
        normalized.contains('le caes') ||
        normalized.contains('sale o que') ||
        normalized.contains('vamos o que') ||
        normalized.contains('te apuntas') ||
        normalized.contains('hacemos algo')) {
      intents.add(ConversationIntent.invitation);
    }

    // Pregunta de presencia ("estás ahí", "sigues ahí", "estás por ahí")
    if (normalized.contains('estas ahi') ||
        normalized.contains('estas por ahi') ||
        normalized.contains('sigues ahi') ||
        normalized.contains('sigues por ahi') ||
        normalized.contains('estas hay') ||
        normalized.contains('andas por ahi') ||
        normalized == 'estas?' ||
        normalized == 'estas ?' ||
        normalized == 'estas') {
      intents.add(ConversationIntent.askPresence);
    }

    // Solicitud de ayuda / tarea / duda
    if (normalized.contains('tarea') ||
        normalized.contains('ayuda') ||
        normalized.contains('ayudas') ||
        normalized.contains('colaboras') ||
        normalized.contains('colaborar') ||
        normalized.contains('pregunta') ||
        normalized.contains('duda') ||
        normalized.contains('un favor') ||
        normalized.contains('me ayudas') ||
        normalized.contains('me colaboras') ||
        normalized.contains('te puedo preguntar') ||
        normalized.contains('tengo una duda') ||
        normalized.contains('tengo una pregunta') ||
        normalized.contains('necesito')) {
      intents.add(ConversationIntent.askHelpOrQuestion);
    }

    // Agradecimiento
    if (tokens.contains('gracias') ||
        normalized.contains('muchas gracias') ||
        normalized.contains('mil gracias') ||
        normalized.contains('te agradezco') ||
        normalized.contains('muy amable')) {
      intents.add(ConversationIntent.thanks);
    }

    // Despedida
    if (tokens.contains('chao') ||
        tokens.contains('adios') ||
        normalized.contains('hasta luego') ||
        normalized.contains('nos vemos') ||
        normalized.contains('hablamos') ||
        normalized.contains('descans') ||
        normalized.contains('hasta manana') ||
        normalized.contains('feliz noche') ||
        normalized.contains('buenas noches') ||
        normalized.contains('feliz tarde') ||
        normalized.contains('que estes bien') ||
        normalized.contains('que este bien') ||
        tokens.contains('cuidate')) {
      intents.add(ConversationIntent.farewell);
    }

    // Risa
    if (tokens.any(
      (t) =>
          t.startsWith('jaja') || t.startsWith('jeje') || t.startsWith('jajaj'),
    )) {
      intents.add(ConversationIntent.laughter);
    }

    // Afirmación
    final isAffirmativeSi = normalized == 'si' ||
        normalized == 'si claro' ||
        normalized == 'si de una' ||
        normalized == 'si hagamosle' ||
        normalized == 'si vamos' ||
        normalized == 'si creo que si' ||
        normalized == 'si esta bien' ||
        normalized == 'si porfa' ||
        normalized == 'si gracias' ||
        normalized == 'si quiero ir' ||
        normalized == 'si puede ser';

    if (isAffirmativeSi ||
        tokens.contains('dale') ||
        tokens.contains('listo') ||
        tokens.contains('ok') ||
        tokens.contains('perfecto') ||
        tokens.contains('claro') ||
        tokens.contains('seguro') ||
        tokens.contains('hagamosle') ||
        normalized.contains('de una') ||
        normalized.contains('de acuerdo') ||
        normalized.contains('me parece bien') ||
        normalized.contains('me sirve') ||
        normalized.contains('listo pues') ||
        normalized.contains('dale pues')) {
      intents.add(ConversationIntent.affirmation);
    }

    // Negación / Rechazar suavemente
    final isNegation = tokens.contains('no') ||
        normalized.contains('para nada') ||
        normalized.contains('no gracias') ||
        normalized.contains('por ahora no') ||
        normalized.contains('no creo') ||
        normalized.contains('creo que no') ||
        normalized.contains('no puedo') ||
        normalized.contains('no se si pueda') ||
        normalized.contains('hoy no creo') ||
        normalized.contains('tal vez otro dia') ||
        normalized.contains('hoy estoy ocupado') ||
        normalized.contains('mejor despues');

    if (isNegation &&
        !normalized.contains('no te preocupes') &&
        !normalized.contains('no hay problema') &&
        !normalized.contains('no pasa nada')) {
      intents.add(ConversationIntent.negation);
    }

    // Pregunta sobre batería / carga del celular (Nivel 2: Fast Path + Android)
    if (normalized.contains('bateria') ||
        normalized.contains('cuanta carga') ||
        normalized.contains('cuanta bateria') ||
        normalized.contains('nivel de carga') ||
        normalized.contains('porcentaje de bateria') ||
        (normalized.contains('carga') &&
            (normalized.contains('tiene') ||
                normalized.contains('tienes') ||
                normalized.contains('queda')))) {
      intents.add(ConversationIntent.askDeviceBattery);
    }

    // Recordatorio de plan / compromiso previo ("dijiste que íbamos", "habías dicho que salíamos")
    if (normalized.contains('dijiste que') ||
        normalized.contains('dijiste') ||
        normalized.contains('habias dicho') ||
        normalized.contains('habias prometido') ||
        normalized.contains('quedamos en') ||
        normalized.contains('quedamos de') ||
        normalized.contains('hablamos de')) {
      intents.add(ConversationIntent.planReminder);
    }

    // Pregunta sobre la hora ("qué hora es", "tienes la hora", "qué hora tienes")
    if (normalized.contains('que hora es') ||
        normalized.contains('que horas son') ||
        normalized.contains('tienes la hora') ||
        normalized.contains('que hora tienes') ||
        normalized.contains('hora tienes') ||
        normalized.contains('me dices la hora') ||
        normalized.contains('la hora porfa') ||
        normalized.contains('que hora es por alla')) {
      intents.add(ConversationIntent.askTime);
    }

    // Pregunta sobre la fecha / día ("qué día es hoy", "qué fecha es hoy", "a cómo estamos")
    if (normalized.contains('que dia es hoy') ||
        normalized.contains('que fecha es hoy') ||
        normalized.contains('a como estamos hoy') ||
        normalized.contains('a cuantos estamos') ||
        normalized.contains('a como estamos') ||
        normalized.contains('que dia estamos') ||
        normalized.contains('que dia de la semana es')) {
      intents.add(ConversationIntent.askDate);
    }

    // Pregunta sobre ubicación / ciudad / país ("dónde estás", "en qué ciudad estás", "de dónde eres")
    if (normalized.contains('donde estas') ||
        normalized.contains('en que ciudad estas') ||
        normalized.contains('en donde estas') ||
        normalized.contains('de que ciudad eres') ||
        normalized.contains('de donde eres') ||
        normalized.contains('en que pais estas') ||
        normalized.contains('por donde andas') ||
        normalized.contains('en que lugar estas')) {
      intents.add(ConversationIntent.askLocation);
    }

    // Pregunta sobre disponibilidad / ocupación
    if (normalized.contains('estas ocupado') ||
        normalized.contains('andas ocupado') ||
        normalized.contains('estas ocupada') ||
        normalized.contains('andas ocupada') ||
        normalized.contains('tienes tiempo') ||
        normalized.contains('puedes hablar') ||
        normalized.contains('estas libre') ||
        normalized.contains('andas libre') ||
        normalized.contains('tienes un momento') ||
        normalized.contains('tienes un minuto') ||
        normalized.contains('tienes un ratico') ||
        normalized.contains('puedes responder')) {
      intents.add(ConversationIntent.askAvailability);
    }

    // Pregunta sobre comida / alimentación
    if (normalized.contains('almorzaste') ||
        normalized.contains('ya comiste') ||
        normalized.contains('cenaste') ||
        normalized.contains('desayunaste') ||
        normalized.contains('vas a comer') ||
        normalized.contains('que almorzaste') ||
        normalized.contains('que comiste') ||
        normalized.contains('que cenaste') ||
        normalized.contains('tienes hambre')) {
      intents.add(ConversationIntent.askFood);
    }

    // Pregunta sobre presencia física / casa
    if (normalized.contains('estas en la casa') ||
        normalized.contains('andas en la casa') ||
        normalized.contains('estas en casa') ||
        normalized.contains('andas en casa') ||
        normalized.contains('estas en tu casa') ||
        normalized.contains('en la casa?') ||
        normalized.contains('en la casa ?') ||
        normalized.contains('en casa?')) {
      intents.add(ConversationIntent.askPhysicalLocation);
    }

    // Pregunta sobre bienestar familiar / entorno
    if (normalized.contains('tu familia') ||
        normalized.contains('la familia') ||
        normalized.contains('en tu casa') ||
        normalized.contains('los tuyos') ||
        normalized.contains('todos en tu casa') ||
        normalized.contains('como van todos') ||
        normalized.contains('como estan todos') ||
        normalized.contains('como esta la gente')) {
      intents.add(ConversationIntent.askFamily);
    }

    // Pregunta sobre descanso / noche / sueño
    if (normalized.contains('vas a dormir') ||
        normalized.contains('te vas a dormir') ||
        normalized.contains('sigues despierto') ||
        normalized.contains('andas despierto') ||
        normalized.contains('trasnochando') ||
        normalized.contains('no puedes dormir') ||
        normalized.contains('despierto a esta hora') ||
        normalized.contains('te vas a acostar')) {
      intents.add(ConversationIntent.askSleep);
    }

    // Pregunta sobre música / beats / canciones
    if (normalized.contains('estas escuchando') ||
        normalized.contains('que musica') ||
        normalized.contains('escuchando musica') ||
        normalized.contains('que tema') ||
        normalized.contains('que cancion') ||
        normalized.contains('que beat') ||
        normalized.contains('oyendo musica')) {
      intents.add(ConversationIntent.askMusic);
    }

    // Pregunta sobre clima cotidiano
    if (normalized.contains('lloviendo') ||
        normalized.contains('esta lloviendo') ||
        normalized.contains('mucho calor') ||
        normalized.contains('hace calor') ||
        normalized.contains('hace frio') ||
        normalized.contains('como esta el clima') ||
        normalized.contains('que tal el clima')) {
      intents.add(ConversationIntent.askWeatherSocial);
    }

    // Solicitud de llamada telefónica
    if (normalized.contains('puedo llamar') ||
        normalized.contains('te puedo llamar') ||
        normalized.contains('te puedo marcar') ||
        normalized.contains('hacemos llamada') ||
        normalized.contains('hablar por llamada') ||
        normalized.contains('tiempo para una llamada') ||
        normalized.contains('te marco') ||
        normalized.contains('te llamo')) {
      intents.add(ConversationIntent.askCall);
    }

    // Ausencia / "Andas perdido"
    if (normalized.contains('te perdiste') ||
        normalized.contains('que te hiciste') ||
        normalized.contains('tan perdido') ||
        normalized.contains('por que tan perdido') ||
        normalized.contains('andas perdido') ||
        normalized.contains('donde te metiste')) {
      intents.add(ConversationIntent.askLostOrMissing);
    }

    // Opinión / Visto bueno
    if (normalized.contains('como lo ves') ||
        normalized.contains('que opinas') ||
        normalized.contains('te gusta') ||
        normalized.contains('que tal te parece') ||
        normalized.contains('como te parece') ||
        normalized.contains('que te parece') ||
        normalized.contains('esta bacano') ||
        normalized.contains('esta chimba')) {
      intents.add(ConversationIntent.askOpinionSocial);
    }

    // Si es saludo puro según el tokenizer pero no activó flag específico
    if (intents.isEmpty && isPureGreeting(normalized)) {
      intents.add(ConversationIntent.greeting);
    }

    return intents;
  }
}
