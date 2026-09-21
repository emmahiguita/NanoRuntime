/**
 * whatsapp_chat_conversation.js — Visor de Conversación y Flujo de Mensajes
 * 
 * QUÉ HACE:
 * Renderiza la secuencia cronológica de mensajes del chat seleccionado, mostrando
 * burbujas de entrada/salida, marcas de estado y distintivos de IA local.
 * 
 * CÓMO FUNCIONA:
 * Consulta `whatsAppStorage.getMessages()`, genera el markup de burbujas con escape
 * de entidades HTML y ejecuta auto-desplazamiento suave al fondo de la conversación.
 * 
 * POR QUÉ:
 * Mantener el visor de conversación desacoplado de la barra lateral y del compositor
 * facilita el testing, reduce la complejidad del código y respeta el límite de < 200 LOC.
 */

import { whatsAppStorage } from '../services/whatsapp_storage.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { MessageDirection, MessageStatus } from '../domain/whatsapp_types.js';

export class WhatsAppChatConversation {
  /**
   * @param {HTMLElement} container - Contenedor del flujo de mensajes.
   */
  constructor(container) {
    this.container = container;
    this.activeThreadId = null;
    this._unsubscribers = [];

    this._bindEvents();
    this.render();
  }

  _bindEvents() {
    const unsubSent = whatsAppBus.subscribe(WhatsAppEvents.MESSAGE_SENT, (msg) => {
      if (msg.conversationId === this.activeThreadId) this.render();
    });
    const unsubRecv = whatsAppBus.subscribe(WhatsAppEvents.MESSAGE_RECEIVED, (msg) => {
      if (msg.conversationId === this.activeThreadId) this.render();
    });

    this._unsubscribers.push(unsubSent, unsubRecv);
  }

  /**
   * Carga y visualiza una conversación por su identificador.
   * @param {string} threadId
   */
  loadThread(threadId) {
    this.activeThreadId = threadId;
    this.render();
    this.scrollToBottom();
  }

  /**
   * Renderiza el flujo de mensajes o el estado vacío correspondiente.
   */
  render() {
    if (!this.activeThreadId) {
      this.container.innerHTML = `
        <div style="flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; color: var(--text-tertiary); text-align: center; padding: 32px;">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.3" style="margin-bottom: 12px; opacity: 0.5;">
            <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>
          </svg>
          <p style="font-weight: 600; font-size: 14px; color: var(--text-secondary); margin-bottom: 4px;">Selecciona una conversación</p>
          <p style="font-size: 12px; max-width: 280px;">Elige un contacto en la lista izquierda para ver el historial y chatear con asistencia de IA local.</p>
        </div>
      `;
      return;
    }

    const messages = whatsAppStorage.getMessages(this.activeThreadId);
    if (messages.length === 0) {
      this.container.innerHTML = `
        <div style="flex: 1; display: flex; align-items: center; justify-content: center; color: var(--text-tertiary); font-size: 13px;">
          No hay mensajes previos en este chat. Escribe abajo para iniciar.
        </div>
      `;
      return;
    }

    this.container.innerHTML = messages
      .map((msg) => {
        const isInbound = msg.direction === MessageDirection.INBOUND;
        const time = new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        const checkIcon = !isInbound ? this._getStatusIcon(msg.status) : '';
        const aiBadge = msg.isAiGenerated ? `<span class="wa-ai-badge">Nano IA</span>` : '';

        return `
          <div class="wa-bubble ${isInbound ? 'inbound' : 'outbound'}">
            <div class="wa-bubble-text">${this._escapeHtml(msg.text)}</div>
            <div class="wa-bubble-meta">
              ${aiBadge}
              <span>${time}</span>
              ${checkIcon}
            </div>
          </div>
        `;
      })
      .join('');

    this.scrollToBottom();
  }

  /**
   * Desplaza el scroll suavemente al último mensaje.
   */
  scrollToBottom() {
    requestAnimationFrame(() => {
      this.container.scrollTop = this.container.scrollHeight;
    });
  }

  /**
   * Retorna el icono de estado de entrega para mensajes enviados.
   * @private
   */
  _getStatusIcon(status) {
    if (status === MessageStatus.READ || status === MessageStatus.DELIVERED) {
      return `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#25D366" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6L7 17l-5-5"/><path d="M22 10l-7.5 7.5L13 16"/></svg>`;
    }
    return `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`;
  }

  /**
   * Sanitiza cadenas de texto contra inyección HTML.
   * @private
   */
  _escapeHtml(str) {
    return (str || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  /**
   * Limpieza de listeners al destruir el componente.
   */
  destroy() {
    this._unsubscribers.forEach((fn) => fn());
    this._unsubscribers = [];
  }
}
