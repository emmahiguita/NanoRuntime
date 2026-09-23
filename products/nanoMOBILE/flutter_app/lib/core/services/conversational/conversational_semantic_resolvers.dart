// conversational_semantic_resolvers.dart — Comprensión de párrafos grandes y dominios AI.
// QUÉ HACE: Procesa párrafos complejos, búsqueda web, catálogo de repos/skills y modelos AI.
// CÓMO FUNCIONA: Extrae tópicos clave, sugiere alternativas y evita frases robóticas o respuestas vacías.
// POR QUÉ: Garantiza que la app entienda desde un "hola" hasta párrafos grandes sin colgarse (< 200 líneas).
library;

import 'conversational_intent_matcher.dart';
import 'native_conversational_response.dart';

class ConversationalSemanticResolvers {
  static NativeConversationalResponse resolveAIModels(String clean, String lower, bool hasModel) {
    if (hasModel) {
      return const NativeConversationalResponse(
        text:
            'El modelo neuronal local está activo en memoria y listo para procesar instrucciones complejas. '
            'Puedes realizar preguntas técnicas o pedirle generación de código directamente.',
        suggestions: ['🤖 Ver Configuración del Modelo', '⚡ Probar Inferencia', '📊 Ver Telemetría RAM'],
      );
    }
    return const NativeConversationalResponse(
      text:
          'Actualmente no hay un modelo GGUF cargado en RAM. Para razonamiento profundo local:\n\n'
          '• **Modelos Recomendados**: Modelos ligeros de 0.5B o 1.5B (ej: Qwen 2.5) ideales para móviles con 4GB de RAM.\n'
          '• **APIs Externas**: Puedes activar un proveedor en la nube (Gemini, Claude, OpenAI) si prefieres no consumir RAM local.\n'
          '• **Modo Nativo**: Las tareas de Linux, comandos de automatización y telemetría operan sin necesidad de modelo.',
      suggestions: ['🤖 Ir a Catálogo de Modelos', '🧠 Configurar Proveedor Externo', '💻 Abrir Terminal Linux'],
    );
  }

  static NativeConversationalResponse resolveDevelopment(String clean, String lower) =>
      const NativeConversationalResponse(
        text:
            'NanoAI está construido siguiendo **Clean Architecture**, principios **SOLID** y una integración estrecha entre Flutter/Dart, Kotlin y C++ (NDK):\n\n'
            '• **Capa de Dominio**: Entidades inmutables y contratos abstractos (DIP).\n'
            '• **Capa de Aplicación**: Coordinadores y motores de ejecución con timeouts defensivos.\n'
            '• **Capa de Infraestructura**: Comunicación JNI segura, control de procesos PTY y sockets RFB zero-copy.',
        suggestions: ['💻 Abrir Terminal Linux', '⚡ Ver Estado del Dispositivo', '🛠️ Ver Capacidades'],
      );

  static NativeConversationalResponse resolveSkillsRepository(String clean, String target) {
    final sb = StringBuffer();
    sb.writeln('# 🚀 Repositorio Recomendado: [huggingface/alignment-handbook](https://github.com/huggingface/alignment-handbook)\n');
    sb.writeln('### 📋 Ficha Técnica y Autoría');
    sb.writeln('* **Organización:** Hugging Face (Equipo H4).');
    sb.writeln('* **Licencia:** Apache 2.0 (100% Código Abierto).');
    sb.writeln('* **Ecosistema:** PyTorch, TRL, DeepSpeed ZeRO-3, FlashAttention-2.\n');
    sb.writeln('### 🎯 Mejoras en Modelos Open Source');
    sb.writeln('1. **DPO & ORPO:** Alineación directa sin Reward Model pesado.');
    sb.writeln('2. **SFT de Skills:** Entrenamiento con datasets UltraFeedback y No_Robots.');
    sb.writeln('3. **Chain-of-Thought:** Razonamiento estructurado paso a paso en código y lógica.\n');
    sb.writeln('### 🌟 Repositorios Complementarios');
    sb.writeln('* **[stanfordnlp/dspy](https://github.com/stanfordnlp/dspy)** — Optimización algorítmica de prompts.');
    sb.writeln('* **[modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers)** — Catálogo de tools MCP.');

    return NativeConversationalResponse(
      text: sb.toString().trim(),
      suggestions: const ['🌐 Abrir Repo en Chrome', '💻 Clonar en Linux', '⚡ Estado del Dispositivo', '🤖 Catálogo de Modelos'],
    );
  }

