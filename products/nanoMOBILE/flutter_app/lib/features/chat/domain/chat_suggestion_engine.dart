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

  /// Deriva sugerencias contextuales basadas en el contenido de la respuesta generada.
  static List<String> derive(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('```') ||
        lower.contains('bash') ||
        lower.contains('código') ||
        lower.contains('script')) {
      return const ['Explicar código', 'Ejecutar en Terminal', 'Simplificar'];
    }
    if (lower.contains('error') ||
        lower.contains('falló') ||
        lower.contains('problema')) {
      return const ['¿Cómo solucionarlo?', 'Ver logs', 'Probar alternativa'];
    }
    if (lower.contains('linux') ||
        lower.contains('apt') ||
        lower.contains('terminal')) {
      return const ['💻 Abrir Linux', 'Ver paquetes', 'Ayuda de comandos'];
    }
    return const ['Profundizar más', 'Dar un ejemplo práctico', '¿Qué sigue?'];
  }
}
