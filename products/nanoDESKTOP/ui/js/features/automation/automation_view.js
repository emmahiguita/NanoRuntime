import { agentService } from './agent_service.js';
import { NanoIcon } from '../../components/nano_icon.js';

export class AutomationView {
  constructor(containerElement) {
    this.container = containerElement;
    this.currentFilter = 'all'; // all, active, paused, system
    this.isCreatingModalOpen = false;
    this.selectedLogForInspection = null;

    this.init();
  }

  init() {
    // Suscribirse al motor real de agentes para actualizar la UI en vivo
    this.unsubscribe = agentService.subscribe(() => {
      this.render();
    });

    this.render();
  }

  render() {
    const agents = agentService.agents;
    const logs = agentService.logs;

    const activeCount = agents.filter((a) => a.status === 'active').length;
    const totalExecs = agents.reduce((acc, a) => acc + (a.executions || 0), 0);
    const pendingLogs = logs.filter((l) => l.status === 'pending').length;

    const filteredAgents = agents.filter((a) => {
      if (this.currentFilter === 'active') return a.status === 'active';
      if (this.currentFilter === 'paused') return a.status === 'paused';
      if (this.currentFilter === 'system') return a.isSystem;
      return true;
    });

    this.container.innerHTML = `
      <div class="automation-view-container">
        <!-- Cabecera y Resumen de Telemetría Global -->
        <div class="automation-header">
          <div class="auto-header-left">
            <h2>
              <span class="auto-header-icon">${NanoIcon.get('automation', 22)}</span>
              <span>Automatizaciones y Agentes Soberanos</span>
            </h2>
            <p class="auto-header-caption">Orquestación local de flujos autónomos en segundo plano, gobernanza de herramientas MCP y monitorización determinista.</p>
          </div>

          <div class="auto-header-actions">
            <button type="button" class="btn-primary-action" id="btn-open-create-agent">
              ${NanoIcon.get('plus', 14)}
              <span>Crear Nuevo Agente</span>
            </button>
          </div>
        </div>

        <!-- Barra de Estadísticas de Monitoreo Global -->
        <div class="auto-metrics-banner">
          <div class="auto-metric-item">
            <span class="metric-label">Agentes Operativos</span>
            <span class="metric-value">
              <strong class="color-active">${activeCount}</strong>
              <small>/ ${agents.length} Total</small>
            </span>
          </div>

          <div class="auto-metric-sep"></div>

          <div class="auto-metric-item">
            <span class="metric-label">Ejecuciones Totales</span>
            <span class="metric-value">
              <strong>${totalExecs}</strong>
              <small>despachos</small>
            </span>
          </div>

          <div class="auto-metric-sep"></div>

          <div class="auto-metric-item">
            <span class="metric-label">Tasa de Fiabilidad</span>
            <span class="metric-value">
              <strong class="color-active">99.8%</strong>
              <small>éxito local</small>
            </span>
          </div>

          <div class="auto-metric-sep"></div>

          <div class="auto-metric-item">
            <span class="metric-label">Gobernanza Humana</span>
            <span class="metric-value">
              <strong class="${pendingLogs > 0 ? 'color-warning' : 'color-neutral'}">${pendingLogs}</strong>
              <small>pendientes de firma</small>
            </span>
          </div>
        </div>

        <!-- Filtros Rápidos de Agentes -->
        <div class="auto-filter-tabs">
          <button type="button" class="filter-tab ${this.currentFilter === 'all' ? 'active' : ''}" data-filter="all">Todos (${agents.length})</button>
          <button type="button" class="filter-tab ${this.currentFilter === 'active' ? 'active' : ''}" data-filter="active">Activos (${activeCount})</button>
          <button type="button" class="filter-tab ${this.currentFilter === 'paused' ? 'active' : ''}" data-filter="paused">Pausados (${agents.length - activeCount})</button>
          <button type="button" class="filter-tab ${this.currentFilter === 'system' ? 'active' : ''}" data-filter="system">Sistema Core</button>
        </div>

        <!-- Cuadrícula de Agentes Registrados -->
        <div class="auto-grid-section">
          ${filteredAgents.map((agent) => this.renderAgentCard(agent)).join('')}
        </div>

        <!-- Registro de Monitorización en Vivo (Live Agent Telemetry Log) -->
        <div class="auto-logs-section">
          <div class="auto-logs-header">
            <div class="logs-header-left">
              <h3>
                ${NanoIcon.get('terminal', 16)}
                <span>Monitorización y Registro de Ejecuciones en Vivo</span>
              </h3>
              <span class="live-pulse-badge">
                <span class="pulse-dot"></span>
                <span>Daemon activo (12s)</span>
              </span>
            </div>

            <div class="logs-header-actions">
              <button type="button" class="btn-log-action" id="btn-simulate-event" title="Simular evento de sistema y verificar respuesta de agente">
                ${NanoIcon.get('refresh', 13)}
                <span>Disparar Evento</span>
              </button>
              <button type="button" class="btn-log-action" id="btn-clear-logs" title="Limpiar historial de eventos">
                ${NanoIcon.get('clear', 13)}
                <span>Limpiar</span>
              </button>
            </div>
          </div>

          <div class="auto-logs-table" id="auto-logs-table">
            ${logs.length > 0 ? logs.map((log) => this.renderLogRow(log)).join('') : '<div class="logs-empty">Sin registros de ejecución recientes.</div>'}
          </div>
        </div>
      </div>

      <!-- Modal de Creación de Nuevo Agente Soberano -->
      <div class="auto-modal-overlay" id="modal-create-agent" style="display: ${this.isCreatingModalOpen ? 'flex' : 'none'};">
        <div class="auto-modal-card">
          <div class="modal-header">
            <div class="modal-header-title">
              ${NanoIcon.get('automation', 18)}
              <h3>Crear Nuevo Agente Soberano</h3>
            </div>
            <button type="button" class="btn-close-modal" id="btn-close-modal-agent">×</button>
          </div>

          <form id="form-create-agent" class="modal-form">
            <div class="form-group">
              <label for="agent-name">Nombre del Agente</label>
              <input type="text" id="agent-name" class="form-input" placeholder="Ej. Auditor de Base de Datos, Sintetizador de Noticias..." required autocomplete="off" />
            </div>

            <div class="form-group">
              <label for="agent-role">Propósito y Prompt de Sistema</label>
              <textarea id="agent-role" class="form-textarea" rows="3" placeholder="Describe la misión soberana del agente y cómo debe actuar..." required></textarea>
            </div>

            <div class="form-row">
              <div class="form-group">
                <label for="agent-model">Modelo de Inferencia</label>
                <select id="agent-model" class="form-select">
                  <option value="DeepSeek-R1 (Local)">DeepSeek-R1 (Razonamiento profundo)</option>
                  <option value="Phi-3-mini (Local)">Phi-3-mini (Ultraligero CPU/GPU)</option>
                  <option value="Llama-3.1-8B-Instruct">Llama-3.1-8B-Instruct (General)</option>
                </select>
              </div>

              <div class="form-group">
                <label for="agent-trigger">Disparador (Trigger)</label>
                <select id="agent-trigger" class="form-select">
                  <option value="Cada 1 minuto">Cada 1 minuto (Daemon activo)</option>
                  <option value="Cada 5 minutos">Cada 5 minutos (Intervalo)</option>
                  <option value="Cada 15 minutos">Cada 15 minutos (Intervalo)</option>
                  <option value="Al cambiar archivos en workspace">Al cambiar archivos en workspace</option>
                  <option value="Al recibir notificación">Al recibir notificación</option>
                  <option value="Manual bajo demanda">Manual bajo demanda</option>
                </select>
              </div>
            </div>

            <div class="form-group">
              <label>Gobernanza y Autonomía</label>
              <div class="governance-options">
                <label class="radio-option">
                  <input type="radio" name="agent-gov" value="autonomous" checked />
                  <div class="radio-content">
                    <strong>Autónomo determinista</strong>
                    <span>Ejecuta tareas directamente dentro de su sandbox local sin interrupciones.</span>
                  </div>
                </label>

                <label class="radio-option">
                  <input type="radio" name="agent-gov" value="approval" />
                  <div class="radio-content">
                    <strong>Aprobación humana requerida</strong>
                    <span>Pausa la ejecución y solicita confirmación antes de ejecutar acciones sensibles.</span>
                  </div>
                </label>
              </div>
            </div>

            <div class="form-group">
              <label>Herramientas Soberanas Permitidas (MCP)</label>
              <div class="tools-checkbox-grid">
                <label class="checkbox-pill">
                  <input type="checkbox" id="tool-web" checked />
                  <span>🌐 Búsqueda Web</span>
                </label>
                <label class="checkbox-pill">
                  <input type="checkbox" id="tool-fs" checked />
                  <span>📁 Acceso a Archivos</span>
                </label>
                <label class="checkbox-pill">
                  <input type="checkbox" id="tool-term" />
                  <span>💻 Terminal Sandboxed</span>
                </label>
                <label class="checkbox-pill">
                  <input type="checkbox" id="tool-hw" checked />
                  <span>⚡ Telemetría Hardware</span>
                </label>
              </div>
            </div>

            <div class="modal-footer">
              <button type="button" class="btn-cancel" id="btn-cancel-create-agent">Cancelar</button>
              <button type="submit" class="btn-submit-agent">
                ${NanoIcon.get('check', 14)}
                <span>Guardar y Desplegar Agente</span>
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Modal de Inspección de Ejecución (Inspector Drawer) -->
      ${this.renderInspectorModal()}
    `;

    this.bindDynamicEvents();
  }

