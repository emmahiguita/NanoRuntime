"""Vista del panel: estados y acciones fijos, formulario desplazable sin recortes."""

import tkinter as tk
from tkinter import ttk

from .whatsapp_local_server import LOCAL_URL
from .whatsapp_local_settings import FIELDS
from .whatsapp_panel_status import ConnectionIndicators
from .whatsapp_private_fields import PrivateConnectionFields


class ScrollableForm(ttk.Frame):
    """Desplaza solo el formulario; botones e indicadores nunca quedan debajo de la ventana."""

    def __init__(self, parent):
        super().__init__(parent)
        self.pack(fill="both", expand=True, padx=16)
        background = ttk.Style(parent).lookup("TFrame", "background") or "#F0F0F0"
        self.canvas = tk.Canvas(self, highlightthickness=0, background=background)
        bar = ttk.Scrollbar(self, orient="vertical", command=self.canvas.yview)
        bar.pack(side="right", fill="y")
        self.canvas.pack(side="left", fill="both", expand=True)
        self.canvas.configure(yscrollcommand=bar.set)
        self.content = ttk.Frame(self.canvas, padding=(0, 0, 8, 8))
        item = self.canvas.create_window((0, 0), window=self.content, anchor="nw")
        self.content.bind("<Configure>", lambda _: self.canvas.configure(
            scrollregion=self.canvas.bbox("all")))
        self.canvas.bind("<Configure>", lambda e: self.canvas.itemconfigure(item, width=e.width))
        parent.bind("<MouseWheel>", self._wheel, add="+")

    def _wheel(self, event):
        """Solo consume rueda sobre el formulario, no sobre botones ni estados."""
        x, y = self.canvas.winfo_pointerxy()
        inside = (self.canvas.winfo_rootx() <= x < self.canvas.winfo_rootx() + self.canvas.winfo_width()
                  and self.canvas.winfo_rooty() <= y < self.canvas.winfo_rooty() + self.canvas.winfo_height())
        if inside and self.content.winfo_reqheight() > self.canvas.winfo_height():
            steps = -int(event.delta / 120)
            if not steps and event.delta:
                steps = -1 if event.delta > 0 else 1
            self.canvas.yview_scroll(steps, "units")
            return "break"


class PanelView:
    """Componentes existentes con callbacks originales; no crea otro servidor o configuración."""

    def __init__(self, panel, root, stored, defaults):
        """Compone la vista compacta y conecta los mismos callbacks."""
        # ── Header compacto ──────────────────────────────────────────
        header = ttk.Frame(root, padding=(16, 10, 16, 4))
        header.pack(fill="x")
        ttk.Label(header, text="Nano Negocios · WhatsApp Gateway",
                  font=("Segoe UI", 13, "bold")).pack(anchor="w")
        ttk.Label(header, text="Credenciales cifradas en este PC · no se incluyen en la APK.",
                  font=("Segoe UI", 8), foreground="#667085").pack(anchor="w", pady=(2, 0))

        # ── Indicadores de estado (fila horizontal compacta) ─────────
        self.indicators = ConnectionIndicators(root, panel.status)
        self.indicators.webhook(bool(stored.get("META_APP_SECRET")))

        # ── Footer fijo (botones + aviso + URL) ──────────────────────
        footer = ttk.Frame(root, padding=(16, 6, 16, 8))
        footer.pack(side="bottom", fill="x")
        buttons = ttk.Frame(footer)
        buttons.pack(fill="x")
        self.actions, self.control_states = {}, {}
        for index, (key, label, action) in enumerate((
            ("save", "Guardar", panel.save), ("start", "Iniciar", panel.start),
            ("stop", "Detener", panel.stop), ("meta", "Meta", panel.check_meta),
            ("mcp", "MCP", panel.check_mcp), ("webhook", "Webhook", panel.check_webhook),
        )):
            button = ttk.Button(buttons, text=label, command=action)
            buttons.columnconfigure(index % 3, weight=1)
            button.grid(row=index // 3, column=index % 3, sticky="ew", padx=2, pady=2)
            self.actions[key] = button
        self.indicators.bind_notice(footer)
        ttk.Label(footer, text=f"Local: {LOCAL_URL}",
                  font=("Segoe UI", 8), foreground="#667085").pack(anchor="w", pady=(4, 0))

        # ── Formulario desplazable: fields en 2 columnas ─────────────
        form = ScrollableForm(root).content
        form.columnconfigure(1, weight=1)
        self.entries = {}
        field_meta = (
            ("Token temporal de Meta", True),
            ("WABA ID", False),
            ("Phone Number ID", False),
            ("Versión Graph", False),
            ("App Secret (webhook)", True),
        )
        for row, (key, (label, masked)) in enumerate(zip(FIELDS, field_meta)):
            ttk.Label(form, text=label, font=("Segoe UI", 9)).grid(
                row=row, column=0, sticky="w", padx=(0, 8), pady=3)
            entry = ttk.Entry(form, show="●" if masked else "")
            entry.insert(0, stored.get(key) or defaults.get(key, ""))
            entry.grid(row=row, column=1, sticky="ew", pady=3)
            self.entries[key] = entry
        self.private_fields = PrivateConnectionFields(form, root, stored)

    def update_controls(self, controller, busy, closing):
        """Deshabilita acciones incompatibles; no bloquea el hilo visual ni envía consultas."""
        active = controller.active
        ready = bool(active and controller.server and controller.server.started
                     and not controller.stopping.is_set())
        enabled = {"save": not active, "start": not active, "stop": active,
                   "meta": ready, "mcp": ready, "webhook": ready}
        for key, button in self.actions.items():
            state = "normal" if enabled[key] and not busy and not closing else "disabled"
            if self.control_states.get(key) != state:
                button.configure(state=state)
                self.control_states[key] = state
