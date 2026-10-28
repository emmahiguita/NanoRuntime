/** AgentService: conserva CRUD/Observer y delega persistencia y ejecución segura. */
import { formatRelativeTime } from '../../core/utils.js';
import { TRIGGER_MAP, validateAgentInput } from './automation_modals.js';
import { loadAgentState, normalizeAgent, persistItems } from './agent_persistence.js';
import { executeAgent, approveAction, rejectAction } from './agent_execution.js';

export class AgentService {
  constructor() {
    this.agentsKey = 'nano_desktop_agents_v2';
    this.logsKey = 'nano_desktop_agent_logs_v1';
    this.agents = [];
    this.logs = [];
    this.listeners = [];
    this.running = new Map();
    this.daemonTimer = null;
    this.daemonBusy = false;
    this._load();
    this.startDaemon();
  }

  /** Observer compatible; la desuscripción elimina la referencia a la vista. */
  subscribe(cb) {
    this.listeners.push(cb);
    return () => { this.listeners = this.listeners.filter((item) => item !== cb); };
  }

  /** Un observer averiado no impide restaurar el ciclo de vida ni avisar a otros. */
  notify() {
    for (const cb of [...this.listeners]) {
      try { cb({ agents: this.agents, logs: this.logs }); }
      catch (error) { console.warn('[AgentService] Observer falló:', error); }
    }
  }

  /** Fiabilidad de resultados terminados; pendientes/cancelaciones no son éxitos. */
  get successRate() {
    const successes = this.agents.reduce((sum, agent) => sum + agent.successCount, 0);
    const errors = this.agents.reduce((sum, agent) => sum + agent.errorCount, 0);
    return successes + errors ? Math.round(successes * 100 / (successes + errors)) + '%' : '—';
  }

  _normalizeAgent(agent) { return normalizeAgent(agent); }
  _load() { loadAgentState(this); }
  _saveAgents() {
    return persistItems(this.agentsKey, this.agents.map(({ successRate, ...agent }) => agent));
  }
  _saveLogs() { return persistItems(this.logsKey, this.logs); }

  /** Un único tick en curso evita solapar intervalos lentos del mismo daemon. */
  startDaemon() {
    if (this.daemonTimer) return;
    this.daemonTimer = setInterval(async () => {
      if (this.daemonBusy) return;
      this.daemonBusy = true;
      try {
        for (const agent of [...this.agents]) {
          if (!this.daemonTimer) break;
          if (agent.status !== 'active' || agent.triggerType !== 'interval' || !agent.intervalSeconds) continue;
          if ((Date.now() - (agent.lastRunTimestamp || 0)) / 1000 >= agent.intervalSeconds) {
            await this.executeAgent(agent.id, false);
          }
        }
      } catch (error) { console.warn('[AgentService] Tick falló:', error); }
      finally { this.daemonBusy = false; }
    }, 12000);
  }

  /** Detener el daemon solicita cancelación del trabajo actual, no solo del timer. */
  stopDaemon() {
    clearInterval(this.daemonTimer);
    this.daemonTimer = null;
    for (const controller of this.running.values()) controller.abort();
  }

  executeAgent(id, isManual = true) { return executeAgent(this, id, isManual); }
  approveAction(id) { return approveAction(this, id); }
  rejectAction(id) { return rejectAction(this, id); }

  /** Valida también en servicio: callers distintos del formulario no crean datos vacíos. */
  createAgent(data) {
    const validation = validateAgentInput(data);
    if (!validation.isValid) throw new Error(Object.values(validation.errors).join(' '));
    const trigger = data.trigger || 'Manual bajo demanda';
    const info = TRIGGER_MAP[trigger] || { type: 'demand', seconds: null };
    if (info.type === 'event') throw new Error('Este disparador no tiene productor de eventos conectado.');
    const agent = normalizeAgent({
      id: 'agent-' + crypto.randomUUID(), ...validation.data,
      category: 'Agente Personalizado', model: data.model || '',
      trigger, triggerType: info.type, intervalSeconds: info.seconds,
      governance: data.governance || 'autonomous', tools: data.tools || ['Web Search'],
      status: 'active', isSystem: false, executions: 0, successCount: 0, errorCount: 0,
      lastRun: 'Nunca', lastRunTimestamp: null,
    });
    this.agents.unshift(agent);
    if (!this._saveAgents()) {
      this.agents.shift();
      throw new Error('No se pudo guardar el agente.');
    }
    this._pushLog(agent, 'Agente configurado', 'El agente todavía no ha ejecutado herramientas.', '—');
    this._saveLogs();
    this.notify();
    return agent;
  }

  /** Pausar conserva configuración y solicita cancelar la ejecución iniciada. */
  toggleAgentStatus(id) {
    const agent = this.agents.find((item) => item.id === id);
    if (!agent) return;
    agent.status = agent.status === 'paused' ? 'active' : 'paused';
    if (agent.status === 'paused') this.running.get(id)?.abort();
    this._saveAgents();
    this.notify();
  }

  /** Eliminar invalida planes pendientes; no afirma liberar recursos nativos no confirmados. */
  deleteAgent(id) {
    const agent = this.agents.find((item) => item.id === id);
    if (!agent) return;
    this.running.get(id)?.abort();
    this.agents = this.agents.filter((item) => item.id !== id);
    for (const log of this.logs.filter((item) => item.agentId === id && item.status === 'pending')) {
      rejectAction(this, log.id, 'Agente eliminado; plan cancelado');
    }
    this._saveAgents();
    this.notify();
  }

  /** Limpiar conserva aprobaciones en curso para no perder su trazabilidad. */
  clearLogs() {
    this.logs = this.logs.filter((log) => log.status === 'pending' || log.status === 'approving');
    this._saveLogs();
    this.notify();
  }

  /** Registro único con duración observada o ausente, nunca un tiempo ficticio. */
  _pushLog(agent, action, output, duration, status = 'ok', statusText = 'Configurado') {
    const now = Date.now();
    const log = {
      id: 'log-' + crypto.randomUUID(), timestamp: now, time: formatRelativeTime(now),
      agentId: agent.id, agentName: agent.name, model: agent.model,
      action, output, duration, status, statusText,
    };
    this.logs.unshift(log);
    if (this.logs.length > 50) {
      const index = this.logs.findLastIndex((item) => item.status !== 'pending' && item.status !== 'approving');
      if (index >= 0) this.logs.splice(index, 1);
    }
    return log;
  }
}

export const agentService = new AgentService();
