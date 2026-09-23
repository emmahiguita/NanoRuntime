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
   * Envía un mensaje del usuario e invoca la inferencia con streaming en tiempo real.
   */
  async sendMessage(text, attachedFiles = [], options = {}) {
    const trimmed = text.trim();
    if (!trimmed || appState.getState().isGenerating) return;

    const webEnabled = Boolean(options.web);
    const deepThinkEnabled = options.deepThink !== false;

    // 1. Agregar mensaje del usuario a la sesión activa
    appState.addMessage('user', trimmed);
    appState.setState({ isGenerating: true });

    // 2. Transición del búho a estado thinking
    if (this.owlInstance) {
      this.owlInstance.setState('thinking');
    }

    // 3. Agregar burbuja de respuesta inicial del asistente
    appState.addMessage('assistant', 'Pensando...', {
      isStreaming: true,
      startTime: Date.now(),
      model: appState.getState().currentModel,
    });

    // Obtiene el modelo activo del estado global o usa el fallback por defecto
    const activeModel = appState.getState().currentModel || 'qwen.gguf';

    try {
      // Iniciar estado thinking en el búho
      if (this.owlInstance) {
        this.owlInstance.setState('thinking');
      }

      // Invoca el transporte hacia el backend (Tauri IPC o REST) transmitiendo tokens en tiempo real
      await transport.chatPromptStream({
        prompt: trimmed,
        model: activeModel,
        maxTokens: 512,
        webSearch: webEnabled,
        deepThink: deepThinkEnabled,
        attachedFiles,
        onToken: (chunk, meta) => {
          appState.appendStreamToken(chunk);
          // Transición suave a responding durante la generación continua
          if (this.owlInstance && this.owlInstance.currentState !== 'responding') {
            this.owlInstance.setState('responding');
          }
        },
        onDone: (meta) => {
          appState.updateLastMessage(null, {
            isStreaming: false,
            tok_s: meta.tok_s ? meta.tok_s.toFixed(1) : '0.0',
            time: meta.time || '0.00s',
            model: meta.model || activeModel,
          });

          // Notificar al búho éxito: despliegue de alas y júbilo (owl_fly)
          if (this.owlInstance) {
            this.owlInstance.setState('success');
          }
        },
        onError: (err) => {
          appState.updateLastMessage(`[Error Runtime] No se pudo completar la inferencia: ${err.message}`, {
            error: true,
            isStreaming: false,
          });

          if (this.owlInstance) {
            this.owlInstance.setState('error');
          }
        },
      });
    } catch (err) {
      appState.updateLastMessage(`[Error Inesperado] ${err.message}`, {
        error: true,
        isStreaming: false,
      });

      if (this.owlInstance) {
        this.owlInstance.setState('error');
      }
    } finally {
      appState.setState({ isGenerating: false });
    }
  }
}

export const chatService = new ChatService();
