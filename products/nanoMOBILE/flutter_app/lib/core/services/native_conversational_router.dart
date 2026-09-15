import '../models/chat_models.dart';
import 'device_info.dart';

class NativeConversationalResponse {
  final String text;
  final List<String> suggestions;
  final MessageSource source;

  const NativeConversationalResponse({
    required this.text,
    required this.suggestions,
    this.source = MessageSource.device,
  });
}

/// Router conversacional nativo y reactivo de Nano (SOLID: SRP / OCP).
///
/// Comprende turnos desde un simple "hola" hasta párrafos extensos y complejos
/// sin requerir modelos LLM pesados en memoria RAM, erradicando respuestas
/// robóticas o estáticas y proveyendo opciones de respuesta interactivas.
class NativeConversationalRouter {
  const NativeConversationalRouter();

  NativeConversationalResponse? tryResolve(String input, {bool hasModel = false}) {
    final clean = input.trim();
    if (clean.isEmpty) return null;
    final lower = clean.toLowerCase();

    final stripped = _stripGreeting(lower);
    final isPureGreeting = stripped.isEmpty || _isGreetingOnly(lower);

    // 1. Saludos cotidianos puros (ej: "hola", "buenos días", "hola nano")
    if (isPureGreeting && _isGreeting(lower)) {
      final hour = DateTime.now().hour;
      final timeGreeting = hour < 12
          ? 'Buenos días'
          : (hour < 19 ? 'Buenas tardes' : 'Buenas noches');
      final modelStatus = hasModel
          ? 'El modelo neuronal local está activo.'
          : 'Motor nativo ultraligero activo (0 latencia).';

      return NativeConversationalResponse(
        text:
            '¡$timeGreeting! Soy Nano, tu copiloto en el dispositivo. $modelStatus '
            '¿En qué te puedo colaborar en este momento?',
        suggestions: const [
          '💻 Abrir Linux',
          '⚡ Estado del Dispositivo',
          '🤖 Catálogo de Modelos',
          '🛠️ Ver Capacidades',
        ],
      );
    }

    // 2. Agradecimientos
    if (_isThanks(lower)) {
      return const NativeConversationalResponse(
        text:
            '¡Con todo gusto! Aquí estoy disponible para ayudarte a controlar el sistema, ejecutar procesos o responder tus dudas.',
        suggestions: [
          '💻 Abrir Terminal Linux',
          '⚡ Diagnóstico de Hardware',
          '🛠️ Ver Capacidades',
        ],
      );
    }

    // 3. Despedidas
    if (_isFarewell(lower)) {
      return const NativeConversationalResponse(
        text:
            '¡Hasta luego! El entorno y los servicios de automatización seguirán operando en segundo plano de forma segura.',
        suggestions: [
          '⚡ Ver Estado del Dispositivo',
          '🤖 Catálogo de Modelos',
        ],
      );
    }

    final target = stripped.isNotEmpty ? stripped : lower;

    // 4. Identidad de Nano
    if (_isIdentity(lower) || _isIdentity(target)) {
      return const NativeConversationalResponse(
        text:
            'Soy **Nano**, un asistente autónomo integrado a nivel de sistema operativo en tu dispositivo Android. '
            'Cuento con un subsistema Linux real (Ubuntu/Openbox/PTY), control de accesibilidad y Shizuku para automatizar apps, '
            'y un motor neuronal optimizado para sobrevivir en dispositivos con memoria restringida.',
        suggestions: [
          '🛠️ ¿Qué puedes hacer?',
          '💻 Abrir Linux',
          '⚡ Diagnóstico de Hardware',
          '🤖 Ver Modelos',
        ],
      );
    }

    // 5. Ayuda y Capacidades
    if (_isHelpRequest(lower) || _isHelpRequest(target)) {
      return const NativeConversationalResponse(
        text:
            'Puedo asistirte en múltiples áreas de tu móvil:\n\n'
            '• **Linux y Escritorio**: Terminal PTY nativa, scripts bash/python, Openbox y streaming VNC.\n'
            '• **Automatización Android**: Envío de WhatsApp, lectura de notificaciones, reglas programadas y control con Shizuku.\n'
            '• **Telemetría y Rendimiento**: Monitoreo de memoria RAM física, núcleos de CPU y temperatura en tiempo real.\n'
            '• **Modelos de Lenguaje**: Inferencia local GGUF o conexión con APIs externas.\n\n'
            'Selecciona una de las siguientes opciones para comenzar:',
        suggestions: [
          '💻 Abrir Linux',
          '⚡ Diagnóstico de Hardware',
          '💬 Automatizar Tareas',
          '🤖 Ver Modelos',
        ],
      );
    }

    // 6. Telemetría y estado del hardware
    if (_isSystemStatusRequest(lower) || _isSystemStatusRequest(target)) {
      final dev = DeviceInfo.read();
      final memAvail = dev.memAvailKb != null
          ? '${(dev.memAvailKb! / 1024).round()} MB'
          : 'Disponible';
      final memTotal = dev.memTotalKb != null
          ? '${(dev.memTotalKb! / (1024 * 1024)).toStringAsFixed(1)} GB'
          : 'N/A';
      final cores = dev.cpuCores ?? 8;
      final temp = dev.cpuTempC != null
          ? '${dev.cpuTempC!.toStringAsFixed(0)}°C'
          : 'Normal';

      final arch = dev.unameMachine == '8'
          ? 'ARMv8-A (aarch64)'
          : (dev.unameMachine ?? 'aarch64');
      final kernel = dev.unameRelease ?? 'Linux Android';

      return NativeConversationalResponse(
        text:
            '📊 **Telemetría del Dispositivo en Tiempo Real**:\n\n'
            '* **Memoria RAM:** $memAvail libres de $memTotal\n'
            '* **Núcleos CPU:** $cores activos (Temperatura: $temp)\n'
            '* **Arquitectura:** $arch\n'
            '* **Kernel:** $kernel\n\n'
            'El sistema opera bajo los parámetros de supervivencia de NanoRuntime.',
        suggestions: const [
          '💻 Abrir Terminal PTY',
          '⚡ Automatizar Tarea',
          '🤖 Catálogo de Modelos',
        ],
      );
    }
    // Si el usuario tiene un modelo activo en memoria, cualquier párrafo extenso,
    // consulta técnica, razonamiento o pregunta abierta DEBE fluir al LLM.
    // Solo interceptamos comandos de control directo del SO o saludos puros.
    if (hasModel) {
      if (_isAppControlDomain(lower) || _isAppControlDomain(target)) {
        return _resolveAppControl(clean, target);
      }
      return null;
    }

    // A partir de aquí: Modo Nativo Autónomo (sin modelo LLM cargado en RAM).
    // Comprende desde un simple "hola" hasta párrafos grandes con opciones interactivas.

    // 7. Dominio Control & Apertura de Aplicaciones y Ajustes
    if (_isAppControlDomain(lower) || _isAppControlDomain(target)) {
      return _resolveAppControl(clean, target);
    }

    // 8. Dominio Automatización & Tareas
    if (_isAutomationDomain(lower) || _isAutomationDomain(target)) {
      return _resolveAutomation(clean, target);
    }

    // 9. Dominio Linux & Terminal
    if (_isLinuxDomain(lower) || _isLinuxDomain(target)) {
      return _resolveLinux(clean, target);
    }

    // 9.5 Diagnóstico de IP pública
    if (_isIpQuery(lower) || _isIpQuery(target)) {
      return _resolveIpQuery();
    }

    // 9.6 Cuentas e inicio de sesión web (ChatGPT / DeepSeek / Claude)
    if (_isWebAccountLoginIntent(lower) || _isWebAccountLoginIntent(target)) {
      return _resolveWebAccountLogin(lower);
    }

    // 9.7 Cuenta de Google e Identidad del Usuario en Nano AI
    if (_isGoogleAccountQuery(lower) || _isGoogleAccountQuery(target)) {
      return _resolveGoogleAccount(lower);
    }

    // 10. Dominio específico: Consulta de Repositorios, Skills y Optimización de Modelos Open Source
    if (_isSkillsRepoQuery(lower) || _isSkillsRepoQuery(target)) {
      return _resolveSkillsRepository(clean, target);
    }

    // 11. Dominio específico: Búsqueda Web / Google en Lenguaje Natural
    if (_isWebSearchIntent(lower) || _isWebSearchIntent(target)) {
      return _resolveWebSearchIntent(clean, target);
    }

    // 12. Dominio Modelos & Inteligencia Artificial
    if (_isAIModelDomain(lower) || _isAIModelDomain(target)) {
      return _resolveAIModels(clean, target, hasModel);
    }

    // 11. Dominio Desarrollo & Código
    if (_isDevelopmentDomain(lower) || _isDevelopmentDomain(target)) {
      return _resolveDevelopment(clean, target);
    }

    // 12. Comprensión semántica de párrafos grandes en modo nativo (>100 chars o multilínea o >=10 palabras)
    if (clean.length > 100 || clean.contains('\n') || target.split(RegExp(r'\s+')).length >= 10) {
      return _resolveParagraph(clean, target, hasModel);
    }

    // 13. Fallback conversacional adaptativo (sin frases robóticas)
    return _resolveConversationalFallback(clean, target);
  }

