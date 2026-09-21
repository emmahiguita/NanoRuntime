/**
 * agent_service.js — Singleton de Orquestación de Agentes Soberanos
 *
 * QUÉ HACE: Gestiona ciclo de vida (CRUD), daemon de fondo, gobernanza humana
 *   y observabilidad (subscribe/notify) de todos los agentes locales.
 * CÓMO FUNCIONA: Patrón Observer + singleton exportado. Persiste en localStorage.
 *   Delega ejecución de herramientas a agent_executor.js (SRP).
 * POR QUÉ: Las vistas no deben conocer lógica de persistencia ni ejecución.
 */

import { formatRelativeTime }                       from '../../core/utils.js';
import { TRIGGER_MAP }                              from './automation_modals.js';
import { getDefaultAgents, getDefaultLogs }         from './automation_defaults.js';
import { runAgentTools }                            from './agent_executor.js';

class AgentService {
  constructor() {
    this.agentsKey   = 'nano_desktop_agents_v2';
    this.logsKey     = 'nano_desktop_agent_logs_v1';
    this.agents      = [];
    this.logs        = [];
    this.listeners   = [];
    this.daemonTimer = null;
    this._load();
    this.startDaemon();
  }

  // ─── Observabilidad: patrón pub/sub ───────────────────────────────────────

  /** Suscribe un callback; retorna la función para desuscribirse. */
  subscribe(cb) { this.listeners.push(cb); return () => { this.listeners = this.listeners.filter((l) => l !== cb); }; }
  notify()      { this.listeners.forEach((cb) => cb({ agents: this.agents, logs: this.logs })); }

  // ─── Persistencia localStorage ────────────────────────────────────────────

  _load() {
    try {
      this.agents = JSON.parse(localStorage.getItem(this.agentsKey)) || null;
      if (!this.agents) { this.agents = getDefaultAgents(); this._saveAgents(); }
      this.logs   = JSON.parse(localStorage.getItem(this.logsKey))   || null;
      if (!this.logs)   { this.logs   = getDefaultLogs();   this._saveLogs(); }
    } catch {
      // Si localStorage falla, usar los defaults y continuar
      this.agents = getDefaultAgents();
      this.logs   = getDefaultLogs();
    }
  }

  _saveAgents() { try { localStorage.setItem(this.agentsKey, JSON.stringify(this.agents)); } catch {} }
  _saveLogs()   { try { localStorage.setItem(this.logsKey,   JSON.stringify(this.logs));   } catch {} }

  // ─── Daemon de Segundo Plano ──────────────────────────────────────────────

  /**
   * Inicia el daemon de intervalo soberano.
   * BUG FIX: Guard `if (this.daemonTimer) return` previene timers zombie acumulados.
   * Cada navegación entre vistas NO crea un nuevo timer —el singleton lo reutiliza.
   */
  startDaemon() {
    if (this.daemonTimer) return; // Guard anti-zombie
    this.daemonTimer = setInterval(async () => {
      const now = Date.now();
      for (const a of this.agents) {
        if (a.status !== 'active' || a.triggerType !== 'interval' || !a.intervalSeconds) continue;
        if ((now - (a.lastRunTimestamp || 0)) / 1000 >= a.intervalSeconds) {
          await this.executeAgent(a.id, false);
        }
      }
    }, 12000); // Tick cada 12s — evalúa si algún agente de intervalo debe dispararse
  }

  /** Para el daemon limpiamente. Expuesto para testing y cleanup controlado. */
  stopDaemon() {
    if (this.daemonTimer) { clearInterval(this.daemonTimer); this.daemonTimer = null; }
  }

  // ─── Ejecución y Gobernanza ───────────────────────────────────────────────

  /**
   * Ejecuta un agente: delega herramientas a agent_executor.js,
   * aplica gobernanza humana si es disparo automático, y emite log.
   */
  async executeAgent(agentId, isManual = true) {
    const agent = this.agents.find((a) => a.id === agentId);
    if (!agent) return null;

    // Delegación a agent_executor: este servicio no contiene lógica de herramientas (SRP)
    let { actionSummary, detailedOutput, status, statusText, elapsedMs } = await runAgentTools(agent);

    // Gobernanza humana: agente de aprobación disparado automáticamente → queda pendiente
    if (agent.governance === 'approval' && !isManual) { status = 'pending'; statusText = 'Requiere Aprobación'; }

    // Actualizar estado del agente
    agent.executions       = (agent.executions || 0) + 1;
    agent.lastRunTimestamp = Date.now();
    agent.lastRun          = formatRelativeTime(agent.lastRunTimestamp);
    this._saveAgents();

    // Crear y registrar entrada de log de telemetría
    const now   = Date.now();
    const entry = { id: `log-${now}`, timestamp: now, time: formatRelativeTime(now),
      agentId: agent.id, agentName: agent.name, model: agent.model,
      action: actionSummary, output: detailedOutput, duration: `${elapsedMs}ms`, status, statusText };

    this.logs.unshift(entry);
    if (this.logs.length > 50) this.logs.pop(); // Cap historial: máx 50 entradas
    this._saveLogs();
    this.notify();
    return entry;
  }

