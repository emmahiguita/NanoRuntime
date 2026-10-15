/**
 * whatsapp_chat_list.js — Componente de Lista de Conversaciones de WhatsApp
 * 
 * QUÉ HACE:
 * Renderiza el panel izquierdo de chats con pestañas de filtro (Todos, No leídos,
 * Clientes, Etiquetas), buscador y tarjetas de contacto con avatar y badges.
 * 
 * CÓMO FUNCIONA:
 * Filtra en memoria por texto o pestaña activa, actualiza el DOM de forma eficiente
 * y emite el id seleccionado al mediador principal.
 * 
 * POR QUÉ:
 * El principio de Responsabilidad Única (SRP) mantiene la selección de hilos aislada
 * de la renderización del mensaje, garantizando rendimiento y < 200 líneas.
 */

import { whatsAppStorage } from '../services/whatsapp_storage.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { NanoIcon } from '../../../components/nano_icon.js';
import { escapeHtml } from '../../../core/utils.js';

export class WhatsAppChatList {
  constructor(container, onSelectThread) {
    this.container = container;
    this.onSelectThread = onSelectThread;
    this.activeThreadId = null;
    this.filterTerm = '';
    this.activeTab = 'all';
    this._unsubscribers = [];

    this._renderBase();
    this._bindEvents();
  }

  _renderBase() {
    this.container.innerHTML = `
      <div class="wa-sidebar-header">
        <div class="wa-sidebar-title-row">
          <div class="wa-title-left">
            <span class="wa-brand-icon">${NanoIcon.get('whatsapp', 22)}</span>
            <span class="wa-title-text">Chats de WhatsApp</span>
          </div>
        </div>
        <div class="wa-search-row">
          <div class="wa-search-box">
            <span class="wa-search-icon">${NanoIcon.get('search', 14)}</span>
            <input type="search" class="wa-search-input" id="wa-search-input" aria-label="Buscar conversaciones" placeholder="Buscar conversaciones…" />
          </div>
        </div>
        <div class="wa-filter-tabs">
          <button type="button" class="wa-tab-pill active" data-tab="all">Todos <span class="tab-count" id="wa-tab-all-count"></span></button>
          <button type="button" class="wa-tab-pill" data-tab="unread">No leídos <span class="tab-count" id="wa-tab-unread-count"></span></button>
          <button type="button" class="wa-tab-pill" data-tab="clients">Clientes</button>
        </div>
      </div>
      <div class="wa-chat-list" id="wa-chat-items-container"></div>
    `;

    this.itemsContainer = this.container.querySelector('#wa-chat-items-container');
    this.searchInput = this.container.querySelector('#wa-search-input');
    this.tabAllCount = this.container.querySelector('#wa-tab-all-count');
    this.tabUnreadCount = this.container.querySelector('#wa-tab-unread-count');
    this.render();
  }

  _bindEvents() {
    this.searchInput?.addEventListener('input', (e) => {
      this.filterTerm = e.target.value.toLowerCase().trim();
      this.render();
    });

    this.container.querySelectorAll('.wa-tab-pill').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.container.querySelectorAll('.wa-tab-pill').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        this.activeTab = btn.dataset.tab;
        this.render();
      });
    });

    const unsub = whatsAppBus.subscribe(WhatsAppEvents.CONVERSATIONS_UPDATED, () => this.render());
    this._unsubscribers.push(unsub);
  }

  render() {
    // Rehacer la lista no debe moverla al cambiar de conversación o contador.
    const previousTop = this.itemsContainer.scrollTop;
    const all = whatsAppStorage.getConversations();
    if (this.tabAllCount) this.tabAllCount.textContent = all.length;
    if (this.tabUnreadCount) this.tabUnreadCount.textContent = all.filter((c) => c.unreadCount > 0).length;

    const filtered = all.filter((conv) => {
      if (this.activeTab === 'unread' && (!conv.unreadCount || conv.unreadCount <= 0)) return false;
      if (this.activeTab === 'clients' && (!conv.tags || !conv.tags.includes('Cliente'))) return false;
      if (!this.filterTerm) return true;
      const name = (conv.contact?.name || '').toLowerCase();
      const last = (conv.lastMessage?.text || '').toLowerCase();
      return name.includes(this.filterTerm) || last.includes(this.filterTerm);
    });

    if (filtered.length === 0) {
      this.itemsContainer.innerHTML = `
        <div class="wa-empty-list-notice">${all.length ? 'Sin resultados para este filtro.' : 'Aún no hay conversaciones guardadas.'}</div>
      `;
      return;
    }

    this.itemsContainer.innerHTML = filtered.map((conv) => {
      const isActive = conv.id === this.activeThreadId;
      const initial = (conv.contact?.name || 'W')[0].toUpperCase();
      const time = conv.lastMessage?.timestamp ? new Date(conv.lastMessage.timestamp) : null;
      const timeStr = time && !Number.isNaN(time.getTime())
        ? time.toLocaleTimeString('es', { hour: '2-digit', minute: '2-digit' }) : '';
      const preview = conv.lastMessage?.text?.replace(/\n/g, ' ') || 'Sin mensajes';
      const hasAttach = conv.hasAttach;

      return `
        <button type="button" class="wa-chat-item ${isActive ? 'active' : ''}"
          aria-pressed="${isActive}" data-thread-id="${escapeHtml(String(conv.id))}">
          <div class="wa-avatar-wrap">
            <div class="wa-avatar">${escapeHtml(initial)}</div>
          </div>
          <div class="wa-chat-info">
            <div class="wa-chat-top-row">
              <span class="wa-chat-name">${escapeHtml(String(conv.contact?.name || 'Contacto'))}</span>
              <span class="wa-chat-time">${timeStr}</span>
            </div>
            <div class="wa-chat-bottom-row">
              <span class="wa-chat-preview">
                ${hasAttach ? `<span class="attach-mini">${NanoIcon.get('attach', 11)}</span> ` : ''}${escapeHtml(String(preview))}
              </span>
              ${conv.unreadCount > 0 ? `<span class="wa-badge-unread">${conv.unreadCount}</span>` : ''}
            </div>
          </div>
        </button>
      `;
    }).join('');
    this.itemsContainer.scrollTop = previousTop;

    this.itemsContainer.querySelectorAll('.wa-chat-item').forEach((el) => {
      el.addEventListener('click', () => this.selectThread(el.dataset.threadId));
    });
  }

  selectThread(threadId) {
    this.activeThreadId = threadId;

    const convs = whatsAppStorage.getConversations();
    const target = convs.find((c) => c.id === threadId);
    if (target && target.unreadCount > 0) {
      target.unreadCount = 0;
      whatsAppStorage.saveConversations(convs);
    }
    // Actualiza contador y selección después de leer; nunca equivale a recibo de Meta.
    this.render();

    if (typeof this.onSelectThread === 'function') {
      this.onSelectThread(threadId);
    }
  }

  destroy() {
    this._unsubscribers.forEach((fn) => fn());
    this._unsubscribers = [];
  }
}
