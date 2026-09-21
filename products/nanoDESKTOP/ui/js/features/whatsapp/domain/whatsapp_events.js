/**
 * whatsapp_events.js — Bus de Eventos Reactivo para WhatsApp Desktop
 * 
 * QUÉ HACE:
 * Provee un despachador de eventos Observer para desacoplar totalmente
 * los servicios de almacenamiento, sesión, agente de IA y la interfaz de usuario.
 * 
 * CÓMO FUNCIONA:
 * Registra funciones callback agrupadas por tipo de evento y las ejecuta
 * de forma asíncrona segura con captura de excepciones para no romper la cadena.
 * 
 * POR QUÉ:
 * Evita el acoplamiento circular entre vistas y controladores (Principio de
 * Responsabilidad Única y Desacoplamiento de Clean Architecture).
 */

export const WhatsAppEvents = Object.freeze({
  SESSION_CHANGED: 'session:changed',
  QR_RECEIVED: 'session:qr_received',
  CONVERSATIONS_UPDATED: 'conversations:updated',
  MESSAGE_RECEIVED: 'message:received',
  MESSAGE_SENT: 'message:sent',
  DRAFT_SUGGESTED: 'ai:draft_suggested',
  POLICY_CHANGED: 'policy:changed',
  ERROR_OCCURRED: 'error:occurred',
});

class WhatsAppEventBus {
  constructor() {
    /** @type {Map<string, Set<Function>>} */
    this.listeners = new Map();
  }

  /**
   * Suscribe un listener a un evento específico.
   * @param {string} event - Nombre del evento (constante de WhatsAppEvents).
   * @param {Function} callback - Función a ejecutar.
   * @returns {Function} Función desuscriptora para prevenir fugas de memoria.
   */
  subscribe(event, callback) {
    if (typeof callback !== 'function') return () => {};
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    const bucket = this.listeners.get(event);
    bucket.add(callback);

    return () => {
      bucket.delete(callback);
      if (bucket.size === 0) {
        this.listeners.delete(event);
      }
    };
  }

  /**
   * Emite un evento a todos los suscriptores registrados.
   * @param {string} event - Nombre del evento.
   * @param {any} payload - Datos del evento.
   */
  emit(event, payload) {
    const bucket = this.listeners.get(event);
    if (!bucket || bucket.size === 0) return;

    bucket.forEach((callback) => {
      try {
        callback(payload);
      } catch (err) {
        console.error(`[WhatsAppEventBus] Error procesando evento ${event}:`, err);
      }
    });
  }

  /**
   * Limpia todos los listeners registrados (útil para pruebas y recarga de vistas).
   */
  clear() {
    this.listeners.clear();
  }
}

export const whatsAppBus = new WhatsAppEventBus();
