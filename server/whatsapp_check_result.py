"""Resultado público de una comprobación: evidencia y texto, nunca credenciales."""

from dataclasses import dataclass


@dataclass(frozen=True)
class CheckResult:
    """El servicio declara éxito/pendiente/error; la vista no adivina por frases."""

    level: str
    message: str
    webhook_configured: bool | None = None
