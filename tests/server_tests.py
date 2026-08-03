#!/usr/bin/env python3
"""Pruebas funcionales del servidor de telemetría (server/main.py).

Uso:
    python tests/server_tests.py

La suite gestiona su propio ciclo de vida: inicia el servidor, ejecuta las
pruebas y lo detiene. No requiere dependencias adicionales (stdlib + websockets).
"""
import asyncio
import json
import os
import signal
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

import websockets

ROOT = Path(__file__).resolve().parent.parent
PORT = 8000
WS_URL = f"ws://localhost:{PORT}/ws/telemetry"
HTTP = f"http://localhost:{PORT}"

PASS = 0
FAIL = 0


def check(name: str, ok: bool, detail: str = ""):
    global PASS, FAIL
    if ok:
        PASS += 1
        print(f"  PASS  {name}" + (f"  [{detail}]" if detail else ""))
    else:
        FAIL += 1
        print(f"  FAIL  {name}" + (f"  [{detail}]" if detail else ""))


def wait_port(host: str, port: int, timeout: float = 30.0) -> bool:
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            with urllib.request.urlopen(f"http://{host}:{port}/metrics", timeout=1.5):
                return True
        except Exception:
            time.sleep(0.5)
    return False


def spawn_server(extra_env=None) -> subprocess.Popen:
    env = dict(os.environ)
    if extra_env:
        env.update(extra_env)
    return subprocess.Popen(
        [sys.executable, str(ROOT / "server" / "main.py")],
        cwd=str(ROOT),
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )


def kill_tree(proc: subprocess.Popen):
    if proc and proc.poll() is None:
        try:
            proc.kill()
        except Exception:
            pass
        proc.wait(timeout=5)


async def ws_snapshots(count: int, timeout_s: float = 60.0) -> list:
    import websockets

    snaps = []
    async with websockets.connect(WS_URL) as ws:
        async with asyncio.timeout(timeout_s):
            for _ in range(count):
                snaps.append(json.loads(await ws.recv()))
    return snaps


async def test_main_suite():
    print("\n== Suites principales (hardware + inferencia real) ==")
    # /metrics
    body = urllib.request.urlopen(f"{HTTP}/metrics", timeout=5).read().decode()
    check(
        "/metrics",
        "nanortime_throughput_tokens_per_sec" in body
        and "nanortime_gpu_vram_allocated_bytes" in body,
    )
    # /api/v1/system-info
    info = json.loads(urllib.request.urlopen(f"{HTTP}/api/v1/system-info", timeout=5).read())
    check("/api/v1/system-info", bool(info["gpuName"]) and info["cpuCores"] > 0, info["gpuName"])

    # contrato WS
    snaps = await ws_snapshots(2)
    snap = snaps[-1]
    required = [
        "timestamp", "timeLabel", "gpuName", "throughputTokSec", "latencyMs", "inference",
        "vramAllocatedMb", "vramTotalMb", "gpuUtilPercent", "cpuUtilPercent", "systemRamMb",
        "systemRamTotalMb", "procRssMb", "tempCelsius", "powerWatts", "realBenchmarkMicrosec",
        "tokenStream",
    ]
    missing = [k for k in required if k not in snap]
    check("contrato WS (18 campos)", not missing, f"faltan: {missing}" if missing else f"{len(snap)} campos")

    # campos fake no deben existir
    fake = [k for k in snap if k in (
        "layerHeatmap", "flameStages", "aiDiagnostics", "avgEntropy", "kvCacheMb",
        "activeContextTokens", "oomRiskPercent", "skewness", "kurtosis", "cpuCores", "swapUsedMb",
    )]
    check("cero campos fake/simulados", not fake, f"residuales: {fake}" if fake else "ok")

    # latencia del ciclo real (perf_counter)
    check("latencia telemetría > 0 µs", snap["realBenchmarkMicrosec"] > 0, f"{snap['realBenchmarkMicrosec']} µs")

    # cadencia ~500ms: 10 snapshots en ~5s
    t0 = time.monotonic()
    batch = await ws_snapshots(10)
    elapsed = time.monotonic() - t0
    cadence_ok = 4.0 <= elapsed <= 8.0
    check("cadencia 500ms (10 snaps en ~5s)", cadence_ok, f"{elapsed:.1f}s")

    # ciclo real de inferencia (paciencia: carga de modelo 1.09GB en frío)
    inf = snap["inference"]
    if inf["available"]:
        done = False
        async with asyncio.timeout(40):
            async with websockets.connect(WS_URL) as ws:
                while True:
                    s = json.loads(await ws.recv())
                    if s["inference"]["tokSec"] > 0 and s["inference"]["tokens"] > 0:
                        i = s["inference"]
                        check(
                            "inferencia real (tok/s, latencia, tokens, texto)",
                            i["tokSec"] > 0 and i["latencyMsPerToken"] > 0 and len(s["tokenStream"]) > 0,
                            f"{i['tokSec']} tok/s · {i['latencyMsPerToken']} ms/tok · {i['tokens']} tokens",
                        )
                        done = True
                        break
        check("ciclo de inferencia completó a tiempo", done)
    else:
        print("  SKIP  inferencia real (motor/modelo no disponibles)")


def test_disabled_mode():
    print("\n== Modo deshabilitado (NANO_INFERENCE_ENABLED=0) ==")
    proc = spawn_server({"NANO_INFERENCE_ENABLED": "0"})
    try:
        if not wait_port("localhost", PORT):
            check("servidor arrancó", False)
            return
        body = urllib.request.urlopen(f"{HTTP}/metrics", timeout=5).read().decode()
        check("servidor arrancó en modo deshabilitado", "nanortime_throughput_tokens_per_sec" in body)
        import websockets

        asyncio.run(_check_disabled())
    finally:
        kill_tree(proc)


async def _check_disabled():
    import websockets

    async with websockets.connect(WS_URL) as ws:
        snap = json.loads(await ws.recv())
        check("inference.available=False (no lanza motor)", snap["inference"]["available"] is False)


def test_missing_model():
    print("\n== Modelo inexistente (NANO_MODEL inválido) ==")
    proc = spawn_server({"NANO_MODEL": "C:/no/existe.gguf"})
    try:
        if not wait_port("localhost", PORT):
            check("servidor arrancó", False)
            return
        import websockets

        asyncio.run(_check_missing_model())
    finally:
        kill_tree(proc)


async def _check_missing_model():
    import websockets

    async with websockets.connect(WS_URL) as ws:
        snap = json.loads(await ws.recv())
        inf = snap["inference"]
        check("available=False con modelo inválido", inf["available"] is False)
        check("error descriptivo presente", "no encontrado" in inf["error"].lower(), inf["error"])


def main():
    server = spawn_server()
    try:
        if not wait_port("localhost", PORT):
            print("FAIL  servidor no arrancó")
            sys.exit(1)
        asyncio.run(test_main_suite())
    finally:
        kill_tree(server)
        time.sleep(1)

    test_disabled_mode()
    time.sleep(1)
    test_missing_model()

    print(f"\n===== RESUMEN: {PASS} PASS, {FAIL} FAIL =====")
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
