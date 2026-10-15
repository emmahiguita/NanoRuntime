/** Estado del cliente: no declara conexión sin un adaptador oficial confirmado. */
import { SessionStatus } from '../domain/whatsapp_types.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';

class WhatsAppSessionManager {
  constructor() { this.status = SessionStatus.DISCONNECTED; }
  /** Meta Cloud requiere servidor: nunca fabrica QR ni códigos de WhatsApp Web. */
  startPairing() { throw new Error('Conecta el cliente al servidor oficial de Nano.'); }
  /** Rechaza confirmaciones locales sin evidencia del transporte remoto. */
  confirmConnection() { throw new Error('No hay adaptador oficial conectado.'); }
  /** Desconecta sin modificar mensajes ni secretos. */
  disconnect(reason = 'Cliente sin conexión oficial.') {
    this.status = SessionStatus.DISCONNECTED;
    whatsAppBus.emit(WhatsAppEvents.SESSION_CHANGED, { status: this.status, reason });
  }
  /** Compatibilidad de ciclo de vida: no quedan temporizadores de sesión ficticios. */
  stopTimers() {}
  destroy() { this.disconnect(); }
}
export const whatsAppSessionManager = new WhatsAppSessionManager();
