/**
 * automation_defaults.js — Datos por Defecto del Módulo de Automatización
 *
 * QUÉ HACE: Provee los agentes y logs iniciales SOLO cuando localStorage está
 *   vacío (primer arranque real del sistema).
 * CÓMO FUNCIONA: Funciones puras que retornan arrays de objetos; no tocan DOM
 *   ni storage — eso es responsabilidad de AgentService (SRP).
 * POR QUÉ: Los contadores históricos nacen en cero (executions: 0, successCount: 0,
 *   errorCount: 0) y lastRunTimestamp en null sin simular actividad inexistente.
 */

/**
 * Agentes del sistema incluidos en la instalación por defecto.
 * Representan los 4 agentes soberanos del NanoRuntime local, todos con
 * historial limpio (executions: 0, successCount: 0, errorCount: 0, lastRun: 'Nunca').
 * @returns {Object[]}
 */
export function getDefaultAgents() {
  return [
    {
      id: 'agent-memory-guardian',
      name: 'Memory Guardian & Auto-Eviction',
      role: 'Consulta la memoria RAM real del sistema; no ejecuta descargas automáticas.',
      category: 'Sistema Core',
      model: 'DeepSeek-R1 (Local)',
      trigger: 'Cada 1 minuto',
      triggerType: 'interval',
      intervalSeconds: 60,
      lastRunTimestamp: null,
      governance: 'autonomous',
      tools: ['Hardware Watcher'],
      searchQuery: '',
      status: 'paused',
      isSystem: true,
      executions: 0,
      successCount: 0,
      errorCount: 0,
      lastRun: 'Nunca',
    },
    {
      id: 'agent-event-router',
      name: 'Enrutador de Eventos & Notificaciones',
      role: 'Configuración pendiente: requiere conectar un productor real de notificaciones.',
      category: 'Gobernanza',
      model: 'Phi-3-mini',
      trigger: 'Al recibir notificación',
      triggerType: 'event',
      intervalSeconds: null,
      lastRunTimestamp: null,
      governance: 'approval',
      tools: ['RemoteInput', 'Shizuku Hook'],
      searchQuery: '',
      status: 'paused',
      isSystem: true,
      executions: 0,
      successCount: 0,
      errorCount: 0,
      lastRun: 'Nunca',
    },
    {
      id: 'agent-mcp-dispatcher',
      name: 'Servidor de Herramientas MCP Soberano',
      role: 'Consulta web conectada; archivos y terminal aún requieren un adaptador ejecutable.',
      category: 'Herramientas MCP',
      model: 'DeepSeek-R1-Distill-Qwen',
      trigger: 'Manual bajo demanda',
      triggerType: 'demand',
      intervalSeconds: null,
      lastRunTimestamp: null,
      governance: 'autonomous',
      tools: ['DuckDuckGo API', 'Filesystem RAG', 'Terminal'],
      searchQuery: '',
      status: 'paused',
      isSystem: true,
      executions: 0,
      successCount: 0,
      errorCount: 0,
      lastRun: 'Nunca',
    },
    {
      id: 'agent-code-auditor',
      name: 'Auditor Soberano de Código & Git',
      role: 'Inspecciona cambios de archivos en el workspace, analiza sintaxis y genera resúmenes periódicos.',
      category: 'Desarrollo',
      model: 'Llama-3.1-8B-Instruct',
      trigger: 'Cada 15 minutos',
      triggerType: 'interval',
      intervalSeconds: 900,
      lastRunTimestamp: null,
      governance: 'approval',
      tools: ['Git Status', 'AST Parser', 'Changelog'],
      searchQuery: '',
      status: 'paused',
      isSystem: false,
      executions: 0,
      successCount: 0,
      errorCount: 0,
      lastRun: 'Nunca',
    },
  ];
}

/** Sin ejecuciones observadas, el historial inicial está vacío. */
export function getDefaultLogs() {
  return [];
}
