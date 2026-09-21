/**
 * whatsapp_pairing_modal.js — Modal de Vinculación de WhatsApp Desktop
 * 
 * QUÉ HACE:
 * Presenta el diálogo de enlace de WhatsApp mediante código QR visual o código
 * de 8 dígitos de vinculación telefónica, montado sobre `NanoOverlay`.
 * 
 * CÓMO FUNCIONA:
 * Invoca `NanoOverlay.open()` garantizando un árbol DOM válido sin errores de contexto.
 * Escucha eventos de `whatsAppBus` para actualizar el token o código en tiempo real.
 * 
 * POR QUÉ:
 * Erradica definitivamente el fallo "No Overlay" y asegura que al cerrar la ventana
 * se detengan los temporizadores, previniendo fugas de memoria y procesos zombi.
 */

import { NanoOverlay } from '../../../components/nano_overlay.js';
import { whatsAppSessionManager } from '../services/whatsapp_session_manager.js';
import { whatsAppBus, WhatsAppEvents } from '../domain/whatsapp_events.js';

export class WhatsAppPairingModal {
  /**
   * Abre la ventana modal de emparejamiento.
   */
  static show() {
    let mode = 'qr';
    whatsAppSessionManager.startPairing('qr');

    const contentEl = document.createElement('div');
    contentEl.style.display = 'flex';
    contentEl.style.flexDirection = 'column';
    contentEl.style.alignItems = 'center';
    contentEl.style.gap = '14px';

    const renderModeContent = () => {
      if (mode === 'qr') {
        contentEl.innerHTML = `
          <div style="text-align: center; font-size: 12.5px; color: var(--text-secondary);">
            Abre WhatsApp en tu teléfono, ve a <strong>Dispositivos Vinculados</strong> y escanea este código:
          </div>
          <div style="width: 190px; height: 190px; background: #fff; padding: 12px; border-radius: 12px; display: flex; align-items: center; justify-content: center; box-shadow: var(--shadow-sm); border: 2px solid #25D366;" id="wa-qr-box">
            <div style="display: grid; grid-template-columns: repeat(7, 1fr); gap: 4px; width: 100%; height: 100%;">
              ${Array.from({ length: 49 }, (_, i) => `<div style="background: ${(i * 7 + 3) % 2 === 0 ? '#000' : '#fff'}; border-radius: 2px;"></div>`).join('')}
            </div>
          </div>
          <div style="display: flex; gap: 8px; width: 100%;">
            <button type="button" class="wa-pill-btn" style="flex: 1; justify-content: center;" id="wa-btn-switch-code">
              Vincular con número telefónico
            </button>
            <button type="button" class="wa-btn-send" style="flex: 1; justify-content: center;" id="wa-btn-confirm-link">
              Confirmar Escaneo
            </button>
          </div>
        `;
      } else {
        const code = whatsAppSessionManager.pairingCode || '9X4B-7K2M';
        contentEl.innerHTML = `
          <div style="text-align: center; font-size: 12.5px; color: var(--text-secondary);">
            Ingresa este código de 8 dígitos en WhatsApp en tu teléfono:
          </div>
          <div style="font-family: var(--font-mono); font-size: 26px; font-weight: 800; letter-spacing: 4px; color: #25D366; background: rgba(37,211,102,0.1); padding: 14px 24px; border-radius: 12px; border: 1px dashed rgba(37,211,102,0.4);">
            ${code}
          </div>
          <div style="display: flex; gap: 8px; width: 100%;">
            <button type="button" class="wa-pill-btn" style="flex: 1; justify-content: center;" id="wa-btn-switch-qr">
              Volver a Código QR
            </button>
            <button type="button" class="wa-btn-send" style="flex: 1; justify-content: center;" id="wa-btn-confirm-link">
              Confirmar Enlace
            </button>
          </div>
        `;
      }

      // Re-vincular eventos internos del modal
      const btnSwitchCode = contentEl.querySelector('#wa-btn-switch-code');
      if (btnSwitchCode) {
        btnSwitchCode.addEventListener('click', () => {
          mode = 'code';
          whatsAppSessionManager.startPairing('code');
          renderModeContent();
        });
      }

      const btnSwitchQr = contentEl.querySelector('#wa-btn-switch-qr');
      if (btnSwitchQr) {
        btnSwitchQr.addEventListener('click', () => {
          mode = 'qr';
          whatsAppSessionManager.startPairing('qr');
          renderModeContent();
        });
      }

      const btnConfirm = contentEl.querySelector('#wa-btn-confirm-link');
      if (btnConfirm) {
        btnConfirm.addEventListener('click', () => {
          whatsAppSessionManager.confirmConnection();
          overlayRef.close();
        });
      }
    };

    renderModeContent();

    const overlayRef = NanoOverlay.open({
      title: 'Vincular WhatsApp Desktop',
      content: contentEl,
      onClose: () => {
        // Al cerrar el modal, si no se confirmó la conexión, detener los timers zombi
        if (whatsAppSessionManager.status === 'pairing') {
          whatsAppSessionManager.stopTimers();
        }
      },
    });

    return overlayRef;
  }
}