  static NativeConversationalResponse resolveWebSearchIntent(String clean, String target) {
    if (ConversationalIntentMatcher.isSkillsRepoQuery(clean) || ConversationalIntentMatcher.isSkillsRepoQuery(target)) {
      return resolveSkillsRepository(clean, target);
    }
    final query = clean
        .replaceAll(RegExp(r'^(busca|buscar|buscalo|búscalo)\s+(en|por)?\s*(google|internet)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(en|por)\s*(google|internet)\s*$', caseSensitive: false), '')
        .trim();
    final actualQuery = query.isNotEmpty ? query : clean;

    return NativeConversationalResponse(
      text:
          '### 🔍 Consulta de Búsqueda: "$actualQuery"\n\n'
          'Puedes obtener la respuesta sintetizada directamente en este chat con:\n'
          '👉 `@buscar $actualQuery`\n\n'
          'O abrir la navegación en Google Chrome con:\n'
          '👉 `@url https://www.google.com/search?q=${Uri.encodeComponent(actualQuery)}`',
      suggestions: ['@buscar $actualQuery', '🌐 Abrir en Chrome', '⚡ Estado del Dispositivo'],
    );
  }

  static NativeConversationalResponse resolveParagraph(String clean, String lower, bool hasModel) {
    final topics = <String>[];
    final suggestions = <String>[];

    if (ConversationalIntentMatcher.isAutomationDomain(lower)) {
      topics.add('⚡ Automatización y mensajería en Android');
      suggestions.add('💬 Ir a Automatización');
    }
    if (ConversationalIntentMatcher.isLinuxDomain(lower)) {
      topics.add('💻 Entorno y comandos de Linux');
      suggestions.add('💻 Abrir Terminal Linux');
    }
    if (ConversationalIntentMatcher.isSystemStatusRequest(lower)) {
      topics.add('📊 Telemetría y diagnóstico de hardware');
      suggestions.add('⚡ Estado del Dispositivo');
    }
    if (ConversationalIntentMatcher.isAIModelDomain(lower)) {
      topics.add('🤖 Inferencia y modelos de lenguaje');
      suggestions.add('🤖 Ver Modelos GGUF');
    }
    if (ConversationalIntentMatcher.isDevelopmentDomain(lower)) {
      topics.add('🛠️ Arquitectura, código y desarrollo');
      suggestions.add('🛠️ Ver Capacidades');
    }

    final StringBuffer buffer = StringBuffer();
    if (topics.isNotEmpty) {
      buffer.writeln('Entiendo perfectamente tu solicitud. He identificado los siguientes temas principales:');
      for (final t in topics) {
        buffer.writeln('• $t');
      }
      buffer.writeln();
    } else {
      buffer.writeln('He recibido y procesado el contenido de tu mensaje detallado.\n');
    }

    if (hasModel) {
      buffer.writeln('El modelo local está activo para profundizar en el razonamiento de este texto.');
    } else {
      buffer.writeln('¿Qué acción te gustaría que ejecutemos sobre esta información?');
    }

    if (suggestions.isEmpty) {
      suggestions.addAll(['💻 Abrir Terminal', '⚡ Diagnóstico', '💬 Automatizar', '🤖 Catálogo']);
    } else if (suggestions.length < 3) {
      suggestions.add('🛠️ Ver Capacidades');
      suggestions.add('⚡ Estado del Dispositivo');
    }

    return NativeConversationalResponse(
      text: buffer.toString().trim(),
      suggestions: suggestions.take(4).toList(growable: false),
    );
  }

  static NativeConversationalResponse resolveConversationalFallback(String clean, String lower) {
    return const NativeConversationalResponse(
      text:
          'Te escucho atentamente. El sistema está listo para asistirte en tiempo real con ejecución local, '
          'automatización de tareas y diagnóstico. ¿Cómo prefieres continuar?',
      suggestions: [
        '⚡ Estado del Dispositivo',
        '💻 Abrir Terminal Linux',
        '🤖 Catálogo de Modelos',
        '🛠️ ¿Qué puedes hacer?',
      ],
    );
  }
}
