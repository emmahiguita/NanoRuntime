"""Campos privados del panel: solo el usuario copia manualmente valores ocultos."""

import tkinter as tk
from tkinter import ttk

from .whatsapp_local_settings import PRIVATE_FIELDS


class PrivateConnectionFields:
    """No imprime, transmite ni renueva llaves; reutiliza la configuración ya cargada."""

    def __init__(self, frame, root: tk.Tk, stored: dict):
        section = ttk.LabelFrame(frame, text="Conexión de Meta y Nano Mobile", padding=10)
        section.grid(sticky="ew", pady=(12, 0))
        section.columnconfigure(1, weight=1)
        labels = ("Lectura / MCP", "Verificación del webhook", "Envío de mensajes", "Administrar plantillas")
        for row, (key, label) in enumerate(zip(PRIVATE_FIELDS, labels)):
            ttk.Label(section, text=label).grid(row=row, column=0, sticky="w", padx=(0, 8))
            value = stored.get(key, "")
            field = ttk.Entry(section, show="●")
            field.insert(0, value)
            field.configure(state="readonly")
            field.grid(row=row, column=1, sticky="ew", pady=4)
            ttk.Button(section, text="Copiar", state="normal" if value else "disabled",
                       command=lambda content=value: self._copy(root, content)).grid(
                           row=row, column=2, padx=(8, 0))
        ttk.Label(
            section,
            text="MCP usa solo Lectura. Envío y plantillas tienen permisos separados. "
                 "Verificación va a Meta. No pegues claves en chats. Primer guardado: reabre el panel.",
            wraplength=420,
        ).grid(row=len(PRIVATE_FIELDS), column=0, columnspan=3, sticky="w", pady=(8, 0))

    @staticmethod
    def _copy(root: tk.Tk, content: str):
        """Acción explícita del usuario: portapapeles local, sin logs ni copia automática."""
        if content:
            root.clipboard_clear()
            root.clipboard_append(content)
