// personal_intent_router.dart
//
// QUÉ HACE: clasifica de manera determinista y liviana la intención personal del usuario.
// CÓMO: normaliza el texto eliminando puntuación, tildes y mayúsculas, y evalúa patrones de dominio.
// POR QUÉ: evita llamar al LLM o sobrecargar la KV cache para consultas deterministas (hora, fecha, planes).

import '../../engine/language/whatsapp_text_normalizer.dart';
import '../domain/personal_intent.dart';

abstract final class PersonalIntentRouter {
  static String normalize(String input) =>
      WhatsAppTextNormalizer.normalizeForUnderstanding(input);

  static PersonalIntent route(String input) {
    final norm = normalize(input);
    if (norm.isEmpty) return PersonalIntent.generalConversation;

    // 1. Hora actual
    if (norm == 'hora' ||
        norm == 'la hora' ||
        norm.startsWith('que hora') ||
        norm.startsWith('q hora') ||
        norm.contains('la hora') ||
        norm.contains('dime la hora') ||
        norm.contains('que hora es') ||
        norm.contains('que horas son')) {
      return PersonalIntent.currentTime;
    }

    // 2. Fecha actual
    if (norm.contains('que fecha') ||
        norm.contains('que dia es hoy') ||
        norm.contains('hoy que dia es') ||
        norm.contains('cual es la fecha') ||
        norm.contains('en que fecha estamos')) {
      return PersonalIntent.currentDate;
    }

    // 3. Tareas / Rol de Nano (¿Qué harás tú? / ¿Quién estará atento?)
    if (norm.contains('que haras') ||
        norm.contains('que vas a hacer') ||
        norm.contains('que vas hacer') ||
        norm.contains('que tienes pendiente tu') ||
        norm.contains('que tienes tu pendiente') ||
        norm.contains('tu eres quien') ||
        norm.contains('tu quien va a estar') ||
        norm.contains('estar atento con las conversaciones') ||
        norm.contains('atento a las conversaciones') ||
        norm.contains('quien va a estar atento') ||
        norm.contains('quien estara atento')) {
      return PersonalIntent.nanoDailyPlan;
    }

    // 4. Tareas del Usuario (¿Qué tengo que hacer? / ¿Qué hago hoy?)
    if (norm.contains('que tengo que hacer') ||
        norm.contains('que tengo pendiente') ||
        norm.contains('que hago hoy') ||
        norm.contains('que tengo para hoy') ||
        norm.contains('cuales son mis tareas') ||
        norm.contains('que pendientes tengo') ||
        norm.contains('que falta por hacer') ||
        norm.contains('que toca despues') ||
        norm.contains('que hicimos ayer') ||
        norm.contains('que debo recordar hoy')) {
      return PersonalIntent.userDailyPlan;
    }

    // 5. Saludo social puro
    if (norm == 'hola' ||
        norm == 'holaa' ||
        norm == 'buenas' ||
        norm == 'buenos dias' ||
        norm == 'buenas tardes' ||
        norm == 'buenas noches') {
      return PersonalIntent.social;
    }

    return PersonalIntent.generalConversation;
  }
}