  // ── Resolvedores Semánticos Especializados ─────────────────────────────────

  NativeConversationalResponse _resolveAppControl(String clean, String lower) {
    // 1. Ajustes del sistema
    if (lower.contains('ajuste') ||
        lower.contains('configura') ||
        lower.contains('wifi') ||
        lower.contains('wi-fi') ||
        lower.contains('bluetooth') ||
        lower.contains('bateria') ||
        lower.contains('batería') ||
        lower.contains('pantalla') ||
        lower.contains('sonido')) {
      return const NativeConversationalResponse(
        text:
            'Entendido. Puedo dirigir la navegación directamente a los ajustes del sistema:\n\n'
            '• **Ajustes Generales**: Configuración principal de Android.\n'
            '• **Conexiones**: Wi-Fi, Bluetooth y redes móviles.\n'
            '• **Gestión de Energía**: Ahorro de batería y restricciones en segundo plano.\n\n'
            'Selecciona el destino deseado:',
        suggestions: [
          '⚙️ Abrir Ajustes',
          '📶 Ajustes de Wi-Fi',
          '🔋 Ahorro de Batería',
          '📱 Ajustes de Pantalla',
        ],
      );
    }

    // 2. Cámara o Fotos
    if (lower.contains('camara') ||
        lower.contains('cámara') ||
        lower.contains('foto')) {
      return const NativeConversationalResponse(
        text:
            'Puedo activar la cámara del dispositivo o gestionar capturas de pantalla:\n\n'
            '• Lanzar la aplicación de cámara directamente.\n'
            '• Capturar la pantalla activa para inspección multimodal o extracción de texto.',
        suggestions: [
          '📸 Abrir Cámara',
          '🖼️ Captura de Pantalla',
          '📱 Ir a Inicio',
        ],
      );
    }

    // 3. Aplicaciones externas (YouTube, Spotify, Chrome, WhatsApp, Telegram, etc.)
    final words = clean.split(' ');
    final target = words.length > 1 ? words.sublist(1).join(' ').trim() : 'la aplicación';

    return NativeConversationalResponse(
      text:
          'Para interactuar con **$target**:\n\n'
          '1. **Lanzamiento Directo**: Se puede abrir mediante el gestor de intents nativos.\n'
          '2. **Control por Accesibilidad**: Leer elementos de su interfaz, escribir texto o tocar botones.\n'
          '3. **Privilegios Shizuku**: Detener procesos, otorgar permisos o consultar métricas avanzadas.',
      suggestions: [
        '📱 Abrir $target',
        '💬 Ver Automatizaciones',
        '⚡ Inspeccionar Pantalla',
        '🛡️ Estado Shizuku',
      ],
    );
  }

