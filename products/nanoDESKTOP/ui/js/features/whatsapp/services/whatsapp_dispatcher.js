/** Puerto de mensajería: no registra envíos ni entregas sin confirmación del proveedor. */
class WhatsAppDispatcher {
  /** Conserva el borrador: sin adaptador inyectado, el envío falla explícitamente. */
  async sendMessage() {
    return { success: false, error: 'Envío no disponible: conecta este cliente al servidor oficial de Nano.' };
  }
  /** La recepción debe venir del servidor autenticado, no de una simulación. */
  receiveMessage() { throw new Error('Recepción oficial no integrada en esta bandeja.'); }
  /** No programa automatizaciones mientras el transporte no esté integrado. */
  destroy() {}
}
export const whatsAppDispatcher = new WhatsAppDispatcher();
