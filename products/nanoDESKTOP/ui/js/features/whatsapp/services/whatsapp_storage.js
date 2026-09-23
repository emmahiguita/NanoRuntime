/**
 * whatsapp_storage.js — Repositorio Local de Persistencia para WhatsApp Desktop
 * 
 * QUÉ HACE:
 * Gestiona el almacenamiento persistente de conversaciones, mensajes y configuración
 * usando el motor local de almacenamiento del navegador de forma determinista.
 * 
 * CÓMO FUNCIONA:
 * Lee y escribe JSON serializado bajo claves versionadas con captura de errores
 * de cuota de disco y provee datos iniciales para una experiencia inmediata.
 * 
 * POR QUÉ:
 * Garantiza que las conversaciones y políticas no se pierdan al recargar la aplicación
 * o cambiar de pestaña en el escritorio (Principio de Responsabilidad Única).
 */

import { ConversationThread, WhatsAppContact, WhatsAppMessage, MessageDirection, MessageStatus, AutoReplyPolicy, ToneProfile } from '../domain/whatsapp_types.js';

const STORAGE_KEYS = Object.freeze({
  CONVERSATIONS: 'nano_wa_desktop_conversations_v4',
  MESSAGES: 'nano_wa_desktop_messages_v4',
  POLICY: 'nano_wa_desktop_policy_v4',
  ACTIVE_THREAD: 'nano_wa_desktop_active_thread_v4',
});

class WhatsAppStorage {
  constructor() {
    this._initSeedDataIfEmpty();
  }