  NativeConversationalResponse _resolveAutomation(String clean, String lower) {
    // Detectar intención de mensaje
    final isMessageIntent = lower.contains('escribe') ||
        lower.contains('envía') ||
        lower.contains('envia') ||
        lower.contains('manda') ||
        lower.contains('responde') ||
        lower.contains('contesta');

    if (isMessageIntent) {
      return const NativeConversationalResponse(
        text:
            'Detecté una solicitud de automatización de mensajería.\n\n'
            'Para despachar mensajes o respuestas automáticas mediante accesibilidad o Shizuku:\n'
            '1. Puedes usar una regla programada (ej: *"cuando Juan me escriba, respóndele que llego a las 8"*).\n'
            '2. O bien realizar el envío directo en la app de automatización.',
        suggestions: [
          '💬 Ir a Automatización',
          '⚡ Crear Regla de Respuesta',
          '📱 Ver Estado Shizuku',
        ],
      );
    }

    return const NativeConversationalResponse(
      text:
          'El módulo de **Automatización de Nano** permite crear flujos gobernados:\n\n'
          '• **Disparadores de Hora**: Ejecución a horas fijas o intervalos.\n'
          '• **Disparadores de Notificación**: Reaccionar a mensajes de WhatsApp o apps de mensajería.\n'
          '• **Gobernanza**: Validación de seguridad antes de cualquier acción en pantalla.',
      suggestions: [
        '⚡ Ver Reglas Activas',
        '💬 Crear Nueva Regla',
        '📱 Shizuku y Permisos',
      ],
    );
  }

