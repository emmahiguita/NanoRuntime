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
  CONVERSATIONS: 'nano_wa_desktop_conversations_v1',
  MESSAGES: 'nano_wa_desktop_messages_v1',
  POLICY: 'nano_wa_desktop_policy_v1',
  ACTIVE_THREAD: 'nano_wa_desktop_active_thread_v1',
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
   * Guarda un nuevo mensaje en el historial del hilo.
   * @param {WhatsAppMessage} message
   */
  saveMessage(message) {
    try {
      const list = this.getMessages(message.conversationId);
      list.push(message);
      localStorage.setItem(`${STORAGE_KEYS.MESSAGES}_${message.conversationId}`, JSON.stringify(list));

      // Actualizar último mensaje en la conversación
      const convs = this.getConversations();
      const target = convs.find((c) => c.id === message.conversationId);
      if (target) {
        target.lastMessage = message;
        if (message.direction === MessageDirection.INBOUND) {
          target.unreadCount += 1;
        }
        this.saveConversations(convs);
      }
    } catch (e) {
      console.error('[WhatsAppStorage] Error guardando mensaje:', e);
    }
  }

  /**
   * Obtiene la política de respuesta automática del agente.
   * @returns {AutoReplyPolicy}
   */
  getPolicy() {
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.POLICY);
      return raw ? new AutoReplyPolicy(JSON.parse(raw)) : new AutoReplyPolicy({});
    } catch {
      return new AutoReplyPolicy({});
    }
  }

  /**
   * Guarda la política de respuesta automática configurada por el usuario.
   * @param {AutoReplyPolicy} policy
   */
  savePolicy(policy) {
    try {
      localStorage.setItem(STORAGE_KEYS.POLICY, JSON.stringify(policy));
    } catch (e) {
      console.error('[WhatsAppStorage] Error guardando política:', e);
    }
  }

  /**
   * Inicializa datos reales de demostración si el almacenamiento está vacío.
   * @private
   */
  _initSeedDataIfEmpty() {
    try {
      if (localStorage.getItem(STORAGE_KEYS.CONVERSATIONS)) return;

      const contact1 = new WhatsAppContact({
        id: 'wa_c_01',
        name: 'Carlos Mendoza (Soporte TI)',
        phone: '+57 312 456 7890',
        isBusiness: true,
        verified: true,
      });

      const contact2 = new WhatsAppContact({
        id: 'wa_c_02',
        name: 'Dra. Elena Ramos',
        phone: '+57 300 987 6543',
        isBusiness: false,
        verified: false,
      });

      const conv1 = new ConversationThread({
        id: 'thread_01',
        contact: contact1,
        unreadCount: 1,
        autoReply: true,
      });

      const conv2 = new ConversationThread({
        id: 'thread_02',
        contact: contact2,
        unreadCount: 0,
        autoReply: false,
      });

      const msg1 = new WhatsAppMessage({
        conversationId: 'thread_01',
        direction: MessageDirection.INBOUND,
        text: 'Hola, ¿podrías confirmarme si el clúster de inferencia local ya está activo en el servidor?',
        timestamp: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
      });

      const msg2 = new WhatsAppMessage({
        conversationId: 'thread_02',
        direction: MessageDirection.OUTBOUND,
        text: 'Documentos recibidos correctamente, los revisaremos de inmediato.',
        timestamp: new Date(Date.now() - 1000 * 60 * 180).toISOString(),
        status: MessageStatus.READ,
      });

      conv1.lastMessage = msg1;
      conv2.lastMessage = msg2;

      this.saveConversations([conv1, conv2]);
      localStorage.setItem(`${STORAGE_KEYS.MESSAGES}_thread_01`, JSON.stringify([msg1]));
      localStorage.setItem(`${STORAGE_KEYS.MESSAGES}_thread_02`, JSON.stringify([msg2]));
    } catch (e) {
      console.warn('[WhatsAppStorage] No se pudieron inicializar datos de semilla:', e);
    }
  }
}

export const whatsAppStorage = new WhatsAppStorage();
