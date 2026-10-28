/**
 * whatsapp_storage.js — Repositorio Local de Persistencia para WhatsApp Desktop
 * 
 * QUÉ HACE:
 * Gestiona el almacenamiento persistente de conversaciones, mensajes y configuración
 * usando el motor local de almacenamiento del navegador de forma determinista.
 * 
 * CÓMO FUNCIONA:
 * Lee y escribe JSON serializado bajo claves versionadas con captura de errores
 * de cuota de disco, conservando únicamente los datos almacenados.
 * 
 * POR QUÉ:
 * Garantiza que las conversaciones y políticas no se pierdan al recargar la aplicación
 * o cambiar de pestaña en el escritorio (Principio de Responsabilidad Única).
 */

import { ConversationThread, WhatsAppMessage, AutoReplyPolicy, MessageDirection } from '../domain/whatsapp_types.js';

const STORAGE_KEYS = Object.freeze({
  CONVERSATIONS: 'nano_wa_desktop_conversations_v4',
  MESSAGES: 'nano_wa_desktop_messages_v4',
  POLICY: 'nano_wa_desktop_policy_v4',
  ACTIVE_THREAD: 'nano_wa_desktop_active_thread_v4',
});

class WhatsAppStorage {
  constructor() {
    // No crea contactos ficticios ni sobrescribe conversaciones al recargar.
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

}

export const whatsAppStorage = new WhatsAppStorage();
