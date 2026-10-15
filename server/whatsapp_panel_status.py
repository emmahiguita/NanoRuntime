"""Indicadores permanentes; verde solo con evidencia y alertas accesibles por texto."""

import tkinter as tk
from tkinter import ttk


COLORS = {"ok": "#167347", "warning": "#946200", "error": "#B42318", "off": "#667085"}


class ConnectionIndicators:
    """Representa estado local y últimas comprobaciones sin sondear Meta ni leer secretos."""

    def __init__(self, parent, status):
        """Crea cuatro estados compactos en una sola fila horizontal."""
        self.status, self.labels, self.states = status, {}, {}
        self.running = False
        bar = ttk.Frame(parent, padding=(16, 0, 16, 6))
        bar.pack(fill="x")
        for key, title in (
            ("server", "Servidor"), ("meta", "Meta"), ("mcp", "MCP"), ("webhook", "Webhook"),
        ):
            cell = tk.Frame(bar, background="#F8F9FB", highlightthickness=1,
                            highlightbackground="#E2E6EC")
            cell.pack(side="left", fill="x", expand=True, padx=(0, 4))
            tk.Label(cell, text=title, background="#F8F9FB", foreground="#344054",
                     font=("Segoe UI", 8, "bold"), anchor="w", padx=6, pady=2).pack(fill="x")
            label = tk.Label(cell, background="#F8F9FB", anchor="w", font=("Segoe UI", 8),
                             padx=6, pady=3)
            label.pack(fill="x")
            self.labels[key] = label
        self.set("server", "off", "Detenido")
        self.reset_checks()

    def set(self, key, level, text):
        """Solo repinta cambios; el texto acompaña al color para no depender de él."""
        if self.states.get(key) != (level, text):
            self.states[key] = (level, text)
            self.labels[key].configure(text=f"● {text}", foreground=COLORS[level])

    def reset_checks(self):
        """Un reinicio/cambio de configuración invalida éxitos de la sesión anterior."""
        self.set("meta", "off", "Sin comprobar")
        self.set("mcp", "off", "Sin comprobar")

    def webhook(self, configured):
        """Tener secreto no demuestra recepción: configuración sigue en ámbar."""
        self.set("webhook", "warning", "Pendiente" if configured else "Falta Secret")

    def update_server(self, controller, fault, closing):
        """Verde depende del hilo vivo y Uvicorn iniciado, no del último mensaje del panel."""
        ready = bool(controller.active and controller.server and controller.server.started)
        stopping = closing or controller.stopping.is_set()
        if self.running and (not ready or stopping):
            self.reset_checks()
        self.running = ready and not stopping
        if closing or (controller.active and stopping):
            self.set("server", "warning", "Deteniendo…")
        elif fault:
            self.set("server", "error", "Error")
        elif ready:
            self.set("server", "ok", "Puerto 8010")
        elif controller.active:
            self.set("server", "warning", "Iniciando…")
        else:
            self.set("server", "off", "Detenido")

    def bind_notice(self, parent):
        """Aviso visible con tono semántico, sin banners decorativos ni secretos."""
        self.notice_label = tk.Label(parent, textvariable=self.status, anchor="w",
                                     justify="left", foreground=COLORS["off"],
                                     font=("Segoe UI", 9))
        self.notice_label.pack(fill="x", pady=(4, 0))
        self.notice_label.bind("<Configure>", lambda e: self.notice_label.configure(
            wraplength=max(200, e.width - 8)))

    def notice(self, level, message):
        """El estado de Meta/MCP permanece visible aunque este aviso cambie."""
        self.status.set(message)
        self.notice_label.configure(foreground=COLORS[level])
