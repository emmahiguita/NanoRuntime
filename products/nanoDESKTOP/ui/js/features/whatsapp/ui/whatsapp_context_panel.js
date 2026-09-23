/**
 * whatsapp_context_panel.js — Panel Lateral de Contexto de Contacto e Inteligencia de Negocio
 * 
 * QUÉ HACE:
 * Renderiza la 3ra columna de WhatsApp: ficha del contacto con avatar y cita cursiva,
 * contexto de negocio (Agente IA, tono, reglas, etiquetas, sugerencias) y estado de vinculación.
 * 
 * CÓMO FUNCIONA:
 * Lee el hilo activo desde `whatsAppStorage`, construye las tarjetas reactivas
 * y escucha eventos para mantener la información siempre sincronizada.
 * 
 * POR QUÉ:
 * El principio de Responsabilidad Única (SRP) aísla la inteligencia de negocio
 * garantizando código mantenible, libre de fugas y estrictamente < 200 LOC.
 */

import { whatsAppStorage } from '../services/whatsapp_storage.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { NanoIcon } from '../../../components/nano_icon.js';

export class WhatsAppContextPanel {
  constructor(container) {
    this.container = container;
    this.activeThreadId = null;
    this._unsubscribers = [];

    this._bindEvents();
    this.render();
  }

  _bindEvents() {
    const unsub = whatsAppBus.subscribe(WhatsAppEvents.CONVERSATIONS_UPDATED, () => this.render());
    this._unsubscribers.push(unsub);
  }

  setActiveThread(threadId) {
    this.activeThreadId = threadId;
    this.render();
  }

  render() {
    const convs = whatsAppStorage.getConversations();
    const thread = convs.find((c) => c.id === this.activeThreadId) || convs[0];
    const contact = thread?.contact || { name: 'María González', phone: '+52 55 1234 5678' };
    const tags = thread?.tags || ['Cliente', 'VIP', 'Interesado'];

    this.container.innerHTML = `
      <div class="wa-context-scroll">
        <div class="wa-context-header-quote">
          <div class="wa-quote-feather-bg"></div>
          <div class="wa-header-signature">"Conversaciones que crean oportunidades"</div>
        </div>

        <!-- Tarjeta 1: Información del Contacto -->
        <div class="wa-context-card">
          <div class="wa-card-header">
            <span class="wa-card-title">Información del contacto</span>
            <button type="button" class="wa-card-action-btn" title="Editar contacto">
              <span class="edit-icon">✏️</span> <span>Editar</span>
            </button>
          </div>
          <div class="wa-contact-profile-row">
            <div class="wa-profile-avatar-wrap">
              <div class="wa-profile-avatar">${contact.name[0]}</div>
              <span class="wa-profile-online-badge"></span>
            </div>
            <div class="wa-profile-info">
              <div class="wa-profile-name">${contact.name}</div>
              <div class="wa-profile-phone">${contact.phone}</div>
              <div class="wa-profile-status">● En línea</div>
            </div>
            <div class="wa-profile-actions">
              <button type="button" class="wa-btn-circle" title="Llamada">${NanoIcon.get('chat', 14)}</button>
              <button type="button" class="wa-btn-circle" title="Videollamada">${NanoIcon.get('video', 14) || '📹'}</button>
              <button type="button" class="wa-btn-circle" title="Más">···</button>
            </div>
          </div>
          <div class="wa-contact-quote-box">
            <div class="quote-feather-mini"></div>
            <div class="quote-text-cursive">"La tecnología bien usada hace la vida más simple"</div>
          </div>
        </div>

        <!-- Tarjeta 2: Contexto de Negocio -->
        <div class="wa-context-card">
          <div class="wa-card-header"><span class="wa-card-title">Contexto de negocio</span></div>
          <div class="wa-business-items">
            <div class="wa-biz-row">
              <span class="wa-biz-icon">${NanoIcon.get('sparkle', 16) || '🤖'}</span>
              <div class="wa-biz-text">
                <span class="wa-biz-label">Agente IA</span>
                <span class="wa-biz-desc">Responde, califica, cotiza y da seguimiento.</span>
              </div>
              <span class="wa-badge-active-pill">● ACTIVO ›</span>
            </div>
            <div class="wa-biz-row">
              <span class="wa-biz-icon">${NanoIcon.get('chat', 16)}</span>
              <div class="wa-biz-text">
                <span class="wa-biz-label">Tono</span>
                <span class="wa-biz-desc">Cercano, profesional y empático.</span>
              </div>
            </div>
            <div class="wa-biz-row">
              <span class="wa-biz-icon">${NanoIcon.get('shield', 16) || '📋'}</span>
              <div class="wa-biz-text">
                <span class="wa-biz-label">Reglas</span>
                <span class="wa-biz-desc">Usar precios oficiales. No prometer sin stock.</span>
              </div>
              <span class="wa-biz-arrow">›</span>
            </div>
            <div class="wa-biz-row">
              <span class="wa-biz-icon">🏷️</span>
              <div class="wa-biz-text">
                <span class="wa-biz-label">Etiquetas</span>
                <div class="wa-tags-container">
                  ${tags.map((t) => `<span class="wa-tag-pill ${t.toLowerCase()}">${t}</span>`).join('')}
                  <button type="button" class="wa-tag-pill add" title="Añadir etiqueta">+</button>
                </div>
              </div>
            </div>
            <div class="wa-biz-row suggestions-block">
              <span class="wa-biz-icon">💡</span>
              <div class="wa-biz-text full">
                <span class="wa-biz-label">Sugerencias IA</span>
                <div class="wa-suggestion-line">
                  <span>Enviar brochure del plan profesional</span>
                  <button type="button" class="btn-apply-suggestion" data-prompt="Enviar brochure del plan profesional">Aplicar</button>
                </div>
                <div class="wa-suggestion-line">
                  <span>Ofrecer demo personalizada</span>
                  <button type="button" class="btn-apply-suggestion" data-prompt="Ofrecer demo personalizada">Aplicar</button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Tarjeta 3: Estado de Vinculación -->
        <div class="wa-context-card">
          <div class="wa-card-header">
            <span class="wa-card-title">Estado de vinculación</span>
            <button type="button" class="wa-card-action-btn" id="wa-btn-config-session"><span>⚙️ Configuración</span></button>
          </div>
          <div class="wa-link-status-row">
            <div class="wa-link-left">
              <span class="wa-link-icon-green">${NanoIcon.get('whatsapp', 24)}</span>
              <div class="wa-link-info">
                <div class="wa-link-connected">● Conectado</div>
                <div class="wa-link-number">Número: +52 55 9876 5432</div>
                <div class="wa-link-sync">Última sincronización: hace 2 minutos</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `;

    this._bindCardActions();
  }

  _bindCardActions() {
    this.container.querySelectorAll('.btn-apply-suggestion').forEach((btn) => {
      btn.addEventListener('click', () => {
        const prompt = btn.dataset.prompt;
        if (prompt && this.activeThreadId) {
          whatsAppBus.emit(WhatsAppEvents.DRAFT_SUGGESTED, {
            conversationId: this.activeThreadId,
            draft: prompt,
          });
        }
      });
    });

    const btnConfig = this.container.querySelector('#wa-btn-config-session');
    btnConfig?.addEventListener('click', () => {
      whatsAppBus.emit('ui:open_pairing_modal');
    });
  }

  destroy() {
    this._unsubscribers.forEach((fn) => fn());
    this._unsubscribers = [];
  }
}
