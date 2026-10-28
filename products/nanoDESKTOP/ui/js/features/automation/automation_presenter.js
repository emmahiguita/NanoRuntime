import { NanoIcon } from '../../components/nano_icon.js';
import { escapeHtml as esc } from '../../core/utils.js';
import { readiness, taskState, toolLabels, logLabel } from './automation_contract.js';

export function renderTask(agent, service) {
  const state = taskState(agent, service);
  const check = readiness(agent);
  const names = agent.tools?.length ? agent.tools : ['LLM Fallback'];
  const tools = [...new Set(names.map(name => toolLabels[name] || name))].join(' · ');
  const id = esc(agent.id);
  const running = service.running.has(agent.id);
  const action = state.key === 'pending' ? 'review' : 'run';
  const label = state.key === 'pending' ? 'Revisar' : 'Ejecutar';
  return `<article class="task-row" data-task="${id}">
    <div class="task-main"><h3>${esc(agent.name)}</h3><p>${esc(agent.role)}</p>
      <div class="task-meta"><span>${esc(tools)}</span><span>${esc(agent.trigger || 'Manual')}</span>
        <span>${agent.governance === 'approval' ? 'Con aprobación' : 'Ejecución directa'}</span></div>
      ${check.reason ? `<p class="task-blocker">${NanoIcon.get('shield',14)} ${esc(check.reason)}</p>` : ''}</div>
    <div class="task-controls"><span class="task-state" data-state="${state.key}">${running ? '<span class="activity-spinner" aria-hidden="true"></span>' : ''}${state.label}</span>
      <div class="task-buttons">
      ${agent.status === 'archived' ? `<button data-action="restore" data-agent-id="${id}">Restaurar</button>` : running ? `<button data-action="cancel" data-agent-id="${id}" ${service.running.get(agent.id).signal.aborted ? 'disabled' : ''}>Cancelar espera</button>`
        : `<button data-action="${action}" data-agent-id="${id}" ${!check.ready ? 'disabled' : ''}>${NanoIcon.get(action === 'review' ? 'shield' : 'play',14)} ${label}</button>`}
      ${agent.triggerType === 'interval' && agent.status !== 'archived' ? `<button data-action="toggle" data-agent-id="${id}" ${!check.ready || running ? 'disabled' : ''}>${NanoIcon.get(agent.status === 'paused' ? 'play' : 'pause',14)} ${agent.status === 'paused' ? 'Activar' : 'Pausar'}</button>` : ''}
      <button class="icon-button" data-action="edit" data-agent-id="${id}" aria-label="Editar ${esc(agent.name)}" title="Editar tarea" ${running ? 'disabled' : ''}>${NanoIcon.get('edit',16)}</button>
      ${agent.status !== 'archived' ? `<button class="icon-button" data-action="archive" data-agent-id="${id}" aria-label="Archivar ${esc(agent.name)}" title="Archivar tarea" ${running ? 'disabled' : ''}>${NanoIcon.get('archive',16)}</button>` : ''}
      </div></div></article>`;
}

export function renderHistory(log) {
  const pending = log.status === 'pending';
  const running = ['running','approving'].includes(log.status);
  const date = log.timestamp ? new Date(log.timestamp).toLocaleString('es', {dateStyle:'short',timeStyle:'short'}) : log.time || '';
  return `<article class="execution-row" data-log="${esc(log.id)}">
    <div class="execution-heading"><div><strong>${esc(log.agentName || 'Tarea')}</strong>
      <span class="execution-time">${esc(date)}</span></div>
      <span class="task-state" data-state="${pending ? 'pending' : running ? 'running' : log.status}">${running ? '<span class="activity-spinner" aria-hidden="true"></span>' : ''}${esc(logLabel(log))}</span></div>
    <p class="execution-summary">${esc(log.statusText || log.action)}</p>
    <div class="execution-steps" aria-label="Progreso de la ejecución"><span>${log.status==='configured'?'Configuración guardada':'Solicitud registrada'}</span>${log.status==='configured'?'':`<span>${pending ? 'Espera aprobación' : running ? 'Procesando' : 'Finalizada'}</span>${!pending && !running ? `<span>${esc(log.duration || 'Sin duración')}</span>` : ''}`}</div>
    ${pending ? `<p class="approval-context">${esc(log.output)}</p><div class="execution-actions"><button data-action="approve" data-log-id="${esc(log.id)}">${NanoIcon.get('check',14)} Aprobar ejecución</button><button data-action="reject" data-log-id="${esc(log.id)}">Rechazar</button></div>`
      : !running ? `<details><summary>Ver resultado</summary><pre>${esc(log.output || 'Sin salida registrada.')}</pre>${log.toolResults?.map(result => `<p>${esc(toolLabels[result.name] || result.name)} · ${result.error ? 'Error' : 'Completada'} · ${Number(result.elapsedMs) || 0} ms</p>`).join('') || ''}</details>` : '<p class="execution-note">Se mostrará el resultado real al terminar. Puedes cancelar la espera desde la tarea.</p>'}
    ${log.persistenceError ? `<p role="alert">${esc(log.persistenceError)}</p>` : ''}
  </article>`;
}

