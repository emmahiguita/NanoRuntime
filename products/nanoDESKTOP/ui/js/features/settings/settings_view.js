import { transport } from '../../core/transport.js';
import { appState } from '../../core/state.js';
import { escapeHtml } from '../../core/utils.js';
import { readPreferences, savePreferences } from '../../core/preferences.js';
import { NanoIcon } from '../../components/nano_icon.js';

/** Controls persist only settings actually consumed by the chat. */
export class SettingsView {
  constructor(container) {
    this.container = container;
    this.render();
    this.updateModels(appState.getState());
    this.unsubscribe = appState.subscribe(state => {
      if (state.models !== this.lastModels || state.currentModel !== this.lastModel) this.updateModels(state);
    });
    this.loadModels();
  }
  render() {
    const prefs = readPreferences();
    const theme = document.documentElement.dataset.theme || 'light';
    this.container.innerHTML = `<div class="nano-settings-view">
      <div class="settings-header-row"><div><h2>Configuración</h2><p>Modelos locales, apariencia y Nano Mobile</p></div></div>
      <div class="settings-sections-grid">
        <section class="settings-card"><h3>${NanoIcon.get('sun',17)} Apariencia</h3>
          <label for="setting-theme-select">Tema</label><select id="setting-theme-select" class="settings-select">
            <option value="light" ${theme === 'light' ? 'selected' : ''}>Claro</option>
            <option value="dark" ${theme === 'dark' ? 'selected' : ''}>Oscuro</option></select></section>
        <section class="settings-card"><h3>${NanoIcon.get('cpu',17)} Inferencia local</h3>
          <label for="setting-default-model">Modelo seleccionado</label>
          <select id="setting-default-model" class="settings-select"><option>Cargando catálogo…</option></select>
          <button id="settings-refresh" class="settings-btn-save">Actualizar catálogo</button>
          <label for="setting-max-tokens">Máximo de tokens por respuesta del chat</label>
          <select id="setting-max-tokens" class="settings-select">${[512,1024,2048,4096].map(n => `<option value="${n}" ${prefs.maxTokens === n ? 'selected' : ''}>${n}</option>`).join('')}</select>
          <p class="settings-sublabel">Los modelos grandes requieren RAM suficiente. La carga real confirma su compatibilidad.</p>
          <button id="btn-save-settings" class="settings-btn-save">Guardar preferencias</button></section>
        <section class="settings-card"><h3>${NanoIcon.get('network',17)} Nano Mobile</h3>
          <p>El servidor auxiliar permite usar los modelos GGUF del PC desde Mobile.</p>
          <p class="settings-sublabel">Por defecto escucha solo en este PC. Compartir por LAN requiere activación explícita y clave de acceso. En Mobile configura la dirección del PC, puerto 3001 y la misma clave.</p>
          <p class="settings-sublabel">Entrega respuestas completas, también mediante SSE. No confirma cancelación por solicitud. Los proveedores de nube aún no están integrados aquí.</p>
          <p id="settings-bridge" role="status">Comprobando servidor…</p>
          <button id="settings-check" class="settings-btn-save">Comprobar servidor auxiliar</button></section>
        <section class="settings-card"><h3>${NanoIcon.get('shield',17)} Privacidad y servicios</h3>
          <p>La inferencia GGUF se ejecuta en el PC. La búsqueda Web consulta fuentes externas cuando la activas.</p>
          <p class="settings-sublabel">El historial se guarda en este perfil, sin cifrado propio. RAM corresponde al equipo; GPU y VRAM no tienen medición disponible.</p>
          <p class="settings-sublabel">Comprueba WhatsApp desde su módulo. Esta pantalla no confirma vinculación ni entrega.</p></section>
      </div><p id="settings-feedback" role="status" aria-live="polite"></p></div>`;
    const find = id => this.container.querySelector('#' + id);
    this.report = text => { if (!this.destroyed) find('settings-feedback').textContent = text; };
    find('setting-theme-select').addEventListener('change', event => {
      try { localStorage.setItem('nano_theme', event.target.value); document.documentElement.dataset.theme = event.target.value; this.report('Tema guardado.'); }
      catch { this.report('No se pudo guardar el tema.'); }
    });
    find('btn-save-settings').addEventListener('click', () => {
      try { savePreferences({ maxTokens: Number(find('setting-max-tokens').value) }); this.report('Preferencias guardadas para el siguiente mensaje del chat.'); }
      catch (error) { this.report('No se pudo guardar: ' + error.message); }
    });
    find('setting-default-model').addEventListener('change', async event => {
      const select = event.target; select.disabled = true;
      try {
        const model = await transport.activateModel(select.value);
        appState.setState({ currentModel: model.path });
        this.report(transport.isTauri ? 'Modelo seleccionado; se cargará al responder.' : 'Modelo confirmado por el servidor.');
      } catch (error) { select.value = appState.getState().currentModel; this.report(error.message); }
      finally { select.disabled = false; }
    });
    find('settings-refresh').addEventListener('click', () => this.loadModels());
    find('settings-check').addEventListener('click', () => this.checkBridge());
    this.checkBridge();
  }
  async loadModels() {
    try { const models = await transport.listModels(); if (!this.destroyed) appState.setState({ models }); }
    catch (error) { this.report(error.message); }
  }
  updateModels(state) {
    this.lastModels = state.models; this.lastModel = state.currentModel;
    const select = this.container.querySelector('#setting-default-model');
    select.innerHTML = '<option value="">Selecciona un GGUF instalado</option>' + (state.models || []).map(m => `<option value="${escapeHtml(m.path)}">${escapeHtml(m.name)}</option>`).join('');
    select.value = state.currentModel;
  }
  async checkBridge() {
    const node = this.container.querySelector('#settings-bridge');
    try {
      const base = transport.isTauri ? 'http://127.0.0.1:3001' : transport.webBaseUrl;
      const response = await fetch(base + '/health', { signal: AbortSignal.timeout(5000) });
      const data = await response.json();
      if (!response.ok || data.service !== 'nano-runtime-bridge') throw new Error();
      if (!this.destroyed) node.textContent = 'Servidor accesible en este PC. Falta comprobar la conexión desde el teléfono en LAN.';
    } catch { if (!this.destroyed) node.textContent = 'Servidor auxiliar no disponible. La inferencia nativa funciona por separado.'; }
  }
  onShow() { this.container.querySelector('#setting-theme-select').value = document.documentElement.dataset.theme || 'light'; }
  destroy() { this.destroyed = true; this.unsubscribe?.(); this.container.innerHTML = ''; }
}
