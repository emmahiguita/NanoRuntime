/**
 * automation_modals.js — Modales "Crear Agente" e "Inspector" (< 200 LOC)
 *
 * QUÉ HACE: Modales con validación inline y soporte de searchQuery opcional.
 * CÓMO: NanoOverlay en document.body + escapeHtml defensivo.
 */

import { NanoIcon } from '../../components/nano_icon.js';
import { NanoOverlay } from '../../components/nano_overlay.js';
import { escapeHtml } from '../../core/utils.js';
import { loadAgentModelOptions } from './agent_model_options.js';

export const TRIGGER_MAP = {
  'Cada 1 minuto':   { type: 'interval', seconds: 60 },
  'Cada 5 minutos':  { type: 'interval', seconds: 300 },
  'Cada 15 minutos': { type: 'interval', seconds: 900 },
  'Al cambiar archivos en workspace': { type: 'event', seconds: null },
  'Al recibir notificación':          { type: 'event', seconds: null },
  'Manual bajo demanda':              { type: 'demand', seconds: null },
};

export function validateAgentInput({ name, role, searchQuery } = {}) {
  const errors = {};
  const trimmedName = (name || '').trim();
  const trimmedRole = (role || '').trim();
  const trimmedQuery = (searchQuery || '').trim();

  if (!trimmedName) errors.name = 'El nombre del agente es obligatorio.';
  else if (trimmedName.length > 80) errors.name = 'El nombre no puede exceder 80 caracteres.';

  if (!trimmedRole) errors.role = 'El propósito y prompt del agente es obligatorio.';
  else if (trimmedRole.length > 400) errors.role = 'El propósito no puede exceder 400 caracteres.';

  return {
    isValid: Object.keys(errors).length === 0,
    errors,
    data: { name: trimmedName, role: trimmedRole, searchQuery: trimmedQuery },
  };
}

export function openCreateAgentModal(onSubmit) {
  const content = `
    <form id="form-create-agent-overlay" class="modal-form" novalidate>
      <div class="form-group" id="group-agent-name">
        <label for="ov-agent-name">Nombre del Agente</label>
        <input type="text" id="ov-agent-name" class="form-input" placeholder="Ej. Auditor de Base de Datos..." required autocomplete="off" />
        <span class="field-error-msg" id="err-agent-name" style="display:none; color:#ef4444; font-size:11px; margin-top:4px;"></span>
      </div>
      <div class="form-group" id="group-agent-role">
        <label for="ov-agent-role">Propósito y Prompt de Sistema</label>
        <textarea id="ov-agent-role" class="form-textarea" rows="3" placeholder="Describe la misión soberana del agente..." required></textarea>
        <span class="field-error-msg" id="err-agent-role" style="display:none; color:#ef4444; font-size:11px; margin-top:4px;"></span>
      </div>
      <div class="form-group" id="group-agent-search">
        <label for="ov-agent-search-query">Término de Búsqueda Web (Opcional)</label>
        <input type="text" id="ov-agent-search-query" class="form-input" placeholder="Query personalizada para herramientas web..." autocomplete="off" />
      </div>
      <div class="form-row">
        <div class="form-group">
          <label for="ov-agent-model">Modelo de Inferencia</label>
          <select id="ov-agent-model" class="form-select">
            <option value="">Consultando modelos locales…</option>
          </select>
        </div>
        <div class="form-group">
          <label for="ov-agent-trigger">Disparador (Trigger)</label>
          <select id="ov-agent-trigger" class="form-select">
            ${Object.keys(TRIGGER_MAP).map((k) => `<option value="${k}" ${TRIGGER_MAP[k].type === 'event' ? 'disabled' : ''}>${k}${TRIGGER_MAP[k].type === 'event' ? ' — no conectado' : ''}</option>`).join('')}
          </select>
        </div>
      </div>
      <div class="form-group">
        <label>Gobernanza y Autonomía</label>
        <div class="governance-options">
          <label class="radio-option">
            <input type="radio" name="ov-agent-gov" value="autonomous" checked />
            <div class="radio-content"><strong>Autónomo con guardas</strong><span>Las acciones sensibles requieren aprobación.</span></div>
          </label>
          <label class="radio-option">
            <input type="radio" name="ov-agent-gov" value="approval" />
            <div class="radio-content"><strong>Aprobación requerida</strong><span>Solicita confirmación antes de actuar.</span></div>
          </label>
        </div>
      </div>
      <div class="form-group">
        <label>Herramientas Soberanas Permitidas (MCP)</label>
        <div class="tools-checkbox-grid">
          <label class="checkbox-pill"><input type="checkbox" id="ov-tool-web" checked /><span>🌐 Búsqueda Web</span></label>
          <label class="checkbox-pill"><input type="checkbox" id="ov-tool-fs" disabled /><span>Archivos — no conectado</span></label>
          <label class="checkbox-pill"><input type="checkbox" id="ov-tool-term" disabled /><span>Terminal — no conectado</span></label>
          <label class="checkbox-pill"><input type="checkbox" id="ov-tool-hw" checked /><span>⚡ Hardware</span></label>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn-cancel" id="ov-btn-cancel-agent">Cancelar</button>
        <button type="submit" class="btn-submit-agent">${NanoIcon.get('check', 14)} <span>Guardar y Desplegar</span></button>
      </div>
    </form>
  `;

  const instance = NanoOverlay.open({ title: `${NanoIcon.get('automation', 18)} Crear Nuevo Agente Soberano`, content, closeOnBackdrop: true });
  loadAgentModelOptions(instance.element.querySelector('#ov-agent-model'));
  instance.element.querySelector('#ov-btn-cancel-agent')?.addEventListener('click', () => instance.close());

  const form = instance.element.querySelector('#form-create-agent-overlay');
  if (form) {
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const nameInput = form.querySelector('#ov-agent-name');
      const roleInput = form.querySelector('#ov-agent-role');
      const queryInput = form.querySelector('#ov-agent-search-query');

      form.querySelectorAll('.field-error').forEach((el) => el.classList.remove('field-error'));
      form.querySelectorAll('.field-error-msg').forEach((el) => { el.textContent = ''; el.style.display = 'none'; });
      if (nameInput) nameInput.style.borderColor = '';
      if (roleInput) roleInput.style.borderColor = '';

      const v = validateAgentInput({ name: nameInput?.value, role: roleInput?.value, searchQuery: queryInput?.value });
      if (!v.isValid) {
        if (v.errors.name) {
          nameInput?.classList.add('field-error');
          if (nameInput) nameInput.style.borderColor = '#ef4444';
          const errEl = form.querySelector('#err-agent-name');
          if (errEl) { errEl.textContent = v.errors.name; errEl.style.display = 'block'; }
          nameInput?.focus();
        }
        if (v.errors.role) {
          roleInput?.classList.add('field-error');
          if (roleInput) roleInput.style.borderColor = '#ef4444';
          const errEl = form.querySelector('#err-agent-role');
          if (errEl) { errEl.textContent = v.errors.role; errEl.style.display = 'block'; }
          if (!v.errors.name) roleInput?.focus();
        }
        return;
      }

      const tools = [];
      if (form.querySelector('#ov-tool-web')?.checked)  tools.push('Web Search');
      if (form.querySelector('#ov-tool-fs')?.checked)   tools.push('Filesystem RAG');
      if (form.querySelector('#ov-tool-term')?.checked) tools.push('Terminal Sandbox');
      if (form.querySelector('#ov-tool-hw')?.checked)   tools.push('Hardware Watcher');

      try { onSubmit({
        name: v.data.name, role: v.data.role, searchQuery: v.data.searchQuery,
        model: form.querySelector('#ov-agent-model')?.value || '',
        trigger: form.querySelector('#ov-agent-trigger')?.value || '',
        governance: form.querySelector('input[name="ov-agent-gov"]:checked')?.value || 'autonomous',
        tools,
      }); } catch (error) {
        const notice = form.querySelector('#err-agent-name');
        notice.textContent = error.message;
        notice.style.display = 'block';
        notice.setAttribute('role', 'alert');
        return;
      }
      instance.close();
    });
  }
}

