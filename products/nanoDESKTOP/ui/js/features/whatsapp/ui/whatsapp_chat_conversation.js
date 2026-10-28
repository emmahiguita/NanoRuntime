/** Historial local con fechas reales: no inventa presencia ni confirmaciones. */
import { whatsAppStorage } from '../services/whatsapp_storage.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { MessageDirection } from '../domain/whatsapp_types.js';
import { escapeHtml } from '../../../core/utils.js';

export class WhatsAppChatConversation {
  constructor(container) {
    this.container = container;
    this.activeThreadId = null;
    this._unsubscribers = [WhatsAppEvents.MESSAGE_SENT, WhatsAppEvents.MESSAGE_RECEIVED,
      WhatsAppEvents.CONVERSATIONS_UPDATED].map(event => whatsAppBus.subscribe(event, () => this.render()));
    this.render();
  }
  /** Selecciona el hilo local sin consultar contactos externos. */
  loadThread(threadId) { this.activeThreadId = threadId; this.render(true); }
  /** La ausencia de historial se reconoce, no se rellena con ejemplos. */
  render(changedThread = false) {
    const previousBody = this.container.querySelector('#wa-messages-body');
    const previousTop = previousBody?.scrollTop || 0;
    const nearEnd = !previousBody || previousBody.scrollHeight - previousTop - previousBody.clientHeight < 80;
    const thread = whatsAppStorage.getConversations().find(c => c.id === this.activeThreadId);
    if (!thread) {
      this.container.innerHTML = `<div class="wa-empty-chat-state">
        <img class="wa-empty-owl" src="assets/brand/nano-logo-mark.svg" alt="" />
        <h2>Tu bandeja de mensajes</h2>
        <p>Selecciona una conversación para comenzar.</p>
      </div>`;
      return;
    }
    const name = String(thread.contact?.name || 'Contacto');
    const messages = whatsAppStorage.getMessages(thread.id);
    let lastDate = '';
    const stream = messages.map(msg => {
      const timestamp = msg.timestamp ? new Date(msg.timestamp) : null;
      const date = timestamp && !Number.isNaN(timestamp.getTime())
        ? timestamp.toLocaleDateString('es', { day: 'numeric', month: 'long', year: 'numeric' })
        : 'Fecha no disponible';
      const divider = date !== lastDate ? `<div class="wa-date-divider"><span>${date}</span></div>` : '';
      lastDate = date;
      return divider + this._renderBubble(msg);
    }).join('');
    this.container.innerHTML = `
      <div class="wa-conversation-header"><div class="wa-conv-header-left">
        <div class="wa-avatar large">${escapeHtml(name[0])}</div>
        <div class="wa-conv-header-meta">
          <div class="wa-conv-name">${escapeHtml(name)}</div>
          <div class="wa-conv-subline">Historial local · no sincronizado con Meta</div>
        </div>
      </div></div>
      <div class="wa-messages-body ${changedThread ? 'wa-thread-enter' : ''}" id="wa-messages-body">
        ${stream || '<div class="wa-empty-list-notice">Sin mensajes guardados en este registro.</div>'}
      </div>`;
    // Actualizaciones no relacionadas conservan el punto de lectura del historial.
    if (changedThread || nearEnd) this.scrollToBottom();
    else this.container.querySelector('#wa-messages-body').scrollTop = previousTop;
  }
  /** El estado legado no prueba entrega; se requieren recibos reales del proveedor. */
  _renderBubble(msg) {
    const direction = msg.direction === MessageDirection.INBOUND ? 'inbound' : 'outbound';
    const date = msg.timestamp ? new Date(msg.timestamp) : null;
    const time = date && !Number.isNaN(date.getTime())
      ? date.toLocaleTimeString('es', { hour: '2-digit', minute: '2-digit' }) : '';
    return `<div class="wa-bubble-row ${direction}"><div class="wa-bubble ${direction}">
      <div class="wa-bubble-text">${escapeHtml(String(msg.text || '')).replace(/\n/g, '<br>')}</div>
      <div class="wa-bubble-footer"><span class="wa-time-stamp">${time}</span>
        ${direction === 'outbound' ? '<span class="wa-time-stamp">Entrega no verificada</span>' : ''}
      </div></div></div>`;
  }
  /** Un desmonte cancela el frame pendiente para evitar callbacks tardíos. */
  scrollToBottom() {
    cancelAnimationFrame(this._frame);
    this._frame = requestAnimationFrame(() => {
      const body = this.container.querySelector('#wa-messages-body');
      if (body) body.scrollTop = body.scrollHeight;
    });
  }
  destroy() { cancelAnimationFrame(this._frame); this._unsubscribers.forEach(fn => fn()); }
}
