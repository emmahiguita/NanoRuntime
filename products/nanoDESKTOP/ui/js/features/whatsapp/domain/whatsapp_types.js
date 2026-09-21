/**
 * whatsapp_types.js — Modelos y Tipos de Dominio para WhatsApp Desktop
 * 
 * QUÉ HACE:
 * Define las entidades, enumeraciones y estructuras de datos inmutables
 * para conversaciones, mensajes, contactos, sesiones y políticas de automatización.
 * 
 * CÓMO FUNCIONA:
 * Provee objetos planos y enums congelados (Object.freeze) para garantizar integridad
 * referencial en toda la arquitectura limpia sin efectos secundarios.
 * 
 * POR QUÉ:
 * El principio de Inversión de Dependencias (DIP) requiere que las capas de
 * aplicación y UI dependan de abstracciones y modelos de dominio estables.
 */

export const MessageDirection = Object.freeze({
  INBOUND: 'inbound',
  OUTBOUND: 'outbound',
  SYSTEM: 'system',
});

export const MessageStatus = Object.freeze({
  PENDING: 'pending',
  SENT: 'sent',
  DELIVERED: 'delivered',
  READ: 'read',
  FAILED: 'failed',
});

export const SessionStatus = Object.freeze({
  DISCONNECTED: 'disconnected',
  PAIRING: 'pairing',
  CONNECTING: 'connecting',
  CONNECTED: 'connected',
  SYNCING: 'syncing',
});

export const ToneProfile = Object.freeze({
  PROFESSIONAL: 'professional',
  FRIENDLY: 'friendly',
  CONCISE: 'concise',
  COMMERCIAL: 'commercial',
});

export class WhatsAppContact {
  /**
   * Entidad de contacto de WhatsApp.
   * @param {Object} params - Propiedades del contacto.
   */
  constructor({
    id,
    name,
    phone,
    avatar = null,
    isBusiness = false,
    verified = false,
    lastSeen = null,
  }) {
    this.id = id || `contact_${Date.now()}`;
    this.name = name || 'Contacto';
    this.phone = phone || '';
    this.avatar = avatar;
    this.isBusiness = Boolean(isBusiness);
    this.verified = Boolean(verified);
    this.lastSeen = lastSeen || new Date().toISOString();
  }
}

export class WhatsAppMessage {
  /**
   * Entidad de mensaje individual dentro de una conversación.
   * @param {Object} params - Propiedades del mensaje.
   */
  constructor({
    id,
    conversationId,
    direction = MessageDirection.INBOUND,
    text = '',
    timestamp = null,
    status = MessageStatus.DELIVERED,
    isAiGenerated = false,
    attachments = [],
  }) {
    this.id = id || `msg_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.conversationId = conversationId;
    this.direction = direction;
    this.text = text;
    this.timestamp = timestamp || new Date().toISOString();
    this.status = status;
    this.isAiGenerated = Boolean(isAiGenerated);
    this.attachments = attachments || [];
  }
}

export class ConversationThread {
  /**
   * Hilo de conversación entre el usuario y un contacto.
   * @param {Object} params - Propiedades del hilo.
   */
  constructor({
    id,
    contact,
    unreadCount = 0,
    pinned = false,
    draft = '',
    lastMessage = null,
    autoReply = false,
  }) {
    this.id = id;
    this.contact = contact instanceof WhatsAppContact ? contact : new WhatsAppContact(contact || {});
    this.unreadCount = Number(unreadCount) || 0;
    this.pinned = Boolean(pinned);
    this.draft = draft || '';
    this.lastMessage = lastMessage ? (lastMessage instanceof WhatsAppMessage ? lastMessage : new WhatsAppMessage(lastMessage)) : null;
    this.autoReply = Boolean(autoReply);
  }
}

export class AutoReplyPolicy {
  /**
   * Política de gobernanza para respuestas autónomas de IA.
   * @param {Object} params - Configuración de la política.
   */
  constructor({
    enabled = false,
    tone = ToneProfile.PROFESSIONAL,
    delaySeconds = 3,
    requireHumanApproval = true,
    signature = '— Nano AI (Local)',
  }) {
    this.enabled = Boolean(enabled);
    this.tone = tone;
    this.delaySeconds = Math.max(0, Number(delaySeconds) || 3);
    this.requireHumanApproval = Boolean(requireHumanApproval);
    this.signature = signature;
  }
}