export function openInspectorModal(log, onRerun) {
  const statusColor = log.status === 'ok' ? 'color-active' : (log.status === 'partial_success' ? 'color-warning' : 'color-error');
  const content = `
    <div class="inspector-body">
      <div class="inspector-meta-grid">
        <div><strong>Estado:</strong> <span class="${statusColor}">${escapeHtml(log.statusText)}</span></div>
        <div><strong>Duración:</strong> ${escapeHtml(log.duration || '—')}</div>
        <div><strong>Marca temporal:</strong> ${escapeHtml(log.time)}</div>
        <div><strong>Modelo configurado:</strong> ${escapeHtml(log.model || 'No seleccionado')}</div>
      </div>
      <div class="inspector-section"><label>Acción</label><div class="inspector-box">${escapeHtml(log.action)}</div></div>
      <div class="inspector-section"><label>Salida / Razonamiento</label><pre class="inspector-code-box">${escapeHtml(log.output || 'Sin salida.')}</pre></div>
      <div class="modal-footer">
        <button type="button" class="btn-cancel" id="ov-btn-dismiss-insp">Cerrar</button>
        <button type="button" class="btn-submit-agent" id="ov-btn-rerun" data-agent-id="${log.agentId || ''}">
          ${NanoIcon.get('refresh', 14)} <span>Re-ejecutar</span>
        </button>
      </div>
    </div>
  `;
  const instance = NanoOverlay.open({
    title: `${NanoIcon.get('terminal', 18)} Ejecución — ${escapeHtml(log.agentName)}`,
    content, extraClass: 'inspector-card', closeOnBackdrop: true,
  });
  instance.element.querySelector('#ov-btn-dismiss-insp')?.addEventListener('click', () => instance.close());
  const btnRerun = instance.element.querySelector('#ov-btn-rerun');
  if (btnRerun && log.agentId) {
    btnRerun.addEventListener('click', () => { instance.close(); onRerun(log.agentId); });
  }
}
