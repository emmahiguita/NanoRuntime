#!/usr/bin/env python3
r"""
NanoAI Research — Rellena los placeholders \TODO{} del paper con datos reales.

Toma los JSONs de benchmark y actualiza docs/paper/main.tex automáticamente.
Ejecutar DESPUÉS de correr todos los scripts de benchmark.

Uso:
    python3 scripts/fill_paper_todos.py

Fuentes de datos:
    data/research/eval_results.json        → MMLU, HumanEval
    data/research/routing_results.json     → routing metrics
    data/research/benchmark_summary.json   → RAM, tok/s, cold start (desde benchmark_memory.sh)
"""

import json
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

PAPER_PATH = Path("docs/paper/main.tex")
EVAL_PATH = Path("data/research/eval_results.json")
ROUTING_PATH = Path("data/research/routing_results.json")
BENCH_PATH = Path("data/research/benchmark_summary.json")


def load_json(path: Path) -> dict:
    if not path.exists():
        print(f"⚠️  No encontrado: {path} — se saltará")
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def apply_todo(tex: str, key: str, value: str) -> str:
    """Reemplaza \\TODO{key} con value en el LaTeX."""
    pattern = r'\\TODO\{' + re.escape(key) + r'\}'
    return re.sub(pattern, value, tex)


def main():
    if not PAPER_PATH.exists():
        print(f"❌ Paper no encontrado: {PAPER_PATH}")
        sys.exit(1)

    tex = PAPER_PATH.read_text(encoding="utf-8")
    replacements = {}

    # ── Calidad del modelo (MMLU, HumanEval) ────────────────────────
    eval_data = load_json(EVAL_PATH)
    if eval_data:
        mmlu = eval_data.get("mmlu", {})
        he = eval_data.get("humaneval", {})
        if mmlu:
            replacements["MMLU_ACC"] = f"{mmlu.get('accuracy_pct', 0):.1f}\\%"
            replacements["MMLU_CORRECT"] = str(mmlu.get("correct", "?"))
            replacements["MMLU_TOTAL"] = str(mmlu.get("total", "?"))
            replacements["MMLU_LAT"] = f"{mmlu.get('avg_latency_ms', 0):.0f}"
        if he:
            replacements["HUMANEVAL_P1"] = f"{he.get('pass_at_1_pct', 0):.1f}\\%"
            replacements["HUMANEVAL_PASSED"] = str(he.get("passed", "?"))
            replacements["HUMANEVAL_TOTAL"] = str(he.get("total", "?"))
            replacements["HUMANEVAL_LAT"] = f"{he.get('avg_latency_ms', 0):.0f}"

    # ── Routing (entropía, tiers, costo) ────────────────────────────
    routing_data = load_json(ROUTING_PATH)
    if routing_data:
        s = routing_data.get("summary", {})
        r = s.get("routing", {})
        p = s.get("performance", {})
        c = s.get("cost", {})

        replacements["ROUTING_LOCAL"] = str(r.get("local_count", "?"))
        replacements["ROUTING_CLOUD"] = str(r.get("cloud_count", "?"))
        replacements["ROUTING_ACC"] = f"{r.get('routing_accuracy_pct', 0):.1f}\\%"
        replacements["ENTROPY_LOCAL"] = f"{p.get('avg_entropy_local', 0):.3f}"
        replacements["ENTROPY_CLOUD"] = f"{p.get('avg_entropy_cloud', 0):.3f}"
        replacements["LAT_LOCAL"] = f"{p.get('avg_latency_local_ms', 0):.0f}"
        replacements["LAT_CLOUD"] = f"{p.get('avg_latency_cloud_ms', 0):.0f}"
        replacements["CLOUD_COST"] = f"\\${c.get('cloud_cost_usd', 0):.5f}"
        replacements["ALL_CLOUD_COST"] = f"\\${c.get('hypothetical_all_cloud_cost_usd', 0):.5f}"
        replacements["COST_SAVINGS"] = f"{c.get('cost_savings_pct', 0):.1f}\\%"

    # ── Benchmark memoria (desde benchmark_memory.sh) ────────────────
    bench_data = load_json(BENCH_PATH)
    if bench_data:
        nm = bench_data.get("nanortime", {})
        bl = bench_data.get("baseline", {})
        replacements["NANO_RSS"] = f"{nm.get('peak_rss_gb', '?')}"
        replacements["NANO_TOK_S"] = f"{nm.get('avg_tok_s', '?')}"
        replacements["BASELINE_RSS"] = f"{bl.get('peak_rss_gb', '?')}"
        replacements["FILE_SIZE_GB"] = f"{nm.get('file_size_gb', '?')}"
        replacements["FILE_RAM_RATIO"] = f"{nm.get('file_to_ram_ratio', '?')}"
        replacements["COLD_START_S"] = f"{nm.get('cold_start_s', '?')}"
        replacements["CONTEXT_TOKENS"] = f"{nm.get('context_tokens', '?')}"

    # Aplicar reemplazos
    applied = []
    for key, val in replacements.items():
        new_tex = apply_todo(tex, key, val)
        if new_tex != tex:
            tex = new_tex
            applied.append(f"  {key} → {val}")

    PAPER_PATH.write_text(tex, encoding="utf-8")

    print("=" * 50)
    print("Paper TODO fill-in")
    print("=" * 50)
    if applied:
        for line in applied:
            print(line)
        print(f"\n✅ {len(applied)} valores rellenados en {PAPER_PATH}")
    else:
        print("ℹ️  No se encontraron TODOs coincidentes. Verifica las claves en main.tex.")

    # Contar TODOs restantes
    remaining = re.findall(r'\\TODO\{[^}]+\}', tex)
    print(f"⏳ TODOs restantes: {len(remaining)}")
    for t in remaining:
        print(f"   {t}")


if __name__ == "__main__":
    main()
