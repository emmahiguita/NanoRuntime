#!/usr/bin/env python3
"""Baseline llama.cpp vía llama-server: mmap vs --no-mmap.

Mide generación sostenida (timings del server), cold start de carga y RSS
del proceso servidor (psutil), 5 iteraciones por modo.
"""
import json
import subprocess
import time
import urllib.request
from pathlib import Path

import psutil

MODEL = Path(r"C:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\data\qwen_tmp.gguf")
SERVER = r"C:\llama-cpp-server\bin\llama-server.exe"
PROMPT = "Explain the attention mechanism in transformers and why it scales quadratically with sequence length."
N_TOKENS = 80


def run_baseline(mode: str, port: int, iterations: int = 5):
    cmd = [SERVER, "--model", str(MODEL), "-ngl", "0", "-t", "8",
           "--port", str(port), "--no-webui"]
    if mode == "nommap":
        cmd.append("--no-mmap")

    print(f"\n[{mode}] arrancando server en :{port}")
    t_load0 = time.monotonic()
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))

    # Esperar health
    for _ in range(60):
        try:
            urllib.request.urlopen(f"http://localhost:{port}/health", timeout=2)
            break
        except Exception:
            time.sleep(0.5)
    load_ms = (time.monotonic() - t_load0) * 1000
    server_rss = psutil.Process(proc.pid).memory_info().rss / (1024 * 1024)

    runs = []
    for i in range(iterations):
        body = json.dumps({"prompt": PROMPT, "n_predict": N_TOKENS, "seed": 42,
                           "temperature": 0, "cache_prompt": False}).encode()
        t0 = time.monotonic()
        req = urllib.request.Request(f"http://localhost:{port}/completion", data=body,
                                     headers={"Content-Type": "application/json"})
        resp = json.loads(urllib.request.urlopen(req, timeout=300).read())
        wall = (time.monotonic() - t0) * 1000
        tim = resp.get("timings", {})
        tok_s = tim.get("predicted_per_second")
        pred_ms = tim.get("predicted_ms")
        tokens = resp.get("content", "").count(" ") + 1
        run = {
            "iter": i + 1,
            "wall_ms": round(wall, 1),
            "tok_s": round(tok_s, 2) if tok_s else None,
            "tokens": tokens,
            "server_rss_mb": round(server_rss, 1),
            "load_ms": round(load_ms, 1),
        }
        runs.append(run)
        print(f"  [{i+1}/{iterations}] tok/s={run['tok_s']} wall={wall:.0f}ms RSS={server_rss:.0f}MB")

    proc.terminate()
    try:
        proc.wait(timeout=10)
    except Exception:
        proc.kill()
    return {"mode": mode, "load_ms": round(load_ms, 1), "server_rss_mb": round(server_rss, 1),
            "runs": runs}


def main():
    results = [run_baseline("mmap", 8091), run_baseline("nommap", 8092)]
    dest = Path(r"C:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\data\research\llama_baseline_results.json")
    dest.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print("\nGuardado en", dest)


if __name__ == "__main__":
    main()
