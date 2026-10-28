"""Boundary shared by every HTTP route, including static assets and proxy routes."""
import hmac
import ipaddress
import os
from urllib.parse import urlsplit


def is_loopback(value):
    try:
        return ipaddress.ip_address(value).is_loopback
    except ValueError:
        return value == "localhost"


def validate_bind(host):
    if not is_loopback(host) and len(os.environ.get("NANO_API_KEY", "")) < 32:
        raise ValueError("Para compartir en LAN configura NANO_API_KEY con al menos 32 caracteres")


def check_access(handler):
    """LAN clients authenticate; browsers must also match the exact host and port."""
    authority = handler.headers.get("Host", "")
    parsed = urlsplit("http://" + authority)
    try:
        if parsed.port != handler.server.server_address[1]:
            return 403
        host = parsed.hostname or ""
        # Reject arbitrary DNS names (DNS rebinding); only literal IPs/localhost.
        if host != "localhost":
            ipaddress.ip_address(host)
    except ValueError:
        return 403
    origin = handler.headers.get("Origin")
    if origin and origin != "http://" + authority:
        return 403
    if handler.headers.get("Sec-Fetch-Site") == "cross-site":
        return 403
    if not is_loopback(handler.client_address[0]):
        expected = os.environ.get("NANO_API_KEY", "")
        provided = handler.headers.get("Authorization", "").removeprefix("Bearer ")
        if not provided:
            provided = handler.headers.get("X-Nano-API-Key", "")
        if len(expected) < 32 or not hmac.compare_digest(provided.encode(), expected.encode()):
            return 401
    return None
