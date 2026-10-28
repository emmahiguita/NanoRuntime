/**
 * chat_intent_router.js — Enrutador de Intenciones y Contexto Funcional del Chat (< 200 LOC)
 *
 * QUÉ HACE:
 *   1. Detecta comandos e intenciones operativas directas del usuario en el chat (encender/conectar
 *      modelo, apagar modelo, consultar telemetría real, ejecutar agentes de automatización o abrir vistas).
 *   2. Construye el contexto funcional real del sistema para que el modelo local GGUF conozca sus
 *      capacidades dentro de NanoAI Studio Desktop sin alucinar métricas ni funciones inexistentes.
 *
 * CÓMO FUNCIONA:
 *   Evalúa expresiones regulares deterministas sobre el mensaje de entrada y, si corresponde a una
 *   acción del sistema, invoca los servicios reales (`systemService`, `agentService`, `transport`).
 *
 * POR QUÉ:
 *   Aplicando SRP y Clean Architecture, separa la orquestación de acciones del sistema respecto al
 *   transporte de streaming de tokens en `chat_service.js`.
 */
import { transport } from '../../core/transport.js';
import { appState } from '../../core/state.js';
import { systemService } from '../system/system_service.js';
import { agentService } from '../automation/agent_service.js';

/**
 * QUÉ HACE: Evalúa si el mensaje del usuario solicita una acción directa sobre el motor o la app.
 * CÓMO FUNCIONA: Retorna `{ handled: true, responseText }` si ejecutó la acción real, o `{ handled: false }`.
 * POR QUÉ: Permite que el usuario controle el encendido/apagado de modelos y agentes desde el propio chat.
 */
export async function tryExecuteChatAction(rawText) {
  const text = (rawText || '').trim();
  const lower = text.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');

  // 1. Apagar / desconectar modelo local (liberar RAM)
  if (
    /^\/(apagar|off|unload|desactivar)\b/.test(lower) ||
    /\b(apaga|apagar|desactiva|desactivar|desconecta|desconectar)\s+(el\s+|los\s+)?(modelo|modelos|motor)\b/.test(lower)
  ) {
    await systemService.deactivateModel();
    const tel = appState.getState().telemetry;
    const ramInfo = tel?.available_ram_mb
      ? `RAM libre actual: **${tel.available_ram_mb.toLocaleString()} MB** de **${tel.total_ram_mb.toLocaleString()} MB**.`
      : 'Memoria del proceso liberada.';
    return {
      handled: true,
      responseText: `**Modelo local apagado correctamente.**\n- Estado del motor: Desconectado (0 modelos en RAM).\n- ${ramInfo}\n- Cuando vuelvas a escribir una consulta o uses \`/activar\`, el modelo se reconectará automáticamente.`,
    };
  }

  // 2. Activar / encender / conectar modelo local
  if (
    /^\/(activar|on|conectar|load)\b/.test(lower) ||
    /\b(activa|activar|enciende|encender|conecta|conectar|carga|cargar)\s+(el\s+|los\s+)?(modelo|modelos|motor)\b/.test(lower)
  ) {
    const path = await transport.ensureActiveModel();
    const selected = await systemService.activateModel(path);
    const name = selected?.name || path.split(/[\\/]/).pop();
    return {
      handled: true,
      responseText: `**Modelo local conectado y activo en RAM.**\n- Modelo: **${name}**\n- Ruta verificada: \`${path}\`\n- Estado: Listo para inferencia local y puente Nano Mobile.`,
    };
  }

  // 3. Consultar estado y telemetría real del sistema
  if (
    /^\/(estado|status|telemetria|sistema)\b/.test(lower) ||
    /^(estado del sistema|ver telemetria|como esta el sistema)$/.test(lower)
  ) {
    const [tel, models] = await Promise.all([
      systemService.refreshTelemetry(),
      systemService.loadModels(),
    ]);
    const activeModel = models.find((m) => m.is_loaded || m.selected);
    const usedMb = tel?.used_ram_mb != null ? `${tel.used_ram_mb.toLocaleString()} MB` : 'N/A';
    const totalMb = tel?.total_ram_mb != null ? `${tel.total_ram_mb.toLocaleString()} MB` : 'N/A';
    const activeAgents = agentService.agents.filter((a) => a.status === 'active' || a.status === 'executing').length;
    return {
      handled: true,
      responseText: [
        '**Estado Real de NanoAI Studio Desktop:**',
        `- **Sistema Operativo:** ${tel?.os_name || 'Windows'} (${tel?.arch || 'x86_64'})`,
        `- **Memoria RAM medida:** ${usedMb} en uso / ${totalMb} totales`,
        `- **Modelo GGUF seleccionado:** ${activeModel ? `${activeModel.name} (${activeModel.is_loaded ? 'Activo en RAM' : 'Listo para auto-conexión'})` : 'Ninguno activo'}`,
        `- **Catálogo en disco:** ${models.length} archivo(s) .gguf detectado(s)`,
        `- **Agentes de Automatización activos:** ${activeAgents} de ${agentService.agents.length}`,
      ].join('\n'),
    };
  }

  // 4. Ejecutar agentes de automatización reales
  if (
    /^\/(automatizacion|agentes|ejecutar)\b/.test(lower) ||
    /\b(ejecuta|ejecutar|corre|correr|inicia|iniciar)\s+(los\s+)?(agentes|automatizaciones)\b/.test(lower)
  ) {
    const agents = agentService.agents;
    if (!agents.length) {
      return {
        handled: true,
        responseText: 'No hay agentes configurados todavía. Abre el módulo **Automatizaciones** en la barra lateral para crear uno.',
      };
    }
    const target = agents.find((a) => a.status === 'active') || agents[0];
    await agentService.executeAgent(target.id, true);
    const latestLog = agentService.logs[0];
    return {
      handled: true,
      responseText: [
        `**Agente ejecutado:** ${target.name}`,
        `- **Estado:** ${latestLog?.statusText || 'Completado'}`,
        `- **Resumen:** ${latestLog?.action || 'Ejecución finalizada'}`,
        latestLog?.output ? `\n\`\`\`text\n${latestLog.output}\n\`\`\`` : '',
      ].filter(Boolean).join('\n'),
    };
  }

  // 5. Ayuda / funciones integradas
  if (
    /^\/(ayuda|help|funciones|comandos)\b/.test(lower) ||
    /\b(cuales son tus funciones|que funciones tienes|que puedes hacer en nano)\b/.test(lower)
  ) {
    return {
      handled: true,
      responseText: [
        '**Funciones reales integradas en NanoAI Studio Desktop:**',
        '1. **Inferencia Local GGUF Auto-Conectada:** Al escribir cualquier consulta, conecto y activo automáticamente el modelo local `.gguf` disponible.',
        '2. **Control de Encendido/Apagado de Modelos:** Escribe `apaga el modelo` (`/apagar`) para liberar RAM o `activa el modelo` (`/activar`) para cargarlo.',
        '3. **Telemetría Real de Hardware:** Escribe `/estado` para consultar RAM medida por el kernel y estado del catálogo GGUF.',
        '4. **Automatización con Agentes:** Escribe `ejecuta los agentes` (`/automatizacion`) para correr herramientas reales (`Hardware Watcher`, `Web Search` e inferencia local).',
        '5. **Puente LAN / Nano Mobile:** Expongo `/completion`, `/api/viability` y `/v1/chat/completions` para conectar Nano Mobile.',
      ].join('\n'),
    };
  }

  return { handled: false, responseText: '' };
}

