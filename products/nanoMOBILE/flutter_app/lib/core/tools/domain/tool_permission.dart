/// Permisos granulares de ejecución para el Policy Gate de Nano.
library;

/// Declaración de un permiso específico que una herramienta requiere para ejecutarse.
enum ToolPermission {
  /// Envío de respuestas directas vía RemoteInput de notificaciones nativas.
  notificationReply,

  /// Lectura de contactos de WhatsApp o del sistema Android.
  contactsRead,

  /// Lectura de conversaciones y mensajes observados.
  messagesRead,

  /// Navegación activa en pestañas del navegador interno.
  browserNavigate,

  /// Extracción de contenido del DOM o captura visual de páginas web.
  browserRead,

  /// Lectura de archivos locales en almacenamiento del dispositivo o rootfs Linux.
  fileSystemRead,

  /// Modificación o eliminación de archivos locales.
  fileSystemWrite,

  /// Ejecución de binarios o comandos de consola en terminal/Linux/Android.
  terminalExecute,

  /// Inyección de toques o gestos mediante servicio de accesibilidad o Shizuku.
  accessibilityControl,

  /// Búsqueda y lectura de recuerdos y base de datos FTS4.
  memoryRead,

  /// Escritura y persistencia de nuevos recuerdos o preferencias de estilo.
  memoryWrite,

  /// Acceso libre a la red externa vía HTTP/WebSockets.
  network;

  /// Clave en formato texto para serialización y políticas de seguridad.
  String get key => name;

  /// Conversión segura desde string.
  static ToolPermission? fromKey(String key) {
    for (final perm in ToolPermission.values) {
      if (perm.name.toLowerCase() == key.toLowerCase()) {
        return perm;
      }
    }
    return null;
  }
}
