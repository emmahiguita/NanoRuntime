/// Motor de generación heurística de sugerencias rápidas tras la respuesta de IA.
///
/// **QUÉ HACE:**
/// Analiza el texto de respuesta del asistente para derivar 3 opciones contextuales inmediatas.
///
/// **CÓMO FUNCIONA:**
/// Evalúa palabras clave del contenido (bloques de código, errores, referencias a terminal Linux)
/// y devuelve un conjunto acotado de sugerencias accionables.
///
/// **POR QUÉ:**
/// Enriquece la experiencia móvil (UX) permitiendo al usuario continuar la interacción
/// con un solo toque (chips sugeridos) sin tener que escribir en el teclado táctil.
class ChatSuggestionEngine {
  const ChatSuggestionEngine();

  // QUÉ HACE: Deriva sugerencias contextuales basadas en el contenido de la respuesta generada.
  // CÓMO FUNCIONA: Heurística semántica por intención: código, errores, Linux, modelos, saludos o explicaciones.
  // POR QUÉ: Permite interacción continua fluida con chips táctiles sin fricción de teclado en móvil.
  static List<String> derive(String text) {
    final lower = text.toLowerCase();

    // 1. Código / scripts / ejecución
    if (lower.contains('```') ||
        lower.contains('bash') ||
        lower.contains('código') ||
        lower.contains('script')) {
      return const ['Explicar código', 'Ejecutar en Terminal', 'Simplificar'];
    }

    // 2. Errores / excepciones / depuración
    if (lower.contains('error') ||
        lower.contains('falló') ||
        lower.contains('problema') ||
        lower.contains('bug')) {
      return const ['¿Cómo solucionarlo?', 'Ver logs', 'Probar alternativa'];
    }

    // 3. Entorno Linux / terminal / subsistema
    if (lower.contains('linux') ||
        lower.contains('apt') ||
        lower.contains('terminal') ||
        lower.contains('ubuntu')) {
      return const ['💻 Abrir Linux', 'Ver paquetes', 'Ayuda de comandos'];
    }

    // 4. Modelos neuronales / IA local / RAM
    if (lower.contains('modelo') ||
        lower.contains('gguf') ||
        lower.contains('qwen') ||
        lower.contains('deepseek') ||
        lower.contains('whisper')) {
      return const ['🤖 Catálogo de Modelos', '⚡ Diagnóstico de RAM', 'Comparar modelos'];
    }

    // 5. Automatización Android / Shizuku / WhatsApp
    if (lower.contains('automatiz') ||
        lower.contains('shizuku') ||
        lower.contains('whatsapp') ||
        lower.contains('notificaci')) {
      return const ['⚡ Ver Tareas Activas', 'Crear Nueva Automatización', 'Probar Disparador'];
    }

    // 6. Saludo o bienvenida inicial
    if (lower.contains('hola') ||
        lower.contains('buenos días') ||
        lower.contains('buenas tardes') ||
        lower.contains('bienvenido')) {
      return const ['⚡ Diagnóstico del Sistema', '💻 Abrir Linux', '🤖 Catálogo de Modelos'];
    }

    // 7. Pregunta o alternativas sugeridas por la IA
    if (lower.contains('¿') || lower.contains('opciones') || lower.contains('pasos')) {
      return const ['Opción recomendada', 'Ver paso a paso', 'Dar un ejemplo práctico'];
    }

    return const ['Profundizar más', 'Dar un ejemplo práctico', '¿Qué sigue?'];
  }
}
