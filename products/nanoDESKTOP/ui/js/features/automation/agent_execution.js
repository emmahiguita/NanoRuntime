/** Ejecuta planes aprobados una sola vez y conserva su identidad y cancelación. */
import { formatRelativeTime } from '../../core/utils.js';
import { resolveAgentTools, runAgentTools } from './agent_executor.js';

/** Firma solo configuración ejecutable; cambiar el plan invalida la autorización. */
function fingerprint(agent) {
  return JSON.stringify([agent.name, agent.role, agent.model, agent.tools, agent.searchQuery, agent.governance]);
}

/** Un botón Ejecutar no sustituye la aprobación explícita de una acción sensible. */
function needsApproval(agent) {
  return agent.governance === 'approval' || resolveAgentTools(agent).some((tool) => tool.requiresApproval || tool.type === 'ACTION');
}

/** Crea un pendiente sin llamar herramientas ni incrementar éxitos/ejecuciones. */
function deferExecution(service, agent) {
  const existing = service.logs.find((log) => log.agentId === agent.id && log.status === 'pending');
  if (existing) return existing;
  const log = service._pushLog(agent, 'Plan pendiente de autorización',
    `Herramientas solicitadas: ${(agent.tools || []).join(', ')}. Todavía no se ejecutaron.`,
    '—', 'pending', 'Requiere aprobación');
  log.planFingerprint = fingerprint(agent);
  if (!service._saveLogs()) {
    log.status = 'error';
    log.statusText = 'No se pudo guardar el plan; no se ejecutó';
  }
  service.notify();
  return log;
}

/** Serializa por agente y restaura el estado incluso si falla el backend. */
export async function executeAgent(service, agentId, isManual = true, approvedLog = null) {
  const agent = service.agents.find((item) => item.id === agentId);
  if (!agent || service.running.has(agentId)) return null;
  if (!isManual && agent.status !== 'active') return null;
  if (!approvedLog && needsApproval(agent)) return deferExecution(service, agent);

  const controller = new AbortController();
  const previousStatus = agent.status;
  service.running.set(agentId, controller);
  agent.status = 'executing';
  service.notify();
  const started = performance.now();
  let result;
  try {
    result = await runAgentTools(agent, null, {
      signal: controller.signal, approved: Boolean(approvedLog),
    });
    controller.signal.throwIfAborted();
  } catch (error) {
    const cancelled = controller.signal.aborted || error.name === 'AbortError';
    result = {
      status: cancelled ? 'cancelled' : 'error',
      statusText: cancelled ? 'Cancelada; revisar efectos ya iniciados' : 'Error de ejecución',
      actionSummary: `Ejecución de ${agent.name}`,
      detailedOutput: error.message || String(error),
      elapsedMs: Math.round(performance.now() - started), toolResults: [],
    };
  } finally {
    service.running.delete(agentId);
    // Pausar mientras ejecuta conserva la pausa, no reactiva el agente al terminar.
    if (agent.status === 'executing') agent.status = previousStatus;
  }

  const retained = service.agents.includes(agent);
  if (retained) {
    agent.executions++;
    agent.lastRunTimestamp = Date.now();
    agent.lastRun = formatRelativeTime(agent.lastRunTimestamp);
    if (result.status === 'ok') agent.successCount++;
    else if (result.status === 'cancelled') agent.cancelledCount++;
    else agent.errorCount++;
    service._saveAgents();
  }
  const log = approvedLog || service._pushLog(agent, result.actionSummary,
    result.detailedOutput, `${result.elapsedMs}ms`, result.status, result.statusText);
  Object.assign(log, {
    action: result.actionSummary, output: result.detailedOutput,
    duration: `${result.elapsedMs}ms`, status: result.status,
    statusText: result.statusText, toolResults: result.toolResults || [],
  });
  delete log.planFingerprint;
  service._saveLogs();
  service.notify();
  return log;
}

/** Reclama un plan pendiente antes de esperar: dobles clics no pueden repetirlo. */
export async function approveAction(service, logId) {
  const log = service.logs.find((item) => item.id === logId);
  if (!log || log.status !== 'pending') return null;
  const agent = service.agents.find((item) => item.id === log.agentId);
  if (!agent || !log.planFingerprint || log.planFingerprint !== fingerprint(agent)) {
    return rejectAction(service, logId, 'Plan ausente o cambiado; solicita una nueva ejecución');
  }
  if (service.running.has(agent.id)) return null;
  log.status = 'approving';
  log.statusText = 'Autorizada; ejecución en curso';
  if (!service._saveLogs()) {
    log.status = 'pending';
    log.statusText = 'No se pudo guardar la aprobación; no se ejecutó';
    service.notify();
    return null;
  }
  return executeAgent(service, agent.id, true, log);
}

/** Rechaza sin ejecutar y sin contar como fallo una operación que no comenzó. */
export function rejectAction(service, logId, reason = 'Rechazada antes de ejecutar') {
  const log = service.logs.find((item) => item.id === logId);
  if (!log || log.status !== 'pending') return null;
  log.status = 'cancelled';
  log.statusText = reason;
  delete log.planFingerprint;
  service._saveLogs();
  service.notify();
  return log;
}
