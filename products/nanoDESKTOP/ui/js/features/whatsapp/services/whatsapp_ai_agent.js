/** Redacta con el motor real; no sustituye los fallos por frases de contingencia. */
import { transport } from '../../../core/transport.js';
import { whatsAppStorage } from './whatsapp_storage.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { ToneProfile, MessageDirection } from '../domain/whatsapp_types.js';

class WhatsAppAiAgent {
  constructor() { this._abortController = null; }
  /** Usa roles y sesión por hilo para mantener separadas las conversaciones. */
  async generateDraft(conversationId, options = {}) {
    this.cancelPendingGeneration();
    const policy = whatsAppStorage.getPolicy();
    const tone = options.tone || policy.tone || ToneProfile.PROFESSIONAL;
    const messages = whatsAppStorage.getMessages(conversationId)
      .filter(m => m.text?.trim() && [MessageDirection.INBOUND, MessageDirection.OUTBOUND].includes(m.direction))
      .slice(-12);
    if (!messages.length) throw new Error('No hay mensajes guardados para redactar una respuesta.');
    const latest = messages.at(-1);
    if (latest.direction !== MessageDirection.INBOUND) {
      throw new Error('El último mensaje de la conversación debe ser entrante.');
    }
    const controller = new AbortController();
    this._abortController = controller;
    const tones = {
      professional: 'Español neutro, profesional y cortés.',
      friendly: 'Español neutro, cercano y respetuoso.',
      concise: 'Español neutro, breve y directo.',
      commercial: 'Español neutro, atento a la consulta comercial.',
    };
    const history = messages.slice(0, -1).map(m => ({
      role: m.direction === MessageDirection.INBOUND ? 'user' : 'assistant', content: m.text,
    }));
    // Cancela la espera del transporte, sin prometer la detención del backend nativo.
    const timeout = setTimeout(() => controller.abort(
      new DOMException('El modelo no terminó el borrador en 120 segundos.', 'TimeoutError')), 120000);
    try {
      const result = await transport.generateText({
        prompt: `Redacta solo un borrador para responder al siguiente mensaje.
${tones[tone] || tones.professional}
No inventes precios, disponibilidad ni hechos desconocidos.
Mensaje: ${latest.text}`,
        history, session_id: `whatsapp-draft:${conversationId}`,
        max_tokens: 160, signal: controller.signal,
      });
      controller.signal.throwIfAborted();
      const draft = result.text?.trim();
      if (!draft) throw new Error('El modelo devolvió un borrador vacío.');
      whatsAppBus.emit(WhatsAppEvents.DRAFT_SUGGESTED, { conversationId, draft });
      return draft;
    } finally {
      clearTimeout(timeout);
      if (this._abortController === controller) this._abortController = null;
    }
  }
  /** Cancela solo esta asistencia, sin afectar a otros módulos. */
  cancelPendingGeneration() { this._abortController?.abort(); this._abortController = null; }
  destroy() { this.cancelPendingGeneration(); }
}
export const whatsAppAiAgent = new WhatsAppAiAgent();
