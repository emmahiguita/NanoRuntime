/**
 * whatsapp_policy_bar.js — Barra de Políticas y Gobernanza del Chat
 * 
 * QUÉ HACE:
 * Muestra el estado del contacto activo, permite conmutar el Agente Autónomo
 * para el chat seleccionado, elegir el tono y simular recepción de mensajes.
 * 
 * CÓMO FUNCIONA:
 * Lee y persiste la configuración en `whatsAppStorage` y notifica al despachador
 * para actualizar las reglas de respuesta en vivo sin recargar la pantalla.
 * 
 * POR QUÉ:
 * Cumple con el principio de Gobernanza y Supervisión Humana, permitiendo al usuario
 * elegir exactamente cómo y cuándo debe intervenir la IA local en WhatsApp.
 */

import { whatsAppStorage } from '../services/whatsapp_storage.js';
import { whatsAppSessionManager } from '../services/whatsapp_session_manager.js';
import { whatsAppDispatcher } from '../services/whatsapp_dispatcher.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { SessionStatus, ToneProfile } from '../domain/whatsapp_types.js';

export class WhatsAppPolicyBar {
  /**
   * @param {HTMLElement} container - Contenedor padre superior de la conversación.
   */
  constructor(container) {
    this.container = container;
    this.activeThreadId = null;
    this._unsubscribers = [];

    this._bindEvents();
    this.render();
  }

  _bindEvents() {
    const unsubSession = whatsAppBus.subscribe(WhatsAppEvents.SESSION_CHANGED, () => this.render());
    this._unsubscribers.push(unsessionHandler => unsubSession());
  }

  /**
   * Asigna el hilo de conversación activo y refresca la barra.
   * @param {string | null} threadId
   */
  setActiveThread(threadId) {
    this.activeThreadId = threadId;
    this.render();
  }

  render() {
    if (!this.activeThreadId) {
      this.container.innerHTML = `
        <div class="wa-policy-bar">
          <div class="wa-policy-left">
            <span style="font-weight: 600; color: var(--text-tertiary);">Ningún chat activo</span>
          </div>
          <div class="wa-policy-right">
            ${this._renderSessionPill()}
          </div>
        </div>
      `;
      return;
    }

    const convs = whatsAppStorage.getConversations();
    const thread = convs.find((c) => c.id === this.activeThreadId);
    const contact = thread?.contact;
    const policy = whatsAppStorage.getPolicy();

    this.container.innerHTML = `
      <div class="wa-policy-bar">
        <div class="wa-policy-left">
          <div style="font-weight: 700; color: var(--text-primary); display: flex; align-items: center; gap: 6px;">
            <span>${contact?.name || 'Contacto'}</span>
            ${contact?.isBusiness ? '<span style="font-size: 10px; background: rgba(37,211,102,0.15); color: #25D366; padding: 1px 5px; border-radius: 4px; font-weight: 700;">EMPRESA</span>' : ''}
          </div>
          <span style="color: var(--text-tertiary); font-size: 11px;">${contact?.phone || ''}</span>
        </div>
        <div class="wa-policy-right">
          <button type="button" class="wa-pill-btn ${thread?.autoReply ? 'active' : ''}" id="wa-btn-toggle-auto">
            <span>Agente IA: ${thread?.autoReply ? 'ACTIVO' : 'MANUAL'}</span>
          </button>
          <select id="wa-select-tone" class="wa-pill-btn" style="outline: none; cursor: pointer;">
            <option value="${ToneProfile.PROFESSIONAL}" ${policy.tone === ToneProfile.PROFESSIONAL ? 'selected' : ''}>Tono: Profesional</option>
            <option value="${ToneProfile.FRIENDLY}" ${policy.tone === ToneProfile.FRIENDLY ? 'selected' : ''}>Tono: Amable</option>
            <option value="${ToneProfile.CONCISE}" ${policy.tone === ToneProfile.CONCISE ? 'selected' : ''}>Tono: Conciso</option>
            <option value="${ToneProfile.COMMERCIAL}" ${policy.tone === ToneProfile.COMMERCIAL ? 'selected' : ''}>Tono: Comercial</option>
          </select>
          <button type="button" class="wa-pill-btn" id="wa-btn-simulate-inbound" title="Simular mensaje entrante para pruebas">
            + Simular Mensaje
          </button>
          ${this._renderSessionPill()}
        </div>
      </div>
    `;

    this._bindControls(thread, policy);
  }

  _bindControls(thread, policy) {
    const btnToggle = this.container.querySelector('#wa-btn-toggle-auto');
    if (btnToggle && thread) {
      btnToggle.addEventListener('click', () => {
        thread.autoReply = !thread.autoReply;
        const convs = whatsAppStorage.getConversations();
        const idx = convs.findIndex((c) => c.id === thread.id);
        if (idx !== -1) convs[idx] = thread;
        whatsAppStorage.saveConversations(convs);
        this.render();
      });
    }

    const selectTone = this.container.querySelector('#wa-select-tone');
    if (selectTone) {
      selectTone.addEventListener('change', (e) => {
        policy.tone = e.target.value;
        whatsAppStorage.savePolicy(policy);
      });
    }

    const btnSimulate = this.container.querySelector('#wa-btn-simulate-inbound');
    if (btnSimulate && this.activeThreadId) {
      btnSimulate.addEventListener('click', () => {
        const samples = [
          '¿Cuál es el horario de atención para consultas técnicas?',
          '¿Tienen soporte para despliegue de modelos en equipos locales?',
          'Por favor confírmame el presupuesto estimado.',
          '¿Podrías enviarme la documentación del proyecto?',
        ];
        const randomText = samples[Math.floor(Math.random() * samples.length)];
        whatsAppDispatcher.receiveMessage({
          conversationId: this.activeThreadId,
          text: randomText,
        });
      });
    }
  }

  _renderSessionPill() {
    const isConnected = whatsAppSessionManager.status === SessionStatus.CONNECTED;
    return `
      <span class="wa-pill-btn ${isConnected ? 'active' : ''}" style="cursor: default;">
        <span style="width: 6px; height: 6px; border-radius: 50%; background: ${isConnected ? '#25D366' : '#EF4444'}; display: inline-block;"></span>
        <span>${isConnected ? 'Conectado' : 'Sin vincular'}</span>
      </span>
    `;
  }

  destroy() {
    this._unsubscribers.forEach((fn) => fn());
    this._unsubscribers = [];
  }
}
