// whatsapp_web_types.dart
//
// QUÉ HACE:
// Define los tipos de datos, enumeraciones y estados de navegación
// de la experiencia WhatsApp Web dentro de Nano Mobile.
//
// CÓMO FUNCIONA:
// - WhatsAppDisplayMode: Conmuta entre modo móvil responsive, modo tablet
//   y fallback a la vista web de escritorio original.
// - WhatsAppNavState: Modela la máquina de estados de navegación maestra-detalle
//   (chatList = lista de chats completa, conversation = chat activo fullscreen).
//
// POR QUÉ:
// Aplica ISP y SRP aislando los contratos de estado fuera de la lógica
// de ejecución y renderizado, garantizando archivos modulares bajo 200 líneas.

/// Modo de visualización visual inyectado en WhatsApp Web.
enum WhatsAppDisplayMode {
  /// Vista adaptativa optimizada ergonómicamente para teléfonos móviles.
  mobile,

  /// Vista adaptativa de doble panel optimizada para tablets / pantallas grandes.
  tablet,

  /// Vista web original sin adaptaciones inyectadas (modo escritorio tradicional).
  originalFallback,
}

/// Estado de navegación maestro-detalle en WhatsApp Web móvil.
enum WhatsAppNavState {
  /// Lista de chats principal (#side) a pantalla completa.
  chatList,

  /// Conversación activa (#main) a pantalla completa con cabecera y teclado adaptativo.
  conversation,
}
