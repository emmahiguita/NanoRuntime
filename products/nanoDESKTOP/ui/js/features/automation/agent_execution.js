/** Ejecuta planes aprobados una sola vez y conserva su identidad y cancelación. */
import { formatRelativeTime } from '../../core/utils.js';
import { resolveAgentTools, runAgentTools } from './agent_executor.js';
import { readiness, toolLabels } from './automation_contract.js';

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
    `Se utilizará: ${(agent.tools?.length ? agent.tools : ['LLM Fallback']).map(name => toolLabels[name] || name).join(', ')}. Todavía no se ejecutó ninguna herramienta.`,
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
  if (agent.status === 'archived') throw new Error('Restaura la tarea antes de ejecutarla.');
  if (!isManual && agent.status !== 'active') return null;
  const capability = readiness(agent);
  if (!capability.ready) {
    if (!isManual) return null;
    throw new Error(capability.reason);
  }
  if (!approvedLog && needsApproval(agent)) return deferExecution(service, agent);

  const executionLog = approvedLog || service._pushLog(agent, 'Ejecución de ' + agent.name,
    'La tarea está en curso. El resultado aparecerá al terminar.', '—', 'running', 'En ejecución');
  executionLog.startedAt = Date.now();
  if (!service._saveLogs()) {
    executionLog.status = 'error';
    executionLog.statusText = 'No se pudo guardar el inicio; no se ejecutó';
    service.notify();
    throw new Error(executionLog.statusText);
  }

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
    if (!service._saveAgents()) executionLog.persistenceError = 'La tarea terminó, pero no se pudieron guardar sus contadores.';
  }
  const log = executionLog;
  Object.assign(log, {
    action: result.actionSummary, output: result.detailedOutput,
    duration: `${result.elapsedMs}ms`, status: result.status,
    statusText: result.statusText, toolResults: result.toolResults || [],
    finishedAt: Date.now(),
  });
  delete log.planFingerprint;
  if (!service._saveLogs()) log.persistenceError = 'El resultado está disponible en esta sesión, pero no se pudo guardar en el historial.';
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
  const capability = readiness(agent);
  if (!capability.ready) throw new Error(capability.reason);
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
