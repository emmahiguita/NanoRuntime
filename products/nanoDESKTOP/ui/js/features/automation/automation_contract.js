import { TOOL_REGISTRY } from './tool_registry.js';

export const toolLabels = {
  'Hardware Watcher': 'Memoria del equipo', 'Web Search': 'Búsqueda web',
  'DuckDuckGo API': 'Búsqueda web', 'LLM Fallback': 'Modelo local',
};
export function readiness(agent) {
  if (agent.tools != null && (!Array.isArray(agent.tools) || agent.tools.some(name => typeof name !== 'string'))) {
    return { ready:false, reason:'La configuración de herramientas no es válida. Edita esta tarea.' };
  }
  const names = agent.tools?.length ? agent.tools : ['LLM Fallback'];
  const missing = names.filter(name => !TOOL_REGISTRY.has(name) || TOOL_REGISTRY.get(name).available === false);
  if (missing.length) return { ready: false, reason: 'Sin conexión: ' + missing.join(', ') };
  if (agent.triggerType === 'event') return { ready: false, reason: 'Este disparador aún no tiene una fuente de eventos.' };
  if (names.some(name => TOOL_REGISTRY.get(name)?.type === 'MODEL') && !agent.model?.trim()) {
    return { ready: false, reason: 'Selecciona un modelo local para esta tarea.' };
  }
  return { ready: true, reason: '' };
}
export function taskState(agent, service) {
  if (agent.status === 'archived') return { key: 'archived', label: 'Archivada' };
  const running = service.running.get(agent.id);
  if (running) return { key: 'running', label: running.signal.aborted ? 'Cancelando espera' : 'En ejecución' };
  if (service.logs.some(log => log.agentId === agent.id && log.status === 'pending')) return { key: 'pending', label: 'Por aprobar' };
  if (!readiness(agent).ready) return { key: 'blocked', label: 'Requiere configuración' };
  if (agent.triggerType === 'demand') return { key: 'idle', label: 'Manual' };
  return agent.status === 'active' ? { key: 'scheduled', label: 'Programada' } : { key: 'paused', label: 'En pausa' };
}
export function logLabel(log) {
  return ({ok:'Completada', error:'Error', partial_success:'Resultado parcial', pending:'Por aprobar',
    approving:'En ejecución', running:'En ejecución', cancelled:'Cancelada', configured:'Configurada'})[log.status] || log.statusText || 'Sin estado';
}