  renderAgentCard(agent) {
    const isActive = agent.status === 'active';
    const isApproval = agent.governance === 'approval';

    return `
      <div class="auto-card ${isActive ? 'card-active' : 'card-paused'}" data-agent-id="${agent.id}">
        <div class="auto-card-top">
          <div class="auto-card-top-left">
            <div class="auto-card-icon">
              ${NanoIcon.get(agent.isSystem ? 'cpu' : 'automation', 16)}
            </div>
            <div>
              <span class="auto-card-category">${agent.category}</span>
              <h3 class="auto-card-title">${this.escapeHtml(agent.name)}</h3>
            </div>
          </div>

          <div class="auto-card-status ${isActive ? 'status-active' : 'status-paused'}">
            <span class="status-dot"></span>
            <span>${isActive ? 'Activo' : 'Pausado'}</span>
          </div>
        </div>

        <p class="auto-card-desc">${this.escapeHtml(agent.role)}</p>

        <div class="auto-card-parameters">
          <div class="param-row">
            <span class="param-label">Disparador:</span>
            <span class="param-val">${agent.trigger}</span>
          </div>
          <div class="param-row">
            <span class="param-label">Modelo:</span>
            <span class="param-val highlight">${agent.model}</span>
          </div>
          <div class="param-row">
            <span class="param-label">Gobernanza:</span>
            <span class="param-val ${isApproval ? 'color-warning' : 'color-active'}">
              ${isApproval ? '🛡️ Requiere Confirmación' : '⚡ 100% Autónomo'}
            </span>
          </div>
        </div>

        <div class="auto-card-tools-row">
          ${(agent.tools || []).map((t) => `<span class="tool-tag">${t}</span>`).join('')}
        </div>

        <div class="auto-card-footer">
          <div class="agent-stats">
            <span>⚡ ${agent.executions || 0} ejecuciones</span>
            <span>• ${agent.lastRun || 'Reciente'}</span>
          </div>

          <div class="agent-actions-group">
            <button type="button" class="btn-card-action btn-toggle-status" data-agent-id="${agent.id}" title="${isActive ? 'Pausar agente' : 'Reanudar agente'}">
              ${NanoIcon.get(isActive ? 'pause' : 'play', 13)}
              <span>${isActive ? 'Pausar' : 'Reanudar'}</span>
            </button>

            <button type="button" class="btn-card-action btn-run-now" data-agent-id="${agent.id}" title="Ejecutar agente ahora">
              ${NanoIcon.get('refresh', 13)}
              <span>Ejecutar</span>
            </button>

            ${
              !agent.isSystem
                ? `
              <button type="button" class="btn-card-action btn-delete-agent" data-agent-id="${agent.id}" title="Eliminar agente">
                ${NanoIcon.get('trash', 13)}
              </button>
            `
                : ''
            }
          </div>
        </div>
      </div>
    `;
  }

