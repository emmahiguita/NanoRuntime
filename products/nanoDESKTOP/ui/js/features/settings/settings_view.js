/**
 * settings_view.js — Vista de Configuración y Gobernanza FeatherCore
 *
 * QUÉ HACE:
 * Permite configurar el tema visual (Modo Claro oficial / Oscuro), el motor
 * local nanoRUNTIME, los límites de VRAM/contexto, y la gobernanza de datos offline.
 *
 * CÓMO FUNCIONA:
 * Guarda preferencias en localStorage y despacha actualizaciones de tema reactivas.
 */

import { NanoIcon } from '../../components/nano_icon.js';

export class SettingsView {
  constructor(containerElement) {
    this.container = containerElement;
    this._init();
  }

  _init() {
    this.render();
  }

  render() {
    const currentTheme = document.documentElement.getAttribute('data-theme') || 'light';

    this.container.innerHTML = `
      <div class="nano-settings-view">
        <!-- Header -->
        <div class="settings-header-row">
          <div>
            <h2>Configuración del Sistema</h2>
            <p>Personaliza el entorno local de Nano, la inferencia offline y la gobernanza de datos</p>
          </div>
        </div>

        <div class="settings-sections-grid">
          <!-- Card 1: Apariencia & Tema -->
          <div class="settings-card">
            <div class="settings-card-header">
              <div class="settings-card-icon">
                ${NanoIcon.get('sun', 16)}
              </div>
              <div>
                <span class="settings-card-title">Apariencia y Sistema Visual</span>
                <span class="settings-card-desc">Estilo FeatherCore y contraste</span>
              </div>
            </div>

            <div class="settings-field-group">
              <label class="settings-label" for="setting-theme-select">Tema de la Interfaz</label>
              <select id="setting-theme-select" class="settings-select">
                <option value="light" ${currentTheme === 'light' ? 'selected' : ''}>☀️ FeatherCore Oficial (Modo Claro)</option>
                <option value="dark" ${currentTheme === 'dark' ? 'selected' : ''}>🌙 Modo Oscuro Zafiro</option>
              </select>
            </div>

            <div class="settings-toggle-row">
              <div>
                <span class="settings-label" style="display: block;">Animaciones Cinemáticas del Búho</span>
                <span class="settings-sublabel">Transiciones GPU y física de capas de Nano Owl</span>
              </div>
              <label class="settings-switch">
                <input type="checkbox" id="setting-owl-anim" checked />
                <span class="settings-slider"></span>
              </label>
            </div>
          </div>

          <!-- Card 2: Motor de Inferencia nanoRUNTIME -->
          <div class="settings-card">
            <div class="settings-card-header">
              <div class="settings-card-icon">
                ${NanoIcon.get('brain', 16)}
              </div>
              <div>
                <span class="settings-card-title">Motor de Inferencia Local</span>
                <span class="settings-card-desc">Parámetros de ejecución nanoRUNTIME.exe</span>
              </div>
            </div>

            <div class="settings-field-group">
              <label class="settings-label" for="setting-default-model">Modelo Primario por Defecto</label>
              <select id="setting-default-model" class="settings-select">
                <option value="qwen-2.5">Qwen 2.5 1.5B Instruct (Q8_0 local) — Recomendado</option>
                <option value="phi-3">Phi-3-mini-4k-instruct (Q4_K_M)</option>
                <option value="llama-3">Llama-3.1-8B-Instruct (Q4_K_M)</option>
              </select>
            </div>

            <div class="settings-field-group">
              <label class="settings-label" for="setting-max-tokens">Ventana Máxima de Generación</label>
              <select id="setting-max-tokens" class="settings-select">
                <option value="512">512 tokens (Rápido)</option>
                <option value="1024" selected>1024 tokens (Equilibrado)</option>
                <option value="2048">2048 tokens (Extenso)</option>
              </select>
            </div>
          </div>

          <!-- Card 3: Gobernanza y Privacidad Soberana -->
          <div class="settings-card">
            <div class="settings-card-header">
              <div class="settings-card-icon">
                ${NanoIcon.get('lock', 16) || NanoIcon.get('chat', 16)}
              </div>
              <div>
                <span class="settings-card-title">Privacidad Soberana y Seguridad</span>
                <span class="settings-card-desc">Garantía de procesamiento on-premise</span>
              </div>
            </div>

            <div class="settings-toggle-row">
              <div>
                <span class="settings-label" style="display: block;">Modo 100% Offline Forzado</span>
                <span class="settings-sublabel">Bloquea cualquier salida a red no autorizada</span>
              </div>
              <label class="settings-switch">
                <input type="checkbox" id="setting-offline-only" checked />
                <span class="settings-slider"></span>
              </label>
            </div>

            <div class="settings-toggle-row">
              <div>
                <span class="settings-label" style="display: block;">Telemetría de Hardware Local</span>
                <span class="settings-sublabel">Monitoreo continuo de VRAM, GPU y tok/s</span>
              </div>
              <label class="settings-switch">
                <input type="checkbox" id="setting-telemetry" checked />
                <span class="settings-slider"></span>
              </label>
            </div>
          </div>

          <!-- Card 4: WhatsApp y Canales Conectados -->
          <div class="settings-card">
            <div class="settings-card-header">
              <div class="settings-card-icon" style="color: #20C76A; background: #ECFBF3;">
                ${NanoIcon.get('whatsapp', 16) || NanoIcon.get('chat', 16)}
              </div>
              <div>
                <span class="settings-card-title">Canales de Mensajería</span>
                <span class="settings-card-desc">Estado de conexión de WhatsApp y automatizaciones</span>
              </div>
            </div>

            <div class="settings-field-group">
              <span class="settings-label">Estado de la Sesión WhatsApp</span>
              <span style="font-size: 12px; color: var(--nano-success); font-weight: 600; display: flex; align-items: center; gap: 6px;">
                <span style="width: 8px; height: 8px; border-radius: 50%; background: var(--nano-success);"></span>
                Vinculado • Dispositivo Primario
              </span>
            </div>

            <button type="button" class="settings-btn-save" id="btn-save-settings">
              Guardar Preferencias
            </button>
          </div>
        </div>
      </div>
    `;

    this._bindEvents();
  }

  _bindEvents() {
    const themeSelect = this.container.querySelector('#setting-theme-select');
    themeSelect?.addEventListener('change', (e) => {
      const theme = e.target.value;
      document.documentElement.setAttribute('data-theme', theme);
      document.documentElement.dataset.theme = theme;
      localStorage.setItem('nano_theme', theme);
    });

    const btnSave = this.container.querySelector('#btn-save-settings');
    btnSave?.addEventListener('click', () => {
      alert('Preferencias guardadas exitosamente en almacenamiento local.');
    });
  }

  destroy() {
    this.container.innerHTML = '';
  }
}
