/**
 * whatsapp_chat_conversation.js — Visor de Conversación y Flujo de Mensajes
 * 
 * QUÉ HACE:
 * Renderiza la cabecera del contacto activo (avatar, tags, acciones), la fecha,
 * burbujas de diálogo con doble check azul y el indicador de escritura '● ● ●'.
 * 
 * CÓMO FUNCIONA:
 * Lee los mensajes del almacén para el hilo activo y actualiza el DOM de forma
 * segura con scroll automático asistido por requestAnimationFrame.
 * 
 * POR QUÉ:
 * Cumple con el Principio de Responsabilidad Única (SRP) y garantiza total
 * fidelidad visual con la referencia del diseño sin superar las 200 líneas.
 */

import { whatsAppStorage } from '../services/whatsapp_storage.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { MessageDirection } from '../domain/whatsapp_types.js';
import { NanoIcon } from '../../../components/nano_icon.js';

export class WhatsAppChatConversation {
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

  loadThread(threadId) {
    this.activeThreadId = threadId;
    this.render();
    this.scrollToBottom();
  }

  render() {
    if (!this.activeThreadId) {
      this.container.innerHTML = `
        <div class="wa-empty-chat-state">
          <p>Selecciona una conversación para comenzar a chatear.</p>
        </div>
      `;
      return;
    }

    const convs = whatsAppStorage.getConversations();
    const thread = convs.find((c) => c.id === this.activeThreadId);
    const contactName = thread?.contact?.name || 'María González';
    const isOnline = thread?.online ?? true;
    const tags = thread?.tags || ['Cliente', 'VIP', 'Interesado'];
    const messages = whatsAppStorage.getMessages(this.activeThreadId);

    const headerHtml = `
      <div class="wa-conversation-header">
        <div class="wa-conv-header-left">
          <div class="wa-avatar-wrap">
            <div class="wa-avatar large">${contactName[0]}</div>
            ${isOnline ? '<span class="wa-avatar-online-dot"></span>' : ''}
          </div>
          <div class="wa-conv-header-meta">
            <div class="wa-conv-name">${contactName}</div>
            <div class="wa-conv-subline">
              <span class="wa-status-online">● En línea</span>
              <div class="wa-header-tags">
                ${tags.map((t) => `<span class="wa-tag-pill ${t.toLowerCase()}">${t}</span>`).join('')}
              </div>
            </div>
          </div>
        </div>
        <div class="wa-conv-header-actions">
          <button type="button" class="wa-action-icon" title="Buscar">${NanoIcon.get('search', 16)}</button>
          <button type="button" class="wa-action-icon" title="Llamada">${NanoIcon.get('phone', 16) || NanoIcon.get('chat', 16)}</button>
          <button type="button" class="wa-action-icon" title="Info">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
          </button>
          <button type="button" class="wa-action-icon" title="Más opciones">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="1"/><circle cx="12" cy="5" r="1"/><circle cx="12" cy="19" r="1"/></svg>
          </button>
        </div>
      </div>
    `;

    const streamHtml = `
      <div class="wa-messages-body" id="wa-messages-body">
        <div class="wa-date-divider">
          <span>Hoy, 12 de marzo</span>
        </div>
        ${messages.map((m) => this._renderBubble(m)).join('')}
        ${this.activeThreadId === 'wa_1' ? `
          <div class="wa-typing-indicator-row">
            <div class="wa-typing-bubble">
              <span class="dot"></span><span class="dot"></span><span class="dot"></span>
            </div>
          </div>
        ` : ''}
      </div>
    `;

    this.container.innerHTML = `${headerHtml}${streamHtml}`;
    this.scrollToBottom();
  }

  _renderBubble(msg) {
    const isInbound = msg.direction === MessageDirection.INBOUND;
    const time = msg.timestamp ? new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '10:24';
    const textFormatted = this._escapeHtml(msg.text).replace(/\n/g, '<br>');

    return `
      <div class="wa-bubble-row ${isInbound ? 'inbound' : 'outbound'}">
        <div class="wa-bubble ${isInbound ? 'inbound' : 'outbound'}">
          <div class="wa-bubble-text">${textFormatted}</div>
          <div class="wa-bubble-footer">
            <span class="wa-time-stamp">${time}</span>
            ${!isInbound ? '<span class="wa-double-check">✓✓</span>' : ''}
          </div>
        </div>
      </div>
    `;
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      const body = this.container.querySelector('#wa-messages-body');
      if (body) body.scrollTop = body.scrollHeight;
    });
  }

  _escapeHtml(str) {
    return (str || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  destroy() {
    this._unsubscribers.forEach((fn) => fn());
    this._unsubscribers = [];
  }
}
