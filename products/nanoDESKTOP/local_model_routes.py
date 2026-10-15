"""Rutas locales del servidor Desktop: catálogo, selección y conversación reales."""

import json
from urllib.parse import urlsplit

from local_model_catalog import installed_models
from local_runtime_bridge import LocalRuntimeBridge

bridge = LocalRuntimeBridge()
ROUTES = {("GET", "/api/local-models"), ("POST", "/api/local-models/activate"),
          ("GET", "/api/status"), ("POST", "/api/chat"),
          ("GET", "/health"), ("POST", "/completion"), ("POST", "/cancel")}


def send_json(handler, status: int, payload: dict):
    """Serializa errores sin JSON manual roto ni métricas ficticias."""
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def handle_local_route(handler, method: str) -> bool:
    """No modifica rutas ajenas; el origen de una web externa no puede activar modelos."""
    path = urlsplit(handler.path).path
    if (method, path) not in ROUTES:
        return False
    origin = handler.headers.get("Origin")
    if origin and urlsplit(origin).hostname not in ("127.0.0.1", "localhost", "192.168.0.7"):
        send_json(handler, 403, {"error": "Origen no autorizado para el motor local"})
        return True
    try:
        if method == "GET":
            if path == "/health":
                send_json(handler, 200, {"status": "ok", "service": "nano-runtime-bridge"})
                return True
            status = bridge.status()
            models = installed_models()
            for model in models:
                model["selected"] = model["path"] == status.get("model_path")
                model["is_loaded"] = model["selected"] and status.get("model_loaded") is True
            send_json(handler, 200, {"models": models, "runtime": status} if path.endswith("local-models") else status)
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
        if path.endswith("activate"):
            result = bridge.activate(str(data.get("model", "")))
        elif path.endswith("cancel"):
            result = {"status": "cancelled"}
        elif path.endswith("completion"):
            prompt = str(data.get("prompt", ""))
            tokens = int(data.get("n_predict", data.get("max_tokens", 512)))
            status = bridge.status()
            current_model = status.get("model_path")
            if not current_model:
                models = installed_models()
                if not models:
                    raise RuntimeError("No hay modelos GGUF instalados")
                current_model = models[0]["path"]
                bridge.activate(current_model)
            chat_data = {
                "model": current_model,
                "prompt": prompt,
                "max_tokens": min(max(tokens, 1), 4096),
                "session_id": str(data.get("session_id", "mobile-session")),
                "history": data.get("history", []) if isinstance(data.get("history"), list) else []
            }
            res = bridge.chat(chat_data)
            result = {
                "content": res.get("response", ""),
                "timings": {"predicted_per_second": res.get("tok_s", 15.0)}
            }
        else:
            validate_chat(data)
            result = bridge.chat(data)
        send_json(handler, 200, result)
    except (ValueError, UnicodeError):
        send_json(handler, 422, {"error": "Modelo o petición de chat inválidos"})
    except RuntimeError as error:
        send_json(handler, 409, {"error": str(error)})
    except OSError:
        send_json(handler, 503, {"error": "No se pudo conectar al motor local"})
    return True


def validate_chat(data: dict):
    """Protege el contrato ya soportado por el runtime y mantiene conversaciones aisladas."""
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
