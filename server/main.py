import asyncio
import hmac
import json
import logging
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, Any, List

import psutil
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse

logging.basicConfig(level=logging.WARNING, format="%(asctime)s [%(levelname)s] %(message)s")

app = FastAPI(title="NanoRuntime Real Hardware + Inference Telemetry Server", version="2.5.0")

# CORS: allowed origins from env var (comma-separated), defaults to localhost.
# allow_credentials=True with wildcard origins is invalid per spec and rejected
# by browsers. Use explicit origins for any credentialed deployment.
_cors_origins = os.environ.get("NANO_CORS_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000")
ALLOWED_ORIGINS = [o.strip() for o in _cors_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Configuración del motor de inferencia real (nanortime.exe + GGUF)
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent.parent
NANORTIME_EXE = Path(os.environ.get("NANO_ENGINE", BASE_DIR / "target" / "release" / "nanortime.exe"))
MODEL_PATH = Path(os.environ.get("NANO_MODEL", BASE_DIR / "data" / "qwen_tmp.gguf"))
INFERENCE_PROMPT = os.environ.get(
    "NANO_PROMPT",
    "Explica en dos oraciones qué es un motor de inferencia de modelos de lenguaje.",
)

def _parse_int_env(key: str, default: int) -> int:
    try:
        val = int(os.environ.get(key, str(default)))
        return val if val >= 0 else default
    except (ValueError, TypeError):
        logging.warning("%s=%s inválido, usando %s", key, os.environ.get(key, ""), default)
        return default

def _parse_float_env(key: str, default: float) -> float:
    try:
        val = float(os.environ.get(key, str(default)))
        return val if val >= 0 else default
    except (ValueError, TypeError):
        logging.warning("%s=%s inválido, usando %s", key, os.environ.get(key, ""), default)
        return default

INFERENCE_MAX_TOKENS = _parse_int_env("NANO_MAX_TOKENS", 48)
INFERENCE_INTERVAL_S = _parse_float_env("NANO_INFERENCE_INTERVAL_S", 6.0)
INFERENCE_ENABLED = os.environ.get("NANO_INFERENCE_ENABLED", "1") == "1"


NANO_METRICS_TOKEN = os.environ.get("NANO_METRICS_TOKEN", "")
MAX_WS_CONNECTIONS = int(os.environ.get("NANO_MAX_WS_CONNECTIONS", "10"))


def _check_metrics_auth(request: Request):
    """Simple token auth for metrics/system-info endpoints.
    If NANO_METRICS_TOKEN is set, require it as ?token= query param or Bearer header."""
    if not NANO_METRICS_TOKEN:
        return  # Auth disabled by default
    token = request.query_params.get("token") or request.headers.get("Authorization", "").removeprefix("Bearer ")
    # Constant-time comparison to prevent timing attacks that could leak the
    # token byte-by-byte. hmac.compare_digest is the stdlib-standard way.
    if not hmac.compare_digest(token, NANO_METRICS_TOKEN):
        raise HTTPException(status_code=403, detail="Invalid or missing metrics token")


class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket) -> bool:
        if len(self.active_connections) >= MAX_WS_CONNECTIONS:
            await websocket.close(code=1013, reason="Too many connections")
            return False
        await websocket.accept()
        self.active_connections.append(websocket)
        return True

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except WebSocketDisconnect:
                # Client disconnected — normal, clean up without noise.
                disconnected.append(connection)
            except Exception:
                # Unexpected error (serialization, protocol, etc.) — log and clean up.
                logging.warning("Broadcast send failed for a connection", exc_info=True)
                disconnected.append(connection)
        for conn in disconnected:
            self.disconnect(conn)


manager = ConnectionManager()

# ---------------------------------------------------------------------------
# Estado cacheado: mediciones reales (nvidia-smi + psutil + motor de inferencia)
# ---------------------------------------------------------------------------
CACHED_GPU_METRICS: Dict[str, Any] = {
    "gpuName": "Unknown (nvidia-smi not available)",
    "tempCelsius": 0.0,
    "powerWatts": 0.0,
    "vramAllocatedMb": 0.0,
    "vramTotalMb": 0.0,
    "gpuUtilPercent": 0.0,
}

