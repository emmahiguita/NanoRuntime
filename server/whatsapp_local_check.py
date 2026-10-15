"""Diagnóstico manual local: red y errores seguros, sin copiar credenciales."""

import json
from urllib.error import HTTPError, URLError
from urllib.request import ProxyHandler, Request, build_opener

from .whatsapp_graph_transport import NoCredentialRedirect
from .whatsapp_local_server import LOCAL_URL
from .whatsapp_local_settings import load_settings
from .whatsapp_check_result import CheckResult


def check_meta_result() -> CheckResult:
    """Solo el botón del propietario llama esta lectura; no envía ni modifica Meta."""
    settings = load_settings()
    request = Request(LOCAL_URL + "/api/v1/whatsapp/templates", headers={
        "X-Nano-API-Key": settings.get("NANO_WHATSAPP_API_KEY", "")})
    # La llave local no debe pasar por proxies del sistema ni redirecciones.
    opener = build_opener(ProxyHandler({}), NoCredentialRedirect())
    try:
        with opener.open(request, timeout=25) as response:
            payload = json.loads(response.read(4 * 1024 * 1024 + 1))
        items = payload.get("data") if isinstance(payload, dict) else None
        if not isinstance(items, list):
            return CheckResult("error", "Meta devolvió una estructura inesperada; no se confirma conexión.")
        return CheckResult("ok", f"Lectura real de Meta correcta: {len(items)} plantillas en esta página. Recepción y envío NO comprobados.")
    except HTTPError as error:
        # Solo cabeceras diagnósticas propias: no lee ni muestra el error remoto crudo.
        kind = error.headers.get("X-Nano-Failure-Kind", "")
        codes = []
        for key, header in (("HTTP Meta", "X-Nano-Upstream-HTTP"),
                            ("código", "X-Nano-Meta-Code"), ("subcódigo", "X-Nano-Meta-Subcode")):
            value = error.headers.get(header, "")
            if value.isascii() and value.isdigit() and len(value) <= 10:
                codes.append(f"{key}={value}")
        error.close()
        reasons = {
            "meta_credentials": "Meta rechazó la credencial. Renueva el token en este panel.",
            "meta_permissions": "Meta rechazó permisos. Revisa acceso a la WABA y whatsapp_business_management.",
            "meta_parameters": "Meta rechazó el activo o parámetros. Revisa WABA, app y versión Graph.",
            "meta_network": "No se alcanzó Meta. Revisa Internet, proxy y certificados TLS.",
            "meta_response": "La respuesta de Meta no se pudo interpretar.",
            "meta_rejected": "Meta rechazó la solicitud; revisa sus códigos de diagnóstico.",
        }
        if kind in reasons:
            return CheckResult("error", f"{reasons[kind]} {' '.join(codes)}".strip())
        return CheckResult("error", f"Gateway HTTP {error.code}: acceso no confirmado. Revisa configuración local; no se deduce un token inválido.")
    except (URLError, TimeoutError, OSError):
        return CheckResult("error", "No se alcanzó el gateway local. Pulsa Iniciar y espera a que complete el arranque.")
    except (ValueError, UnicodeDecodeError):
        return CheckResult("error", "El gateway devolvió una respuesta ilegible; no se confirma conexión.")


def check_meta_readonly() -> str:
    """Conserva el contrato textual anterior; la vista usa el resultado tipado."""
    return check_meta_result().message
