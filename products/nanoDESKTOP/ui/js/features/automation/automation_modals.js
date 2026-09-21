/**
 * automation_modals.js — Modales del Módulo de Automatización
 *
 * QUÉ HACE: Gestiona los dos modales del módulo: "Crear Agente" e "Inspector".
 * CÓMO FUNCIONA: Usa NanoOverlay (singleton DOM en document.body) para garantizar
 *                que los modales no queden atrapados en stacking contexts locales.
 *                Esto elimina definitivamente el error visual "No Overlay".
 * POR QUÉ: El .auto-modal-overlay previo usaba position:fixed dentro de #view-automation
 *           que tiene overflow:hidden → el modal quedaba recortado (cajas rojas).
 *           NanoOverlay monta en document.body, fuera de cualquier stacking context.
 */

import { NanoIcon } from '../../components/nano_icon.js';
import { NanoOverlay } from '../../components/nano_overlay.js';
import { escapeHtml } from '../../core/utils.js';

// Mapa de disparadores conocidos → tipo e intervalo en segundos.
// Centralizado aquí para que createAgent() no use string-parsing frágil.
export const TRIGGER_MAP = {
  'Cada 1 minuto':   { type: 'interval', seconds: 60 },
  'Cada 5 minutos':  { type: 'interval', seconds: 300 },
  'Cada 15 minutos': { type: 'interval', seconds: 900 },
  'Al cambiar archivos en workspace': { type: 'event', seconds: null },
  'Al recibir notificación':          { type: 'event', seconds: null },
  'Manual bajo demanda':              { type: 'demand', seconds: null },
};

/**
 * Abre el modal de creación de nuevo agente soberano.
 * @param {Function} onSubmit — Callback con los datos del formulario al guardar
 */
export function openCreateAgentModal(onSubmit) {
  // HTML interno del modal — formulario de configuración del agente
  const content = `
    <form id="form-create-agent-overlay" class="modal-form" novalidate>
      <div class="form-group">
        <label for="ov-agent-name">Nombre del Agente</label>
        <input type="text" id="ov-agent-name" class="form-input"
               placeholder="Ej. Auditor de Base de Datos..." required autocomplete="off" />
      </div>
      <div class="form-group">
        <label for="ov-agent-role">Propósito y Prompt de Sistema</label>
        <textarea id="ov-agent-role" class="form-textarea" rows="3"
                  placeholder="Describe la misión soberana del agente..." required></textarea>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label for="ov-agent-model">Modelo de Inferencia</label>
          <select id="ov-agent-model" class="form-select">
            <option value="DeepSeek-R1 (Local)">DeepSeek-R1 (Razonamiento profundo)</option>
            <option value="Phi-3-mini (Local)">Phi-3-mini (Ultraligero CPU/GPU)</option>
            <option value="Llama-3.1-8B-Instruct">Llama-3.1-8B-Instruct (General)</option>
          </select>
        </div>
        <div class="form-group">
          <label for="ov-agent-trigger">Disparador (Trigger)</label>
          <select id="ov-agent-trigger" class="form-select">
            ${Object.keys(TRIGGER_MAP).map((k) =>
              `<option value="${k}">${k}</option>`
            ).join('')}
          </select>
        </div>
      </div>
      <div class="form-group">
        <label>Gobernanza y Autonomía</label>
        <div class="governance-options">
          <label class="radio-option">
            <input type="radio" name="ov-agent-gov" value="autonomous" checked />
            <div class="radio-content">
              <strong>Autónomo determinista</strong>
              <span>Ejecuta directamente en sandbox local sin interrupciones.</span>
            </div>
          </label>
          <label class="radio-option">
            <input type="radio" name="ov-agent-gov" value="approval" />
            <div class="radio-content">
              <strong>Aprobación humana requerida</strong>
              <span>Pausa y solicita confirmación antes de acciones sensibles.</span>
            </div>
          </label>
        </div>
      </div>
      <div class="form-group">
        <label>Herramientas Soberanas Permitidas (MCP)</label>
        <div class="tools-checkbox-grid">
          <label class="checkbox-pill"><input type="checkbox" id="ov-tool-web" checked /><span>🌐 Búsqueda Web</span></label>
          <label class="checkbox-pill"><input type="checkbox" id="ov-tool-fs" checked /><span>📁 Acceso a Archivos</span></label>
          <label class="checkbox-pill"><input type="checkbox" id="ov-tool-term" /><span>💻 Terminal Sandboxed</span></label>
          <label class="checkbox-pill"><input type="checkbox" id="ov-tool-hw" checked /><span>⚡ Telemetría Hardware</span></label>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn-cancel" id="ov-btn-cancel-agent">Cancelar</button>
        <button type="submit" class="btn-submit-agent">
          ${NanoIcon.get('check', 14)}
          <span>Guardar y Desplegar Agente</span>
        </button>
      </div>
    </form>
  `;

  // NanoOverlay monta en document.body → nunca queda atrapado en stacking contexts
  const instance = NanoOverlay.open({
    title: `${NanoIcon.get('automation', 18)} Crear Nuevo Agente Soberano`,
    content,
    closeOnBackdrop: true,
  });

  // Vincular cancelar al botón interno (además del X del overlay)
  const btnCancel = instance.element.querySelector('#ov-btn-cancel-agent');
  if (btnCancel) btnCancel.addEventListener('click', () => instance.close());

  // Capturar submit del formulario y pasar datos al callback
  const form = instance.element.querySelector('#form-create-agent-overlay');
  if (form) {
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const tools = [];
      if (form.querySelector('#ov-tool-web')?.checked)  tools.push('Web Search');
      if (form.querySelector('#ov-tool-fs')?.checked)   tools.push('Filesystem RAG');
      if (form.querySelector('#ov-tool-term')?.checked) tools.push('Terminal Sandbox');
      if (form.querySelector('#ov-tool-hw')?.checked)   tools.push('Hardware Watcher');

      onSubmit({
        name:       form.querySelector('#ov-agent-name')?.value.trim()  || '',
        role:       form.querySelector('#ov-agent-role')?.value.trim()  || '',
        model:      form.querySelector('#ov-agent-model')?.value        || '',
        trigger:    form.querySelector('#ov-agent-trigger')?.value      || '',
        governance: form.querySelector('input[name="ov-agent-gov"]:checked')?.value || 'autonomous',
        tools,
      });
      instance.close();
    });
  }
}

