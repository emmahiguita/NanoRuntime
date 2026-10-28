/**
 * local_model_api.js — Gestión del Ciclo de Vida de Modelos GGUF (< 200 LOC)
 *
 * QUÉ HACE: Gestiona el listado, activación (encendido), desactivación (apagado) y auto-selección
 *           de modelos GGUF locales tanto en Tauri IPC como en el servidor HTTP local.
 * CÓMO FUNCIONA: Comunica las órdenes reales al supervisor nativo (nano_activate_model / nano_deactivate_model)
 *                o a los endpoints REST (/api/local-models/activate y /deactivate) sin simulaciones.
 * POR QUÉ: SRP — Separa el ciclo de vida de archivos GGUF del cliente de transporte general.
 */

/**
 * QUÉ HACE: Obtiene el catálogo real de archivos GGUF desde el servidor HTTP Desktop.
 * CÓMO FUNCIONA: Consulta GET /api/local-models y sincroniza client.selectedModelPath si hay uno activo.
 * POR QUÉ: Evita inventar modelos de demostración cuando el directorio está vacío.
 */
export async function listLocalModels(client) {
  const response = await fetch(client.webBaseUrl + '/api/local-models', { signal: AbortSignal.timeout(10000) });
  if (!response.ok) throw new Error('Catálogo local no disponible: HTTP ' + response.status);
  const result = await response.json();
  if (!Array.isArray(result.models)) throw new Error('El catálogo devolvió un formato inválido.');
  const models = result.models.filter((m) => typeof m.path === 'string' && m.path && typeof m.name === 'string');
  const selected = models.find((m) => m.selected || m.is_loaded);
  if (selected) client.selectedModelPath = selected.path;
  return models;
}

/**
 * QUÉ HACE: Conecta y carga en memoria RAM el modelo local especificado por su ruta.
 * CÓMO FUNCIONA: En Tauri invoca 'nano_activate_model'; en modo HTTP invoca POST /api/local-models/activate.
 * POR QUÉ: Permite encender explícitamente o auto-activar el modelo antes de conversar o ejecutar agentes.
 */
export async function activateLocalModel(client, path) {
  if (!path || typeof path !== 'string') {
    throw new Error('Debes indicar una ruta de modelo GGUF válida.');
  }
  if (client.isTauri) {
    const models = await client.listModels();
    const model = models.find((m) => m.path === path || m.name === path || m.id === path);
    const targetPath = model ? model.path : path;
    await window.__TAURI__.core.invoke('nano_activate_model', { model: targetPath });
    client.selectedModelPath = targetPath;
    return model ? { ...model, is_loaded: true, selected: true } : { path: targetPath, name: targetPath, is_loaded: true, selected: true };
  }
  const response = await fetch(client.webBaseUrl + '/api/local-models/activate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: path }),
    signal: AbortSignal.timeout(15000),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || 'No se pudo activar el modelo local.');
  if (data.selected?.path !== path) throw new Error('El motor no confirmó el archivo seleccionado.');
  client.selectedModelPath = path;
  return data.selected;
}

/**
 * QUÉ HACE: Apaga el modelo local activo y libera la memoria RAM asociada.
 * CÓMO FUNCIONA: En Tauri invoca 'nano_deactivate_model'; en HTTP invoca POST /api/local-models/deactivate.
 * POR QUÉ: Permite al usuario apagar los modelos desde el Topbar, la vista de Modelos o por comando de chat.
 */
export async function deactivateLocalModel(client) {
  if (client.isTauri) {
    const res = await window.__TAURI__.core.invoke('nano_deactivate_model');
    client.selectedModelPath = '';
    return res;
  }
  const response = await fetch(client.webBaseUrl + '/api/local-models/deactivate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
    signal: AbortSignal.timeout(10000),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || 'No se pudo apagar el modelo local.');
  client.selectedModelPath = '';
  return data;
}

/**
 * QUÉ HACE: Garantiza que exista un modelo local conectado y activo cuando el usuario envía un mensaje o acción.
 * CÓMO FUNCIONA: Si no hay modelo seleccionado, consulta el catálogo real, elige el modelo cargado o el primero
 *                disponible en disco y lo activa automáticamente.
 * POR QUÉ: Cumple el requerimiento de auto-conexión al escribir o necesitar una acción sin pasos manuales previos.
 */
export async function ensureActiveLocalModel(client, preferredPath = '') {
  const candidatePath = (preferredPath || client.selectedModelPath || '').trim();
  if (candidatePath) {
    client.selectedModelPath = candidatePath;
    return candidatePath;
  }
  const models = await client.listModels();
  if (!Array.isArray(models) || models.length === 0) {
    throw new Error('No se encontraron archivos .gguf en la carpeta models/.');
  }
  const target = models.find((m) => m.is_loaded || m.selected) || models[0];
  await activateLocalModel(client, target.path);
  return target.path;
}
