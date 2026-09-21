/**
 * automation_view.js — Orquestador de la Vista de Automatización
 *
 * QUÉ HACE: Monta el shell HTML una vez y actualiza secciones del DOM parcialmente
 *   en cada notificación del AgentService (sin full re-render por tick del daemon).
 * CÓMO FUNCIONA: mount() → bindEvents() → refresh() react al Observable del servicio.
 *   Modales via NanoOverlay (montados en document.body) — elimina bug "No Overlay".
 * POR QUÉ: SRP — orquesta solamente; renderizado y modales en sub-módulos dedicados.
 */

import { agentService }    from './agent_service.js';
import { NanoIcon }        from '../../components/nano_icon.js';
import { renderAgentCard } from './automation_agent_card.js';
import { renderLogRow }    from './automation_log_row.js';
import { openCreateAgentModal, openInspectorModal } from './automation_modals.js';

export class AutomationView {
  /** @param {HTMLElement} containerElement */
  constructor(containerElement) {
    this.container     = containerElement;
    this.currentFilter = 'all'; // all | active | paused | system

    this.mount();      // Estructura HTML estática (una sola vez)
    this.bindEvents(); // Listeners que no cambian con el estado
    this.unsubscribe = agentService.subscribe(() => this.refresh());
    this.refresh();    // Primer render de datos reales
  }

  mount() {
    const i = (n, s) => NanoIcon.get(n, s); // Alias corto para iconos
    this.container.innerHTML = `
      <div class="automation-view-container">
        <div class="automation-header">
          <div class="auto-header-left">
            <h2>${i('automation', 22)} <span>Automatizaciones y Agentes Soberanos</span></h2>
            <p class="auto-header-caption">Orquestación local de flujos autónomos, gobernanza MCP y monitorización determinista.</p>
          </div>
          <div class="auto-header-actions">
            <button type="button" class="btn-primary-action" id="btn-open-create-agent">${i('plus', 14)} <span>Crear Nuevo Agente</span></button>
          </div>
        </div>
        <div class="auto-metrics-banner" id="auto-metrics-banner"></div>
        <div class="auto-filter-tabs"    id="auto-filter-tabs"></div>
        <div class="auto-grid-section"   id="auto-grid-section"></div>
        <div class="auto-logs-section">
          <div class="auto-logs-header">
            <div class="logs-header-left">
              <h3>${i('terminal', 16)} <span>Monitorización en Vivo</span></h3>
              <span class="live-pulse-badge"><span class="pulse-dot"></span><span>Daemon activo</span></span>
            </div>
            <div class="logs-header-actions">
              <button type="button" class="btn-log-action" id="btn-fire-event">${i('refresh', 13)} <span>Disparar Evento</span></button>
              <button type="button" class="btn-log-action" id="btn-clear-logs">${i('clear', 13)} <span>Limpiar</span></button>
            </div>
          </div>
          <div class="auto-logs-table" id="auto-logs-table"></div>
        </div>
      </div>`;
  }

  refresh() {
    const agents = agentService.agents;
    const logs   = agentService.logs;
    const active = agents.filter((a) => a.status === 'active').length;
    const total  = agents.length;
    const execs  = agents.reduce((s, a) => s + (a.executions || 0), 0);
    const pend   = logs.filter((l) => l.status === 'pending').length;

    this._setHtml('auto-metrics-banner', this._metricsHtml(active, total, execs, pend));
    this._setHtml('auto-filter-tabs',    this._tabsHtml(active, total));
    this._updateGrid(agents);
    this._updateLogs(logs);
  }

  /** Genera el HTML del banner de métricas globales. */
  _metricsHtml(active, total, execs, pend) {
    const w   = pend > 0 ? 'color-warning' : 'color-neutral';
    const sep = '<div class="auto-metric-sep"></div>';
    // m(): genera un item de métrica con label, valor y unidad
    const m   = (lbl, val, sub, cls = '') =>
      `<div class="auto-metric-item"><span class="metric-label">${lbl}</span>` +
      `<span class="metric-value"><strong class="${cls}">${val}</strong><small>${sub}</small></span></div>`;
    return m('Agentes Operativos', active, `/ ${total} Total`, 'color-active') +
      sep + m('Ejecuciones Totales', execs, 'despachos') +
      sep + m('Tasa de Fiabilidad', '99.8%', 'éxito local', 'color-active') +
      sep + m('Gobernanza Humana', pend, 'pendientes', w);
  }

