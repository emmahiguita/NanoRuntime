/**
 * automation_suite.test.mjs — Batería de Tests Exhaustivos de Automatización
 *
 * Cubre los 13 tests mínimos requeridos:
 * 1. Agente con solo Hardware Watcher → ejecuta hardware handler
 * 2. Agente con solo Web Search → ejecuta web handler
 * 3. Agente con Hardware Watcher + Web Search → ejecuta AMBOS
 * 4. Una herramienta falla, otra funciona → resultado parcial con salida válida conservada
 * 5. Dos agentes ejecutan chatPromptStream simultáneamente → AbortControllers no interfieren
 * 6. Abortar request A no cancela request B
 * 7. Agente antiguo sin successCount/errorCount carga correctamente
 * 8. successRate con cero ejecuciones devuelve '—'
 * 9. successRate después de éxitos y errores reales
 * 10. No se puede crear agente con name vacío (validación modal)
 * 11. No se puede crear agente con role vacío
 * 12. searchQuery personalizado tiene prioridad sobre role como query web
 * 13. Agente antiguo sin searchQuery sigue funcionando
 */

import assert from 'node:assert/strict';
import { runAgentTools } from '../ui/js/features/automation/agent_executor.js';
import { registerTool, resolveWebQuery, TOOL_REGISTRY } from '../ui/js/features/automation/tool_registry.js';
import { validateAgentInput } from '../ui/js/features/automation/automation_modals.js';
import { AgentService } from '../ui/js/features/automation/agent_service.js';
import { TransportClient } from '../ui/js/core/transport.js';

// Polyfill minimal de localStorage y window para entorno Node
const memoryStore = new Map();
globalThis.localStorage = {
  getItem: (k) => (memoryStore.has(k) ? memoryStore.get(k) : null),
  setItem: (k, v) => memoryStore.set(k, String(v)),
  removeItem: (k) => memoryStore.delete(k),
  clear: () => memoryStore.clear(),
};

function createMockTransport(overrides = {}) {
  return {
    getSystemStatus: async () => ({
      used_ram_mb: 4096,
      total_ram_mb: 16384,
      status: 'online',
    }),
    calculateModelFit: () => ({
      recommended_offload_layers: 28,
      ttl_policy: '60s',
    }),
    searchWebKnowledge: async (q) => ({
      found: true,
      source: 'DuckDuckGo Mock',
      snippet: `Resultados simulados para query: ${q}`,
    }),
    generateText: async ({ prompt, model_path }) => ({
      text: `Respuesta de modelo ${model_path} para ${prompt.slice(0, 30)}`,
    }),
    isQueryDemandingWeb: () => false,
    ...overrides,
  };
}

let passed = 0;
let failed = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`  ✓ PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  ✕ FAIL: ${name}`);
    console.error(err);
    failed++;
  }
}

console.log('\n--- INICIANDO SUITE DE TESTS AUTOMATIZACIÓN NANOAI ---\n');

// 1. Agente con solo Hardware Watcher → ejecuta hardware handler
await test('1. Agente con solo Hardware Watcher ejecuta hardware handler', async () => {
  const agent = {
    id: 'agent-1',
    name: 'Hardware Inspector',
    role: 'Inspect hardware',
    tools: ['Hardware Watcher'],
  };
  let hardwareCalled = false;
  const mockTransport = createMockTransport({
    getSystemStatus: async () => {
      hardwareCalled = true;
      return { used_ram_mb: 2048, total_ram_mb: 8192 };
    },
  });

  const res = await runAgentTools(agent, mockTransport);
  assert.equal(hardwareCalled, true);
  assert.equal(res.status, 'ok');
  assert.match(res.actionSummary, /Memoria RAM/);
  assert.match(res.detailedOutput, /RAM medida: 2048 MB de 8192 MB/);
});

