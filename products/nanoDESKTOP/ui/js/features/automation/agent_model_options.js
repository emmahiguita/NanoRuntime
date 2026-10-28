/** Pobla el selector con rutas devueltas por el catálogo nativo, no nombres ficticios. */
import { transport } from '../../core/transport.js';

export async function loadAgentModelOptions(select) {
  if (!select) return;
  select.disabled = true;
  try {
    const models = await transport.listModels();
    if (!select.isConnected) return;
    select.replaceChildren();
    // ModelEntry del IPC incluye name y path; el ejecutor necesita la ruta.
    for (const model of models) {
      if (typeof model.path !== 'string' || !model.path.trim()) continue;
      const option = document.createElement('option');
      option.value = model.path;
      option.textContent = model.name || model.path;
      select.append(option);
    }
    if (!select.options.length) {
      const option = document.createElement('option');
      option.value = '';
      option.textContent = 'Sin modelos locales detectados';
      select.append(option);
    }
  } catch (error) {
    console.warn('[Automation] Catálogo local no disponible:', error);
    select.replaceChildren(new Option('Catálogo no disponible', ''));
  } finally {
    select.disabled = false;
  }
}
