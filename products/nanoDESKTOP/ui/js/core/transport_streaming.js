/** Transporte real: errores visibles, controller por petición y sin mock automático. */
import { streamNativeChat } from './transport_native_stream.js';

/** Espera cancelable para dependencias que no admiten AbortSignal, sin inventar su cancelación. */
function waitWithSignal(promise, signal) {
  signal.throwIfAborted();
  return new Promise((resolve, reject) => {
    const abort = () => reject(signal.reason || new DOMException('Cancelada', 'AbortError'));
    signal.addEventListener('abort', abort, { once: true });
    promise.then(resolve, reject).finally(() => signal.removeEventListener('abort', abort));
  });
}

/** No cambia modelo ni sampler: conserva IPC o REST y comunica la causa real del fallo. */
export async function streamChatPrompt(client, {
  prompt, model = '', maxTokens = 512, webSearch = false, history = [], sessionId = null,
  attachedFiles = [], onToken = () => {}, onDone = () => {}, onError = () => {},
  requestId = null, signal = null,
}) {
  const reqId = requestId || crypto.randomUUID();
  if (client.activeControllers.has(reqId)) {
    onError(new Error('Ya hay una petición activa con este requestId.'));
    return;
  }
  const controller = new AbortController();
  client.activeControllers.set(reqId, controller);
  const forwardAbort = () => controller.abort(signal.reason);
  signal?.addEventListener('abort', forwardAbort, { once: true });
  if (signal?.aborted) forwardAbort();
  // Límite de seguridad, no promesa de latencia: impide una espera UI indefinida.
  const deadline = setTimeout(() => controller.abort(
    new DOMException('El runtime no terminó en 180 segundos.', 'TimeoutError')), 180000);
  const started = performance.now();
  try {
    controller.signal.throwIfAborted();
    if (!model) throw new Error('Selecciona un modelo local real antes de iniciar la conversación.');
    let webContext = '';
    // El modelo local no envía consultas a terceros si el usuario dejó Web apagado.
    if (webSearch) {
      const result = await waitWithSignal(client.searchWebKnowledge(prompt), controller.signal);
      if (result?.found) webContext = '\n[Fuente web: ' + result.source + ']\n' + result.snippet;
    }
    const attachments = attachedFiles.map((file) =>
      '\n[Archivo: ' + file.name + ']\n' + String(file.content || '').slice(0, 3000)).join('\n');
    const fullPrompt = (attachments + webContext + '\n' + prompt).trim();
    controller.signal.throwIfAborted();
    if (client.isTauri) {
      await streamNativeChat({ requestId: reqId, prompt: fullPrompt, model, maxTokens, history, sessionId,
        signal: controller.signal, onToken, onDone, started });
      return;
    }
    const response = await fetch(client.webBaseUrl + '/api/chat', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt: fullPrompt, model, max_tokens: maxTokens, history, session_id: sessionId || reqId }),
      signal: controller.signal,
    });
    const data = await response.json();
    if (!response.ok || data.error || data.tier === 'error' || data.status === 'error') {
      throw new Error(data.error || 'El runtime respondió HTTP ' + response.status + '.');
    }
    if (typeof data.response !== 'string' || !data.response.trim()) {
      throw new Error('El runtime devolvió una respuesta vacía o ilegible.');
    }
    const tokS = Number.isFinite(data.tok_s) && data.tok_s > 0 ? data.tok_s : null;
    // REST no ofrece SSE: entrega una sola respuesta, sin fingir tokens en vivo.
    onToken(data.response, { tok_s: tokS, buffered: true });
    controller.signal.throwIfAborted();
    onDone({ text: data.response, tok_s: tokS,
      time: ((performance.now() - started) / 1000).toFixed(2) + 's',
      model: data.model ?? data.model_name ?? null, tier: data.tier ?? null,
      confidence: data.confidence, buffered: true });
  } catch (error) {
    onError(error);
  } finally {
    clearTimeout(deadline);
    signal?.removeEventListener('abort', forwardAbort);
    if (client.activeControllers.get(reqId) === controller) client.activeControllers.delete(reqId);
  }
}
