/**
 * whatsapp_session_manager.js — Gestor de Sesión y Vinculación WhatsApp Desktop
 * 
 * QUÉ HACE:
 * Controla el ciclo de vida de la sesión (desconectado, vinculando QR/código, conectado)
 * y emite eventos de estado de forma segura sin procesos zombi.
 * 
 * CÓMO FUNCIONA:
 * Administra temporizadores de refresco y simulación de escaneo con almacenamiento
 * de identificadores para ejecutar `clearInterval`/`clearTimeout` explícitamente en el desmonte.
 * 
 * POR QUÉ:
 * Los procesos zombi en bucles de polling o listeners huérfanos consumen CPU y saturan
 * la memoria de la aplicación de escritorio (Principio de Control de Ciclo de Vida).
 */

import { SessionStatus } from '../domain/whatsapp_types.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';

class WhatsAppSessionManager {
  constructor() {
    this.status = SessionStatus.DISCONNECTED;
    this.pairingCode = null;
    this.qrPayload = null;
    this._qrRefreshTimer = null;
    this._pairingTimeoutTimer = null;
    this._heartbeatTimer = null;
  }

  /**
   * Inicia el proceso de vinculación mediante Código QR o Código Telefónico.
   * @param {'qr' | 'code'} mode - Modo de vinculación solicitado.
   * @param {string} [phoneNumber] - Número de teléfono en caso de código de 8 dígitos.
   */
  startPairing(mode = 'qr', phoneNumber = '') {
    this.stopTimers();
    this.status = SessionStatus.PAIRING;
    whatsAppBus.emit(WhatsAppEvents.SESSION_CHANGED, { status: this.status, mode });

    if (mode === 'qr') {
      this._generateQrToken();
      // Refrescar el código QR cada 35 segundos para evitar caducidad de seguridad
      this._qrRefreshTimer = setInterval(() => {
        this._generateQrToken();
      }, 35000);
    } else {
      this.pairingCode = this._generateEightDigitCode(phoneNumber);
      whatsAppBus.emit(WhatsAppEvents.QR_RECEIVED, { code: this.pairingCode, type: 'code' });
    }

    // Timeout de emparejamiento determinista de 3 minutos para liberar recursos
    this._pairingTimeoutTimer = setTimeout(() => {
      if (this.status === SessionStatus.PAIRING) {
        this.disconnect('Tiempo de vinculación agotado. Vuelve a intentarlo.');
      }
    }, 180000);
  }

  /**
   * Simula o confirma el enlace exitoso tras el escaneo.
   */
  confirmConnection() {
    this.stopTimers();
    this.status = SessionStatus.CONNECTED;
    this.pairingCode = null;
    this.qrPayload = null;
    whatsAppBus.emit(WhatsAppEvents.SESSION_CHANGED, { status: this.status });

    // Heartbeat ligero cada 30s para verificar vitalidad
    this._heartbeatTimer = setInterval(() => {
      if (this.status === SessionStatus.CONNECTED) {
        whatsAppBus.emit(WhatsAppEvents.SESSION_CHANGED, { status: this.status, ping: Date.now() });
      }
    }, 30000);
  }

  /**
   * Desconecta la sesión y limpia todos los recursos activos.
   * @param {string} [reason]
   */
  disconnect(reason = 'Sesión finalizada por el usuario.') {
    this.stopTimers();
    this.status = SessionStatus.DISCONNECTED;
    this.pairingCode = null;
    this.qrPayload = null;
    whatsAppBus.emit(WhatsAppEvents.SESSION_CHANGED, { status: this.status, reason });
  }

  /**
   * Detiene de inmediato todos los temporizadores activos para prevenir procesos zombi.
   */
  stopTimers() {
    if (this._qrRefreshTimer) {
      clearInterval(this._qrRefreshTimer);
      this._qrRefreshTimer = null;
    }
    if (this._pairingTimeoutTimer) {
      clearTimeout(this._pairingTimeoutTimer);
      this._pairingTimeoutTimer = null;
    }
    if (this._heartbeatTimer) {
      clearInterval(this._heartbeatTimer);
      this._heartbeatTimer = null;
    }
  }

  /**
   * Genera un identificador QR estructurado reproducible.
   * @private
   */
  _generateQrToken() {
    const timestamp = Date.now();
    const entropy = Math.random().toString(36).substring(2, 10);
    this.qrPayload = `2@nanoai-wa-bridge:${entropy},${timestamp},desktop`;
    whatsAppBus.emit(WhatsAppEvents.QR_RECEIVED, { qr: this.qrPayload, type: 'qr' });
  }

  /**
   * Genera un código de 8 dígitos alfanumérico para vinculación por número telefónico.
   * @private
   */
  _generateEightDigitCode(phone) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 8; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return `${code.substring(0, 4)}-${code.substring(4)}`;
  }

  /**
   * Método de destrucción completa invocado al descargar la vista.
   */
  destroy() {
    this.stopTimers();
    this.status = SessionStatus.DISCONNECTED;
  }
}

export const whatsAppSessionManager = new WhatsAppSessionManager();
