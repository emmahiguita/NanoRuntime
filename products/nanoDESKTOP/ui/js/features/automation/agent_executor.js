/**
 * agent_executor.js — Orquestador de Ejecución Multi-Tool Soberano (< 150 LOC)
 *
 * QUÉ HACE: Orquesta la ejecución de TODAS las herramientas configuradas para un
 *   agente soberano, soportando concurrencia de herramientas READ_ONLY y
 *   ejecución secuencial para herramientas de ACCIÓN/MODELO.
 * CÓMO FUNCIONA:
 *   1. Resuelve las herramientas del agente desde `TOOL_REGISTRY`.
 *   2. Agrupa por tipo: READ_ONLY (concurrentes con Promise.all) y secuenciales.
 *   3. Si una falla y otra tiene éxito → 'partial_success' preservando salidas válidas.
 *   4. Si solo corre una herramienta, mantiene la salida idéntica al contrato previo.
 * POR QUÉ: Evita el anterior cuello de botella if/else que ignoraba herramientas
 *   secundarias y cumple SRP delegando los handlers a tool_registry.js.
 */

import { transport as defaultTransport } from '../../core/transport.js';
import { TOOL_REGISTRY } from './tool_registry.js';

/**
 * Resuelve las definiciones de herramientas para un agente deduplicando por groupId.
 * @param {Object} agent
 * @returns {Array<Object>} Lista de definiciones de herramientas a ejecutar
 */
export function resolveAgentTools(agent) {
  const toolsList = Array.isArray(agent?.tools) ? agent.tools : [];
  const resolved = [];
  const seenGroups = new Set();

  for (const toolName of toolsList) {
    const def = TOOL_REGISTRY.get(toolName);
    // Una capacidad desconocida falla explícitamente; no se sustituye por otra.
    if (!def) {
      resolved.push({ name: toolName, type: 'READ_ONLY', groupId: toolName,
        execute: async () => { throw new Error('Herramienta no conectada: ' + toolName); } });
      continue;
    }
    if (def && !seenGroups.has(def.groupId)) {
      seenGroups.add(def.groupId);
      resolved.push(def);
    }
  }

  // Fallback si no hay herramientas reconocidas configuradas
  if (resolved.length === 0) {
    const fallbackDef = TOOL_REGISTRY.get('LLM Fallback');
    if (fallbackDef) resolved.push(fallbackDef);
  }

  return resolved;
}

/**
 * Ejecuta con seguridad una herramienta individual capturando excepciones runtime.
 */
async function executeSingleTool(toolDef, agent, context) {
  const start = performance.now();
  try {
    context.signal?.throwIfAborted();
    if ((toolDef.requiresApproval || toolDef.type === 'ACTION') && !context.approved) {
      throw new Error('Esta herramienta requiere aprobación previa.');
    }
    const res = await toolDef.execute(agent, context);
    context.signal?.throwIfAborted();
    return {
      name: toolDef.name,
      summary: res.summary || `${toolDef.name}: Ejecutado`,
      output: res.output || res.detail || '',
      elapsedMs: Math.round(performance.now() - start),
      error: res.error || null,
    };
  } catch (err) {
    return {
      name: toolDef.name,
      summary: `Fallo en ${toolDef.name}: ${err.message}`,
      output: `[Error en ${toolDef.name}]\n${err.message}`,
      elapsedMs: Math.round(performance.now() - start),
      error: err,
    };
  }
}

/**
 * Ejecuta TODAS las herramientas del agente y combina sus resultados.
 * @param {Object} agent - Agente con su configuración y herramientas
 * @param {Object} [customTransport] - Transporte opcional para pruebas/mocking
 * @returns {Promise<{actionSummary: string, detailedOutput: string, status: string, statusText: string, elapsedMs: number}>}
 */
export async function runAgentTools(agent, customTransport = null, options = {}) {
  const startTime = performance.now();
  const context = {
    transport: customTransport || defaultTransport,
    executionId: `exec-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`,
    timestamp: Date.now(),
    signal: options.signal, approved: options.approved === true, previousResults: [],
  };

  const toolsToRun = resolveAgentTools(agent);
  const readOnlyTools = toolsToRun.filter((t) => t.type === 'READ_ONLY');
  const sequentialTools = toolsToRun.filter((t) => t.type !== 'READ_ONLY');

  // Ejecución concurrente para herramientas READ_ONLY
  const readOnlyPromises = readOnlyTools.map((t) => executeSingleTool(t, agent, context));
  const readOnlyResults = await Promise.all(readOnlyPromises);
  context.signal?.throwIfAborted();
  context.previousResults = readOnlyResults;

  // Ejecución secuencial para herramientas con efectos secundarios o de modelo
  const sequentialResults = [];
  for (const toolDef of sequentialTools) {
    const res = await executeSingleTool(toolDef, agent, context);
    sequentialResults.push(res);
    context.previousResults = [...readOnlyResults, ...sequentialResults];
    context.signal?.throwIfAborted();
  }

  const results = [...readOnlyResults, ...sequentialResults];
  const totalElapsed = Math.round(performance.now() - startTime);

  if (results.length === 0) {
    return {
      actionSummary: `Sin acciones para ${agent?.name || 'Agente'}`,
      detailedOutput: 'No se encontraron herramientas ejecutables configuradas.',
      status: 'error',
      statusText: 'Sin Acciones',
      elapsedMs: totalElapsed,
      success: false, toolResults: [],
    };
  }

  const successCount = results.filter((r) => !r.error).length;
  const failureCount = results.length - successCount;

  let status = 'ok';
  let statusText = 'Éxito';
  if (failureCount === results.length) {
    status = 'error';
    statusText = 'Error';
  } else if (failureCount > 0) {
    status = 'partial_success';
    statusText = 'Éxito parcial';
  }

  // Si solo hay un resultado, conservamos compatibilidad exacta 1:1 con el formato previo
  if (results.length === 1) {
    return {
      actionSummary: results[0].summary,
      detailedOutput: results[0].output,
      status,
      statusText,
      elapsedMs: totalElapsed,
      success: status === 'ok', toolResults: results,
    };
  }

  // Si hay múltiples herramientas, consolidamos con prefijos claros por herramienta
  return {
    actionSummary: results.map((r) => r.summary).join(' | '),
    detailedOutput: results.map((r) => `[${r.name}]\n${r.output}`).join('\n\n'),
    status,
    statusText,
    elapsedMs: totalElapsed,
    success: status === 'ok', toolResults: results,
  };
}
