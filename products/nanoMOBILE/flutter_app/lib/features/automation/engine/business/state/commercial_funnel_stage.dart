// commercial_funnel_stage.dart
//
// QUÉ HACE:
// Enumera las etapas deterministas del embudo de ventas conversacional.
//
// CÓMO FUNCIONA:
// - Controla la progresión del cliente desde el saludo inicial hasta la postventa.
// - Proporciona helpers para saber si la conversación está en etapa de compra, pago o escalada.
//
// POR QUÉ:
// Permite que Nano recuerde en qué punto exacto de la negociación se encuentra el cliente.

library;

enum CommercialFunnelStage {
  inquiry,          // Consulta general / saludo
  interest,         // Interés en un producto concreto
  variantSelection, // Seleccionando opciones (talla, color, modelo)
  stockChecked,     // Stock verificado con éxito
  cartActive,       // Artículos en carrito
  checkout,         // Solicitando dirección / datos de entrega
  paymentPending,   // Esperando confirmación de pago
  paymentConfirmed, // Pago verificado
  fulfilled,        // Entregado o enviado
  escalatedHuman;   // En manos de un operador humano

  bool get isShopping =>
      this == interest ||
      this == variantSelection ||
      this == stockChecked ||
      this == cartActive;

  bool get isCheckout =>
      this == checkout || this == paymentPending;

  bool get isCompleted =>
      this == paymentConfirmed || this == fulfilled;
}