// 2. Agente con solo Web Search → ejecuta web handler
await test('2. Agente con solo Web Search ejecuta web handler', async () => {
  const agent = {
    id: 'agent-2',
    name: 'Web Researcher',
    role: 'Search web',
    tools: ['Web Search'],
  };
  let webQueryReceived = null;
  const mockTransport = createMockTransport({
    searchWebKnowledge: async (q) => {
      webQueryReceived = q;
      return { found: true, source: 'TestWeb', snippet: 'Result 123' };
    },
  });

  const res = await runAgentTools(agent, mockTransport);
  assert.equal(res.status, 'ok');
  assert.equal(webQueryReceived, 'Web Researcher');
  assert.match(res.actionSummary, /Búsqueda Web/);
  assert.match(res.detailedOutput, /Búsqueda web/);
});

// 3. Agente con Hardware Watcher + Web Search → ejecuta AMBOS
await test('3. Agente con Hardware Watcher + Web Search ejecuta AMBOS', async () => {
  const agent = {
    id: 'agent-3',
    name: 'Hybrid Agent',
    role: 'Hardware and Web inspector',
    tools: ['Hardware Watcher', 'Web Search'],
  };
  let hwCalled = false;
  let webCalled = false;
  const mockTransport = createMockTransport({
    getSystemStatus: async () => { hwCalled = true; return { used_ram_mb: 1024, total_ram_mb: 4096 }; },
    searchWebKnowledge: async () => { webCalled = true; return { found: true, snippet: 'Info' }; },
  });

  const res = await runAgentTools(agent, mockTransport);
  assert.equal(hwCalled, true, 'Hardware debe ser ejecutado');
  assert.equal(webCalled, true, 'Web debe ser ejecutado');
  assert.equal(res.status, 'ok');
  assert.match(res.actionSummary, /Memoria RAM/);
  assert.match(res.actionSummary, /Búsqueda Web/);
  assert.match(res.detailedOutput, /\[Hardware Watcher\]/);
  assert.match(res.detailedOutput, /\[Web Search\]/);
});

// 4. Una herramienta falla, otra funciona → resultado parcial con salida válida conservada
await test('4. Una herramienta falla y otra funciona -> partial_success y conserva salida válida', async () => {
  const agent = {
    id: 'agent-4',
    name: 'Partial Agent',
    role: 'Test partial',
    tools: ['Hardware Watcher', 'Web Search'],
  };
  const mockTransport = createMockTransport({
    getSystemStatus: async () => {
      throw new Error('Sensor hardware desconectado');
    },
    searchWebKnowledge: async () => ({ found: true, snippet: 'Respuesta web válida' }),
  });

  const res = await runAgentTools(agent, mockTransport);
  assert.equal(res.status, 'partial_success');
  assert.equal(res.statusText, 'Éxito parcial');
  assert.match(res.actionSummary, /Fallo en Hardware Watcher/);
  assert.match(res.actionSummary, /Búsqueda Web/);
  assert.match(res.detailedOutput, /Respuesta web válida/);
  assert.match(res.detailedOutput, /Sensor hardware desconectado/);
});

// 5. Dos agentes ejecutan chatPromptStream simultáneamente → AbortControllers no interfieren
await test('5. Dos ejecuciones simultáneas de chatPromptStream no interfieren en AbortControllers', async () => {
  const transport = new TransportClient();
  transport.selectedModelPath = 'fixture.gguf';
  globalThis.fetch = async (_url, {signal}) => {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(resolve, 15);
      signal.addEventListener('abort', () => { clearTimeout(timer); reject(signal.reason); }, {once:true});
    });
    return {ok:true, json:async () => ({response:'Respuesta de prueba'})};
  };
  const tokenEventsA = [];
  const tokenEventsB = [];

  let doneA = false;
  let doneB = false;

  const promiseA = new Promise((resolve) => {
    transport.chatPromptStream({
      prompt: 'Prompt A',
      requestId: 'req-A',
      onToken: (tok) => tokenEventsA.push(tok),
      onDone: () => { doneA = true; resolve(); },
    });
  });

  const promiseB = new Promise((resolve) => {
    transport.chatPromptStream({
      prompt: 'Prompt B',
      requestId: 'req-B',
      onToken: (tok) => tokenEventsB.push(tok),
      onDone: () => { doneB = true; resolve(); },
    });
  });

  assert.equal(transport.activeControllers.has('req-A'), true);
  assert.equal(transport.activeControllers.has('req-B'), true);
  assert.notEqual(transport.activeControllers.get('req-A'), transport.activeControllers.get('req-B'));

  await Promise.all([promiseA, promiseB]);
  assert.equal(doneA, true);
  assert.equal(doneB, true);
  assert.equal(transport.activeControllers.size, 0, 'Cleaned up in finally');
});

