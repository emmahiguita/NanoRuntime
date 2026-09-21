/**
 * automation_agent_card.js — Renderizador de Tarjeta de Agente Soberano
 *
 * QUÉ HACE: Genera el HTML de una tarjeta de agente dado su estado.
 * CÓMO FUNCIONA: Función pura que recibe el objeto `agent` y devuelve string HTML.
 *                No tiene estado interno ni efectos secundarios.
 * POR QUÉ: Separar el renderizado de la orquestación cumple SRP (Single Responsibility).
 *          Así automation_view.js no excede 200 LOC y la tarjeta puede testearse sola.
 */

import { NanoIcon } from '../../components/nano_icon.js';
import { escapeHtml } from '../../core/utils.js';

/**
 * Genera el HTML de la tarjeta de un agente soberano.
 * @param {Object} agent — Objeto de agente del AgentService
 * @returns {string} — Fragmento HTML listo para insertar con innerHTML
 */
export function renderAgentCard(agent) {
  // Derivamos estados visuales a partir del modelo
  const isActive   = agent.status === 'active';
  const isApproval = agent.governance === 'approval';
  const iconName   = agent.isSystem ? 'cpu' : 'automation';

  // Etiqueta de gobernanza: ⚡ Autónomo vs 🛡️ Requiere confirmación
  const govLabel = isApproval
    ? `<span class="param-val color-warning">🛡️ Requiere Confirmación</span>`
    : `<span class="param-val color-active">⚡ 100% Autónomo</span>`;

  // Tags de herramientas MCP permitidas al agente
  const toolTags = (agent.tools || [])
    .map((t) => `<span class="tool-tag">${escapeHtml(t)}</span>`)
    .join('');

  // Botón eliminar: solo para agentes personalizados (no sistema)
  const deleteBtn = !agent.isSystem
    ? `<button type="button" class="btn-card-action btn-delete-agent"
         data-agent-id="${agent.id}" title="Eliminar agente">
         ${NanoIcon.get('trash', 13)}
       </button>`
    : '';

  return `
    <div class="auto-card ${isActive ? 'card-active' : 'card-paused'}"
         data-agent-id="${agent.id}">

      <!-- Cabecera: icono, categoría, nombre y badge de estado -->
      <div class="auto-card-top">
        <div class="auto-card-top-left">
          <div class="auto-card-icon">${NanoIcon.get(iconName, 16)}</div>
          <div>
            <span class="auto-card-category">${escapeHtml(agent.category)}</span>
            <h3 class="auto-card-title">${escapeHtml(agent.name)}</h3>
          </div>
        </div>
        <div class="auto-card-status ${isActive ? 'status-active' : 'status-paused'}">
          <span class="status-dot"></span>
          <span>${isActive ? 'Activo' : 'Pausado'}</span>
        </div>
      </div>

      <!-- Descripción / misión del agente -->
      <p class="auto-card-desc">${escapeHtml(agent.role)}</p>

      <!-- Parámetros clave: trigger, modelo, gobernanza -->
      <div class="auto-card-parameters">
        <div class="param-row">
          <span class="param-label">Disparador:</span>
          <span class="param-val">${escapeHtml(agent.trigger)}</span>
        </div>
        <div class="param-row">
          <span class="param-label">Modelo:</span>
          <span class="param-val highlight">${escapeHtml(agent.model)}</span>
        </div>
        <div class="param-row">
          <span class="param-label">Gobernanza:</span>
          ${govLabel}
        </div>
      </div>

      <!-- Herramientas MCP habilitadas -->
      <div class="auto-card-tools-row">${toolTags}</div>

      <!-- Pie: estadísticas + acciones -->
      <div class="auto-card-footer">
        <div class="agent-stats">
          <span>⚡ ${agent.executions || 0} ejecuciones</span>
          <span>• ${escapeHtml(agent.lastRun || 'Reciente')}</span>
        </div>
        <div class="agent-actions-group">
          <!-- Toggle activo/pausado -->
          <button type="button" class="btn-card-action btn-toggle-status"
                  data-agent-id="${agent.id}"
                  title="${isActive ? 'Pausar agente' : 'Reanudar agente'}">
            ${NanoIcon.get(isActive ? 'pause' : 'play', 13)}
            <span>${isActive ? 'Pausar' : 'Reanudar'}</span>
          </button>
          <!-- Ejecución manual inmediata -->
          <button type="button" class="btn-card-action btn-run-now"
                  data-agent-id="${agent.id}" title="Ejecutar agente ahora">
            ${NanoIcon.get('refresh', 13)}
            <span>Ejecutar</span>
          </button>
          ${deleteBtn}
        </div>
      </div>
    </div>
  `;
}