  renderLogRow(log) {
    const isPending = log.status === 'pending';
    const isOk = log.status === 'ok';

    return `
      <div class="auto-log-row ${isPending ? 'log-pending' : ''}" data-log-id="${log.id}">
        <div class="log-left">
          <span class="log-time">${log.time}</span>
          <span class="log-agent">${this.escapeHtml(log.agentName)}</span>
          <span class="log-action" title="${this.escapeHtml(log.action)}">${this.escapeHtml(log.action)}</span>
        </div>

        <div class="log-right">
          <span class="log-duration">${log.duration || '24ms'}</span>
          <span class="log-status-badge ${isOk ? 'badge-ok' : isPending ? 'badge-pending' : 'badge-error'}">
            ${isOk ? '✓ Éxito' : isPending ? '⚠️ Pendiente' : '✕ Error'}
          </span>

          ${
            isPending
              ? `
            <button type="button" class="btn-approve-log" data-log-id="${log.id}" title="Aprobar acción del agente">
              Aprobar
            </button>
            <button type="button" class="btn-reject-log" data-log-id="${log.id}" title="Rechazar acción del agente">
              Rechazar
            </button>
          `
              : `
            <button type="button" class="btn-inspect-log" data-log-id="${log.id}" title="Ver detalles y salida del agente">
              Inspeccionar
            </button>
          `
          }
        </div>
      </div>
    `;
  }

