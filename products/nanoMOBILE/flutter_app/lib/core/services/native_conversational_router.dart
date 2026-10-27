// native_conversational_router.dart — Router conversacional nativo y reactivo de Nano.
// QUÉ HACE: Comprende turnos desde un simple "hola" hasta párrafos extensos y complejos sin LLM en RAM.
// CÓMO FUNCIONA: Enrutamiento por intención determinista hacia resolvedores especializados (SOLID/SRP).
// POR QUÉ: Erradica respuestas robóticas y latencias innecesarias, manteniendo archivos < 200 líneas.
library;

import 'conversational/conversational_action_resolvers.dart';
import 'conversational/conversational_intent_matcher.dart';
import 'conversational/conversational_semantic_resolvers.dart';
import 'conversational/conversational_system_resolvers.dart';
import 'conversational/native_conversational_response.dart';
export 'conversational/native_conversational_response.dart';

class NativeConversationalRouter {
  const NativeConversationalRouter();

  NativeConversationalResponse? tryResolve(String input, {bool hasModel = false}) {
    final clean = input.trim();
    if (clean.isEmpty) return null;
    final lower = clean.toLowerCase();

    final stripped = ConversationalIntentMatcher.stripGreeting(lower);
    final isPureGreeting = stripped.isEmpty || ConversationalIntentMatcher.isGreetingOnly(lower);

    final target = stripped.isNotEmpty ? stripped : lower;

    // Si hay modelo disponible o activo, TODAS las interacciones conversacionales
    // (saludos, gracias, identidad, preguntas) deben ir directo al modelo LLM para razonar de verdad.
    // Solo se interceptan comandos de control de hardware/apps u operaciones del sistema.
    if (hasModel) {
      if (ConversationalIntentMatcher.isAppControlDomain(lower) || ConversationalIntentMatcher.isAppControlDomain(target)) {
        return ConversationalActionResolvers.resolveAppControl(clean, target);
      }
      return null;
    }

    // Modo Nativo Autónomo (ÚNICAMENTE cuando NO hay modelo cargado en RAM ni API configurada)
    // 1. Saludos cotidianos puros (ej: "hola", "buenos días", "hola nano")
    if (isPureGreeting && ConversationalIntentMatcher.isGreeting(lower)) {
      return ConversationalSystemResolvers.resolveGreeting(hasModel: false);
    }

    // 2. Agradecimientos
    if (ConversationalIntentMatcher.isThanks(lower)) {
      return ConversationalSystemResolvers.resolveThanks();
    }

    // 3. Despedidas
    if (ConversationalIntentMatcher.isFarewell(lower)) {
      return ConversationalSystemResolvers.resolveFarewell();
    }

    // 4. Identidad de Nano
    if (ConversationalIntentMatcher.isIdentity(lower) || ConversationalIntentMatcher.isIdentity(target)) {
      return ConversationalSystemResolvers.resolveIdentity();
    }

    // 5. Ayuda y Capacidades
    if (ConversationalIntentMatcher.isHelpRequest(lower) || ConversationalIntentMatcher.isHelpRequest(target)) {
      return ConversationalSystemResolvers.resolveHelp();
    }

    // 6. Telemetría y estado del hardware
    if (ConversationalIntentMatcher.isSystemStatusRequest(lower) || ConversationalIntentMatcher.isSystemStatusRequest(target)) {
      return ConversationalSystemResolvers.resolveSystemStatus();
    }

    // Modo Nativo Autónomo (sin modelo LLM cargado en RAM)
    // 7. Control & Apertura de Aplicaciones y Ajustes
    if (ConversationalIntentMatcher.isAppControlDomain(lower) || ConversationalIntentMatcher.isAppControlDomain(target)) {
      return ConversationalActionResolvers.resolveAppControl(clean, target);
    }

    // 8. Automatización & Tareas
    if (ConversationalIntentMatcher.isAutomationDomain(lower) || ConversationalIntentMatcher.isAutomationDomain(target)) {
      return ConversationalActionResolvers.resolveAutomation(clean, target);
    }

    // 9. Linux & Terminal
    if (ConversationalIntentMatcher.isLinuxDomain(lower) || ConversationalIntentMatcher.isLinuxDomain(target)) {
      return ConversationalActionResolvers.resolveLinux(clean, target);
    }

    // 10. Diagnóstico de IP pública
    if (ConversationalIntentMatcher.isIpQuery(lower) || ConversationalIntentMatcher.isIpQuery(target)) {
      return ConversationalActionResolvers.resolveIpQuery();
    }

    // 11. Cuentas e inicio de sesión web (ChatGPT / DeepSeek / Claude / Gemini)
    if (ConversationalIntentMatcher.isWebAccountLoginIntent(lower) || ConversationalIntentMatcher.isWebAccountLoginIntent(target)) {
      return ConversationalActionResolvers.resolveWebAccountLogin(lower);
    }

    // 12. Cuenta de Google e Identidad del Usuario en Nano AI
    if (ConversationalIntentMatcher.isGoogleAccountQuery(lower) || ConversationalIntentMatcher.isGoogleAccountQuery(target)) {
      return ConversationalActionResolvers.resolveGoogleAccount();
    }

    // 13. Repositorios de Skills y Optimización Open Source
    if (ConversationalIntentMatcher.isSkillsRepoQuery(lower) || ConversationalIntentMatcher.isSkillsRepoQuery(target)) {
      return ConversationalSemanticResolvers.resolveSkillsRepository(clean, target);
    }

    // 14. Búsqueda Web / Google en Lenguaje Natural
    if (ConversationalIntentMatcher.isWebSearchIntent(lower) || ConversationalIntentMatcher.isWebSearchIntent(target)) {
      return ConversationalSemanticResolvers.resolveWebSearchIntent(clean, target);
    }

    // 15. Modelos & Inteligencia Artificial
    if (ConversationalIntentMatcher.isAIModelDomain(lower) || ConversationalIntentMatcher.isAIModelDomain(target)) {
      return ConversationalSemanticResolvers.resolveAIModels(clean, target, hasModel);
    }

    // 16. Desarrollo & Código
    if (ConversationalIntentMatcher.isDevelopmentDomain(lower) || ConversationalIntentMatcher.isDevelopmentDomain(target)) {
      return ConversationalSemanticResolvers.resolveDevelopment(clean, target);
    }

    // 17. Comprensión semántica de párrafos grandes en modo nativo (>100 chars, multilínea o >=10 palabras)
    if (clean.length > 100 || clean.contains('\n') || target.split(RegExp(r'\s+')).length >= 10) {
      return ConversationalSemanticResolvers.resolveParagraph(clean, target, hasModel);
    }

    // 18. Si no es un comando de sistema o diagnóstico operativo reconocido, retornar null
    // para evitar fallbacks simulados con respuestas robóticas o predeterminadas.
    return null;
  }
}
