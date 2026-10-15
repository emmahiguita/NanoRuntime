/** Informa cómo conectar Meta; no presenta códigos ni confirmaciones ficticias. */
import { NanoOverlay } from '../../../components/nano_overlay.js';

export class WhatsAppPairingModal {
  /** Reutiliza el modal existente sin leer secretos ni activar cuentas externas. */
  static show() {
    const previousFocus = document.activeElement;
    const modal = NanoOverlay.open({
      title: 'Conexión oficial de WhatsApp',
      extraClass: 'wa-connection-modal',
      onClose: () => { if (!NanoOverlay.activeInstance && previousFocus?.isConnected) previousFocus.focus(); },
      content: `<div class="wa-connection-guide">
        <p>La conexión oficial pasa por el servidor de Nano. Escritorio y móvil consultan la misma bandeja; WhatsApp Web es otra conexión.</p>
        <ol>
          <li><strong>Servidor del PC:</strong> abre «Nano Negocios · Servidor WhatsApp», inicia y comprueba Meta y MCP. Son verificaciones independientes.</li>
          <li><strong>Recepción:</strong> guarda el App Secret en ese panel privado. No es el token temporal ni el token de verificación.</li>
          <li><strong>Meta:</strong> configura un callback HTTPS terminado en <code>/api/v1/whatsapp/webhook</code>, verifica y suscribe el campo <code>messages</code> y la cuenta WABA.</li>
          <li><strong>Bandeja:</strong> conectar un lector autenticado al historial del servidor. Este adaptador de escritorio todavía está pendiente.</li>
          <li><strong>IA local:</strong> selecciona un modelo en la cabecera; «Sugerir respuesta» crea un borrador con el historial seleccionado, sin enviarlo.</li>
        </ol>
        <p>El panel auxiliar del PC ya permite configurar el servidor.
          Su dirección local es <code>127.0.0.1:8010</code>.</p>
        <p>El envío necesita su permiso separado, persistencia saliente y estados reales. MCP ofrece lecturas, no autorización para enviar.</p>
        <p>No introduzcas el token de Meta ni el App Secret en esta vista. Permanecen cifrados en el PC; los registros locales no equivalen a mensajes oficiales.</p>
      </div>`,
    });
    // La guía usa el overlay común; solo agrega semántica y contención del foco.
    const title = modal.element.querySelector('.nano-overlay-title');
    title.id = 'wa-connection-dialog-title-' + crypto.randomUUID();
    modal.element.setAttribute('role', 'dialog');
    modal.element.setAttribute('aria-modal', 'true');
    modal.element.setAttribute('aria-labelledby', title.id);
    const close = modal.element.querySelector('.nano-overlay-btn-close');
    close.focus();
    modal.element.addEventListener('keydown', event => {
      if (event.key === 'Tab') { event.preventDefault(); close.focus(); }
    });
    return modal;
  }
}
