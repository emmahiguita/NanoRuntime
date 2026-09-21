part of 'pragmatic_fast_path.dart';

/// Extracción de intenciones contextuales y de actividad para PragmaticFastPath (< 150 LOC).
///
/// **QUÉ HACE:**
/// Identifica preguntas sobre actividades cotidianas, el transcurso del día,
/// entrenamiento físico, rap/freestyle, invitaciones, presencia, batería, hora, fecha y ubicación.
///
/// **CÓMO FUNCIONA:**
/// Aplica filtros de coincidencia sintáctica normalizada para derivar `ConversationIntent`.
///
/// **POR QUÉ:**
/// Provee respuestas instantáneas a preguntas recurrentes de estado sin invocar el LLM.
extension _PragmaticContextualIntents on PragmaticFastPath {
  void _extractContextualIntents(
    Set<ConversationIntent> intents,
    String normalized,
    Set<String> tokens,
  ) {
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

    if (normalized.contains('tu dia') ||
        normalized.contains('el dia') ||
        normalized.contains('como va el dia') ||
        normalized.contains('como pinta el dia') ||
        normalized.contains('que tal va el dia')) {
      intents.add(ConversationIntent.askDay);
    }

    if (normalized.contains('entren') ||
        normalized.contains('gym') ||
        normalized.contains('gimnasio') ||
        normalized.contains('ejercicio')) {
      intents.add(ConversationIntent.askTraining);
    }

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

    if (normalized.contains('dijiste que') ||
        normalized.contains('dijiste') ||
        normalized.contains('habias dicho') ||
        normalized.contains('habias prometido') ||
        normalized.contains('quedamos en') ||
        normalized.contains('quedamos de') ||
        normalized.contains('hablamos de')) {
      intents.add(ConversationIntent.planReminder);
    }

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

    if (normalized.contains('que dia es hoy') ||
        normalized.contains('que fecha es hoy') ||
        normalized.contains('a como estamos hoy') ||
        normalized.contains('a cuantos estamos') ||
        normalized.contains('a como estamos') ||
        normalized.contains('que dia estamos') ||
        normalized.contains('que dia de la semana es')) {
      intents.add(ConversationIntent.askDate);
    }

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
  }
}
