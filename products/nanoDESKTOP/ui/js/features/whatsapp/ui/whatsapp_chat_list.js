/**
 * whatsapp_chat_list.js — Componente de Lista de Conversaciones de WhatsApp
 * 
 * QUÉ HACE:
 * Renderiza y filtra la lista de hilos de chat, permitiendo al usuario buscar
 * y seleccionar la conversación activa con badges reactivos de no leídos.
 * 
 * CÓMO FUNCIONA:
 * Escucha cambios en el término de búsqueda y en el almacén de conversaciones,
 * actualizando el DOM de manera eficiente mediante fragmentos sin recrear innecesariamente.
 * 
 * POR QUÉ:
 * Separa la vista de selección de hilos de la visualización de mensajes (Principio de
 * Responsabilidad Única - SRP), manteniendo cada módulo < 200 líneas.
 */

import { whatsAppStorage } from '../services/whatsapp_storage.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';

export class WhatsAppChatList {
  /**
   * @param {HTMLElement} container - Contenedor padre de la barra lateral.
   * @param {Function} onSelectThread - Callback cuando el usuario selecciona un chat.
   */
  constructor(container, onSelectThread) {
    this.container = container;
    this.onSelectThread = onSelectThread;
    this.activeThreadId = null;
    this.filterTerm = '';
    this._unsubscribers = [];

    this._renderBase();
    this._bindEvents();
  }

  _renderBase() {
    this.container.innerHTML = `
      <div class="wa-sidebar-header">
        <div class="wa-sidebar-title-row">
          <span>Chats de WhatsApp</span>
        </div>
        <button type="button" class="wa-pill-btn" id="wa-btn-pair-header" title="Vincular teléfono o QR">
          Vincular
        </button>
      </div>
      <div class="wa-search-box">
        <input type="text" class="wa-search-input" id="wa-search-input" placeholder="Buscar chat o contacto..." />
      </div>
      <div class="wa-chat-list" id="wa-chat-items-container"></div>
    `;

    this.itemsContainer = this.container.querySelector('#wa-chat-items-container');
    this.searchInput = this.container.querySelector('#wa-search-input');
    this.render();
  }

  _bindEvents() {
    this.searchInput.addEventListener('input', (e) => {
      this.filterTerm = e.target.value.toLowerCase().trim();
      this.render();
    });

    const btnPair = this.container.querySelector('#wa-btn-pair-header');
    if (btnPair) {
      btnPair.addEventListener('click', () => {
        whatsAppBus.emit('ui:open_pairing_modal');
      });
    }

    const unsub = whatsAppBus.subscribe(WhatsAppEvents.CONVERSATIONS_UPDATED, () => {
      this.render();
    });
    this._unsubscribers.push(unsub);
  }

  /**
   * Renderiza la lista de hilos aplicando filtros y marcando el hilo activo.
   */
  render() {
    const all = whatsAppStorage.getConversations();
    const filtered = all.filter((conv) => {
      if (!this.filterTerm) return true;
      const name = (conv.contact?.name || '').toLowerCase();
      const phone = (conv.contact?.phone || '').toLowerCase();
      const lastMsg = (conv.lastMessage?.text || '').toLowerCase();
      return name.includes(this.filterTerm) || phone.includes(this.filterTerm) || lastMsg.includes(this.filterTerm);
    });

    if (filtered.length === 0) {
      this.itemsContainer.innerHTML = `
        <div style="padding: 24px; text-align: center; color: var(--text-tertiary); font-size: 12px;">
          No se encontraron chats que coincidan con la búsqueda.
        </div>
      `;
      return;
    }

    this.itemsContainer.innerHTML = filtered
      .map((conv) => {
        const isActive = conv.id === this.activeThreadId;
        const initial = (conv.contact?.name || 'W')[0].toUpperCase();
        const timeStr = conv.lastMessage ? new Date(conv.lastMessage.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '';
        const preview = conv.lastMessage?.text || 'Sin mensajes recientes';

        return `
          <div class="wa-chat-item ${isActive ? 'active' : ''}" data-thread-id="${conv.id}">
            <div class="wa-avatar">
              ${initial}
            </div>
            <div class="wa-chat-info">
              <div class="wa-chat-top-row">
                <span class="wa-chat-name">${conv.contact?.name || 'Contacto'}</span>
                <span class="wa-chat-time">${timeStr}</span>
              </div>
              <div class="wa-chat-bottom-row">
                <span class="wa-chat-preview">${preview}</span>
                ${conv.unreadCount > 0 ? `<span class="wa-badge-unread">${conv.unreadCount}</span>` : ''}
              </div>
            </div>
          </div>
        `;
      })
      .join('');

    // Asignar listeners a cada elemento del chat
    this.itemsContainer.querySelectorAll('.wa-chat-item').forEach((el) => {
      el.addEventListener('click', () => {
        const threadId = el.dataset.threadId;
        this.selectThread(threadId);
      });
    });
  }

  /**
   * Selecciona un hilo de conversación y notifica al controlador principal.
   * @param {string} threadId
   */
  selectThread(threadId) {
    this.activeThreadId = threadId;
    this.render();

    // Marcar como leído en almacenamiento
    const convs = whatsAppStorage.getConversations();
    const target = convs.find((c) => c.id === threadId);
    if (target && target.unreadCount > 0) {
      target.unreadCount = 0;
      whatsAppStorage.saveConversations(convs);
    }

    if (typeof this.onSelectThread === 'function') {
      this.onSelectThread(threadId);
    }
  }

  /**
   * Limpia suscripciones activas al desmantelar la vista.
   */
  destroy() {
    this._unsubscribers.forEach((fn) => fn());
    this._unsubscribers = [];
  }
}
