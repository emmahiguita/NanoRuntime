// conversational_intent_matcher.dart — Reconocedor de intenciones en lenguaje natural.
// QUÉ HACE: Detecta patrones léxicos y semánticos (saludos, hardware, comandos, repos, cuentas).
// CÓMO FUNCIONA: Análisis determinista por palabras clave y expresiones sin consumo de CPU/RAM de LLM.
// POR QUÉ: Permite clasificar la intención en <1ms y enviar la solicitud al resolvedor adecuado.
library;

class ConversationalIntentMatcher {
  static const _salutations = [
    'buenos días', 'buenos dias', 'buenas tardes', 'buenas noches',
    'buen día', 'buen dia', 'que tal', 'qué tal', 'como estas', 'cómo estás',
    'hola', 'buenas', 'hey', 'saludos', 'hi', 'hello', 'iniciar', 'empezar',
  ];

  static String stripGreeting(String text) {
    String res = text.trim();
    for (final g in _salutations) {
      if (res == g) return '';
      if (res.startsWith('$g ')) res = res.substring(g.length + 1).trim();
      if (res.endsWith(' $g')) res = res.substring(0, res.length - g.length - 1).trim();
    }
    if (res.startsWith('nano ') || res.startsWith('nano, ')) {
      res = res.replaceFirst(RegExp(r'^nano[,\s]+'), '').trim();
    }
    return res;
  }

  static bool isGreetingOnly(String text) {
    final t = text.trim();
    if (_salutations.contains(t)) return true;
    const pure = [
      'hola nano', 'hola amigo', 'buenas nano', 'hey nano',
      'hola que tal', 'hola cómo estás', 'hola como estas',
    ];
    return pure.contains(t);
  }

  static bool isGreeting(String text) =>
      _salutations.contains(text) ||
      _salutations.any((g) => text.startsWith('$g ') || text.endsWith(' $g'));

  static bool isThanks(String text) =>
      text.contains('gracias') || text.contains('muchas gracias') ||
      text.contains('te lo agradezco') || text.contains('mil gracias') || text.contains('thank');

  static bool isFarewell(String text) => const {
    'chao', 'adios', 'adiós', 'hasta luego', 'nos vemos', 'bye',
  }.contains(text);

  static bool isIdentity(String text) =>
      text.contains('quien eres') || text.contains('quién eres') ||
      text.contains('como te llamas') || text.contains('cómo te llamas') ||
      text.contains('que eres') || text.contains('qué eres');

  static bool isHelpRequest(String text) {
    const q = ['que puedes hacer', 'qué puedes hacer', 'que haces', 'qué haces', 'ayuda', 'help', 'comandos', 'capacidades', 'opciones', 'manual'];
    return q.any((h) => text.contains(h));
  }

  static bool isSystemStatusRequest(String text) {
    const q = ['estado', 'bateria', 'batería', 'ram', 'memoria', 'espacio', 'disco', 'rendimiento', 'temperatura', 'hardware', 'celular', 'dispositivo', 'cpu'];
    return q.any((s) => text.contains(s));
  }

  static bool isAutomationDomain(String text) {
    const k = ['whatsapp', 'notificacion', 'notificación', 'notificaciones', 'mensaje', 'mensajes', 'enviar', 'envia', 'envía', 'manda', 'mandar', 'escribe', 'escribir', 'responde', 'responder', 'contesta', 'contestar', 'automatiza', 'automatizar', 'automatización', 'automatizacion', 'regla', 'reglas', 'recordatorio', 'recordatorios', 'shizuku'];
    return k.any((kw) => text.contains(kw));
  }

  static bool isLinuxDomain(String text) {
    const k = ['linux', 'ubuntu', 'terminal', 'consola', 'shell', 'bash', 'apt', 'compil', 'gcc', 'g++', 'python', 'script', 'c++', 'openbox', 'vnc', 'escritorio', 'pty', 'rootfs'];
    return k.any((kw) => text.contains(kw));
  }

  static bool isAIModelDomain(String text) {
    const k = ['modelo', 'modelos', 'gguf', 'llama', 'qwen', 'phi', 'deepseek', 'gemini', 'chatgpt', 'openai', 'claude', 'inteligencia artificial', 'inferencia', 'tokens', 'llm'];
    return k.any((kw) => text.contains(kw));
  }

  static bool isDevelopmentDomain(String text) {
    const k = ['código', 'codigo', 'programar', 'programación', 'flutter', 'dart', 'kotlin', 'android', 'gradle', 'cmake', 'jni', 'bug', 'arquitectura', 'solid'];
    return k.any((kw) => text.contains(kw));
  }

  static bool isAppControlDomain(String text) =>
      text.startsWith('abre ') || text.startsWith('abrir ') ||
      text.startsWith('lanza ') || text.startsWith('lanzar ') ||
      text.startsWith('ejecuta ') || text.startsWith('ejecutar ') ||
      text.startsWith('inicia ') || text.startsWith('iniciar ') ||
      text.startsWith('entra a ') || text.startsWith('ve a ');

  static bool isSkillsRepoQuery(String text) {
    final t = text.toLowerCase();
    final hasRepo = t.contains('repositorio') || t.contains('repo') || t.contains('github') || t.contains('git ') || t.contains('link') || t.contains('enlace');
    final hasSkills = t.contains('skill') || t.contains('habilidad') || t.contains('open source') || t.contains('codigo abierto') || t.contains('código abierto') || t.contains('nivel de respuesta') || t.contains('mejorar modelo') || t.contains('alignment') || t.contains('dspy') || t.contains('axolotl');
    return (hasRepo && hasSkills) || t.contains('repositorio de skills') || t.contains('repo de skills') || t.contains('skills para modelos');
  }

  static bool isWebSearchIntent(String text) {
    final t = text.toLowerCase();
    return t.startsWith('busca en google') || t.startsWith('buscar en google') ||
        t.startsWith('busca en internet') || t.startsWith('buscar en internet') ||
        t.startsWith('buscalo en google') || t.startsWith('búscalo en google') ||
        t.contains('buscal en google') || t.contains('búscalo en internet') ||
        t.startsWith('investiga en google') || t.startsWith('investiga en internet');
  }

  static bool isIpQuery(String lower) =>
      lower.contains('mi ip') || lower.contains('cual es mi ip') ||
      lower.contains('cuál es mi ip') || lower.contains('dirección ip') ||
      lower.contains('direccion ip') || lower.contains('ip publica') || lower.contains('ip pública');

  static bool isGoogleAccountQuery(String lower) =>
      lower.contains('cuenta de google') || lower.contains('mi cuenta google') ||
      lower.contains('cuenta google') || lower.contains('conectar cuenta') ||
      lower.contains('conectar google') || lower.contains('quien soy') ||
      lower.contains('quién soy') || lower == 'mi cuenta' || lower == 'cuenta' || lower.startsWith('mi cuenta');

  static bool isWebAccountLoginIntent(String lower) =>
      (lower.contains('iniciar sesion') || lower.contains('iniciar sesión') || lower.contains('mi cuenta') || lower.contains('login') || lower.contains('loguear')) &&
      (lower.contains('chatgpt') || lower.contains('chat gpt') || lower.contains('deepseek') || lower.contains('deep seek') || lower.contains('claude') || lower.contains('gemini'));
}
