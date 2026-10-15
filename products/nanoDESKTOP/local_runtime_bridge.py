"""Adaptador Desktop al ejecutable existente de NanoRuntime; el core no se modifica."""

import atexit
import ctypes
import json
import os
import subprocess
import threading
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from local_model_catalog import PROJECT_ROOT, resolve_model
from windows_runtime_job import RuntimeJob

BACKEND_URL = "http://127.0.0.1:8080"


def runtime_status() -> dict:
    """Proceso accesible no significa modelo listo; conserva el contrato real del motor."""
    try:
        with urlopen(BACKEND_URL + "/api/status", timeout=3) as response:
            data = json.loads(response.read())
            return data if isinstance(data, dict) else {"status": "offline"}
    except (OSError, ValueError, URLError):
        return {"status": "offline", "model_loaded": False}


def system_memory() -> dict:
    """Mide RAM del PC mediante Windows; GPU y tok/s nunca se deducen ni simulan."""
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


class LocalRuntimeBridge:
    """Serializa carga/inferencia y administra solo el proceso que esta instancia inició."""

    def __init__(self):
        self.lock = threading.Lock()
        self.process, self.job, self.selected = None, None, None
        atexit.register(self.close)

    def status(self):
        """Normaliza dos contratos existentes sin fabricar identificación o disponibilidad."""
        raw = runtime_status()
        path = raw.get("model") or raw.get("model_name")
        ready = raw.get("model_status") == "ready" or raw.get("model_loaded") is True
        return {**raw, **system_memory(), "model_path": path, "model_name": path,
                "model_loaded": ready, "status": "running" if raw.get("status") == "running" else "offline"}

    def activate(self, identifier: str):
        """Cambiar modelo no interrumpe una inferencia ni sustituye procesos de otros programas."""
        model = resolve_model(identifier)
        if not self.lock.acquire(blocking=False):
            raise RuntimeError("El motor está ocupado; espera a que termine la respuesta")
        started_new = False
        try:
            current = runtime_status()
            if current.get("model") == model["path"]:
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
                current = runtime_status()
                if current.get("model") == model["path"]:
                    self.selected = model
                    return {"selected": model, "runtime": self.status()}
                time.sleep(0.1)
            raise RuntimeError("El runtime no confirmó el modelo seleccionado")
        except (OSError, ValueError, RuntimeError):
            # Un rechazo por motor externo no debe apagarlo; solo se liberan hijos propios.
            if started_new:
                self._stop_owned()
            raise
        finally:
            self.lock.release()

    def chat(self, payload: dict):
        """Envía historial/identidad al servidor real y rechaza respuestas de un modelo distinto."""
        model = resolve_model(str(payload.get("model", "")))
        if not self.lock.acquire(blocking=False):
            raise RuntimeError("El motor está ocupado; no se encoló otra respuesta")
        try:
            if runtime_status().get("model") != model["path"]:
                raise RuntimeError("Activa el modelo elegido antes de escribirle")
            body = json.dumps(payload).encode("utf-8")
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
            return {**data, "model": model["path"], "tier": "local", "buffered": True}
        finally:
            self.lock.release()

    def _stop_owned(self):
        """Cierre acotado; Job Object impide dejar el ejecutable huérfano."""
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

    def close(self):
        """Se llama al cerrar el servidor; nunca manipula un proceso ajeno."""
        self._stop_owned()
