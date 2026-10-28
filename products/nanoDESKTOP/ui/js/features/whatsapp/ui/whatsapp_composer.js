/** Borrador editable por hilo; la IA sugiere, el transporte decide si puede enviar. */
import { NanoIcon } from '../../../components/nano_icon.js';
import { whatsAppDispatcher } from '../services/whatsapp_dispatcher.js';
import { whatsAppStorage } from '../services/whatsapp_storage.js';
import { whatsAppAiAgent } from '../services/whatsapp_ai_agent.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { MessageDirection } from '../domain/whatsapp_types.js';
import { appState } from '../../../core/state.js';

export class WhatsAppComposer {
  constructor(container) {
    this.container = container;
    this.activeThreadId = null;
    this._generationVersion = 0;
    this._render();
    this._unsubscribers = [whatsAppBus.subscribe(WhatsAppEvents.DRAFT_SUGGESTED,
      ({ conversationId, draft }) => {
        if (conversationId !== this.activeThreadId || !draft) return;
        // La respuesta tardía no sustituye texto que el usuario esté escribiendo.
        if (this._generating && this.input.value !== this._generationInput) return;
        this.input.value = draft;
        this._appliedSuggestion = true;
        this.saveDraft();
        this.resizeInput();
      })];
    this.form.addEventListener('submit', e => { e.preventDefault(); this.submitMessage(); });
    this.input.addEventListener('input', () => { this.saveDraft(); this.resizeInput(); });
    this.suggestButton.addEventListener('click', () => this.suggest());
    this._unsubscribers.push(appState.subscribe(() => this.updateSuggestion()));
    // El atajo no permite saltarse el estado deshabilitado del transporte.
    this.input.addEventListener('keydown', event => {
      if (event.key !== 'Enter' || !event.ctrlKey) return;
      event.preventDefault();
      if (this.form.querySelector('[type="submit"]').disabled) {
        this.feedback.textContent = 'Conecta primero la bandeja al servidor oficial para enviar.';
      } else this.form.requestSubmit();
    });
    this.setActiveThread(null);
  }
  /** Solo muestra controles integrados; no ofrece llamadas, voz ni adjuntos de mentira. */
  _render() {
    this.container.innerHTML = `
      <div class="wa-assist-bar">
        <button type="button" class="wa-assist-action" id="wa-generate-draft"
          title="Redactar con el modelo local seleccionado">${NanoIcon.get('sparkle', 16)} Sugerir</button>
        <span class="wa-ai-feedback" id="wa-draft-model"></span>
        <p class="wa-ai-feedback" id="wa-draft-feedback" role="status" aria-live="polite"></p>
      </div>
      <form class="wa-composer-bar" id="wa-composer-form">
        <textarea class="wa-composer-input" id="wa-composer-input" rows="1"
          aria-label="Borrador de respuesta" placeholder="Escribe un borrador…"></textarea>
        <button type="submit" class="wa-btn-send" id="wa-btn-send" disabled aria-label="Enviar mensaje"
          title="Envío pendiente de conexión al servidor oficial">${NanoIcon.get('send', 20)}</button>
      </form>
      <p class="wa-composer-note">Borrador local · envío pendiente de conexión oficial.</p>`;
    this.form = this.container.querySelector('form');
    this.input = this.container.querySelector('textarea');
    this.suggestButton = this.container.querySelector('#wa-generate-draft');
    this.feedback = this.container.querySelector('#wa-draft-feedback');
    this.modelNotice = this.container.querySelector('#wa-draft-model');
  }
  /** Guarda el texto, nunca crea un mensaje ni un recibo de envío. */
  saveDraft() {
    if (!this.activeThreadId) return;
    const conversations = whatsAppStorage.getConversations();
    const thread = conversations.find(c => c.id === this.activeThreadId);
    if (thread) { thread.draft = this.input.value; whatsAppStorage.saveConversations(conversations); }
  }
  /** Ajusta altura sin scroll del documento; desmonte y cambio de hilo cancelan el frame. */
  resizeInput() {
    cancelAnimationFrame(this._resizeFrame);
    this._resizeFrame = requestAnimationFrame(() => {
      if (!this.input.isConnected) return;
      // CSS es la única fuente de medidas: evita que JS imponga la altura del diseño anterior.
      const style = getComputedStyle(this.input);
      const minHeight = parseFloat(style.minHeight) || 34;
      const maxHeight = parseFloat(style.maxHeight) || 120;
      this.input.style.height = 'auto';
      this.input.style.height = Math.min(maxHeight, Math.max(minHeight, this.input.scrollHeight)) + 'px';
      this.input.style.overflowY = this.input.scrollHeight > maxHeight ? 'auto' : 'hidden';
    });
  }
  /** Conserva borrador y cancela la espera propia antes de cambiar de conversación. */
  setActiveThread(threadId) {
    this.saveDraft();
    this.cancelSuggestion();
    this.activeThreadId = threadId;
    this.input.value = whatsAppStorage.getConversations().find(c => c.id === threadId)?.draft || '';
    this.input.disabled = !threadId;
    this.container.hidden = !threadId;
    this.feedback.textContent = '';
    this.updateSuggestion();
    this.resizeInput();
  }
  /** Sugerir solo es relevante cuando el último mensaje guardado es entrante. */
  updateSuggestion() {
    const latest = whatsAppStorage.getMessages(this.activeThreadId).at(-1);
    const model = appState.getState().currentModel;
    this.modelNotice.textContent = model ? model.split(/[\\/]/).at(-1).replace(/\.gguf$/i, '') : 'Selecciona un modelo local';
    this.suggestButton.disabled = this._generating || !model || latest?.direction !== MessageDirection.INBOUND;
  }
  /** Captura hilo y versión; cancelar o navegar impide escribir resultados tardíos. */
  async suggest() {
    const threadId = this.activeThreadId;
    if (!threadId || this._generating) return;
    const version = ++this._generationVersion;
    this._generationInput = this.input.value;
    this._appliedSuggestion = false;
    this._generating = true;
    this.updateSuggestion();
    this.suggestButton.setAttribute('aria-busy', 'true');
    this.feedback.textContent = 'Nano está preparando una respuesta…';
    try {
      await whatsAppAiAgent.generateDraft(threadId);
      if (version === this._generationVersion) {
        this.feedback.textContent = this._appliedSuggestion
          ? 'Borrador listo para revisar.' : 'No se sustituyó el texto que estabas editando.';
      }
    } catch (error) {
      if (version === this._generationVersion) this.feedback.textContent = error.message || 'No se pudo generar el borrador.';
    } finally {
      if (version === this._generationVersion) {
        this._generating = false;
        this.suggestButton.removeAttribute('aria-busy');
        this.updateSuggestion();
      }
    }
  }
  /** Cambiar de chat no cancela modelos de otros módulos: solo esta espera. */
  cancelSuggestion() {
    this._generationVersion++;
    this._generating = false;
    whatsAppAiAgent.cancelPendingGeneration();
    this.suggestButton.removeAttribute('aria-busy');
  }
  /** Un fallo del adaptador conserva el borrador y muestra el motivo real. */
  async submitMessage() {
    if (!this.activeThreadId || !this.input.value.trim()) return;
    const result = await whatsAppDispatcher.sendMessage({
      conversationId: this.activeThreadId, text: this.input.value,
    });
    if (!result.success) this.feedback.textContent = result.error;
  }
  /** Al salir no quedan frames, suscripciones ni solicitudes de asistencia propias. */
  destroy() {
    this.saveDraft();
    this.cancelSuggestion();
    cancelAnimationFrame(this._resizeFrame);
    this._unsubscribers.forEach(fn => fn());
  }
}
