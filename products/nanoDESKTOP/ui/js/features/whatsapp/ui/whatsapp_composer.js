/**
 * whatsapp_composer.js — Barra de Composición y Envío de Mensajes
 * 
 * QUÉ HACE:
 * Gestiona el campo de texto, el botón de envío, la inserción de borradores de IA
 * y la simulación controlada de mensajes entrantes para pruebas deterministas.
 * 
 * CÓMO FUNCIONA:
 * Captura pulsaciones de teclado (`Enter` para enviar, `Shift+Enter` para salto de línea),
 * interactúa con `whatsAppDispatcher` y rellena el input con borradores sugeridos.
 * 
 * POR QUÉ:
 * El principio de Responsabilidad Única (SRP) aísla el manejo del teclado y del formulario
 * de la vista de mensajes, previniendo cuellos de botella y código espagueti.
 */

import { whatsAppDispatcher } from '../services/whatsapp_dispatcher.js';
import { whatsAppAiAgent } from '../services/whatsapp_ai_agent.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';

export class WhatsAppComposer {
  /**
   * @param {HTMLElement} container - Elemento contenedor de la barra de composición.
   */
  constructor(container) {
    this.container = container;
    this.activeThreadId = null;
    this.isGenerating = false;
    this._unsubscribers = [];

    this._render();
    this._bindEvents();
  }

  _render() {
    this.container.innerHTML = `
      <div class="wa-composer-bar">
        <button type="button" class="wa-pill-btn" id="wa-btn-attach" title="Adjuntar archivo">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/>
          </svg>
        </button>
        <input type="text" class="wa-composer-input" id="wa-composer-input" placeholder="Escribe un mensaje en WhatsApp..." disabled />
        <button type="button" class="wa-pill-btn" id="wa-btn-ai-draft" title="Sugerir borrador con IA Local" disabled>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
          </svg>
          <span>Sugerir con IA</span>
        </button>
        <button type="button" class="wa-btn-send" id="wa-btn-send" disabled>
          <span>Enviar</span>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="22" y1="2" x2="11" y2="13"/>
            <polygon points="22 2 15 22 11 13 2 9 22 2"/>
          </svg>
        </button>
      </div>
    `;

    this.input = this.container.querySelector('#wa-composer-input');
    this.btnSend = this.container.querySelector('#wa-btn-send');
    this.btnAi = this.container.querySelector('#wa-btn-ai-draft');
    this.btnAttach = this.container.querySelector('#wa-btn-attach');
  }

  _bindEvents() {
    this.btnSend.addEventListener('click', () => this.submitMessage());

    this.input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        this.submitMessage();
      }
    });

    this.btnAi.addEventListener('click', () => this.requestAiDraft());

    // Escuchar si llega un borrador sugerido externamente
    const unsubDraft = whatsAppBus.subscribe(WhatsAppEvents.DRAFT_SUGGESTED, ({ conversationId, draft }) => {
      if (conversationId === this.activeThreadId && draft) {
        this.input.value = draft;
        this.input.focus();
      }
    });
    this._unsubscribers.push(unsubDraft);
  }

  /**
   * Actualiza el hilo activo y habilita los controles de entrada.
   * @param {string | null} threadId
   */
  setActiveThread(threadId) {
    this.activeThreadId = threadId;
    const hasThread = Boolean(threadId);

    this.input.disabled = !hasThread;
    this.btnSend.disabled = !hasThread;
    this.btnAi.disabled = !hasThread;
    if (hasThread) {
      this.input.focus();
    }
  }

  /**
   * Envía el mensaje actual a través del despachador.
   */
  async submitMessage() {
    if (!this.activeThreadId) return;
    const text = this.input.value.trim();
    if (!text) return;

    this.input.value = '';
    await whatsAppDispatcher.sendMessage({
      conversationId: this.activeThreadId,
      text,
    });
  }

  /**
   * Solicita un borrador asistido al motor de IA local.
   */
  async requestAiDraft() {
    if (!this.activeThreadId || this.isGenerating) return;

    this.isGenerating = true;
    const prevText = this.btnAi.innerHTML;
    this.btnAi.innerHTML = `<span>Pensando...</span>`;
    this.btnAi.disabled = true;

    try {
      const draft = await whatsAppAiAgent.generateDraft(this.activeThreadId);
      if (draft) {
        this.input.value = draft;
        this.input.focus();
      }
    } finally {
      this.isGenerating = false;
      this.btnAi.innerHTML = prevText;
      this.btnAi.disabled = false;
    }
  }

  /**
   * Limpieza de eventos al cerrar el componente.
   */
  destroy() {
    this._unsubscribers.forEach((fn) => fn());
    this._unsubscribers = [];
  }
}