// 6. Abortar request A no cancela request B
await test('6. Abortar request A no cancela request B', async () => {
  const transport = new TransportClient();
  transport.selectedModelPath = 'fixture.gguf';
  globalThis.fetch = async (_url, {signal}) => {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(resolve, 15);
      signal.addEventListener('abort', () => { clearTimeout(timer); reject(signal.reason); }, {once:true});
    });
    return {ok:true, json:async () => ({response:'Respuesta de prueba'})};
  };
  let errorA = null;
  let doneB = false;

  const promiseA = new Promise((resolve) => {
    transport.chatPromptStream({
      prompt: 'Long task A',
      requestId: 'req-A-cancel',
      onError: (err) => { errorA = err; resolve(); },
      onDone: () => resolve(),
    });
  });

  const promiseB = new Promise((resolve) => {
    transport.chatPromptStream({
      prompt: 'Independent task B',
      requestId: 'req-B-keep',
      onDone: () => { doneB = true; resolve(); },
      onError: (err) => resolve(),
    });
  });

  // Cancelar específicamente A
  const abortedA = transport.abort('req-A-cancel');
  assert.equal(abortedA, true);

  await Promise.all([promiseA, promiseB]);

  assert.ok(errorA, 'Request A debe haber recibido error de abort');
  assert.equal(errorA.name, 'AbortError');
  assert.equal(doneB, true, 'Request B debe haber concluido exitosamente sin afectación');
});

// 7. Agente antiguo sin successCount/errorCount carga correctamente
await test('7. Agente antiguo sin successCount/errorCount carga correctamente con normalización', () => {
  memoryStore.clear();
  const legacyAgent = {
    id: 'legacy-1',
    name: 'Agente Antiguo',
    role: 'V1 agent',
    executions: 5,
    // Sin successCount, sin errorCount, sin searchQuery
  };
  memoryStore.set('nano_desktop_agents_v2', JSON.stringify([legacyAgent]));

  const service = new AgentService();
  service.stopDaemon();

  const loaded = service.agents.find((a) => a.id === 'legacy-1');
  assert.ok(loaded);
  assert.equal(loaded.successCount, 0);
  assert.equal(loaded.errorCount, 0);
  assert.equal(loaded.searchQuery, '');
  assert.equal(loaded.executions, 5);
});

// 8. successRate con cero ejecuciones devuelve '—'
await test('8. successRate con cero ejecuciones devuelve "—"', () => {
  memoryStore.clear();
  const service = new AgentService();
  service.stopDaemon();

  const agentZero = service.createAgent({
    name: 'Zero Exec Agent',
    role: 'Waiting to run',
  });

  assert.equal(agentZero.executions, 0);
  assert.equal(agentZero.successRate, '—');
});

// 9. successRate después de éxitos y errores reales
await test('9. successRate después de éxitos y errores reales', () => {
  memoryStore.clear();
  const service = new AgentService();
  service.stopDaemon();

  const testAgent = service._normalizeAgent({
    id: 'calc-agent',
    name: 'Calculation Agent',
    executions: 4,
    successCount: 3,
    errorCount: 1,
  });

  assert.equal(testAgent.successRate, '75%');

  testAgent.executions = 2;
  testAgent.successCount = 1;
  assert.equal(testAgent.successRate, '50%');

  testAgent.executions = 1;
  testAgent.successCount = 1;
  testAgent.errorCount = 0;
  assert.equal(testAgent.successRate, '100%');
});

