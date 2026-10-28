"""
MÓDULO: local_runtime_bridge.py
QUÉ HACE: Adaptador entre el servidor HTTP de NanoAI Desktop y el proceso nativo NanoRuntime (nanortime-web.exe).
CÓMO FUNCIONA: Serializa carga, apagado e inferencia mediante un candado (threading.Lock) y un Windows Job Object.
POR QUÉ: Evita colisiones de concurrencia sobre un único proceso de modelo GGUF y libera RAM de forma determinista.
"""

import atexit
import ctypes
import json
import os
import platform
import subprocess
import threading
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from local_model_catalog import PROJECT_ROOT, resolve_model
from windows_runtime_job import RuntimeJob

BACKEND_URL = "http://127.0.0.1:8080"


def runtime_status() -> dict:
    """Consulta el estado real del motor nativo en 127.0.0.1:8080 sin bloqueo TCP largo si está apagado."""
    try:
        with urlopen(BACKEND_URL + "/api/status", timeout=0.35) as response:
            data = json.loads(response.read())
            return data if isinstance(data, dict) else {"status": "offline"}
    except (OSError, ValueError, URLError):
        return {"status": "offline", "model_loaded": False}


def system_memory() -> dict:
    """Mide RAM física real del sistema en Windows usando GlobalMemoryStatusEx."""
    class Memory(ctypes.Structure):
        _fields_ = [("length", ctypes.c_uint32), ("load", ctypes.c_uint32)] + [
            (name, ctypes.c_uint64) for name in ("total", "available", "total_page", "available_page",
                                               "total_virtual", "available_virtual", "extended")]
    data = Memory()
    data.length = ctypes.sizeof(data)
    if os.name != "nt" or not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(data)):
        return {}
    return {"total_ram_mb": data.total // 1048576, "available_ram_mb": data.available // 1048576,
            "used_ram_mb": (data.total - data.available) // 1048576}


def assess_viability(model_size_bytes: int, mem: dict | None = None) -> dict:
    """Calcula viabilidad real sobre la RAM libre y total del PC para Desktop y Mobile."""
    if isinstance(model_size_bytes, bool) or not isinstance(model_size_bytes, int) or model_size_bytes <= 0:
        raise ValueError("model_size_bytes debe ser un entero positivo")
    memory = mem if isinstance(mem, dict) else system_memory()
    required_mb = max(1, int((model_size_bytes / 1048576) * 1.25 + 256))
    avail_mb = memory.get("available_ram_mb")
    total_mb = memory.get("total_ram_mb")
    if not isinstance(avail_mb, int) or avail_mb <= 0:
        return {"tier": "UNKNOWN", "can_run": False, "should_run_interactive": False,
                "required_ram_mb": required_mb, "available_ram_mb": None,
                "reason": "Sin lectura de RAM disponible del sistema"}
    if avail_mb >= int(required_mb * 1.5):
        return {"tier": "OPTIMAL", "can_run": True, "should_run_interactive": True,
                "required_ram_mb": required_mb, "available_ram_mb": avail_mb,
                "reason": f"Holgura amplia ({avail_mb} MB libres para ~{required_mb} MB requeridos)"}
    if avail_mb >= required_mb:
        return {"tier": "VIABLE", "can_run": True, "should_run_interactive": True,
                "required_ram_mb": required_mb, "available_ram_mb": avail_mb,
                "reason": f"Cabe en RAM libre ({avail_mb} MB libres para ~{required_mb} MB requeridos)"}
    if isinstance(total_mb, int) and total_mb >= required_mb:
        return {"tier": "TIGHT", "can_run": True, "should_run_interactive": False,
                "required_ram_mb": required_mb, "available_ram_mb": avail_mb,
                "reason": f"RAM libre ajustada ({avail_mb} MB libres para ~{required_mb} MB requeridos)"}
    return {"tier": "INSUFFICIENT", "can_run": False, "should_run_interactive": False,
            "required_ram_mb": required_mb, "available_ram_mb": avail_mb,
            "reason": f"Excede la RAM disponible ({avail_mb} MB libres para ~{required_mb} MB requeridos)"}


class LocalRuntimeBridge:
    """Gestiona el ciclo de vida del motor local (activar, apagar e inferir) con exclusión mutua."""

    def __init__(self):
        self.lock = threading.Lock()
        self.process, self.job, self.selected, self.last_tok_s = None, None, None, None
        atexit.register(self.close)

    def status(self):
        """Normaliza el estado del motor y la telemetría de memoria sin inventar datos."""
        raw = runtime_status()
        mem = system_memory()
        path = raw.get("model") or raw.get("model_name")
        ready = raw.get("model_status") == "ready" or raw.get("model_loaded") is True
        size_bytes = os.path.getsize(path) if isinstance(path, str) and os.path.isfile(path) else None
        raw_tok = raw.get("tok_s")
        tok_s = round(float(raw_tok), 2) if isinstance(raw_tok, (int, float)) and raw_tok > 0 else self.last_tok_s
        return {**raw, **mem, "os_name": platform.system(), "arch": platform.machine(),
                "model_path": path, "model_name": path,
                "model_size_mb": size_bytes // 1048576 if size_bytes else raw.get("model_size_mb"),
                "viability": assess_viability(size_bytes, mem) if size_bytes else raw.get("viability"),
                "tok_s": tok_s, "model_loaded": ready,
                "status": "running" if raw.get("status") == "running" else "offline"}

    def activate(self, identifier: str):
        """Inicia o reutiliza el proceso real nanortime-web con el modelo GGUF indicado."""
        model = resolve_model(identifier)
        if not self.lock.acquire(blocking=False):
            raise RuntimeError("El motor está ocupado; espera a que termine la respuesta")
        started_new = False
        try:
            current = runtime_status()
            if current.get("model") == model["path"]:
                self.selected = model
                return {"selected": model, "runtime": self.status()}
            if current.get("status") == "running" and not (self.process and self.process.poll() is None):
                raise RuntimeError("El puerto 8080 pertenece a otro motor; no se reemplazó")
            self._stop_owned()
            candidates = [PROJECT_ROOT / "target" / kind / "nanortime-web.exe" for kind in ("release", "debug")]
            executable = next((path for path in candidates if path.is_file()), None)
            if executable is None:
                raise ValueError("Falta el ejecutable real nanortime-web; no se inició inferencia")
            self.job = RuntimeJob()
            started_new = True
            environment = dict(os.environ, NANO_BIND_ADDR="127.0.0.1", NANO_CORS_ORIGIN="http://127.0.0.1:3001")
            self.process = subprocess.Popen([str(executable), "--model", model["path"], "--port", "8080"],
                                            cwd=PROJECT_ROOT, env=environment, stdout=subprocess.DEVNULL,
                                            stderr=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
            self.job.attach(self.process.pid)
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline and self.process.poll() is None:
                if runtime_status().get("model") == model["path"]:
                    self.selected = model
                    return {"selected": model, "runtime": self.status()}
                time.sleep(0.1)
            raise RuntimeError("El runtime no confirmó el modelo seleccionado")
        except (OSError, ValueError, RuntimeError):
            if started_new:
                self._stop_owned()
            raise
        finally:
            self.lock.release()

    def deactivate(self):
        """Apaga el proceso del modelo local iniciado por este puente y libera la memoria RAM."""
        if not self.lock.acquire(blocking=False):
            raise RuntimeError("El motor está ocupado; espera a que termine la respuesta antes de apagarlo")
        try:
            self._stop_owned()
            return {"unloaded": True, "runtime": self.status()}
        finally:
            self.lock.release()

    def chat(self, payload: dict):
        """Envía el mensaje al motor real verificando que el modelo solicitado esté activo."""
        model = resolve_model(str(payload.get("model", "")))
        if not self.lock.acquire(blocking=False):
            raise RuntimeError("El motor está ocupado; no se encoló otra respuesta")
        try:
            if runtime_status().get("model") != model["path"]:
                raise RuntimeError("Activa el modelo elegido antes de escribirle")
            outgoing = dict(payload)
            if payload.get("context"):
                outgoing["prompt"] = "[Contexto del cliente]\n" + payload["context"] + "\n\n[Mensaje]\n" + payload["prompt"]
            body = json.dumps(outgoing, allow_nan=False).encode("utf-8")
            request = Request(BACKEND_URL + "/api/chat", data=body, method="POST",
                              headers={"Content-Type": "application/json"})
            try:
                with urlopen(request, timeout=120) as response:
                    data = json.loads(response.read())
            except HTTPError as error:
                error.close()
                raise RuntimeError(f"NanoRuntime respondió HTTP {error.code}; no se generó una respuesta válida") from None
            if not isinstance(data, dict) or data.get("error") or data.get("tier") == "error" or not isinstance(data.get("response"), str) or not data["response"].strip():
                raise RuntimeError("El runtime no produjo una respuesta válida")
            tok_s = data.get("tok_s")
            valid_tok_s = round(float(tok_s), 2) if isinstance(tok_s, (int, float)) and not isinstance(tok_s, bool) and tok_s > 0 else None
            if valid_tok_s is not None:
                self.last_tok_s = valid_tok_s
            return {**data, "tok_s": valid_tok_s, "model": model["path"], "tier": "local", "buffered": True}
        finally:
            self.lock.release()

    def _stop_owned(self):
        """Detiene el proceso hijo y cierra el Job Object de Windows."""
        if self.job:
            self.job.close()
            self.job = None
        if self.process:
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
            self.process = None
        self.selected = None
        self.last_tok_s = None

    def close(self):
        """Garantiza limpieza al cerrar el servidor."""
        self._stop_owned()
