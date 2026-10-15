/** Adapta catálogo/activación reales; mantiene separadas rutas locales y nombres visibles. */

/** En web solo acepta el contrato del servidor Desktop; un array vacío no inventa modelos. */
export async function listLocalModels(client) {
  const response = await fetch(client.webBaseUrl + '/api/local-models', { signal: AbortSignal.timeout(10000) });
  if (!response.ok) throw new Error('Catálogo local no disponible: HTTP ' + response.status);
  const result = await response.json();
  if (!Array.isArray(result.models)) throw new Error('El catálogo devolvió un formato inválido.');
  const models = result.models.filter((m) => typeof m.path === 'string' && m.path && typeof m.name === 'string');
  const selected = models.find((m) => m.selected);
  if (selected) client.selectedModelPath = selected.path;
  return models;
}

/** Tauri carga al inferir; web confirma el modelo desde el proceso, no desde una etiqueta. */
export async function activateLocalModel(client, path) {
  if (client.isTauri) {
    const models = await client.listModels();
    const model = models.find((m) => m.path === path);
    if (!model) throw new Error('El archivo no pertenece al catálogo local.');
    client.selectedModelPath = path;
    return model;
  }
  const response = await fetch(client.webBaseUrl + '/api/local-models/activate', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: path }), signal: AbortSignal.timeout(15000),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || 'No se pudo activar el modelo local.');
  if (data.selected?.path !== path) throw new Error('El motor no confirmó el archivo seleccionado.');
  client.selectedModelPath = path;
  return data.selected;
}