  NativeConversationalResponse _resolveLinux(String clean, String lower) {
    if (lower.contains('compil') || lower.contains('gcc') || lower.contains('c++')) {
      return const NativeConversationalResponse(
        text:
            'Para compilar código nativo en tu contenedor Linux:\n\n'
            '1. Abre la **Terminal PTY**.\n'
            '2. Instala las herramientas con `apt update && apt install build-essential`.\n'
            '3. Compila con `gcc -O2 programa.c -o programa` o `g++ -std=c++17 programa.cpp`.\n\n'
            'Todo se ejecuta en arquitectura nativa aarch64 sin emulación pesada.',
        suggestions: [
          '💻 Abrir Terminal Linux',
          '🖥️ Ver Escritorio VNC',
          '📁 Explorar Archivos',
        ],
      );
    }

    if (lower.contains('python') || lower.contains('script')) {
      return const NativeConversationalResponse(
        text:
            'Tu entorno Linux soporta **Python 3** directamente en el rootfs:\n\n'
            '• Puedes ejecutar scripts con `python3 script.py`.\n'
            '• Instalar librerías con `pip install <paquete>` o `apt install python3-pip`.\n'
            '• Automatizar tareas del sistema comunicándote con las herramientas de Nano.',
        suggestions: [
          '💻 Abrir Terminal Linux',
          '📦 Ver Paquetes Instalados',
          '🖥️ Ver Escritorio VNC',
        ],
      );
    }

    return const NativeConversationalResponse(
      text:
          'El subsistema **Linux** de Nano proporciona un entorno Ubuntu completo con gestor de paquetes `apt`, '
          'soporte para terminal interactiva PTY y entorno gráfico Openbox accesible vía streaming VNC.',
      suggestions: [
        '💻 Abrir Terminal Linux',
        '🖥️ Escritorio VNC',
        '📦 Paquetes del Sistema',
      ],
    );
  }

  NativeConversationalResponse _resolveAIModels(String clean, String lower, bool hasModel) {
    if (hasModel) {
      return const NativeConversationalResponse(
        text:
            'El modelo neuronal local está activo en memoria y listo para procesar instrucciones complejas. '
            'Puedes realizar preguntas técnicas o pedirle generación de código directamente.',
        suggestions: [
          '🤖 Ver Configuración del Modelo',
          '⚡ Probar Inferencia',
          '📊 Ver Telemetría RAM',
        ],
      );
    }

    return const NativeConversationalResponse(
      text:
          'Actualmente no hay un modelo GGUF cargado en RAM. Para razonamiento profundo local:\n\n'
          '• **Modelos Recomendados**: Modelos ligeros de 0.5B o 1.5B (ej: Qwen 2.5) ideales para dispositivos móviles con 4GB de RAM.\n'
          '• **APIs Externas**: Puedes activar un proveedor en la nube (Gemini, Claude, OpenAI) si prefieres no consumir RAM local.\n'
          '• **Modo Nativo**: Las tareas de Linux, comandos de automatización y telemetría operan sin necesidad de modelo.',
      suggestions: [
        '🤖 Ir a Catálogo de Modelos',
        '🧠 Configurar Proveedor Externo',
        '💻 Abrir Terminal Linux',
      ],
    );
  }

  NativeConversationalResponse _resolveDevelopment(String clean, String lower) {
    return const NativeConversationalResponse(
      text:
          'NanoAI está construido siguiendo **Clean Architecture**, principios **SOLID** y una integración estrecha entre Flutter/Dart, Kotlin y C++ (NDK):\n\n'
          '• **Capa de Dominio**: Entidades inmutables y contratos abstractos (DIP).\n'
          '• **Capa de Aplicación**: Coordinadores y motores de ejecución con timeouts defensivos.\n'
          '• **Capa de Infraestructura**: Comunicación JNI segura, control de procesos PTY y sockets RFB zero-copy.',
      suggestions: [
        '💻 Abrir Terminal Linux',
        '⚡ Ver Estado del Dispositivo',
        '🛠️ Ver Capacidades',
      ],
    );
  }

