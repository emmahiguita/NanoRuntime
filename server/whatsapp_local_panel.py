"""Panel auxiliar de Nano Desktop: configuración privada y control del gateway real."""

import argparse
import queue
import threading
import tkinter as tk
from tkinter import messagebox, ttk

from .whatsapp_local_controller import GatewayController
from .whatsapp_local_settings import FIELDS, save_settings, upgrade_permissions
from .whatsapp_local_check import check_meta_result
from .whatsapp_mcp_check import check_mcp_result
from .whatsapp_webhook_check import check_webhook_result
from .whatsapp_check_result import CheckResult
from .whatsapp_panel_view import PanelView


class LocalGatewayPanel:
    """Solo configuración técnica: no inventa conversaciones, modelos ni permisos de Meta."""

    def __init__(self, root: tk.Tk, defaults: dict):
        self.root, self.controller = root, GatewayController()
        self.results, self.busy, self.closing = queue.Queue(), False, False
        self.fault, self.transition = None, None
        root.title("Nano Desktop · Servidor de WhatsApp")
        width = min(580, root.winfo_screenwidth() - 80)
        height = min(520, root.winfo_screenheight() - 80)
        root.minsize(520, 460)
        root.geometry(f"{width}x{height}")
        root.protocol("WM_DELETE_WINDOW", self.close)
        try:
            stored = upgrade_permissions()
        except (OSError, ValueError):
            stored = {}
            messagebox.showerror("Configuración privada", "No se pudo abrir el archivo. No se reemplazó su contenido.")
        self.status = tk.StringVar(value="Servidor detenido. Guarda el token y pulsa Iniciar.")
        self.webhook_configured = bool(stored.get("META_APP_SECRET"))
        self.view = PanelView(self, root, stored, defaults)
        self.entries, self.private_fields = self.view.entries, self.view.private_fields
        self.view.update_controls(self.controller, self.busy, self.closing)
        root.after(300, self.poll)

    def work(self, operation, group=None):
        """Saca disco/red del hilo visual; los resultados no contienen secretos."""
        if self.busy or self.closing:
            return
        self.busy = True
        def run():
            try:
                self.results.put((group, operation()))
            except Exception:
                self.results.put((group, CheckResult("error", "Operación fallida; revisa los valores y la conexión. No se mostró ninguna credencial.")))
        threading.Thread(target=run, name="nano-whatsapp-configuration", daemon=True).start()

    def save(self):
        """Guardar exige detener el servidor: evita cambiar credenciales a mitad de petición."""
        if self.controller.active:
            self.view.indicators.notice("warning", "Detén el servidor antes de guardar o renovar el token.")
            return
        values = {key: entry.get() for key, entry in self.entries.items()}
        def operation():
            save_settings(values)
            return CheckResult("ok", "Configuración guardada con DPAPI. Pulsa Iniciar; el acceso Meta aún no está validado.",
                               webhook_configured=bool(values.get("META_APP_SECRET", "").strip()))
        self.work(operation)

    def start(self):
        """Arranca exclusivamente el gateway; no inicia el motor LLM ni automatizaciones."""
        if self.busy or self.controller.active:
            return
        self.fault, self.transition = None, "start"
        self.view.indicators.reset_checks()
        self.view.indicators.webhook(self.webhook_configured)
        self.controller.start()
        self.view.indicators.notice("warning", "Iniciando gateway local…")

    def stop(self):
        """Solicita cierre sin congelar la interfaz ni terminar procesos ajenos."""
        self.controller.stop()
        self.transition = "stop"
        self.view.indicators.notice("warning", "Deteniendo gateway local…")

    def check_meta(self):
        """Consulta plantillas reales por el gateway existente; NO envía ni edita mensajes."""
        if not self.controller.active or not self.controller.server or not self.controller.server.started:
            self.view.indicators.notice("warning", "Inicia primero el servidor local.")
            return
        self.view.indicators.set("meta", "warning", "Comprobando…")
        self.view.indicators.notice("warning", "Consultando Meta en modo solo lectura…")
        self.work(check_meta_result, "meta")

    def poll(self):
        """Comprueba resultados a baja frecuencia; no consulta Meta periódicamente."""
        try:
            group, result = self.results.get_nowait()
            self.busy = False
            self.view.indicators.notice(result.level, result.message)
            if result.webhook_configured is not None:
                self.webhook_configured = result.webhook_configured
                self.view.indicators.webhook(result.webhook_configured)
                if group is None:
                    self.view.indicators.reset_checks()
            if group in {"meta", "mcp"}:
                text = "Lectura verificada" if group == "meta" else "4 lecturas verificadas"
                self.view.indicators.set(group, result.level, text if result.level == "ok" else "Error · ver aviso")
            if group == "webhook" and result.level == "error":
                self.view.indicators.set("webhook", "error", "Sin conexión · ver aviso")
        except queue.Empty:
            pass
        if self.controller.error:
            self.fault, self.transition = self.controller.error, None
            self.view.indicators.notice("error", self.fault)
            self.controller.error = None
        if self.transition == "start" and self.controller.server and self.controller.server.started:
            self.transition = None
            self.view.indicators.notice("ok", "Gateway local iniciado. Comprueba Meta y MCP; recepción aún pendiente.")
        if self.transition == "stop" and not self.controller.active:
            self.transition = None
            self.view.indicators.notice("off", "Servidor detenido; puedes guardar o renovar la configuración.")
        if self.closing and not self.controller.active and not self.busy:
            self.root.destroy()
            return
        self.view.indicators.update_server(self.controller, self.fault, self.closing)
        self.view.update_controls(self.controller, self.busy, self.closing)
        self.root.after(300, self.poll)

    def check_mcp(self):
        """Validación manual de protocolo y herramientas; nunca consulta mensajes ni Meta."""
        if not self.controller.active or not self.controller.server or not self.controller.server.started:
            self.view.indicators.notice("warning", "Inicia primero el servidor local.")
            return
        self.view.indicators.set("mcp", "warning", "Comprobando…")
        self.view.indicators.notice("warning", "Comprobando MCP autenticado en este PC…")
        self.work(check_mcp_result, "mcp")

    def check_webhook(self):
        """Consulta estado de configuración; nunca fabrica una entrega ni firma eventos."""
        if not self.controller.active or not self.controller.server or not self.controller.server.started:
            self.view.indicators.notice("warning", "Inicia primero el servidor local.")
            return
        self.view.indicators.set("webhook", "warning", "Comprobando…")
        self.view.indicators.notice("warning", "Consultando estado del webhook…")
        self.work(check_webhook_result, "webhook")

    def close(self):
        """Espera cierre cooperativo de las operaciones; nunca deja un servidor hijo zombi."""
        self.closing = True
        self.controller.stop()
        self.view.indicators.notice("warning", "Cerrando operaciones y servidor local…")


def main():
    """Los IDs de prueba se pasan explícitamente, sin hacerlos defaults de otras empresas."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--waba-id", default="")
    parser.add_argument("--phone-number-id", default="")
    parser.add_argument("--graph-version", default="")
    parser.add_argument("--start", action="store_true", help="Inicia el gateway al abrir; no envía mensajes")
    args = parser.parse_args()
    root = tk.Tk()
    style = ttk.Style(root)
    style.theme_use("vista")
    root.option_add("*Font", "{Segoe UI} 10")
    panel = LocalGatewayPanel(root, {FIELDS[1]: args.waba_id, FIELDS[2]: args.phone_number_id,
                                    FIELDS[3]: args.graph_version})
    if args.start:
        root.after(0, panel.start)
    try:
        root.mainloop()
    finally:
        panel.controller.stop()
        panel.controller.wait()


if __name__ == "__main__":
    main()
