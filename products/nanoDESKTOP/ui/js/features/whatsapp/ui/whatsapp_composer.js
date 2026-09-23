/**
 * whatsapp_composer.js — Barra de Composición y Envío de Mensajes
 * 
 * QUÉ HACE:
 * Gestiona el campo de texto, botón de adjuntar, selector de emoji y botón de envío
 * 'Enviar' para despachar mensajes en el hilo de WhatsApp activo.
 * 
 * CÓMO FUNCIONA:
 * Captura pulsaciones de teclado (Enter para enviar), gestiona habilitación
 * reactiva y despacha a través de `whatsAppDispatcher`.
 * 
 * POR QUÉ:
 * Separa el formulario de entrada de la visualización de mensajes (SRP), evitando
 * acoplamientos innecesarios y garantizando un código limpio < 200 líneas.
 */

import { whatsAppDispatcher } from '../services/whatsapp_dispatcher.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { NanoIcon } from '../../../components/nano_icon.js';

export class WhatsAppComposer {
  constructor(container) {
    this.container = container;
    this.activeThreadId = null;
    this._unsubscribers = [];

    this._render();
    this._bindEvents();
  }

  _render() {
    this.container.innerHTML = `
      <form class="wa-composer-bar" id="wa-composer-form">
        <button type="button" class="wa-composer-icon-btn" id="wa-btn-attach" title="Adjuntar archivo o imagen">
          ${NanoIcon.get('attach', 18)}
        </button>
        <input 
          type="text" 
          class="wa-composer-input" 
          id="wa-composer-input" 
          placeholder="Escribe un mensaje en WhatsApp..." 
          autocomplete="off"
        />
        <button type="button" class="wa-composer-icon-btn" id="wa-btn-emoji" title="Insertar emoji">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
            <circle cx="12" cy="12" r="10"/>
            <path d="M8 14s1.5 2 4 2 4-2 4-2"/>
            <line x1="9" y1="9" x2="9.01" y2="9"/>
            <line x1="15" y1="9" x2="15.01" y2="9"/>
          </svg>
        </button>
        <button type="submit" class="wa-btn-send" id="wa-btn-send">
          ${NanoIcon.get('send', 15)}
          <span>Enviar</span>
        </button>
      </form>
    `;

    this.form = this.container.querySelector('#wa-composer-form');
    this.input = this.container.querySelector('#wa-composer-input');
    this.btnSend = this.container.querySelector('#wa-btn-send');
    this.btnAttach = this.container.querySelector('#wa-btn-attach');
    this.btnEmoji = this.container.querySelector('#wa-btn-emoji');
  }

  _bindEvents() {
    this.form?.addEventListener('submit', (e) => {
      e.preventDefault();
      this.submitMessage();
    });

    this.btnEmoji?.addEventListener('click', () => {
      if (this.input) {
        this.input.value += ' 😊';
        this.input.focus();
      }
    });

    const unsubDraft = whatsAppBus.subscribe(WhatsAppEvents.DRAFT_SUGGESTED, ({ conversationId, draft }) => {
      if (conversationId === this.activeThreadId && draft && this.input) {
        this.input.value = draft;
        this.input.focus();
      }
    });
    this._unsubscribers.push(unsubDraft);
  }

  setActiveThread(threadId) {
    this.activeThreadId = threadId;
    const hasThread = Boolean(threadId);
    if (this.input) {
      this.input.disabled = !hasThread;
      if (hasThread) this.input.focus();
    }
    if (this.btnSend) {
      this.btnSend.disabled = !hasThread;
    }
  }

  async submitMessage() {
    if (!this.activeThreadId || !this.input) return;
    const text = this.input.value.trim();
    if (!text) return;

    this.input.value = '';
    await whatsAppDispatcher.sendMessage({
      conversationId: this.activeThreadId,
      text,
    });
  }

  destroy() {
    this._unsubscribers.forEach((fn) => fn());
    this._unsubscribers = [];
  }
}
