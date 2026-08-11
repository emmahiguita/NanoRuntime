#!/usr/bin/env python3
"""
Automated NanoRuntime Test Suite — Multi-device, multi-model.
Runs queries, captures metrics, generates JSON + Markdown report.

Usage: python scripts/auto_test.py
Output: data/research/evidence_package/sessions/auto_test_YYYYMMDD_HHMMSS/
"""

import json, os, subprocess, sys, time, argparse, re, shlex
from pathlib import Path
from datetime import datetime

# Fix Windows encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# ── Config ──────────────────────────────────────────────────────────────

PROJECT = Path(__file__).resolve().parent.parent
ADB = r"C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"
WORKDIR = "/data/local/tmp"
BINARY = f"{WORKDIR}/nanortime"

MODELS = {
    "qwen-1.5b": f"{WORKDIR}/qwen.gguf",
    "deepseek-7b-q2k": f"{WORKDIR}/deepseek-q2k.gguf",
    "deepseek-7b-q4": f"{WORKDIR}/deepseek.gguf",
}

QUERIES = [
    # Matemáticas
    ("math_1", "What is 7 times 8?"),
    ("math_2", "What is the square root of 144?"),
    ("math_3", "What is 15 percent of 200?"),
    # Geografía
    ("geo_1", "What is the capital of Japan?"),
    ("geo_2", "What is the largest ocean on Earth?"),
    # Programación
    ("code_1", "What does CPU stand for?"),
    ("code_2", "Define recursion in programming."),
    ("code_3", "What does HTTP stand for?"),
    # Ciencia
    ("sci_1", "What is the speed of light?"),
    ("sci_2", "What is the chemical symbol for gold?"),
]

# ── Helpers ─────────────────────────────────────────────────────────────

def adb_shell(device: str, cmd: str, timeout: int = 30) -> str:
    return subprocess.run(
        [ADB, "-s", device, "shell", cmd],
        capture_output=True, text=True, timeout=timeout
    ).stdout

def run_query(device: str, model_key: str, prompt: str, max_tokens: int = 20) -> dict:
    """Run a single query and capture metrics."""
    model_path = MODELS[model_key]
    # Build chat prompt (no html special chars - just plain text)
    chat_prompt = f"<|im_start|>user\n{prompt}\n<|im_end|>\n<|im_start|>assistant\n"

    ram_before = adb_shell(device, "cat /proc/meminfo | grep MemAvailable").strip()

    t0 = time.monotonic()
    # shlex.quote() provides complete POSIX shell escaping: handles single
    # quotes, double quotes, backticks, $(), semicolons, and all other
    # metacharacters. The previous replace("'", "'\\''") only handled
    # single quotes, leaving the prompt vulnerable to command injection.
    cmd = (
        f"cd {WORKDIR} && LD_LIBRARY_PATH={WORKDIR} {BINARY} "
        f"--model {shlex.quote(model_path)} "
        f"--prompt {shlex.quote(chat_prompt)} "
        f"--max-tokens {max_tokens} --temperature 0.0 --edge-only --quiet"
    )
    result = subprocess.run(
        [ADB, "-s", device, "shell", cmd],
        capture_output=True, text=True, timeout=180
    )
    output = result.stdout
    elapsed_s = time.monotonic() - t0
    combined = result.stdout + result.stderr

    ram_after = adb_shell(device, "cat /proc/meminfo | grep MemAvailable").strip()

    # Parse metrics from combined stdout+stderr
    tok_s = re.search(r'tok_s=([\d.]+)', combined)
    confidence = re.search(r'confidence=([\d.]+)', combined)
    tokens = re.search(r'tokens=(\d+)', combined)

    # Extract response text from stdout (remove log lines)
    response_lines = [l for l in output.split('\n') if not any(
        tag in l for tag in ['INFO', 'WARN', 'DEBUG', 'METRICS', '2026-', '[METRICS]']
    ) if l.strip()]
    response = ' '.join(l.strip() for l in response_lines[-5:] if l.strip())

    # Parse RAM values
    ram_before_mb = int(re.search(r'(\d+)', ram_before).group(1)) // 1024 if re.search(r'(\d+)', ram_before) else 0
    ram_after_mb = int(re.search(r'(\d+)', ram_after).group(1)) // 1024 if re.search(r'(\d+)', ram_after) else 0

    return {
        "tok_s": float(tok_s.group(1)) if tok_s else 0,
        "confidence": float(confidence.group(1)) if confidence else 0,
        "tokens": int(tokens.group(1)) if tokens else 0,
        "elapsed_s": round(elapsed_s, 2),
        "response": response[:150],
        "ram_before_mb": ram_before_mb,
        "ram_after_mb": ram_after_mb,
        "ram_delta_mb": ram_after_mb - ram_before_mb,
        "success": bool(tok_s),
    }