/**
 * Abre el modal inspector de detalles de una ejecución de agente.
 * @param {Object} log — Entrada de log a inspeccionar
 * @param {Function} onRerun — Callback para re-ejecutar el agente desde el inspector
 */
export function openInspectorModal(log, onRerun) {
  const statusColor = log.status === 'ok' ? 'color-active' : 'color-warning';

  const content = `
    <div class="inspector-body">
      <!-- Grid de metadatos clave de la ejecución -->
      <div class="inspector-meta-grid">
        <div><strong>Estado:</strong> <span class="${statusColor}">${escapeHtml(log.statusText)}</span></div>
        <div><strong>Duración:</strong> ${escapeHtml(log.duration || '—')}</div>
        <div><strong>Marca temporal:</strong> ${escapeHtml(log.time)}</div>
        <div><strong>Modelo asignado:</strong> ${escapeHtml(log.model || 'DeepSeek-R1 (Local)')}</div>
      </div>
      <!-- Acción disparada -->
      <div class="inspector-section">
        <label>Acción Disparada</label>
        <div class="inspector-box">${escapeHtml(log.action)}</div>
      </div>
      <!-- Salida / razonamiento del agente -->
      <div class="inspector-section">
        <label>Salida y Razonamiento Soberano del Agente</label>
        <pre class="inspector-code-box">${escapeHtml(log.output || 'Sin salida registrada.')}</pre>
      </div>
      <!-- Acciones del inspector -->
      <div class="modal-footer">
        <button type="button" class="btn-cancel" id="ov-btn-dismiss-insp">Cerrar</button>
        <button type="button" class="btn-submit-agent" id="ov-btn-rerun"
                data-agent-id="${log.agentId || ''}">
          ${NanoIcon.get('refresh', 14)}
          <span>Re-ejecutar Agente</span>
        </button>
      </div>
    </div>
  `;

  const instance = NanoOverlay.open({
    title: `${NanoIcon.get('terminal', 18)} Ejecución — ${escapeHtml(log.agentName)}`,
    content,
    extraClass: 'inspector-card',
    closeOnBackdrop: true,
  });

  // Cerrar con botón interno
  instance.element.querySelector('#ov-btn-dismiss-insp')
    ?.addEventListener('click', () => instance.close());

  // Re-ejecutar el agente desde el inspector y cerrar el modal
  const btnRerun = instance.element.querySelector('#ov-btn-rerun');
  if (btnRerun && log.agentId) {
    btnRerun.addEventListener('click', () => {
      instance.close();
      onRerun(log.agentId);
    });
  }
}
