"""Estado del webhook: consulta pública, sin secretos, simulaciones ni escrituras."""

import argparse
import json
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import ProxyHandler, Request, build_opener

from .whatsapp_graph_transport import NoCredentialRedirect
from .whatsapp_local_server import LOCAL_URL
from .whatsapp_check_result import CheckResult


def run_webhook_audit(base_url: str = LOCAL_URL) -> list[tuple[str, bool, str]]:
    """Health solo demuestra proceso/configuración; no handshake de Meta ni entrega."""
    uri = urlparse(base_url)
    if uri.username or uri.password or uri.query or uri.fragment or uri.path not in ("", "/"):
        return [("Dirección", False, "Usa únicamente la base del gateway")]
    if uri.scheme != "https" and not (uri.scheme == "http" and uri.hostname == "127.0.0.1"):
        return [("Dirección", False, "Se requiere HTTPS o loopback local")]
    opener = build_opener(ProxyHandler({}), NoCredentialRedirect())
    try:
        with opener.open(Request(base_url.rstrip("/") + "/api/v1/whatsapp/health"), timeout=10) as response:
            payload = json.loads(response.read(4096))
        if not isinstance(payload, dict) or payload.get("running") is not True:
            return [("Gateway", False, "Estado no confirmado")]
        configured = payload.get("webhook_configured") is True
        return [("Gateway", True, "Activo"),
                ("Configuración", configured, "Disponible" if configured else "Falta App Secret/configuración"),
                ("Recepción real", False, "Validar suscripción Meta y mensaje entrante autorizado")]
    except HTTPError as error:
        error.close()
        return [("Gateway", False, f"HTTP {error.code}")]
    except (URLError, TimeoutError, OSError, ValueError):
        return [("Gateway", False, "No se pudo consultar el estado")]


def main():
    """CLI de estado sin DPAPI, verify_token en URL ni POST de entregas ficticias."""
    parser = argparse.ArgumentParser(description="Estado real del gateway de WhatsApp")
    parser.add_argument("--url", default=LOCAL_URL)
    for name, success, detail in run_webhook_audit(parser.parse_args().url):
        print(f"{name}: {'OK' if success else 'PENDIENTE'} · {detail}")


def check_webhook_result() -> CheckResult:
    """Distingue fallo de conexión de configuración/recepción pendientes para la vista."""
    results = run_webhook_audit()
    if not results or not results[0][1]:
        return CheckResult("error", "No se pudo consultar el gateway del webhook.")
    configured = next((success for name, success, _ in results if name == "Configuración"), False)
    message = ("Webhook configurado; falta verificar suscripción Meta y recepción real."
               if configured else "Webhook pendiente: falta App Secret/configuración guardada.")
    return CheckResult("warning", message, webhook_configured=configured)


if __name__ == "__main__":
    main()
