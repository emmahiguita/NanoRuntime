/** Streaming IPC real: misma identidad que el controller y limpieza por petición. */
export async function streamNativeChat({ requestId, prompt, model, maxTokens, history, sessionId, signal, onToken, onDone, started }) {
  const { invoke } = window.__TAURI__.core;
  const { listen } = window.__TAURI__.event;
  const listeners = [];
  let resolveDone, rejectDone;
  const done = new Promise((resolve, reject) => { resolveDone = resolve; rejectDone = reject; });
  // Evita un rechazo sin consumidor si falla registrar un listener posterior.
  done.catch(() => {});
  const abort = () => rejectDone(signal.reason || new DOMException('Cancelada', 'AbortError'));
  signal.addEventListener('abort', abort, { once: true });
  try {
    signal.throwIfAborted();
    listeners.push(await listen('chat-token', (event) => {
      if (signal.aborted || event.payload?.request_id !== requestId) return;
      try { onToken(event.payload.token, { elapsed: (performance.now() - started) / 1000 }); }
      catch (error) { rejectDone(error); }
    }));
    signal.throwIfAborted();
    listeners.push(await listen('chat-done', (event) => {
      if (event.payload?.request_id === requestId) resolveDone(event.payload);
    }));
    signal.throwIfAborted();
    listeners.push(await listen('chat-error', (event) => {
      if (event.payload?.request_id === requestId) rejectDone(new Error(event.payload.message));
    }));
    signal.throwIfAborted();
    // invoke confirma inicio; solo chat-done confirma la respuesta del modelo.
    invoke('nano_chat_prompt_stream', {
      input: { prompt, model_path: model, max_tokens: maxTokens, request_id: requestId,
        history, session_id: sessionId || requestId },
    }).catch(rejectDone);
    const payload = await done;
    signal.throwIfAborted();
    if (!payload.text?.trim()) throw new Error('El runtime devolvió una respuesta vacía.');
    onDone({ text: payload.text, tok_s: payload.tok_s ?? null,
      time: ((performance.now() - started) / 1000).toFixed(2) + 's', model: payload.model });
  } finally {
    signal.removeEventListener('abort', abort);
    listeners.forEach((unsubscribe) => unsubscribe());
    // El backend actual no ofrece cancelación por ID: no fingir que detuvo la inferencia.
    if (signal.aborted) console.warn('[Transport] Escucha cancelada; detención nativa no confirmada:', requestId);
  }
}