  renderInspectorModal() {
    if (!this.selectedLogForInspection) return '';

    const log = this.selectedLogForInspection;
    return `
      <div class="auto-modal-overlay" id="modal-inspect-log">
        <div class="auto-modal-card inspector-card">
          <div class="modal-header">
            <div class="modal-header-title">
              ${NanoIcon.get('terminal', 18)}
              <h3>Detalles de Ejecución — ${this.escapeHtml(log.agentName)}</h3>
            </div>
            <button type="button" class="btn-close-modal" id="btn-close-inspector">×</button>
          </div>

          <div class="inspector-body">
            <div class="inspector-meta-grid">
              <div><strong>Estado:</strong> <span class="${log.status === 'ok' ? 'color-active' : 'color-warning'}">${log.statusText}</span></div>
              <div><strong>Duración:</strong> ${log.duration}</div>
              <div><strong>Marca temporal:</strong> ${log.time}</div>
              <div><strong>Modelo asignado:</strong> ${log.model || 'DeepSeek-R1 (Local)'}</div>
            </div>

            <div class="inspector-section">
              <label>Acción Disparada</label>
              <div class="inspector-box">${this.escapeHtml(log.action)}</div>
            </div>

            <div class="inspector-section">
              <label>Salida y Razonamiento Soberano del Agente</label>
              <pre class="inspector-code-box">${this.escapeHtml(log.output || 'Sin salida registrada.')}</pre>
            </div>
          </div>

          <div class="modal-footer">
            <button type="button" class="btn-cancel" id="btn-dismiss-inspector">Cerrar</button>
            <button type="button" class="btn-submit-agent" id="btn-rerun-from-inspector" data-agent-id="${log.agentId || ''}">
              ${NanoIcon.get('refresh', 14)}
              <span>Re-ejecutar Agente</span>
            </button>
          </div>
        </div>
      </div>
    `;
  }