  /**
   * Obtiene todos los hilos de conversación guardados.
   * @returns {ConversationThread[]}
   */
  getConversations() {
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.CONVERSATIONS);
      if (!raw) return [];
      const parsed = JSON.parse(raw);
      return parsed.map((item) => new ConversationThread(item));
    } catch (e) {
      console.error('[WhatsAppStorage] Error cargando conversaciones:', e);
      return [];
    }
  }

  /**
   * Guarda la lista completa de conversaciones.
   * @param {ConversationThread[]} conversations
   */
  saveConversations(conversations) {
    try {
      localStorage.setItem(STORAGE_KEYS.CONVERSATIONS, JSON.stringify(conversations));
    } catch (e) {
      console.error('[WhatsAppStorage] Error guardando conversaciones:', e);
    }
  }

  /**
   * Obtiene los mensajes asociados a una conversación específica.
   * @param {string} conversationId
   * @returns {WhatsAppMessage[]}
   */
  getMessages(conversationId) {
    try {
      const raw = localStorage.getItem(`${STORAGE_KEYS.MESSAGES}_${conversationId}`);
      if (!raw) return [];
      const parsed = JSON.parse(raw);
      return parsed.map((m) => new WhatsAppMessage(m));
    } catch (e) {
      console.error(`[WhatsAppStorage] Error cargando mensajes para ${conversationId}:`, e);
      return [];
    }
  }

  /**
   * Guarda o actualiza un mensaje en el historial del hilo sin duplicados.
   * @param {WhatsAppMessage} message
   */
  saveMessage(message) {
    try {
      const list = this.getMessages(message.conversationId);
      const existingIdx = list.findIndex((m) => m.id === message.id);
      if (existingIdx >= 0) {
        list[existingIdx] = message;
      } else {
        list.push(message);
      }
      localStorage.setItem(`${STORAGE_KEYS.MESSAGES}_${message.conversationId}`, JSON.stringify(list));

      const convs = this.getConversations();
      const target = convs.find((c) => c.id === message.conversationId);
      if (target) {
        target.lastMessage = message;
        if (message.direction === MessageDirection.INBOUND && existingIdx < 0) {
          target.unreadCount = (target.unreadCount || 0) + 1;
        }
        this.saveConversations(convs);
      }
    } catch (e) {
      console.error('[WhatsAppStorage] Error guardando mensaje:', e);
    }
  }

  getPolicy() {
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.POLICY);
      return raw ? new AutoReplyPolicy(JSON.parse(raw)) : new AutoReplyPolicy({});
    } catch {
      return new AutoReplyPolicy({});
    }
  }

  savePolicy(policy) {
    try {
      localStorage.setItem(STORAGE_KEYS.POLICY, JSON.stringify(policy));
    } catch (e) {
      console.error('[WhatsAppStorage] Error guardando política:', e);
    }
  }

  /**
   * Inicializa las conversaciones de muestra idénticas a la referencia visual.
   * @private
   */
  _initSeedDataIfEmpty() {
    try {
      const existing = localStorage.getItem(STORAGE_KEYS.CONVERSATIONS);
      if (existing) {
        try {
          const parsed = JSON.parse(existing);
          if (parsed.length >= 8 && parsed[0]?.contact?.name === 'María González') {
            return;
          }
        } catch {}
      }

      const contacts = [
        { id: 'wa_1', name: 'María González', phone: '+52 55 1234 5678', time: '10:24', unread: 2, tags: ['Cliente', 'VIP', 'Interesado'], last: '¡Perfecto! ¿Cuánto tarda el envío?', online: true },
        { id: 'wa_2', name: 'Carlos Ramírez', phone: '+52 55 2345 6789', time: '09:18', unread: 0, tags: ['Cliente'], last: 'Muchas gracias por la información', online: true },
        { id: 'wa_3', name: 'Tienda Luna', phone: '+52 55 3456 7890', time: 'Ayer', unread: 0, tags: ['Empresa'], last: '¿Tienen este producto en stock?', online: false },
        { id: 'wa_4', name: 'Ana Torres', phone: '+52 55 4567 8901', time: 'Ayer', unread: 0, tags: ['Prospecto'], last: 'Me interesa el plan profesional', online: false },
        { id: 'wa_5', name: 'Distribuidora Sol', phone: '+52 55 5678 9012', time: 'Lun', unread: 0, hasAttach: true, tags: ['Proveedor'], last: 'Adjunto el comprobante de pago', online: false },
        { id: 'wa_6', name: 'Juan Pérez', phone: '+52 55 6789 0123', time: 'Lun', unread: 0, tags: ['Cliente'], last: '¿Puedo hacer una devolución?', online: false },
        { id: 'wa_7', name: 'Claudia Méndez', phone: '+52 55 7890 1234', time: 'Dom', unread: 0, tags: ['VIP'], last: '¡Excelente servicio! 👏', online: false },
        { id: 'wa_8', name: 'Innovatech', phone: '+52 55 8901 2345', time: 'Dom', unread: 0, tags: ['Empresa'], last: 'Cotización para 50 unidades', online: false },
      ];

      const convs = contacts.map((c) => new ConversationThread({
        id: c.id,
        contact: new WhatsAppContact({ id: `c_${c.id}`, name: c.name, phone: c.phone, isBusiness: c.tags.includes('Empresa') }),
        unreadCount: c.unread,
        autoReply: true,
        tags: c.tags,
        online: c.online,
        hasAttach: c.hasAttach || false,
        lastMessageTime: c.time,
        lastMessage: new WhatsAppMessage({ conversationId: c.id, text: c.last, timestamp: new Date().toISOString() }),
      }));

      // Mensajes reales del hilo de María González exactamente como en la referencia visual
      const mariaMsgs = [
        new WhatsAppMessage({ conversationId: 'wa_1', direction: MessageDirection.INBOUND, text: 'Hola! 👋\nMe gustaría saber más sobre el plan profesional. ¿Incluye soporte técnico?', timestamp: '2026-03-12T10:15:00Z', status: MessageStatus.READ }),
        new WhatsAppMessage({ conversationId: 'wa_1', direction: MessageDirection.OUTBOUND, text: '¡Hola María! 😊\nSí, el plan profesional incluye soporte técnico prioritario 24/7, actualizaciones y acceso a todas las funcionalidades de Nano AI. ¿Te gustaría que te comparta los detalles y precios?', timestamp: '2026-03-12T10:16:00Z', status: MessageStatus.READ, isAiGenerated: true }),
        new WhatsAppMessage({ conversationId: 'wa_1', direction: MessageDirection.INBOUND, text: '¡Perfecto! ¿Cuánto tarda el envío?', timestamp: '2026-03-12T10:22:00Z', status: MessageStatus.READ }),
        new WhatsAppMessage({ conversationId: 'wa_1', direction: MessageDirection.OUTBOUND, text: 'El envío se realiza en menos de 24 horas una vez confirmado el pago. Además, te enviamos un correo con la guía de acceso y una breve capacitación de inicio. 🚀', timestamp: '2026-03-12T10:23:00Z', status: MessageStatus.READ, isAiGenerated: true }),
        new WhatsAppMessage({ conversationId: 'wa_1', direction: MessageDirection.INBOUND, text: '¡Genial! Entonces quiero proceder con la compra. ¿Qué métodos de pago aceptan?', timestamp: '2026-03-12T10:24:00Z', status: MessageStatus.DELIVERED })
      ];

      this.saveConversations(convs);
      localStorage.setItem(`${STORAGE_KEYS.MESSAGES}_wa_1`, JSON.stringify(mariaMsgs));
    } catch (e) {
      console.warn('[WhatsAppStorage] Error inicializando datos semilla:', e);
    }
  }
}

export const whatsAppStorage = new WhatsAppStorage();