  /** Gobernanza: aprobar acción pendiente de un agente. */
  async approveAction(logId) {
    const log = this.logs.find((l) => l.id === logId);
    if (!log) return;
    log.status = 'ok';
    log.statusText = 'Aprobado y Ejecutado';
    log.output += `\n\n[Firma Humana: Autorizado a las ${new Date().toLocaleTimeString()}].`;
    this._saveLogs(); this.notify();
  }

  /** Gobernanza: rechazar acción pendiente de un agente. */
  rejectAction(logId) {
    const log = this.logs.find((l) => l.id === logId);
    if (!log) return;
    log.status = 'error';
    log.statusText = 'Rechazado por Usuario';
    log.output += '\n\n[Firma Humana: Acción bloqueada].';
    this._saveLogs(); this.notify();
  }

  // ─── CRUD de Agentes ──────────────────────────────────────────────────────

  /**
   * Crea y despliega un nuevo agente soberano.
   * BUG FIX: Usa TRIGGER_MAP en lugar de string-parsing frágil ('includes("minuto")').
   */
  createAgent(data) {
    const key  = data.trigger || 'Manual bajo demanda';
    const info = TRIGGER_MAP[key] || { type: 'demand', seconds: null };
    const now  = Date.now();
    const agent = {
      id: `agent-${now}`, name: data.name || 'Nuevo Agente Soberano',
      role: data.role || 'Asistente de automatización local', category: 'Agente Personalizado',
      model: data.model || 'DeepSeek-R1 (Local)', trigger: key,
      triggerType: info.type, intervalSeconds: info.seconds,
      governance: data.governance || 'autonomous', tools: data.tools || ['Web Search', 'Filesystem RAG'],
      status: 'active', isSystem: false, executions: 0, successRate: '100%',
      lastRun: 'Nunca', lastRunTimestamp: now,
    };
    this.agents.unshift(agent);
    this._saveAgents();
    this._pushLog(agent, `Despliegue con disparador "${agent.trigger}"`,
      `Inicializado. Gobernanza: ${agent.governance}. Herramientas: ${agent.tools.join(', ')}.`, '28ms');
    this.notify();
    return agent;
  }

  /** Pausa o reanuda un agente por su ID. */
  toggleAgentStatus(agentId) {
    const agent = this.agents.find((a) => a.id === agentId);
    if (!agent) return;
    agent.status = agent.status === 'active' ? 'paused' : 'active';
    this._saveAgents();
    this._pushLog(agent, `Estado → ${agent.status.toUpperCase()}`, `Ciclo de vida: ${agent.status}.`, '6ms');
    this.notify();
  }

  /** Elimina un agente del runtime y libera sus referencias. */
  deleteAgent(agentId) {
    const idx = this.agents.findIndex((a) => a.id === agentId);
    if (idx === -1) return;
    const [removed] = this.agents.splice(idx, 1);
    this._saveAgents();
    this._pushLog(removed, 'Agente eliminado del runtime',
      `"${removed.name}" desregistrado y recursos liberados.`, '4ms');
    this.notify();
  }

  /** Vacía el historial de logs de telemetría. */
  clearLogs() { this.logs = []; this._saveLogs(); this.notify(); }

  // ─── Utilidad interna de log ──────────────────────────────────────────────

  /** Construye y agrega una entrada de log al historial de telemetría. */
  _pushLog(agent, action, output, duration, status = 'ok', statusText = 'Éxito') {
    const now = Date.now();
    this.logs.unshift({ id: `log-${now}`, timestamp: now, time: formatRelativeTime(now),
      agentId: agent.id, agentName: agent.name, model: agent.model,
      action, output, duration, status, statusText });
    if (this.logs.length > 50) this.logs.pop();
    this._saveLogs();
  }
}

export const agentService = new AgentService();