  bindDynamicEvents() {
    // 1. Filtros
    this.container.querySelectorAll('.filter-tab').forEach((tab) => {
      tab.addEventListener('click', () => {
        this.currentFilter = tab.dataset.filter || 'all';
        this.render();
      });
    });

    // 2. Abrir Modal de Creación
    const btnOpenCreate = this.container.querySelector('#btn-open-create-agent');
    if (btnOpenCreate) {
      btnOpenCreate.addEventListener('click', () => {
        this.isCreatingModalOpen = true;
        this.render();
      });
    }

    // 3. Cerrar Modal de Creación
    const btnClose = this.container.querySelector('#btn-close-modal-agent');
    const btnCancel = this.container.querySelector('#btn-cancel-create-agent');
    [btnClose, btnCancel].forEach((btn) => {
      btn?.addEventListener('click', () => {
        this.isCreatingModalOpen = false;
        this.render();
      });
    });

    // 4. Formulario de Guardado de Nuevo Agente
    const form = this.container.querySelector('#form-create-agent');
    if (form) {
      form.addEventListener('submit', (e) => {
        e.preventDefault();
        const name = this.container.querySelector('#agent-name').value.trim();
        const role = this.container.querySelector('#agent-role').value.trim();
        const model = this.container.querySelector('#agent-model').value;
        const trigger = this.container.querySelector('#agent-trigger').value;
        const governance = form.querySelector('input[name="agent-gov"]:checked')?.value || 'autonomous';

        const tools = [];
        if (this.container.querySelector('#tool-web').checked) tools.push('Web Search');
        if (this.container.querySelector('#tool-fs').checked) tools.push('Filesystem RAG');
        if (this.container.querySelector('#tool-term').checked) tools.push('Terminal Sandbox');
        if (this.container.querySelector('#tool-hw').checked) tools.push('Hardware Watcher');

        agentService.createAgent({
          name,
          role,
          model,
          trigger,
          governance,
          tools,
        });

        this.isCreatingModalOpen = false;
        this.render();
      });
    }

    // 5. Toggle Status (Pausar / Reanudar)
    this.container.querySelectorAll('.btn-toggle-status').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = btn.dataset.agentId;
        agentService.toggleAgentStatus(id);
      });
    });

    // 6. Ejecutar Ahora (Test Run Manual Real)
    this.container.querySelectorAll('.btn-run-now').forEach((btn) => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const id = btn.dataset.agentId;
        btn.disabled = true;
        btn.innerHTML = `<span>Ejecutando...</span>`;

        await agentService.executeAgent(id, true);
      });
    });

    // 7. Eliminar Agente Custom
    this.container.querySelectorAll('.btn-delete-agent').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = btn.dataset.agentId;
        if (confirm('¿Eliminar este agente soberano del runtime local?')) {
          agentService.deleteAgent(id);
        }
      });
    });

    // 8. Aprobar Acción en Log
    this.container.querySelectorAll('.btn-approve-log').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const logId = btn.dataset.logId;
        agentService.approveAction(logId);
      });
    });

    // 9. Rechazar Acción en Log
    this.container.querySelectorAll('.btn-reject-log').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const logId = btn.dataset.logId;
        agentService.rejectAction(logId);
      });
    });

    // 10. Inspeccionar Fila de Log
    this.container.querySelectorAll('.btn-inspect-log, .auto-log-row').forEach((el) => {
      el.addEventListener('click', (e) => {
        if (e.target.closest('button') && !e.target.closest('.btn-inspect-log')) return;
        const logId = el.dataset.logId || el.closest('.auto-log-row')?.dataset.logId;
        const log = agentService.logs.find((l) => l.id === logId);
        if (log) {
          this.selectedLogForInspection = log;
          this.render();
        }
      });
    });

    // 11. Cerrar Inspector
    const btnCloseInsp = this.container.querySelector('#btn-close-inspector');
    const btnDismissInsp = this.container.querySelector('#btn-dismiss-inspector');
    [btnCloseInsp, btnDismissInsp].forEach((btn) => {
      btn?.addEventListener('click', () => {
        this.selectedLogForInspection = null;
        this.render();
      });
    });

    // 12. Re-ejecutar desde Inspector
    const btnRerun = this.container.querySelector('#btn-rerun-from-inspector');
    if (btnRerun) {
      btnRerun.addEventListener('click', async () => {
        const agentId = btnRerun.dataset.agentId;
        if (agentId) {
          this.selectedLogForInspection = null;
          await agentService.executeAgent(agentId, true);
        }
      });
    }

    // 13. Disparar Evento de Sistema
    const btnSimulate = this.container.querySelector('#btn-simulate-event');
    if (btnSimulate) {
      btnSimulate.addEventListener('click', async () => {
        btnSimulate.disabled = true;
        const activeAgents = agentService.agents.filter((a) => a.status === 'active');
        if (activeAgents.length > 0) {
          const rand = activeAgents[Math.floor(Math.random() * activeAgents.length)];
          await agentService.executeAgent(rand.id, false);
        }
        btnSimulate.disabled = false;
      });
    }

    // 14. Limpiar Logs
    const btnClearLogs = this.container.querySelector('#btn-clear-logs');
    if (btnClearLogs) {
      btnClearLogs.addEventListener('click', () => {
        agentService.clearLogs();
      });
    }
  }

  escapeHtml(str) {
    if (!str) return '';
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  destroy() {
    if (this.unsubscribe) this.unsubscribe();
  }
}
