/**
 * whatsapp_dispatcher.js — Despachador de Mensajes para WhatsApp Desktop
 * 
 * QUÉ HACE:
 * Provee la lógica de envío de mensajes de texto y adjuntos, validando conectividad,
 * actualizando el repositorio local y orquestando respuestas automáticas.
 * 
 * CÓMO FUNCIONA:
 * Crea instancias inmutables de `WhatsAppMessage`, las persiste en `whatsAppStorage`,
 * emite eventos en el bus y programa respuestas automáticas controladas por tiempo.
 * 
 * POR QUÉ:
 * El principio de Inversión de Dependencias (DIP) y la arquitectura limpia exigen
 * que la UI no escriba directamente en el almacenamiento ni gestione retardos de red.
 */

import { WhatsAppMessage, MessageDirection, MessageStatus, SessionStatus } from '../domain/whatsapp_types.js';
import { whatsAppStorage } from './whatsapp_storage.js';
import { whatsAppSessionManager } from './whatsapp_session_manager.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { whatsAppAiAgent } from './whatsapp_ai_agent.js';

class WhatsAppDispatcher {
  constructor() {
    this._pendingAutoReplyTimers = new Map();
  }

  /**
   * Envía un mensaje en la conversación especificada.
   * @param {Object} params
   * @param {string} params.conversationId - Identificador del hilo.
   * @param {string} params.text - Contenido del mensaje.
   * @param {Array} [params.attachments] - Archivos adjuntos.
   * @returns {Promise<{success: boolean, message: WhatsAppMessage}>}
   */
  async sendMessage({ conversationId, text, attachments = [] }) {
    if (!text || text.trim().length === 0) {
      return { success: false, error: 'El mensaje no puede estar vacío.' };
    }

    const message = new WhatsAppMessage({
      conversationId,
      direction: MessageDirection.OUTBOUND,
      text: text.trim(),
      status: whatsAppSessionManager.status === SessionStatus.CONNECTED ? MessageStatus.SENT : MessageStatus.PENDING,
      attachments,
    });

    whatsAppStorage.saveMessage(message);
    whatsAppBus.emit(WhatsAppEvents.MESSAGE_SENT, message);
    whatsAppBus.emit(WhatsAppEvents.CONVERSATIONS_UPDATED, whatsAppStorage.getConversations());

    // Si la sesión está conectada, actualizar a DELIVERED en 800ms
    if (whatsAppSessionManager.status === SessionStatus.CONNECTED) {
      setTimeout(() => {
        message.status = MessageStatus.DELIVERED;
        whatsAppStorage.saveMessage(message);
        whatsAppBus.emit(WhatsAppEvents.CONVERSATIONS_UPDATED, whatsAppStorage.getConversations());
      }, 800);
    }

    return { success: true, message };
  }

  /**
   * Simula o registra un mensaje entrante desde el canal de WhatsApp.
   * @param {Object} params
   * @param {string} params.conversationId
   * @param {string} params.text
   * @param {string} [params.senderName]
   */
  receiveMessage({ conversationId, text, senderName = 'Cliente' }) {
    const message = new WhatsAppMessage({
      conversationId,
      direction: MessageDirection.INBOUND,
      text: text.trim(),
      status: MessageStatus.DELIVERED,
    });

    whatsAppStorage.saveMessage(message);
    whatsAppBus.emit(WhatsAppEvents.MESSAGE_RECEIVED, message);
    whatsAppBus.emit(WhatsAppEvents.CONVERSATIONS_UPDATED, whatsAppStorage.getConversations());

    // Evaluar si se debe disparar una respuesta automática de IA
    this._handlePotentialAutoReply(conversationId);
  }

  /**
   * Evalúa la política de gobernanza y programa una respuesta automática si está permitida.
   * @private
   */
  _handlePotentialAutoReply(conversationId) {
    const policy = whatsAppStorage.getPolicy();
    if (!policy.enabled) return;

    const convs = whatsAppStorage.getConversations();
    const thread = convs.find((c) => c.id === conversationId);
    if (!thread || !thread.autoReply) return;

    // Limpiar temporizador previo si existía para evitar solapamientos
    if (this._pendingAutoReplyTimers.has(conversationId)) {
      clearTimeout(this._pendingAutoReplyTimers.get(conversationId));
    }

    const delayMs = Math.max(1000, policy.delaySeconds * 1000);
    const timer = setTimeout(async () => {
      this._pendingAutoReplyTimers.delete(conversationId);
      const draft = await whatsAppAiAgent.generateDraft(conversationId, { tone: policy.tone });

      if (!policy.requireHumanApproval) {
        // Enviar automáticamente si la política lo autoriza sin firma humana
        const replyText = `${draft} ${policy.signature}`.trim();
        await this.sendMessage({ conversationId, text: replyText });
      }
    }, delayMs);

    this._pendingAutoReplyTimers.set(conversationId, timer);
  }

  /**
   * Limpia todos los temporizadores de respuesta automática pendientes.
   */
  destroy() {
    this._pendingAutoReplyTimers.forEach((timer) => clearTimeout(timer));
    this._pendingAutoReplyTimers.clear();
  }
}

export const whatsAppDispatcher = new WhatsAppDispatcher();
