/** Presenta datos guardados y política real; nunca inventa presencia, archivos o entrega. */
import { whatsAppStorage } from '../services/whatsapp_storage.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { escapeHtml } from '../../../core/utils.js';

export class WhatsAppContextPanel {
  constructor(container) {
    this.container = container;
    this.activeThreadId = null;
    this.activeTab = 'information';
    this._unsubscribers = [
      whatsAppBus.subscribe(WhatsAppEvents.CONVERSATIONS_UPDATED, () => this.render()),
    ];
    this.render();
  }
  /** Seleccionar un hilo cambia datos, no contactos, permisos ni automatizaciones. */
  setActiveThread(threadId) { this.activeThreadId = threadId; this.render(); }

  /** Solo existen pestañas con contenido implementado; los adjuntos esperan al adaptador. */
  render() {
    const thread = whatsAppStorage.getConversations().find(c => c.id === this.activeThreadId);
    const contact = thread?.contact;
    const policy = whatsAppStorage.getPolicy();
    const tags = Array.isArray(thread?.tags) ? thread.tags : [];
    const safe = value => escapeHtml(String(value ?? ''));
    this.container.innerHTML = `<div class="wa-context-tabs" role="tablist" aria-label="Detalles del chat">
      <button class="wa-context-tab" type="button" role="tab" id="wa-tab-information"
        data-context-tab="information" aria-controls="wa-panel-information">Información</button>
      <button class="wa-context-tab" type="button" role="tab" id="wa-tab-assistance"
        data-context-tab="assistance" aria-controls="wa-panel-assistance">Asistencia</button>
    </div>
    <div class="wa-context-content">
      <section role="tabpanel" id="wa-panel-information" aria-labelledby="wa-tab-information" tabindex="0">
        <div class="wa-context-section">
          ${contact ? `<div class="wa-contact-profile-row">
            <div class="wa-profile-avatar" aria-hidden="true">${safe(contact.name?.[0] || '?')}</div>
            <div class="wa-profile-info"><div class="wa-profile-name">${safe(contact.name)}</div>
              <div class="wa-profile-phone">${safe(contact.phone || 'Número no disponible')}</div></div>
          </div>` : '<h3 class="wa-card-title">Sin conversación seleccionada</h3>'}
          <p class="wa-detail-copy">${thread ? 'Historial local · origen no verificado por Meta.' : 'Aquí aparecerán los datos de la conversación que selecciones.'}</p>
        </div>
        ${tags.length ? `<div class="wa-context-section"><h3 class="wa-card-title">Etiquetas guardadas</h3>
          <div class="wa-tags-container">${tags.map(t => `<span class="wa-tag-pill">${safe(t)}</span>`).join('')}</div></div>` : ''}
        <div class="wa-context-section">
          <h3 class="wa-card-title">Privacidad</h3>
          <p class="wa-detail-copy">No se consulta la presencia del contacto ni se confirma entrega sin evidencia de Meta.</p>
        </div>
      </section>
      <section role="tabpanel" id="wa-panel-assistance" aria-labelledby="wa-tab-assistance" tabindex="0">
        <div class="wa-context-section">
          <h3 class="wa-card-title">Respuesta con IA local</h3>
          <p class="wa-detail-copy">Usa «Sugerir respuesta» junto al borrador. El modelo redacta con el historial del chat seleccionado; tú revisas el texto.</p>
        </div>
        <div class="wa-context-section">
          <h3 class="wa-card-title">Control de envío</h3>
          <p class="wa-detail-copy">Aprobación humana guardada: ${policy.requireHumanApproval ? 'requerida' : 'no requerida'}.</p>
          <p class="wa-detail-copy">El envío y la respuesta automática aún no están conectados en esta bandeja.</p>
        </div>
      </section>
    </div>`;
    this.tabs = [...this.container.querySelectorAll('[role="tab"]')];
    this.tabs.forEach((tab, index) => {
      tab.addEventListener('click', () => this.selectTab(tab.dataset.contextTab));
      // Flechas mueven foco y selección; Tab entra al contenido, sin trampas de teclado.
      tab.addEventListener('keydown', event => {
        if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
        event.preventDefault();
        const next = event.key === 'Home' ? 0 : event.key === 'End' ? this.tabs.length - 1
          : (index + (event.key === 'ArrowRight' ? 1 : -1) + this.tabs.length) % this.tabs.length;
        this.selectTab(this.tabs[next].dataset.contextTab);
        this.tabs[next].focus();
      });
    });
    this.selectTab(this.activeTab);
  }
  /** Un único panel mantiene selección y ARIA sincronizados, también tras actualizar datos. */
  selectTab(name) {
    this.activeTab = name;
    this.tabs.forEach(tab => {
      const selected = tab.dataset.contextTab === name;
      tab.setAttribute('aria-selected', String(selected));
      tab.tabIndex = selected ? 0 : -1;
      this.container.querySelector('#' + tab.getAttribute('aria-controls')).hidden = !selected;
    });
  }
  /** Libera suscripciones; la asistencia pertenece al compositor, no a este panel. */
  destroy() { this._unsubscribers.forEach(fn => fn()); this._unsubscribers = []; }
}
