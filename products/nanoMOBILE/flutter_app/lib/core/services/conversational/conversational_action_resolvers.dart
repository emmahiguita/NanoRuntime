// conversational_action_resolvers.dart — Resolvedores de control de apps, Linux y cuentas.
// QUÉ HACE: Traduce intenciones operativas a explicaciones claras con acciones sugeridas.
// CÓMO FUNCIONA: Mapea solicitudes hacia herramientas Shizuku, intents de Android, PTY Linux y cuentas.
// POR QUÉ: Permite automatizar sin alucinaciones y mantiene el código modular y testeable (< 200 líneas).
library;

import 'native_conversational_response.dart';

class ConversationalActionResolvers {
  static NativeConversationalResponse resolveAppControl(String clean, String lower) {
    if (lower.contains('ajuste') || lower.contains('configura') ||
        lower.contains('wifi') || lower.contains('wi-fi') ||
        lower.contains('bluetooth') || lower.contains('bateria') ||
        lower.contains('batería') || lower.contains('pantalla') || lower.contains('sonido')) {
      return const NativeConversationalResponse(
        text:
            'Entendido. Puedo dirigir la navegación directamente a los ajustes del sistema:\n\n'
            '• **Ajustes Generales**: Configuración principal de Android.\n'
            '• **Conexiones**: Wi-Fi, Bluetooth y redes móviles.\n'
            '• **Gestión de Energía**: Ahorro de batería y restricciones en segundo plano.\n\n'
            'Selecciona el destino deseado:',
        suggestions: [
          '⚙️ Abrir Ajustes', '📶 Ajustes de Wi-Fi', '🔋 Ahorro de Batería', '📱 Ajustes de Pantalla',
        ],
      );
    }

    if (lower.contains('camara') || lower.contains('cámara') || lower.contains('foto')) {
      return const NativeConversationalResponse(
        text:
            'Puedo activar la cámara del dispositivo o gestionar capturas de pantalla:\n\n'
            '• Lanzar la aplicación de cámara directamente.\n'
            '• Capturar la pantalla activa para inspección multimodal o extracción de texto.',
        suggestions: ['📸 Abrir Cámara', '🖼️ Captura de Pantalla', '📱 Ir a Inicio'],
      );
    }

    final words = clean.split(' ');
    final target = words.length > 1 ? words.sublist(1).join(' ').trim() : 'la aplicación';

    return NativeConversationalResponse(
      text:
          'Para interactuar con **$target**:\n\n'
          '1. **Lanzamiento Directo**: Se puede abrir mediante el gestor de intents nativos.\n'
          '2. **Control por Accesibilidad**: Leer elementos de su interfaz, escribir texto o tocar botones.\n'
          '3. **Privilegios Shizuku**: Detener procesos, otorgar permisos o consultar métricas avanzadas.',
      suggestions: ['📱 Abrir $target', '💬 Ver Automatizaciones', '⚡ Inspeccionar Pantalla', '🛡️ Estado Shizuku'],
    );
  }

  static NativeConversationalResponse resolveAutomation(String clean, String lower) {
    final isMessage = lower.contains('escribe') || lower.contains('envía') ||
        lower.contains('envia') || lower.contains('manda') || lower.contains('responde') || lower.contains('contesta');

    if (isMessage) {
      return const NativeConversationalResponse(
        text:
            'Detecté una solicitud de automatización de mensajería.\n\n'
            'Para despachar mensajes o respuestas automáticas mediante accesibilidad o Shizuku:\n'
            '1. Puedes usar una regla programada (ej: *"cuando Juan me escriba, respóndele que llego a las 8"*).\n'
            '2. O bien realizar el envío directo en la app de automatización.',
        suggestions: ['💬 Ir a Automatización', '⚡ Crear Regla de Respuesta', '📱 Ver Estado Shizuku'],
      );
    }

    return const NativeConversationalResponse(
      text:
          'El módulo de **Automatización de Nano** permite crear flujos gobernados:\n\n'
          '• **Disparadores de Hora**: Ejecución a horas fijas o intervalos.\n'
          '• **Disparadores de Notificación**: Reaccionar a mensajes de WhatsApp o apps de mensajería.\n'
          '• **Gobernanza**: Validación de seguridad antes de cualquier acción en pantalla.',
      suggestions: ['⚡ Ver Reglas Activas', '💬 Crear Nueva Regla', '📱 Shizuku y Permisos'],
    );
  }

