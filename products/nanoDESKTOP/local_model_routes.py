"""
MÓDULO: local_model_routes.py
QUÉ HACE: Enrutador HTTP del servidor NanoAI Desktop para catálogo GGUF, activación, apagado y chat local/Mobile.
CÓMO FUNCIONA: Valida entradas JSON, auto-activa modelos disponibles cuando se solicita inferencia y delega en LocalRuntimeBridge.
POR QUÉ: Centraliza el contrato HTTP (< 200 líneas) garantizando cero simulaciones y respuesta determinista.
"""

import json
from urllib.parse import urlsplit

from local_mobile_adapters import format_openai_response, parse_openai_chat, send_sse
from local_model_catalog import installed_models
from local_runtime_bridge import LocalRuntimeBridge, assess_viability

bridge = LocalRuntimeBridge()
ROUTES = {
    ("GET", "/api/local-models"),
    ("POST", "/api/local-models/activate"),
    ("POST", "/api/local-models/deactivate"),
    ("GET", "/api/status"),
    ("POST", "/api/viability"),
    ("POST", "/api/chat"),
    ("GET", "/health"),
    ("POST", "/completion"),
    ("POST", "/cancel"),
    ("GET", "/v1/models"),
    ("POST", "/v1/chat/completions"),
    ("POST", "/chat/completions"),
}


