"""Transporte Graph compartido: respuestas reales y diagnóstico sin secretos."""

import json
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

from fastapi import HTTPException


class NoCredentialRedirect(HTTPRedirectHandler):
    """Impide reenviar Authorization o la llave Nano a otro destino por redirección."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _meta_error(raw: bytes, status: int) -> dict:
    """Solo conserva códigos numéricos y banderas, nunca el cuerpo/error remoto crudo."""
    try:
        payload = json.loads(raw)
        error = payload.get("error", {}) if isinstance(payload, dict) else {}
        if not isinstance(error, dict):
            error = {}
    except (ValueError, UnicodeDecodeError):
        error = {}
    result = {"kind": "meta_rejected", "message": "Meta rechazó la solicitud",
              "upstream_http_status": status}
    for source, target in (("code", "code"), ("error_subcode", "subcode")):
        value = error.get(source)
        if type(value) is int and 0 <= value <= 2147483647:
            result[target] = value
    result["is_transient"] = error.get("is_transient") is True
    code = result.get("code")
    if code == 190:
        result.update(kind="meta_credentials", message="Meta rechazó la credencial; renueva el token")
    elif code == 10 or (isinstance(code, int) and 200 <= code <= 299):
        result.update(kind="meta_permissions", message="Meta rechazó los permisos del activo solicitado")
    elif code == 100:
        result.update(kind="meta_parameters", message="Meta rechazó el activo o parámetros; revisa IDs y versión")
    return result


def _graph_request(method: str, url: str, token: str, body: dict | None = None) -> dict:
    """Una llamada acotada, sin reintentos de envíos que puedan duplicar mensajes."""
    payload = json.dumps(body).encode("utf-8") if body is not None else None
    request = Request(url, data=payload, method=method, headers={
        "Authorization": f"Bearer {token}", "Content-Type": "application/json",
        "Accept": "application/json",
    })
    try:
        with build_opener(NoCredentialRedirect()).open(request, timeout=20) as response:
            raw = response.read(4 * 1024 * 1024 + 1)
        if len(raw) > 4 * 1024 * 1024:
            raise _failure({"kind": "meta_response", "message": "Respuesta Meta excesiva"})
        result = json.loads(raw)
        if not isinstance(result, dict):
            raise ValueError("Respuesta Graph no es objeto")
        # Graph puede incluir access_token en paging.next/previous. No llega al cliente.
        paging = result.get("paging")
        if isinstance(paging, dict):
            result["paging"] = {"cursors": paging["cursors"]} if "cursors" in paging else {}
        return result
    except HTTPError as error:
        try:
            detail = _meta_error(error.read(4096), error.code)
        finally:
            error.close()
        raise _failure(detail) from None
    except (URLError, TimeoutError, OSError):
        raise _failure({"kind": "meta_network", "message": "No se pudo conectar con Meta; revisa red/TLS"}) from None
    except (ValueError, UnicodeDecodeError):
        raise _failure({"kind": "meta_response", "message": "Meta devolvió una respuesta ilegible"}) from None


def _failure(detail: dict) -> HTTPException:
    """Mantiene detail como texto para el móvil; diagnóstico numérico separado en headers."""
    headers = {"X-Nano-Failure-Kind": detail["kind"], "Cache-Control": "no-store"}
    for key, header in (("upstream_http_status", "X-Nano-Upstream-HTTP"),
                        ("code", "X-Nano-Meta-Code"), ("subcode", "X-Nano-Meta-Subcode")):
        if type(detail.get(key)) is int:
            headers[header] = str(detail[key])
    return HTTPException(502, detail["message"], headers=headers)