# Último ciclo real de inferencia ejecutado con nanortime.exe.
CACHED_INFERENCE: Dict[str, Any] = {
    "available": False,   # ¿motor y modelo detectados?
    "active": False,      # ¿inferencia en curso ahora mismo?
    "error": "",
    "lastAtMs": 0,
    "tokens": 0,
    "elapsedMs": 0,
    "tokSec": 0.0,
    "latencyMsPerToken": 0.0,  # elapsed_ms / tokens (medido)
    "confidence": 0.0,
    "text": "",
    "cycleMs": 0,
}


async def async_gpu_poll_loop():
    """Polling real de nvidia-smi (2.0s)."""
    global CACHED_GPU_METRICS
    warned_gpu_unavailable = False
    while True:
        try:
            cmd = [
                "nvidia-smi",
                "--query-gpu=name,temperature.gpu,power.draw,memory.used,memory.total,utilization.gpu",
                "--format=csv,noheader,nounits",
            ]
            output = await asyncio.to_thread(
                subprocess.check_output, cmd, timeout=1.5,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            parts = [p.strip() for p in output.decode().strip().split(",")]
            name = parts[0]
            temp = float(parts[1])
            power = float(parts[2]) if parts[2] != "[N/A]" else 0.0
            vram_used = float(parts[3])
            vram_total = float(parts[4])
            gpu_util = float(parts[5])

            CACHED_GPU_METRICS = {
                "gpuName": name,
                "tempCelsius": temp,
                "powerWatts": power,
                "vramAllocatedMb": vram_used,
                "vramTotalMb": vram_total,
                "gpuUtilPercent": gpu_util,
            }
            warned_gpu_unavailable = False
        except Exception:
            # GPU may be absent or driver not loaded — expected on headless/Linux servers.
            if not warned_gpu_unavailable:
                logging.warning("nvidia-smi poll failed (GPU may be absent or driver not loaded)")
                warned_gpu_unavailable = True
            else:
                logging.debug("nvidia-smi poll still unavailable")
        await asyncio.sleep(2.0)


def run_inference_once() -> Dict[str, Any]:
    """Ejecuta UN ciclo real de generación con nanortime.exe.

    stdout = texto generado (real)
    stderr = línea `[METRICS] tokens=N elapsed_ms=M tok_s=X.XX tier=T confidence=C`
    """
    result: Dict[str, Any] = {}
    try:
        cmd = [
            str(NANORTIME_EXE),
            "--config", str(BASE_DIR / "nano.manifest.json"),
            "--model", str(MODEL_PATH),
            "--prompt", INFERENCE_PROMPT,
            "--max-tokens", str(INFERENCE_MAX_TOKENS),
            "--edge-only",
            "--quiet",
            "--log-level", "warn",
        ]
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=90,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        text = proc.stdout.strip()

        metrics: Dict[str, str] = {}
        for line in proc.stderr.splitlines():
            if line.startswith("[METRICS]"):
                for part in line[len("[METRICS]"):].split():
                    if "=" in part:
                        k, v = part.split("=", 1)
                        metrics[k] = v

        tokens = int(metrics.get("tokens", "0") or 0)
        elapsed_ms = float(metrics.get("elapsed_ms", "0") or 0)
        tok_s = float(metrics.get("tok_s", "0") or 0)
        confidence = float(metrics.get("confidence", "0") or 0)

        result.update({
            "tokens": tokens,
            "elapsedMs": round(elapsed_ms, 1),
            "tokSec": round(tok_s, 2),
            "latencyMsPerToken": round(elapsed_ms / tokens, 3) if tokens > 0 else 0.0,
            "confidence": round(confidence, 3),
            "text": text,
            "error": "" if proc.returncode == 0 else (proc.stderr.strip()[-400:] or f"exit={proc.returncode}"),
        })
    except Exception as exc:  # noqa: BLE001 — el loop debe sobrevivir a fallos del motor
        result.update({"tokens": 0, "tokSec": 0.0, "latencyMsPerToken": 0.0, "text": "", "error": str(exc)[:400]})
    return result


async def async_inference_loop():
    """Ejecuta ciclos reales de inferencia de forma periódica.

    Bajo demanda: sólo corre mientras haya clientes WebSocket conectados
    (el observatorio no debe quemar CPU/GPU en vacío). El intervalo entre
    ciclos es configurable con NANO_INFERENCE_INTERVAL_S.
    """
    global CACHED_INFERENCE
    if not INFERENCE_ENABLED:
        return
    if not NANORTIME_EXE.exists():
        CACHED_INFERENCE["error"] = f"Motor no encontrado: {NANORTIME_EXE}"
        return
    if not MODEL_PATH.exists():
        CACHED_INFERENCE["error"] = f"Modelo no encontrado: {MODEL_PATH}"
        return

    CACHED_INFERENCE["available"] = True
    while True:
        if not manager.active_connections:
            await asyncio.sleep(1.0)
            continue
        t_start = time.perf_counter()
        CACHED_INFERENCE["active"] = True
        try:
            result = await asyncio.to_thread(run_inference_once)
            CACHED_INFERENCE.update(result)
            CACHED_INFERENCE["lastAtMs"] = int(time.time() * 1000)
        finally:
            CACHED_INFERENCE["active"] = False
            CACHED_INFERENCE["cycleMs"] = round((time.perf_counter() - t_start) * 1000, 1)
        await asyncio.sleep(max(0.5, INFERENCE_INTERVAL_S))


async def async_telemetry_broadcast_loop():
    """Genera UN snapshot por tick y lo difunde a todos los clientes.

    Fuente única de datos: todos los clientes reciben el mismo snapshot con
    el mismo timestamp (streams idénticos y sincronizados entre sí).
    """
    step = 0
    while True:
        try:
            snapshot = get_real_system_snapshot(step)
            await manager.broadcast(json.dumps(snapshot))
            step += 1
        except Exception:
            logging.exception("Telemetry broadcast loop error — retrying in 1s")
        await asyncio.sleep(0.5)


@app.on_event("startup")
async def startup_event():
    asyncio.create_task(async_gpu_poll_loop())
    asyncio.create_task(async_inference_loop())
    asyncio.create_task(async_telemetry_broadcast_loop())


def get_real_system_snapshot(step: int) -> dict:
    t_start = time.perf_counter_ns()
    now = time.time()
    ts_ms = int(now * 1000)
    date_str = time.strftime("%H:%M:%S", time.localtime(now))

    # Medición real de CPU, RAM y proceso (psutil)
    cpu_percent = psutil.cpu_percent(interval=None)
    mem_info = psutil.virtual_memory()
    proc = psutil.Process(os.getpid())
    proc_memory = proc.memory_info()

    # Medición real de GPU (nvidia-smi cacheado)
    gpu = CACHED_GPU_METRICS

    # Latencia real del propio ciclo de telemetría (perf_counter)
    t_end = time.perf_counter_ns()
    execution_latency_us = max(40, (t_end - t_start) // 1000)

    # Último ciclo real de inferencia + texto generado
    inf = CACHED_INFERENCE
    words = re.findall(r"\S+", inf.get("text", ""))
    per_token_us = (
        round((inf.get("elapsedMs", 0) * 1000) / max(inf.get("tokens", 0), 1))
        if inf.get("tokens", 0) > 0 else 0
    )
    token_stream = [
        {"id": i, "token": w, "latencyMicrosec": per_token_us}
        for i, w in enumerate(words)
    ]

    return {
        "timestamp": ts_ms,
        "timeLabel": date_str,
        "step": step,
        "gpuName": gpu["gpuName"],
        "throughputTokSec": inf.get("tokSec", 0.0),
        "latencyMs": inf.get("latencyMsPerToken", 0.0),
        "inference": {
            "available": inf.get("available", False),
            "active": inf.get("active", False),
            "error": inf.get("error", ""),
            "lastAtMs": inf.get("lastAtMs", 0),
            "tokens": inf.get("tokens", 0),
            "elapsedMs": inf.get("elapsedMs", 0),
            "tokSec": inf.get("tokSec", 0.0),
            "latencyMsPerToken": inf.get("latencyMsPerToken", 0.0),
            "confidence": inf.get("confidence", 0.0),
            "cycleMs": inf.get("cycleMs", 0),
        },
        "vramAllocatedMb": gpu["vramAllocatedMb"],
        "vramTotalMb": gpu["vramTotalMb"],
        "gpuUtilPercent": gpu["gpuUtilPercent"],
        "cpuUtilPercent": round(cpu_percent, 1),
        "systemRamMb": round(mem_info.used / (1024 * 1024), 1),
        "systemRamTotalMb": round(mem_info.total / (1024 * 1024), 1),
        "procRssMb": round(proc_memory.rss / (1024 * 1024), 1),
        "tempCelsius": gpu["tempCelsius"],
        "powerWatts": gpu["powerWatts"],
        "realBenchmarkMicrosec": execution_latency_us,
        "tokenStream": token_stream,
    }


@app.websocket("/ws/telemetry")
async def websocket_telemetry(websocket: WebSocket):
    # Reject if origin doesn't match allowed origins (when not wildcard)
    origin = websocket.headers.get("origin", "")
    if origin and ALLOWED_ORIGINS != ["*"] and origin not in ALLOWED_ORIGINS:
        await websocket.close(code=4003, reason="Origin not allowed")
        return
    if not await manager.connect(websocket):
        return
    try:
        # Connection is broadcast-only — the server never reads client data.
        # Just wait for disconnect.
        await websocket.receive_text()
    except WebSocketDisconnect:
        pass  # Normal: client closed the connection
    except Exception:
        # Unexpected error — log it so it is diagnosable. Previously this
        # was a bare `except Exception: pass` which swallowed all errors
        # silently, making WebSocket bugs invisible in production.
        logging.exception("WebSocket handler crashed — disconnecting client")
    finally:
        manager.disconnect(websocket)


@app.get("/metrics", response_class=PlainTextResponse)
def prometheus_metrics(request: Request):
    _check_metrics_auth(request)
    snapshot = get_real_system_snapshot(1)
    inf = snapshot["inference"]
    return f"""# HELP nanortime_gpu_vram_allocated_bytes GPU VRAM asignada real en bytes
# TYPE nanortime_gpu_vram_allocated_bytes gauge
nanortime_gpu_vram_allocated_bytes {int(snapshot['vramAllocatedMb'] * 1024 * 1024)}

# HELP nanortime_gpu_utilization_ratio Uso real de GPU (0-1)
# TYPE nanortime_gpu_utilization_ratio gauge
nanortime_gpu_utilization_ratio {snapshot['gpuUtilPercent'] / 100.0}

# HELP nanortime_cpu_utilization_ratio Uso real de CPU
# TYPE nanortime_cpu_utilization_ratio gauge
nanortime_cpu_utilization_ratio {snapshot['cpuUtilPercent'] / 100.0}

# HELP nanortime_throughput_tokens_per_sec Tokens por segundo medidos en el último ciclo real de inferencia
# TYPE nanortime_throughput_tokens_per_sec gauge
nanortime_throughput_tokens_per_sec {inf['tokSec']}

# HELP nanortime_latency_ms Latencia media por token (ms) medida en el último ciclo real de inferencia
# TYPE nanortime_latency_ms gauge
nanortime_latency_ms {inf['latencyMsPerToken']}
"""


@app.get("/api/v1/system-info")
def system_info(request: Request):
    _check_metrics_auth(request)
    gpu = CACHED_GPU_METRICS
    mem = psutil.virtual_memory()
    return {
        "gpuName": gpu["gpuName"],
        "vramTotalMb": gpu["vramTotalMb"],
        "cpuCores": psutil.cpu_count(logical=True),
        "systemRamTotalMb": round(mem.total / (1024 * 1024), 1),
        "os": "Windows CUDA x86_64" if os.name == "nt" else sys.platform,
        "inference": CACHED_INFERENCE["available"],
        "model": MODEL_PATH.name,
        "engine": NANORTIME_EXE.name,
    }


if __name__ == "__main__":
    import uvicorn
    host = os.environ.get("NANO_BIND_ADDR", "127.0.0.1")
    port = int(os.environ.get("NANO_PORT", "8000"))
    uvicorn.run(app, host=host, port=port)