# ── Main ────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", default=None, help="Device ID (default: auto-detect)")
    parser.add_argument("--model", default="qwen-1.5b", choices=list(MODELS.keys()))
    parser.add_argument("--queries", type=int, default=10)
    args = parser.parse_args()

    # Detect device
    if args.device:
        device = args.device
    else:
        devices_out = subprocess.run([ADB, "devices"], capture_output=True, text=True).stdout
        available = [l.split()[0] for l in devices_out.split('\n') if 'device' in l and 'List' not in l]
        if not available:
            print("No devices found. Aborting.")
            sys.exit(1)
        device = available[0]
        print(f"Using device: {device}")

    # Output directory
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    session_dir = PROJECT / "data" / "research" / "evidence_package" / "sessions" / f"auto_{ts}"
    session_dir.mkdir(parents=True, exist_ok=True)

    print(f"Model: {args.model}")
    print(f"Queries: {args.queries}")
    print(f"Output: {session_dir}")
    print("=" * 50)

    results = []
    for i, (tag, prompt) in enumerate(QUERIES[:args.queries]):
        print(f"\n[{i+1}/{args.queries}] {tag}: {prompt[:50]}...")
        r = run_query(device, args.model, prompt)
        status = "OK" if r["success"] else "FAIL"
        print(f"  {status} | tok_s={r['tok_s']:.2f} | conf={r['confidence']:.3f} | RAM {r['ram_delta_mb']:+d}MB")
        r["tag"] = tag
        r["prompt"] = prompt
        r["model"] = args.model
        r["device"] = device
        results.append(r)

    # Compute stats
    ok = [r for r in results if r["success"]]
    tok_vals = [r["tok_s"] for r in ok]
    conf_vals = [r["confidence"] for r in ok]
    ram_deltas = [r["ram_delta_mb"] for r in ok]

    stats = {
        "total": len(results),
        "success": len(ok),
        "success_rate": f"{len(ok)/max(len(results),1)*100:.0f}%",
        "avg_tok_s": round(sum(tok_vals)/max(len(tok_vals),1), 2),
        "min_tok_s": round(min(tok_vals), 2) if tok_vals else 0,
        "max_tok_s": round(max(tok_vals), 2) if tok_vals else 0,
        "avg_confidence": round(sum(conf_vals)/max(len(conf_vals),1), 3),
        "avg_ram_delta_mb": round(sum(ram_deltas)/max(len(ram_deltas),1), 0),
        "oom_crashes": len(results) - len(ok),
        "device": device,
        "model": args.model,
        "timestamp": datetime.now().isoformat(),
    }

    # Save JSON
    report = {"stats": stats, "queries": results}
    json_path = session_dir / "results.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    print(f"\nJSON: {json_path}")

    # Generate Markdown report
    md_path = session_dir / "report.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(f"# NanoRuntime Automated Test Report\n\n")
        f.write(f"**Date:** {ts}\n")
        f.write(f"**Device:** {device}\n")
        f.write(f"**Model:** {args.model}\n\n")
        f.write(f"## Summary\n\n")
        f.write(f"| Metric | Value |\n|--------|-------|\n")
        f.write(f"| Success | {stats['success']}/{stats['total']} ({stats['success_rate']}) |\n")
        f.write(f"| Avg Tok/s | {stats['avg_tok_s']} |\n")
        f.write(f"| Tok/s Range | {stats['min_tok_s']} - {stats['max_tok_s']} |\n")
        f.write(f"| Avg Confidence | {stats['avg_confidence']} |\n")
        f.write(f"| Avg RAM Δ | {stats['avg_ram_delta_mb']} MB |\n")
        f.write(f"| OOM Crashes | {stats['oom_crashes']} |\n\n")
        f.write(f"## Queries\n\n")
        f.write(f"| # | Topic | Tok/s | Conf | RAM Δ | Response |\n")
        f.write(f"|---|-------|-------|------|-------|----------|\n")
        for i, r in enumerate(results):
            f.write(f"| {i+1} | {r['tag']} | {r['tok_s']:.2f} | {r['confidence']:.3f} | {r['ram_delta_mb']:+d} MB | {r['response'][:60]} |\n")

    print(f"Report: {md_path}")
    print("=" * 50)
    print(f"COMPLETED: {stats['success']}/{stats['total']} successful, {stats['oom_crashes']} crashes")


if __name__ == "__main__":
    main()
