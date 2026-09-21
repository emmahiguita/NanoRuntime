/**
 * automation_log_row.js — Renderizador de Fila de Log de Ejecución
 *
 * QUÉ HACE: Genera el HTML de una fila del registro de telemetría en vivo.
 * CÓMO FUNCIONA: Función pura sin estado. Recibe el objeto `log` y retorna HTML.
 * POR QUÉ: SRP — la fila de log no debe conocer nada de la grilla de agentes
 *          ni del ciclo de vida de la vista. Facilita mantenimiento aislado.
 */

import { escapeHtml } from '../../core/utils.js';

/**
 * Genera el HTML de una fila del log de ejecución de agente.
 * @param {Object} log — Entrada de log del AgentService
 * @returns {string} — Fragmento HTML para el contenedor .auto-logs-table
 */
export function renderLogRow(log) {
  const isPending = log.status === 'pending';
  const isOk      = log.status === 'ok';

  // Badge de estado con color semántico
  const badge = isOk
    ? `<span class="log-status-badge badge-ok">✓ Éxito</span>`
    : isPending
      ? `<span class="log-status-badge badge-pending">⚠️ Pendiente</span>`
      : `<span class="log-status-badge badge-error">✕ Error</span>`;

  // Acciones contextuales: aprobar/rechazar si está pendiente, inspeccionar si no
  const actions = isPending
    ? `<button type="button" class="btn-approve-log"
               data-log-id="${log.id}" title="Aprobar acción del agente">Aprobar</button>
       <button type="button" class="btn-reject-log"
               data-log-id="${log.id}" title="Rechazar acción del agente">Rechazar</button>`
    : `<button type="button" class="btn-inspect-log"
               data-log-id="${log.id}" title="Ver detalles y salida del agente">Inspeccionar</button>`;

  return `
    <div class="auto-log-row ${isPending ? 'log-pending' : ''}" data-log-id="${log.id}">
      <!-- Columna izquierda: tiempo, nombre del agente, acción resumida -->
      <div class="log-left">
        <span class="log-time">${escapeHtml(log.time)}</span>
        <span class="log-agent">${escapeHtml(log.agentName)}</span>
        <span class="log-action" title="${escapeHtml(log.action)}">
          ${escapeHtml(log.action)}
        </span>
      </div>
      <!-- Columna derecha: duración, badge y botones de acción -->
      <div class="log-right">
        <span class="log-duration">${escapeHtml(log.duration || '—')}</span>
        ${badge}
        ${actions}
      </div>
    </div>
  `;
}