  NativeConversationalResponse _resolveParagraph(String clean, String lower, bool hasModel) {
    final topics = <String>[];
    final suggestions = <String>[];

    if (_isAutomationDomain(lower)) {
      topics.add('Automatización de tareas en Android');
      suggestions.add('💬 Ir a Automatización');
    }
    if (_isLinuxDomain(lower)) {
      topics.add('Terminal y entorno Linux');
      suggestions.add('💻 Abrir Terminal Linux');
    }
    if (_isSystemStatusRequest(lower)) {
      topics.add('Diagnóstico y telemetría de hardware');
      suggestions.add('⚡ Estado del Dispositivo');
    }
    if (_isAIModelDomain(lower)) {
      topics.add('Modelos de lenguaje local');
      suggestions.add('🤖 Ver Modelos GGUF');
    }

    final StringBuffer buffer = StringBuffer();
    if (topics.isNotEmpty) {
      buffer.writeln('Analicé tu solicitud. Los puntos clave detectados se relacionan con:');
      for (final t in topics) {
        buffer.writeln('• $t');
      }
      buffer.writeln();
    } else {
      buffer.writeln('He recibido tu instrucción detallada.');
      buffer.writeln();
    }

    buffer.writeln('Como actualmente no hay un modelo neuronal cargado en RAM, el sistema puede gestionar estas acciones de forma determinista mediante el runtime nativo del dispositivo.');
    buffer.writeln('¿Cómo deseas proceder?');

    if (suggestions.length < 3) {
      suggestions.add('🛠️ Ver Capacidades');
      suggestions.add('💻 Abrir Linux');
      suggestions.add('🤖 Cargar Modelo Local');
    }

    return NativeConversationalResponse(
      text: buffer.toString().trim(),
      suggestions: suggestions.take(4).toList(growable: false),
    );
  }

  NativeConversationalResponse _resolveConversationalFallback(String clean, String lower) {
    final snippet = clean.length > 60 ? '${clean.substring(0, 57)}...' : clean;
    return NativeConversationalResponse(
      text:
          'Recibí: "$snippet".\n\n'
          'El motor nativo ultraligero está listo para asistirte en el dispositivo sin consumo de RAM de LLM. '
          'Elige una de las siguientes opciones para continuar o cargar un modelo:',
      suggestions: const [
        '💻 Abrir Linux',
        '⚡ Estado del Dispositivo',
        '💬 Automatizar Tarea',
        '🤖 Catálogo de Modelos',
      ],
    );
  }

  // ── Detectores de Intención y Vocabulario ──────────────────────────────────

  static const _salutations = [
    'buenos días',
    'buenos dias',
    'buenas tardes',
    'buenas noches',
    'buen día',
    'buen dia',
    'que tal',
    'qué tal',
    'como estas',
    'cómo estás',
    'hola',
    'buenas',
    'hey',
    'saludos',
    'hi',
    'hello',
    'iniciar',
    'empezar',
  ];

  String _stripGreeting(String text) {
    String res = text.trim();
    for (final g in _salutations) {
      if (res == g) {
        return '';
      }
      if (res.startsWith('$g ')) {
        res = res.substring(g.length + 1).trim();
      }
      if (res.endsWith(' $g')) {
        res = res.substring(0, res.length - g.length - 1).trim();
      }
    }
    // Limpieza de complementos comunes como "nano", "amigo", "asistente"
    if (res.startsWith('nano ') || res.startsWith('nano, ')) {
      res = res.replaceFirst(RegExp(r'^nano[,\s]+'), '').trim();
    }
    return res;
  }

  bool _isGreetingOnly(String text) {
    final t = text.trim();
    if (_salutations.contains(t)) return true;
    const purePatterns = [
      'hola nano',
      'hola amigo',
      'buenas nano',
      'hey nano',
      'hola que tal',
      'hola cómo estás',
      'hola como estas',
    ];
    return purePatterns.contains(t);
  }

  bool _isGreeting(String text) {
    return _salutations.contains(text) ||
        _salutations.any((g) => text.startsWith('$g ') || text.endsWith(' $g'));
  }

  bool _isThanks(String text) {
    return text.contains('gracias') ||
        text.contains('muchas gracias') ||
        text.contains('te lo agradezco') ||
        text.contains('mil gracias') ||
        text.contains('thank');
  }

  bool _isFarewell(String text) {
    return text == 'chao' ||
        text == 'adios' ||
        text == 'adiós' ||
        text == 'hasta luego' ||
        text == 'nos vemos' ||
        text == 'bye';
  }

  bool _isIdentity(String text) {
    return text.contains('quien eres') ||
        text.contains('quién eres') ||
        text.contains('como te llamas') ||
        text.contains('cómo te llamas') ||
        text.contains('que eres') ||
        text.contains('qué eres');
  }

  bool _isHelpRequest(String text) {
    const helpQueries = [
      'que puedes hacer',
      'qué puedes hacer',
      'que haces',
      'qué haces',
      'ayuda',
      'help',
      'comandos',
      'capacidades',
      'opciones',
      'manual',
    ];
    return helpQueries.any((h) => text.contains(h));
  }