// 10. No se puede crear agente con name vacío (validación modal)
await test('10. Validación rechaza creación con name vacío', () => {
  const resultEmpty = validateAgentInput({ name: '   ', role: 'Role válido' });
  assert.equal(resultEmpty.isValid, false);
  assert.ok(resultEmpty.errors.name);

  const resultTooLong = validateAgentInput({ name: 'a'.repeat(81), role: 'Role válido' });
  assert.equal(resultTooLong.isValid, false);
  assert.match(resultTooLong.errors.name, /80 caracteres/);
});

// 11. No se puede crear agente con role vacío
await test('11. Validación rechaza creación con role vacío', () => {
  const resultEmptyRole = validateAgentInput({ name: 'Nombre Válido', role: '   ' });
  assert.equal(resultEmptyRole.isValid, false);
  assert.ok(resultEmptyRole.errors.role);

  const resultTooLongRole = validateAgentInput({ name: 'Nombre Válido', role: 'a'.repeat(401) });
  assert.equal(resultTooLongRole.isValid, false);
  assert.match(resultTooLongRole.errors.role, /400 caracteres/);
});

// 12. searchQuery personalizado tiene prioridad sobre role como query web
await test('12. searchQuery personalizado tiene prioridad sobre name y role', () => {
  const agentWithAll = {
    name: 'Nombre Agente',
    role: 'Rol muy extenso que no debe usarse si existe searchQuery',
    searchQuery: 'mi query personalizada de búsqueda',
  };
  assert.equal(resolveWebQuery(agentWithAll), 'mi query personalizada de búsqueda');

  const agentWithoutQuery = {
    name: 'Nombre Agente',
    role: 'Rol descriptivo',
    searchQuery: '',
  };
  assert.equal(resolveWebQuery(agentWithoutQuery), 'Nombre Agente');

  const agentOnlyRole = {
    name: '',
    role: 'Rol usado cuando name está vacío',
  };
  assert.equal(resolveWebQuery(agentOnlyRole), 'Rol usado cuando name está vacío');
});

// 13. Agente antiguo sin searchQuery sigue funcionando
await test('13. Agente antiguo sin searchQuery sigue funcionando perfectamente', async () => {
  const legacyAgent = {
    id: 'legacy-search',
    name: 'Old Searcher',
    role: 'Buscar novedades del sistema',
    tools: ['Web Search'],
  };
  let querySent = null;
  const mockTransport = createMockTransport({
    searchWebKnowledge: async (q) => {
      querySent = q;
      return { found: true, snippet: 'Legacy OK' };
    },
  });

  const res = await runAgentTools(legacyAgent, mockTransport);
  assert.equal(res.status, 'ok');
  assert.equal(querySent, 'Old Searcher');
  assert.match(res.detailedOutput, /Legacy OK/);
});

// Test 14 (Extra - Preparación Nano Negocio y Gobernanza)
await test('14. Arquitectura extensible permite registrar nueva herramienta de negocio y ejecutarla', async () => {
  let lookupCalled = false;
  registerTool('customer.lookup', {
    type: 'READ_ONLY',
    execute: async (agent, context) => {
      lookupCalled = true;
      return {
        summary: `Cliente consultado para ${agent.name}`,
        output: 'ID: 9942, Nombre: Empresa ABC',
        elapsedMs: 12,
        error: null,
      };
    },
  });

  const bizAgent = {
    name: 'CRM Agent',
    tools: ['customer.lookup'],
  };

  const res = await runAgentTools(bizAgent, createMockTransport());
  assert.equal(lookupCalled, true);
  assert.equal(res.status, 'ok');
  assert.match(res.actionSummary, /Cliente consultado/);
});

console.log(`\n========================================`);
console.log(`RESULTADOS: ${passed} PASADOS, ${failed} FALLADOS`);
console.log(`========================================\n`);

// Detener el daemon del singleton global para liberar el event loop
import('../ui/js/features/automation/agent_service.js').then(({ agentService }) => {
  agentService.stopDaemon();
  process.exit(failed > 0 ? 1 : 0);
});

