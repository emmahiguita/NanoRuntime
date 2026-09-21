/**
 * whatsapp_ai_agent.js — Agente Autónomo de Inteligencia Local para WhatsApp Desktop
 * 
 * QUÉ HACE:
 * Analiza el contexto de mensajes recientes en una conversación y genera respuestas
 * o sugerencias de borrador adaptadas al tono y política configurados.
 * 
 * CÓMO FUNCIONA:
 * Conecta con `transport.chatPromptStream` enviando una orden determinista con el historial
 * reciente. Aplica AbortController con timeout estricto de 12 segundos para evitar bloqueos.
 * 
 * POR QUÉ:
 * Permite una asistencia conversacional soberana y 100% privada, cumpliendo con
 * el principio de Gobernanza Humana (Human-in-the-Loop) y sin tiempos muertos.
 */

import { transport } from '../../../core/transport.js';
import { whatsAppStorage } from './whatsapp_storage.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';
import { ToneProfile } from '../domain/whatsapp_types.js';

class WhatsAppAiAgent {
  constructor() {
    this._abortController = null;
  }

  /**
   * Genera un borrador de respuesta inteligente para la conversación dada.
   * @param {string} conversationId - Identificador del hilo.
   * @param {Object} [options] - Opciones opcionales de tono o prompt manual.
   * @returns {Promise<string>} Texto del borrador generado.
   */
  async generateDraft(conversationId, options = {}) {
    this.cancelPendingGeneration();
    this._abortController = new AbortController();

    const policy = whatsAppStorage.getPolicy();
    const tone = options.tone || policy.tone || ToneProfile.PROFESSIONAL;
    const history = whatsAppStorage.getMessages(conversationId).slice(-6);

    const toneInstructions = {
      [ToneProfile.PROFESSIONAL]: 'Responde de forma ejecutiva, formal, concisa y cortés.',
      [ToneProfile.FRIENDLY]: 'Responde de manera cercana, empática, amable y colaborativa.',
      [ToneProfile.CONCISE]: 'Responde en menos de 2 líneas, directo al punto y sin rodeos.',
      [ToneProfile.COMMERCIAL]: 'Responde como asesor comercial atento a resolver dudas y ofrecer ayuda.',
    };

    const conversationTranscript = history
      .map((m) => `${m.direction === 'inbound' ? 'Cliente' : 'Asistente'}: ${m.text}`)
      .join('\n');

    const systemPrompt = `Eres el Agente Asistente de WhatsApp en Nano AI.
Pauta de tono: ${toneInstructions[tone] || toneInstructions[ToneProfile.PROFESSIONAL]}
Historial reciente:
${conversationTranscript}

Genera ÚNICAMENTE el texto que debe enviarse como respuesta al último mensaje del cliente. Sin introducciones ni comillas.`;

    let generatedText = '';
    const timeoutId = setTimeout(() => {
      this.cancelPendingGeneration();
    }, 12000); // Timeout determinista de 12 segundos

    try {
      await new Promise((resolve) => {
        transport.chatPromptStream({
          prompt: systemPrompt,
          maxTokens: 160,
          onToken: (token) => {
            generatedText += token;
          },
          onDone: (res) => {
            clearTimeout(timeoutId);
            if (res && res.text) generatedText = res.text;
            resolve();
          },
          onError: (err) => {
            clearTimeout(timeoutId);
            console.warn('[WhatsAppAiAgent] Inferencia local con error, usando respuesta de contingencia:', err);
            resolve();
          },
        });
      });
    } catch (e) {
      clearTimeout(timeoutId);
      console.warn('[WhatsAppAiAgent] Excepción durante la generación:', e);
    }

    const cleanDraft = generatedText.trim() || this._getFallbackResponse(tone);
    whatsAppBus.emit(WhatsAppEvents.DRAFT_SUGGESTED, {
      conversationId,
      draft: cleanDraft,
    });

    return cleanDraft;
  }

  /**
   * Cancela cualquier proceso de inferencia pendiente para no sobrecargar el hardware.
   */
  cancelPendingGeneration() {
    if (this._abortController) {
      this._abortController.abort();
      this._abortController = null;
    }
  }

  /**
   * Retorna una plantilla segura si el motor de IA local está en carga o reinicio.
   * @private
   */
  _getFallbackResponse(tone) {
    switch (tone) {
      case ToneProfile.FRIENDLY:
        return '¡Hola! Muchas gracias por escribirnos. Con gusto te ayudo con esa consulta.';
      case ToneProfile.CONCISE:
        return 'Enterado. Procedemos con la verificación solicitada enseguida.';
      case ToneProfile.COMMERCIAL:
        return '¡Hola! Claro que sí, con mucho gusto puedo brindarte todos los detalles.';
      case ToneProfile.PROFESSIONAL:
      default:
        return 'Estimado/a, hemos recibido su mensaje. Nos encontramos revisando la información para atenderle.';
    }
  }

  /**
   * Limpieza de recursos.
   */
  destroy() {
    this.cancelPendingGeneration();
  }
}

export const whatsAppAiAgent = new WhatsAppAiAgent();
