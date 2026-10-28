import { transport } from '../../core/transport.js';
import { appState } from '../../core/state.js';

export class ChatService {
  constructor() {
    this.owlInstance = null;
  }

  setOwlInstance(owl) {
    this.owlInstance = owl;
  }

  /**
   * Invoca inferencia real; IPC transmite tokens y REST entrega una respuesta completa.
   */
  async sendMessage(text, attachedFiles = [], options = {}) {
    const trimmed = text.trim();
    if (!trimmed || appState.getState().isGenerating) return;

    const webEnabled = Boolean(options.web);
    const deepThinkEnabled = options.deepThink !== false;
    // Conserva turnos verificados y sus roles, sin incluir borradores o errores como memoria.
    const before = appState.getState();
    const sessionId = before.currentSessionId;
    const history = before.messages.filter((m) => !m.meta?.error && !m.meta?.isStreaming && m.text?.trim())
      .slice(-12).map((m) => ({ role: m.role, content: m.text }));

    // 1. Agregar mensaje del usuario a la sesión activa
    appState.addMessage('user', trimmed);
    appState.setState({ isGenerating: true });

    // 2. Transición del búho a estado thinking
    if (this.owlInstance) {
      this.owlInstance.setState('thinking');
    }

    // 3. Agregar burbuja de respuesta inicial del asistente
    const pending = appState.addMessage('assistant', 'Pensando...', {
      isStreaming: true,
      startTime: Date.now(),
      model: appState.getState().currentModel,
    });

    // Solo usa una ruta seleccionada; no inventa un nombre de archivo como fallback.
    const activeModel = appState.getState().currentModel || transport.selectedModelPath;

    try {
      // Iniciar estado thinking en el búho
      if (this.owlInstance) {
        this.owlInstance.setState('thinking');
      }

      // Mantiene roles y sesión tanto en IPC como en REST, sin mezclar conversaciones.
      await transport.chatPromptStream({
        prompt: trimmed,
        model: activeModel,
        maxTokens: 512,
        webSearch: webEnabled,
        deepThink: deepThinkEnabled,
        attachedFiles,
        history, sessionId,
        onToken: (chunk, meta) => {
          appState.appendStreamToken(chunk, sessionId, pending.id);
          // Transición suave a responding durante la generación continua
          if (this.owlInstance && this.owlInstance.currentState !== 'responding') {
            this.owlInstance.setState('responding');
          }
        },
        onDone: (meta) => {
          appState.updateLastMessage(meta.text || null, {
            isStreaming: false,
            tok_s: Number.isFinite(meta.tok_s) && meta.tok_s > 0 ? meta.tok_s.toFixed(1) : null,
            time: meta.time || null,
            model: meta.model || activeModel,
            buffered: meta.buffered === true,
          }, sessionId, pending.id);

          // Notificar al búho éxito: despliegue de alas y júbilo (owl_fly)
          if (this.owlInstance) {
            this.owlInstance.setState('success');
          }
        },
        onError: (err) => {
          appState.updateLastMessage(`[Error Runtime] No se pudo completar la inferencia: ${err.message}`, {
            error: true,
            isStreaming: false,
          }, sessionId, pending.id);

          if (this.owlInstance) {
            this.owlInstance.setState('error');
          }
        },
      });
    } catch (err) {
      appState.updateLastMessage(`[Error Inesperado] ${err.message}`, {
        error: true,
        isStreaming: false,
      }, sessionId, pending.id);

      if (this.owlInstance) {
        this.owlInstance.setState('error');
      }
    } finally {
      appState.setState({ isGenerating: false });
    }
  }
}

export const chatService = new ChatService();