  static NativeConversationalResponse resolveLinux(String clean, String lower) {
    if (lower.contains('compil') || lower.contains('gcc') || lower.contains('c++')) {
      return const NativeConversationalResponse(
        text:
            'Para compilar código nativo en tu contenedor Linux:\n\n'
            '1. Abre la **Terminal PTY**.\n'
            '2. Instala herramientas con `apt update && apt install build-essential`.\n'
            '3. Compila con `gcc -O2 prog.c -o prog` o `g++ -std=c++17 prog.cpp`.\n\n'
            'Todo se ejecuta en arquitectura nativa aarch64 sin emulación pesada.',
        suggestions: ['💻 Abrir Terminal Linux', '🖥️ Ver Escritorio VNC', '📁 Explorar Archivos'],
      );
    }

    if (lower.contains('python') || lower.contains('script')) {
      return const NativeConversationalResponse(
        text:
            'Tu entorno Linux soporta **Python 3** directamente en el rootfs:\n\n'
            '• Ejecutar scripts con `python3 script.py`.\n'
            '• Instalar librerías con `pip install <paquete>` o `apt install python3-pip`.\n'
            '• Automatizar tareas comunicándote con las herramientas de Nano.',
        suggestions: ['💻 Abrir Terminal Linux', '📦 Paquetes Instalados', '🖥️ Ver Escritorio VNC'],
      );
    }

    return const NativeConversationalResponse(
      text:
          'El subsistema **Linux** de Nano proporciona un entorno Ubuntu completo con gestor de paquetes `apt`, '
          'soporte para terminal interactiva PTY y entorno gráfico Openbox accesible vía streaming VNC.',
      suggestions: ['💻 Abrir Terminal Linux', '🖥️ Escritorio VNC', '📦 Paquetes del Sistema'],
    );
  }

  static NativeConversationalResponse resolveIpQuery() =>
      const NativeConversationalResponse(
        text:
            '### 🌐 Consulta de IP Pública & Red\n\n'
            'Para obtener y verificar tu dirección IP pública real directamente en la conversación, '
            'ejecuta el comando determinista:\n\n'
            '👉 `@ip`\n\n'
            'Nano consultará la red y te mostrará la IP en un formato estructurado sin código JSON crudo.',
        suggestions: ['@ip', '⚡ Estado del Dispositivo', '📶 Ajustes de Wi-Fi'],
      );

  static NativeConversationalResponse resolveGoogleAccount() =>
      const NativeConversationalResponse(
        text:
            '### 👤 Cuenta de Google Conectada en Nano AI\n\n'
            '• **Titular:** Emmanuel Higuita\n'
            '• **Correo:** emmanuel.higuita.gomez@gmail.com\n'
            '• **Estado:** 🟢 Conectado y Sincronizado en Vivo\n'
            '• **Servicios Vinculados:**\n'
            '  - ⚡ Google Gemini Cloud AI (Activo)\n'
            '  - 🔍 Búsqueda Web Google (Activo)\n'
            '  - ☁️ Sincronización On-Device (Activo)\n\n'
            '💡 *Gestiona tu cuenta o fuerza sincronización con las opciones abajo:*',
        suggestions: ['@cuenta', '@url https://myaccount.google.com', '@url https://gemini.google.com', '⚡ Estado del Dispositivo'],
      );

  static NativeConversationalResponse resolveWebAccountLogin(String lower) {
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
          '• **Modelos en Nano:** Nano ejecuta modelos offline locales (GGUF) y modelos en la nube vía API Key.\n'
          '• **Cuentas personales ($provider):** Para interactuar con tu cuenta de Google/Email en $provider, '
          'puedes abrir la sesión directamente en el navegador del sistema:\n\n'
          '👉 Toca la opción abajo para abrir el navegador:',
      suggestions: ['@url $url', '@url https://chat.deepseek.com', '@url https://chatgpt.com', '⚡ Estado del Dispositivo'],
    );
  }
}
