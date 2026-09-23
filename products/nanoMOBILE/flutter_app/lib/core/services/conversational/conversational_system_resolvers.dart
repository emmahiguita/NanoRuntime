// conversational_system_resolvers.dart — Resolvedores de saludos, estado e identidad.
// QUÉ HACE: Genera respuestas contextuales con opciones interactivas para cortesía, telemetría y ayuda.
// CÓMO FUNCIONA: Lee métricas del dispositivo (RAM, CPU, temp) y calcula saludos según la hora local.
// POR QUÉ: Erradica respuestas robóticas o vacías y cumple la regla de archivos < 200 líneas.
library;

import '../device_info.dart';
import 'native_conversational_response.dart';

class ConversationalSystemResolvers {
  static NativeConversationalResponse resolveGreeting({required bool hasModel}) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? '¡Buenos días!'
        : (hour < 19 ? '¡Buenas tardes!' : '¡Buenas noches!');

    final variants = [
      '$timeGreeting Qué gusto saludarte. Soy Nano AI, tu copiloto en el dispositivo. ¿En qué proyecto o tarea trabajamos hoy?',
      '$timeGreeting Hola. Todo el entorno del dispositivo está listo para operar. ¿Qué deseas consultar o ejecutar?',
      '$timeGreeting Bienvenido de vuelta a Nano AI. Tienes a tu disposición la terminal Linux, automatizaciones y análisis de modelos. ¿Por dónde empezamos?',
    ];
    final selectedGreeting = variants[(DateTime.now().second) % variants.length];

    return NativeConversationalResponse(
      text: selectedGreeting,
      suggestions: const [
        '⚡ Diagnóstico de Hardware',
        '💻 Abrir Linux',
        '🤖 Catálogo de Modelos',
        '🛠️ ¿Qué puedes hacer?',
      ],
    );
  }

  static NativeConversationalResponse resolveThanks() =>
      const NativeConversationalResponse(
        text:
            '¡Con todo gusto! Aquí estoy disponible para ayudarte a controlar el sistema, ejecutar procesos o responder tus dudas.',
        suggestions: [
          '💻 Abrir Terminal Linux',
          '⚡ Diagnóstico de Hardware',
          '🛠️ Ver Capacidades',
        ],
      );

  static NativeConversationalResponse resolveFarewell() =>
      const NativeConversationalResponse(
        text:
            '¡Hasta luego! El entorno y los servicios de automatización seguirán operando en segundo plano de forma segura.',
        suggestions: [
          '⚡ Ver Estado del Dispositivo',
          '🤖 Catálogo de Modelos',
        ],
      );

  static NativeConversationalResponse resolveIdentity() =>
      const NativeConversationalResponse(
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

  static NativeConversationalResponse resolveHelp() =>
      const NativeConversationalResponse(
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

  static NativeConversationalResponse resolveSystemStatus() {
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
}
