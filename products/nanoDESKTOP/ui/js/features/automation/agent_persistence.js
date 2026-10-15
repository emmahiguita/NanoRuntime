/** Persistencia compatible: conserva claves existentes y no fabrica resultados. */
import { getDefaultAgents, getDefaultLogs } from './automation_defaults.js';

// Una colección ilegible no se sobrescribe por defaults en una operación posterior.
const unreadableKeys = new Set();

const count = (value) => Number.isFinite(Number(value)) ? Math.max(0, Math.floor(Number(value))) : 0;

/** Normaliza registros antiguos; una ejecución interrumpida no se reinicia sola. */
export function normalizeAgent(agent) {
  const result = { searchQuery: '', ...agent };
  for (const key of ['executions', 'successCount', 'errorCount', 'cancelledCount']) {
    result[key] = count(result[key]);
  }
  if (result.status === 'executing') result.status = 'paused';
  if (typeof result.searchQuery !== 'string') result.searchQuery = '';
  Object.defineProperty(result, 'successRate', {
    enumerable: true,
    get() {
      const completed = this.successCount + this.errorCount;
      return completed ? `${Math.round(this.successCount * 100 / completed)}%` : '—';
    },
  });
  return result;
}

/** Lee una colección sin sobrescribir el contenido original si está corrupto. */
function readItems(key, defaults) {
  try {
    if (typeof localStorage === 'undefined') return defaults();
    const raw = localStorage.getItem(key);
    if (raw === null) return defaults();
    const items = JSON.parse(raw);
    if (!Array.isArray(items) || items.some((item) => !item || typeof item !== 'object' || Array.isArray(item))) {
      throw new Error('La colección guardada no contiene registros válidos');
    }
    return items;
  } catch (error) {
    console.warn(`[AgentService] No se pudo leer ${key}:`, error);
    unreadableKeys.add(key);
    return [];
  }
}

/** Hidrata agentes y logs; un pendiente antiguo nunca acredita ejecución. */
export function loadAgentState(service) {
  service.agents = readItems(service.agentsKey, getDefaultAgents).map(normalizeAgent);
  service.logs = readItems(service.logsKey, getDefaultLogs).map((log) => {
    if (log.status !== 'approving') return log;
    return { ...log, status: 'cancelled', statusText: 'Ejecución interrumpida; revisar antes de reintentar' };
  });
}

/** Informa fallos de almacenamiento; el caller puede impedir una aprobación no durable. */
export function persistItems(key, items) {
  if (unreadableKeys.has(key)) {
    console.warn('[AgentService] Escritura bloqueada para conservar datos ilegibles:', key);
    return false;
  }
  try {
    if (typeof localStorage === 'undefined') return false;
    localStorage.setItem(key, JSON.stringify(items));
    return true;
  } catch (error) {
    console.warn(`[AgentService] No se pudo guardar ${key}:`, error);
    return false;
  }
}