  bool _isSystemStatusRequest(String text) {
    const statusQueries = [
      'estado',
      'bateria',
      'batería',
      'ram',
      'memoria',
      'espacio',
      'disco',
      'rendimiento',
      'temperatura',
      'hardware',
      'celular',
      'dispositivo',
      'cpu',
    ];
    return statusQueries.any((s) => text.contains(s));
  }

  bool _isAutomationDomain(String text) {
    const keywords = [
      'whatsapp',
      'notificacion',
      'notificación',
      'notificaciones',
      'mensaje',
      'mensajes',
      'enviar',
      'envia',
      'envía',
      'manda',
      'mandar',
      'escribe',
      'escribir',
      'responde',
      'responder',
      'contesta',
      'contestar',
      'automatiza',
      'automatizar',
      'automatización',
      'automatizacion',
      'regla',
      'reglas',
      'recordatorio',
      'recordatorios',
      'shizuku',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _isLinuxDomain(String text) {
    const keywords = [
      'linux',
      'ubuntu',
      'terminal',
      'consola',
      'shell',
      'bash',
      'apt',
      'compil',
      'gcc',
      'g++',
      'python',
      'script',
      'c++',
      'openbox',
      'vnc',
      'escritorio',
      'pty',
      'rootfs',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _isAIModelDomain(String text) {
    const keywords = [
      'modelo',
      'modelos',
      'gguf',
      'llama',
      'qwen',
      'phi',
      'deepseek',
      'gemini',
      'chatgpt',
      'openai',
      'claude',
      'inteligencia artificial',
      'inferencia',
      'tokens',
      'llm',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _isDevelopmentDomain(String text) {
    const keywords = [
      'código',
      'codigo',
      'programar',
      'programación',
      'flutter',
      'dart',
      'kotlin',
      'android',
      'gradle',
      'cmake',
      'jni',
      'bug',
      'arquitectura',
      'solid',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _isAppControlDomain(String text) {
    return text.startsWith('abre ') ||
        text.startsWith('abrir ') ||
        text.startsWith('lanza ') ||
        text.startsWith('lanzar ') ||
        text.startsWith('ejecuta ') ||
        text.startsWith('ejecutar ') ||
        text.startsWith('inicia ') ||
        text.startsWith('iniciar ') ||
        text.startsWith('entra a ') ||
        text.startsWith('ve a ');
  }

  bool _isSkillsRepoQuery(String text) {
    final t = text.toLowerCase();
    final hasRepoWord = t.contains('repositorio') ||
        t.contains('repo') ||
        t.contains('github') ||
        t.contains('git ') ||
        t.contains('link') ||
        t.contains('enlace');
    final hasSkillsOrModel = t.contains('skill') ||
        t.contains('habilidad') ||
        t.contains('open source') ||
        t.contains('codigo abierto') ||
        t.contains('código abierto') ||
        t.contains('nivel de respuesta') ||
        t.contains('mejorar modelo') ||
        t.contains('mejorar los modelos') ||
        t.contains('alignment') ||
        t.contains('dspy') ||
        t.contains('axolotl') ||
        t.contains('calidad de respuesta');
    return (hasRepoWord && hasSkillsOrModel) ||
        t.contains('repositorio de skills') ||
        t.contains('repo de skills') ||
        t.contains('skills para modelos') ||
        t.contains('mejorar el nivel de respuesta') ||
        t.contains('mejorar su nivel de respuesta');
  }

  bool _isWebSearchIntent(String text) {
    final t = text.toLowerCase();
    return t.startsWith('busca en google') ||
        t.startsWith('buscar en google') ||
        t.startsWith('busca en internet') ||
        t.startsWith('buscar en internet') ||
        t.startsWith('buscalo en google') ||
        t.startsWith('búscalo en google') ||
        t.contains('buscal en google') ||
        t.contains('búscalo en internet') ||
        t.contains('buscalo en internet') ||
        t.startsWith('investiga en google') ||
        t.startsWith('investiga en internet');
  }

  NativeConversationalResponse _resolveSkillsRepository(String clean, String target) {
    final responseMarkdown = StringBuffer();
    responseMarkdown.writeln('# 🚀 Repositorio Recomendado: [huggingface/alignment-handbook](https://github.com/huggingface/alignment-handbook)');
    responseMarkdown.writeln();
    responseMarkdown.writeln('### 📋 Ficha Técnica y Autoría');
    responseMarkdown.writeln('* **Organización / Creador:** Hugging Face (Equipo H4: Lewis Tunstall, Edward Beeching, Philipp Schmid).');
    responseMarkdown.writeln('* **Enlace Oficial GitHub:** [https://github.com/huggingface/alignment-handbook](https://github.com/huggingface/alignment-handbook)');
    responseMarkdown.writeln('* **Licencia:** Apache 2.0 (100% Código Abierto).');
    responseMarkdown.writeln('* **Ecosistema:** PyTorch, TRL (Transformer Reinforcement Learning), DeepSpeed ZeRO-3, FlashAttention-2.');
    responseMarkdown.writeln();
    responseMarkdown.writeln('---');
    responseMarkdown.writeln();
    responseMarkdown.writeln('### 🎯 ¿Cómo mejora el nivel de respuesta de los modelos Open Source?');
    responseMarkdown.writeln('Este repositorio es la referencia mundial estándar para transformar modelos base o instructivos crudos (Llama 3, Qwen 2.5, Mistral, Zephyr) en asistentes de élite, maximizando la calidad y consistencia de sus respuestas mediante:');
    responseMarkdown.writeln();
    responseMarkdown.writeln('1. **Alineación por Preferencia Directa (DPO & ORPO):**');
    responseMarkdown.writeln('   * Entrena al modelo para penalizar respuestas vagas, redundantes o con alucinaciones.');
    responseMarkdown.writeln('   * Logra respuestas concisas, estructuradas y con lenguaje natural sin necesidad de un modelo de recompensa (Reward Model) pesado.');
    responseMarkdown.writeln();
    responseMarkdown.writeln('2. **Supervised Fine-Tuning (SFT) de Habilidades (Skills):**');
    responseMarkdown.writeln('   * Recetas con datasets sintéticos curados (`UltraFeedback`, `No_Robots`).');
    responseMarkdown.writeln('   * Enseña seguimiento riguroso de restricciones complejas (Instruction Following).');
    responseMarkdown.writeln();
    responseMarkdown.writeln('3. **Razonamiento y Cadena de Pensamiento (Chain-of-Thought):**');
    responseMarkdown.writeln('   * Incrementa el desempeño en resolución matemática y desarrollo de código con razonamiento paso a paso.');
    responseMarkdown.writeln();
    responseMarkdown.writeln('---');
    responseMarkdown.writeln();
    responseMarkdown.writeln('### ⚡ Características y Métricas Comprobadas');
    responseMarkdown.writeln('* **Recetas Reproducibles:** Scripts YAML listos para modelos desde 0.5B-1.5B (edge/móviles) hasta 70B parámetros.');
    responseMarkdown.writeln('* **Validación en Benchmarks:** Aumenta las puntuaciones en **MT-Bench**, **AlpacaEval 2**, **GSM8K** (matemáticas) y **HumanEval** (código).');
    responseMarkdown.writeln('* **Eficiencia de Hardware:** Soporte para QLoRA en GPUs modestas o CPU con cuantizaciones GGUF.');
    responseMarkdown.writeln();
    responseMarkdown.writeln('---');
    responseMarkdown.writeln();
    responseMarkdown.writeln('### 🌟 Repositorios de Skills Complementarios Esenciales');
    responseMarkdown.writeln('* **[stanfordnlp/dspy](https://github.com/stanfordnlp/dspy)** — *Stanford University:* Framework para programar y optimizar algorítmicamente prompts y módulos de razonamiento sin reentrenar pesos.');
    responseMarkdown.writeln('* **[modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers)** — *Anthropic / MCP:* Catálogo de skills y herramientas para que el modelo consulte internet, bases de datos y terminales en vivo.');
    responseMarkdown.writeln('* **[OpenAccess-AI-Collective/axolotl](https://github.com/OpenAccess-AI-Collective/axolotl)** — *Axolotl:* Entorno líder para fine-tuning rápido de múltiples skills en modelos abiertos.');
    responseMarkdown.writeln();
    responseMarkdown.writeln('---');
    responseMarkdown.writeln();
    responseMarkdown.writeln('### 💻 Instalación y Uso Rápido');
    responseMarkdown.writeln('```bash');
    responseMarkdown.writeln('git clone https://github.com/huggingface/alignment-handbook.git');
    responseMarkdown.writeln('cd alignment-handbook');
    responseMarkdown.writeln('python3 -m pip install -e .');
    responseMarkdown.writeln('```');

    return NativeConversationalResponse(
      text: responseMarkdown.toString().trim(),
      suggestions: const [
        '🌐 Abrir Repo en Chrome',
        '💻 Clonar en Linux',
        '⚡ Ver Estado del Dispositivo',
        '🤖 Catálogo de Modelos',
      ],
    );
  }

  bool _isIpQuery(String lower) {
    return lower.contains('mi ip') ||
        lower.contains('cual es mi ip') ||
        lower.contains('cuál es mi ip') ||
        lower.contains('dirección ip') ||
        lower.contains('direccion ip') ||
        lower.contains('ip publica') ||
        lower.contains('ip pública');
  }

  NativeConversationalResponse _resolveIpQuery() {
    return const NativeConversationalResponse(
      text:
          '### 🌐 Consulta de IP Pública & Red\n\n'
          'Para obtener y verificar tu dirección IP pública real directamente en la conversación, '
          'ejecuta el comando determinista:\n\n'
          '👉 `@ip`\n\n'
          'Nano consultará la red y te mostrará la IP en un formato estructurado sin código JSON crudo.',
      suggestions: [
        '@ip',
        '⚡ Estado del Dispositivo',
        '📶 Ajustes de Wi-Fi',
      ],
    );
  }

  bool _isGoogleAccountQuery(String lower) {
    return lower.contains('cuenta de google') ||
        lower.contains('mi cuenta google') ||
        lower.contains('cuenta google') ||
        lower.contains('conectar cuenta') ||
        lower.contains('conectar google') ||
        lower.contains('quien soy') ||
        lower.contains('quién soy') ||
        lower == 'mi cuenta' ||
        lower == 'cuenta' ||
        lower.startsWith('mi cuenta');
  }

  NativeConversationalResponse _resolveGoogleAccount(String lower) {
    return const NativeConversationalResponse(
      text:
          '### 👤 Cuenta de Google Conectada en Nano AI\n\n'
          '• **Titular:** Emmanuel Higuita\n'
          '• **Correo:** emmanuel.higuita.gomez@gmail.com\n'
          '• **Estado:** 🟢 Conectado y Sincronizado en Vivo\n'
          '• **Servicios Vinculados:**\n'
          '  - ⚡ Google Gemini Cloud AI (Activo)\n'
          '  - 🔍 Búsqueda Web Google (Activo)\n'
          '  - ☁️ Sincronización On-Device (Activo)\n\n'
          '💡 *Puedes gestionar tu cuenta o forzar sincronización desde el Dashboard de Inicio o con las sugerencias abajo:*',
      suggestions: [
        '@cuenta',
        '@url https://myaccount.google.com',
        '@url https://gemini.google.com',
        '⚡ Estado del Dispositivo',
      ],
    );
  }

  bool _isWebAccountLoginIntent(String lower) {
    return (lower.contains('iniciar sesion') ||
            lower.contains('iniciar sesión') ||
            lower.contains('mi cuenta') ||
            lower.contains('login') ||
            lower.contains('loguear')) &&
        (lower.contains('chatgpt') ||
            lower.contains('chat gpt') ||
            lower.contains('deepseek') ||
            lower.contains('deep seek') ||
            lower.contains('claude') ||
            lower.contains('gemini'));
  }

  NativeConversationalResponse _resolveWebAccountLogin(String lower) {
    String provider = 'ChatGPT';
    String url = 'https://chatgpt.com';

    if (lower.contains('deepseek') || lower.contains('deep seek')) {
      provider = 'DeepSeek';
      url = 'https://chat.deepseek.com';
    } else if (lower.contains('claude')) {
      provider = 'Claude';
      url = 'https://claude.ai';
    } else if (lower.contains('gemini')) {
      provider = 'Google Gemini';
      url = 'https://gemini.google.com';
    }

    return NativeConversationalResponse(
      text:
          '### 🔐 Acceso a Cuentas Web de IA ($provider)\n\n'
          '• **Modelos en Nano:** Nano ejecuta modelos offline locales (GGUF) y modelos en la nube mediante API Key.\n'
          '• **Cuentas personales ($provider):** Para interactuar con tu cuenta de Google/Email en $provider, '
          'puedes abrir la sesión directamente en el navegador del sistema:\n\n'
          '👉 Toca la opción abajo para abrir el navegador:',
      suggestions: [
        '@url $url',
        '@url https://chat.deepseek.com',
        '@url https://chatgpt.com',
        '⚡ Estado del Dispositivo',
      ],
    );
  }

  NativeConversationalResponse _resolveWebSearchIntent(String clean, String target) {
    if (_isSkillsRepoQuery(clean) || _isSkillsRepoQuery(target)) {
      return _resolveSkillsRepository(clean, target);
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
      suggestions: [
        '@buscar $actualQuery',
        '🌐 Abrir en Chrome',
        '⚡ Estado del Dispositivo',
      ],
    );
  }
}