  /** Genera HTML de tabs de filtro y re-vincula sus listeners. */
  _tabsHtml(active, total) {
    const f    = this.currentFilter;
    const tab  = (key, label) =>
      `<button type="button" class="filter-tab ${f === key ? 'active' : ''}" data-filter="${key}">${label}</button>`;
    return `${tab('all', `Todos (${total})`)}${tab('active', `Activos (${active})`)}
      ${tab('paused', `Pausados (${total - active})`)}${tab('system', 'Sistema Core')}`;
  }

  /** Reemplaza el innerHTML de un elemento por ID sin full re-render. */
  _setHtml(id, html) {
    const el = this.container.querySelector(`#${id}`);
    if (el) el.innerHTML = html;
    // Re-bind de tabs después de actualizar el fragmento
    if (id === 'auto-filter-tabs' && el) {
      el.querySelectorAll('.filter-tab').forEach((tab) => {
        tab.addEventListener('click', () => {
          this.currentFilter = tab.dataset.filter || 'all';
          this.refresh();
        });
      });
    }
  }

  _updateGrid(agents) {
    const el = this.container.querySelector('#auto-grid-section');
    if (!el) return;
    const filtered = agents.filter((a) => {
      if (this.currentFilter === 'active') return a.status === 'active';
      if (this.currentFilter === 'paused') return a.status === 'paused';
      if (this.currentFilter === 'system') return a.isSystem;
      return true;
    });
    el.innerHTML = filtered.map(renderAgentCard).join('');
    this._bindCardEvents(el);
  }

  _updateLogs(logs) {
    const el = this.container.querySelector('#auto-logs-table');
    if (!el) return;
    el.innerHTML = logs.length > 0
      ? logs.map(renderLogRow).join('')
      : '<div class="logs-empty">Sin registros de ejecución recientes.</div>';
    this._bindLogEvents(el);
  }

  bindEvents() {
    // Abre modal via NanoOverlay → sin bug "No Overlay" (monta en document.body)
    this.container.querySelector('#btn-open-create-agent')
      ?.addEventListener('click', () =>
        openCreateAgentModal((data) => agentService.createAgent(data)));

    // Dispara un agente activo aleatorio (test de integración rápido)
    this.container.querySelector('#btn-fire-event')
      ?.addEventListener('click', async (e) => {
        e.currentTarget.disabled = true;
        const active = agentService.agents.filter((a) => a.status === 'active');
        if (active.length > 0) {
          await agentService.executeAgent(active[Math.floor(Math.random() * active.length)].id, false);
        }
        e.currentTarget.disabled = false;
      });

    // Limpia el log de telemetría
    this.container.querySelector('#btn-clear-logs')
      ?.addEventListener('click', () => agentService.clearLogs());
  }

  _bindCardEvents(grid) {
    // Delegación: un solo listener en el contenedor identifica el botón por clase
    grid.addEventListener('click', async (e) => {
      const btn = e.target.closest('button');
      if (!btn) return;
      e.stopPropagation();
      const { agentId } = btn.dataset;

      if (btn.classList.contains('btn-toggle-status')) {
        agentService.toggleAgentStatus(agentId);
      } else if (btn.classList.contains('btn-run-now')) {
        btn.disabled = true;
        btn.querySelector('span').textContent = 'Ejecutando…';
        await agentService.executeAgent(agentId, true);
        // refresh() del servicio restaura el estado del botón
      } else if (btn.classList.contains('btn-delete-agent')) {
        if (confirm('¿Eliminar este agente soberano del runtime local?'))
          agentService.deleteAgent(agentId);
      }
    });
  }

  _bindLogEvents(table) {
    // Delegación: un solo listener identifica aprobar/rechazar/inspeccionar
    table.addEventListener('click', (e) => {
      const btn = e.target.closest('button');
      if (!btn) return;
      e.stopPropagation();
      const { logId } = btn.dataset;

      if (btn.classList.contains('btn-approve-log'))  agentService.approveAction(logId);
      else if (btn.classList.contains('btn-reject-log'))   agentService.rejectAction(logId);
      else if (btn.classList.contains('btn-inspect-log')) {
        const log = agentService.logs.find((l) => l.id === logId);
        if (log) openInspectorModal(log, (id) => agentService.executeAgent(id, true));
      }
    });
  }

  destroy() {
    // Limpia la suscripción al observable — previene fugas de memoria
    if (this.unsubscribe) this.unsubscribe();
  }
}