def send_json(handler, status: int, payload: dict):
    """Serializa respuestas HTTP JSON estrictas (sin NaN ni valores inventados)."""
    body = json.dumps(payload, separators=(",", ":"), allow_nan=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _ensure_active_model(requested: str | None) -> str:
    """
    QUÉ HACE: Garantiza que el modelo solicitado (o el primer GGUF disponible) esté activo antes de inferir.
    CÓMO FUNCIONA: Si el motor no tiene cargado el modelo pedido, invoca bridge.activate() automáticamente.
    POR QUÉ: Permite que al escribir un mensaje en Desktop o Mobile el modelo se conecte y active sin pasos manuales extra.
    """
    if isinstance(requested, str) and requested.strip():
        target = requested.strip()
        status = bridge.status()
        if status.get("model_path") != target or not status.get("model_loaded"):
            activated = bridge.activate(target)
            return activated["selected"]["path"]
        return target
    status = bridge.status()
    current_model = status.get("model_path")
    if not current_model or not status.get("model_loaded"):
        models = installed_models()
        if not models:
            raise RuntimeError("No hay modelos GGUF instalados")
        current_model = models[0]["path"]
        bridge.activate(current_model)
    return current_model


def _catalog_with_status():
    """Combina el catálogo en disco con el estado real del motor en memoria."""
    status = bridge.status()
    models = installed_models()
    for model in models:
        model["selected"] = model["path"] == status.get("model_path")
        model["is_loaded"] = model["selected"] and status.get("model_loaded") is True
    return models, status


def handle_local_route(handler, method: str) -> bool:
    """Despacha las rutas de modelos locales, telemetría y puente Mobile."""
    path = urlsplit(handler.path).path
    if (method, path) not in ROUTES:
        return False
    try:
        if method == "GET":
            if path == "/health":
                send_json(handler, 200, {"status": "ok", "service": "nano-runtime-bridge",
                    "capabilities": {"completion": True, "streaming": "buffered-sse",
                                     "cancellation": False, "cloud": False,
                                     "viability": True, "openai_v1": True}})
                return True
            if path == "/v1/models":
                models, _ = _catalog_with_status()
                send_json(handler, 200, {
                    "object": "list",
                    "data": [{"id": m["id"], "object": "model", "owned_by": "nano-desktop",
                              "name": m["name"], "path": m["path"], "size_mb": m["size_mb"],
                              "size_bytes": m.get("size_bytes", m.get("size_mb", 0) * 1048576),
                              "selected": m["selected"], "is_loaded": m["is_loaded"]} for m in models],
                })
                return True
            if path.endswith("local-models"):
                models, status = _catalog_with_status()
                send_json(handler, 200, {"models": models, "runtime": status})
                return True
            send_json(handler, 200, bridge.status())
            return True
        if handler.headers.get("Content-Type", "").split(";")[0] != "application/json":
            send_json(handler, 415, {"error": "La operación requiere JSON"})
            return True
        size = int(handler.headers.get("Content-Length", "0"))
        if not 0 < size <= 65536:
            send_json(handler, 413, {"error": "Petición vacía o mayor de 64 KiB"})
            return True
        handler.connection.settimeout(120)
        data = json.loads(handler.rfile.read(size))
        if not isinstance(data, dict):
            raise ValueError("El cuerpo debe ser un objeto JSON")
        if path.endswith("/deactivate"):
            result = bridge.deactivate()
        elif path.endswith("/activate"):
            result = bridge.activate(str(data.get("model", "")))
        elif path == "/api/viability":
            result = assess_viability(data.get("model_size_bytes"))
        elif path.endswith("/cancel"):
            send_json(handler, 501, {"error": "El motor Desktop no admite cancelación por request_id", "cancelled": False})
            return True
        elif path.endswith("/completion"):
            if not isinstance(data.get("stream", False), bool):
                raise ValueError("stream debe ser booleano")
            chat_data = {**data, "prompt": data.get("prompt", ""),
                         "max_tokens": data.get("n_predict", data.get("max_tokens", 512)),
                         "session_id": data.get("session_id") or data.get("request_id")}
            validate_chat(chat_data)
            chat_data["model"] = _ensure_active_model(data.get("model"))
            res = bridge.chat(chat_data)
            result = {"content": res.get("response", ""), "stop": True, "model": res.get("model"),
                      "buffered": True, "timings": {"predicted_per_second": res.get("tok_s")}}
            if data.get("stream"):
                send_sse(handler, [json.dumps(result, allow_nan=False)])
                return True
        elif path in ("/v1/chat/completions", "/chat/completions"):
            chat_data = parse_openai_chat(data)
            validate_chat(chat_data)
            chat_data["model"] = _ensure_active_model(data.get("model"))
            res = bridge.chat(chat_data)
            is_sse, payload = format_openai_response(res, bool(data.get("stream")))
            if is_sse:
                send_sse(handler, payload)
                return True
            result = payload
        else:
            validate_chat(data)
            data["model"] = _ensure_active_model(data.get("model"))
            result = bridge.chat(data)
        send_json(handler, 200, result)
    except (ValueError, UnicodeError):
        send_json(handler, 422, {"error": "Modelo o petición de chat inválidos"})
    except RuntimeError as error:
        send_json(handler, 409, {"error": str(error)})
    except (BrokenPipeError, ConnectionAbortedError, ConnectionResetError):
        return True
    except OSError:
        send_json(handler, 503, {"error": "No se pudo conectar al motor local"})
    return True


def validate_chat(data: dict):
    """Valida el contrato de entrada de conversación antes de tocar el motor."""
    if not isinstance(data.get("prompt"), str) or not data["prompt"].strip():
        raise ValueError("Falta el mensaje")
    tokens = data.get("max_tokens", 512)
    if not isinstance(tokens, int) or isinstance(tokens, bool) or not 1 <= tokens <= 4096:
        raise ValueError("Límite de generación inválido")
    history = data.get("history", [])
    if not isinstance(history, list) or len(history) > 24 or any(
        not isinstance(item, dict) or item.get("role") not in ("user", "assistant")
        or not isinstance(item.get("content"), str) or not item["content"].strip() for item in history
    ):
        raise ValueError("Historial inválido")
    if not isinstance(data.get("session_id"), str) or not 1 <= len(data["session_id"]) <= 128:
        raise ValueError("Falta la identidad de conversación")
    if data.get("context") is not None and not isinstance(data.get("context"), str):
        raise ValueError("Contexto inválido")
    temperature = data.get("temperature")
    if temperature is not None and (isinstance(temperature, bool) or not isinstance(temperature, (int, float))
                                    or not 0 <= temperature <= 2):
        raise ValueError("Temperatura inválida")
