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

      return NativeConversationalResponse(
        text:
            '📊 **Telemetría del Dispositivo en Tiempo Real**:\n\n'
            '• **Memoria RAM**: $memAvail libres de $memTotal\n'
            '• **Núcleos CPU**: $cores activos (Temperatura: $temp)\n'
            '• **Arquitectura**: ${dev.unameMachine ?? "aarch64"}\n'
            '• **Kernel**: ${dev.unameRelease ?? "Linux Android"}\n\n'
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

    // 10. Dominio Modelos & Inteligencia Artificial
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
}

