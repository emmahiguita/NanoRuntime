/**
 * automation_defaults.js — Datos por Defecto del Módulo de Automatización
 *
 * QUÉ HACE: Provee los agentes y logs predeterminados al primer arranque del sistema.
 * CÓMO FUNCIONA: Funciones puras que retornan arrays de objetos.
 *   Se importan en AgentService solo cuando localStorage está vacío.
 * POR QUÉ: Separar datos de la lógica de servicio reduce agent_service.js
 *   y facilita cambiar los defaults sin tocar el motor de ejecución (SRP).
 */

/**
 * Agentes del sistema incluidos en la instalación por defecto.
 * Representan los 4 agentes soberanos del NanoRuntime local.
 * @returns {Object[]}
 */
export function getDefaultAgents() {
  const now = Date.now();
  return [
    {
      id: 'agent-memory-guardian',
      name: 'Memory Guardian & Auto-Eviction',
      role: 'Monitorea la presión de VRAM y aplica políticas TTL de descarga automática tras inactividad.',
      category: 'Sistema Core',
      model: 'DeepSeek-R1 (Local)',
      trigger: 'Cada 1 minuto',
      triggerType: 'interval',
      intervalSeconds: 60,
      lastRunTimestamp: now - 120000,
      governance: 'autonomous',
      tools: ['Hardware Watcher', 'VRAM Optimizer'],
      status: 'active',
      isSystem: true,
      executions: 248,
      successRate: '100%',
      lastRun: 'Hace 2m',
    },
    {
      id: 'agent-event-router',
      name: 'Enrutador de Eventos & Notificaciones',
      role: 'Escucha eventos entrantes del sistema y despacha respuestas asistidas con aprobación humana.',
      category: 'Gobernanza',
      model: 'Phi-3-mini',
      trigger: 'Al recibir notificación',
      triggerType: 'event',
      intervalSeconds: null,
      lastRunTimestamp: now - 720000,
      governance: 'approval',
      tools: ['RemoteInput', 'Shizuku Hook'],
      status: 'active',
      isSystem: true,
      executions: 84,
      successRate: '98.8%',
      lastRun: 'Hace 12m',
    },
    {
      id: 'agent-mcp-dispatcher',
      name: 'Servidor de Herramientas MCP Soberano',
      role: 'Expone capacidades soberanas para inspección de archivos, terminal sandboxed y consulta web en vivo.',
      category: 'Herramientas MCP',
      model: 'DeepSeek-R1-Distill-Qwen',
      trigger: 'Manual bajo demanda',
      triggerType: 'demand',
      intervalSeconds: null,
      lastRunTimestamp: now - 240000,
      governance: 'autonomous',
      tools: ['DuckDuckGo API', 'Filesystem RAG', 'Terminal'],
      status: 'active',
      isSystem: true,
      executions: 412,
      successRate: '99.5%',
      lastRun: 'Hace 4m',
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
      lastRunTimestamp: now - 3600000,
      governance: 'approval',
      tools: ['Git Status', 'AST Parser', 'Changelog'],
      status: 'paused',
      isSystem: false,
      executions: 36,
      successRate: '100%',
      lastRun: 'Hace 1h',
    },
  ];
}

/**
 * Logs de ejecución de demostración para el primer arranque.
 * @returns {Object[]}
 */
export function getDefaultLogs() {
  const now = Date.now();
  return [
    {
      id: 'log-default-1',
      timestamp: now - 120000,
      time: 'Hace 2m',
      agentName: 'Memory Guardian',
      agentId: 'agent-memory-guardian',
      model: 'DeepSeek-R1 (Local)',
      action: 'Comprobación de VRAM: 4.2 GB usados, 11.8 GB libres (26.3%). Sin desalojo.',
      output: 'Telemetría VRAM nominal. Política BALANCED (TTL 15m). Pesos de DeepSeek-R1 conservados en VRAM.',
      status: 'ok',
      statusText: 'Éxito',
      duration: '14ms',
    },
    {
      id: 'log-default-2',
      timestamp: now - 240000,
      time: 'Hace 4m',
      agentName: 'MCP Dispatcher',
      agentId: 'agent-mcp-dispatcher',
      model: 'DeepSeek-R1-Distill-Qwen',
      action: 'Búsqueda web en vivo (DuckDuckGo API): "Rust async runtimes"',
      output: 'Resultados encontrados: Tokio, async-std, smol. Contexto inyectado en prompt soberano.',
      status: 'ok',
      statusText: 'Éxito',
      duration: '340ms',
    },
    {
      id: 'log-default-3',
      timestamp: now - 720000,
      time: 'Hace 12m',
      agentName: 'Event Router',
      agentId: 'agent-event-router',
      model: 'Phi-3-mini',
      action: 'Hook entrante: Petición de lectura remota de logs',
      output: 'Acción de seguridad en espera de confirmación humana determinista.',
      status: 'pending',
      statusText: 'Requiere Aprobación',
      duration: 'En espera',
    },
  ];
}