/**
 * QUÉ HACE: Construye una cabecera breve con datos verificados del entorno para enriquecer el prompt si el usuario pregunta sobre el sistema.
 * CÓMO FUNCIONA: Solo se adjunta cuando la consulta menciona a NanoAI, modelos, memoria, agentes o funciones del sistema.
 * POR QUÉ: Evita sobrecargar prompts cortos de conversación general y a la vez impide que el modelo alucine capacidades cuando le preguntan por sus funciones.
 */
export function buildFunctionalPrompt(userPrompt) {
  const lower = (userPrompt || '').toLowerCase();
  const asksAboutSystem = /\b(nano|modelo|modelos|ram|memoria|agente|agentes|automatizaci|funcion|funciones|puedes hacer|sistema|mobile|whatsapp)\b/.test(lower);
  if (!asksAboutSystem) return userPrompt;

  const state = appState.getState();
  const tel = state.telemetry || {};
  const modelName = (state.currentModel || transport.selectedModelPath || 'Qwen GGUF local').split(/[\\/]/).pop();
  const ramText = tel.used_ram_mb && tel.total_ram_mb
    ? `${tel.used_ram_mb} MB usados de ${tel.total_ram_mb} MB`
    : 'lectura disponible en módulo Modelos';
  const agentsCount = agentService.agents.length;

  return `[Contexto verificado de NanoAI Studio Desktop: Ejecutando modelo local ${modelName}. RAM del sistema: ${ramText}. Agentes configurados: ${agentsCount}. Comandos soportados en chat: /activar, /apagar, /estado, /automatizacion, /ayuda. Responde en español con precisión y sin inventar datos.]\n\n${userPrompt}`;
}
