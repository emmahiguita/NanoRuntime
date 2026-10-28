"""
MÓDULO: local_mobile_adapters.py
QUÉ HACE: Adapta y valida los formatos de petición de Nano Mobile (/completion y OpenAI /v1/chat/completions)
          hacia el contrato interno de NanoRuntime Desktop.
CÓMO FUNCIONA: Extrae historial, contexto del sistema y parámetros de generación, y formatea respuestas JSON o SSE.
POR QUÉ: Aísla la traducción de protocolos Mobile/OpenAI para mantener local_model_routes.py modular y < 200 líneas (SRP).
"""

import json
import time
from uuid import uuid4


def send_sse(handler, frames: list[str]):
    """
    QUÉ HACE: Envía marcos Server-Sent Events (SSE) reales al cliente HTTP.
    CÓMO FUNCIONA: Empaqueta cada elemento con el prefijo estándar 'data: ...\n\n'.
    POR QUÉ: Permite compatibilidad con clientes Mobile/OpenAI que solicitan stream=True sin inventar tokens falsos.
    """
    body = "".join(f"data: {frame}\n\n" for frame in frames).encode("utf-8")
    handler.send_response(200)
    handler.send_header("Content-Type", "text/event-stream; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def parse_openai_chat(data: dict) -> dict:
    """
    QUÉ HACE: Convierte un cuerpo compatible con OpenAI (/v1/chat/completions) al formato de chat de NanoRuntime.
    CÓMO FUNCIONA: Separa los mensajes 'system' en 'context', conserva 'user'/'assistant' en 'history' y valida el último turno.
    POR QUÉ: Permite que Nano Mobile o herramientas externas consuman modelos grandes del PC mediante el estándar OpenAI.
    """
    messages = data.get("messages")
    if not isinstance(messages, list) or not messages:
        raise ValueError("Falta la lista de mensajes")
    if not isinstance(data.get("stream", False), bool):
        raise ValueError("stream debe ser booleano")
    system_parts = []
    conversation = []
    for item in messages:
        if not isinstance(item, dict) or not isinstance(item.get("content"), str) or not item["content"].strip():
            raise ValueError("Mensaje inválido")
        role = item.get("role")
        text = item["content"].strip()
        if role == "system":
            system_parts.append(text)
        elif role in ("user", "assistant"):
            conversation.append({"role": role, "content": text})
        else:
            raise ValueError("Rol de mensaje no soportado")
    if not conversation or conversation[-1]["role"] != "user":
        raise ValueError("El último mensaje debe ser del usuario")
    tokens = data.get("max_completion_tokens", data.get("max_tokens", 512))
    # OpenAI's `user` identifies a person, not a conversation. Requests without
    # an explicit session are stateless and must never share a runtime cache.
    session_id = data.get("session_id") or data.get("request_id") or f"openai-{uuid4().hex}"
    return {
        "prompt": conversation[-1]["content"],
        "history": conversation[:-1],
        "context": "\n\n".join(system_parts) if system_parts else None,
        "max_tokens": tokens,
        "temperature": data.get("temperature"),
        "session_id": session_id,
    }


def format_openai_response(res: dict, stream: bool) -> tuple[bool, dict | list[str]]:
    """
    QUÉ HACE: Construye la respuesta OpenAI Chat Completion (JSON o marcos SSE).
    CÓMO FUNCIONA: Incluye el texto real generado por el motor local y la métrica real tok_s.
    POR QUÉ: Evita duplicar diccionarios de salida en el enrutador HTTP principal.
    """
    text = res.get("response", "")
    model_id = res.get("model")
    created = int(time.time())
    if stream:
        chunk = {
            "id": f"chatcmpl-{created}",
            "object": "chat.completion.chunk",
            "created": created,
            "model": model_id,
            "choices": [{"index": 0, "delta": {"role": "assistant", "content": text}, "finish_reason": "stop"}],
        }
        return True, [json.dumps(chunk, allow_nan=False), "[DONE]"]
    return False, {
        "id": f"chatcmpl-{created}",
        "object": "chat.completion",
        "created": created,
        "model": model_id,
        "choices": [{"index": 0, "message": {"role": "assistant", "content": text}, "finish_reason": "stop"}],
        "timings": {"predicted_per_second": res.get("tok_s")},
    }
