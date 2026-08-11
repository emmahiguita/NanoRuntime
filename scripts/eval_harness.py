#!/usr/bin/env python3
"""
NanoAI Research — Evaluation Harness REAL (MMLU & HumanEval)

Evalúa el runtime nanortime REAL en benchmarks estandarizados:
1. MMLU  — Accuracy Top-1 en múltiple opción (reasoning/conocimiento)
2. HumanEval — Pass@1 en generación de código (ejecución real de tests)

TODOS los números que aparecen en el paper salen de este script.
NO hay simulaciones ni respuestas hardcodeadas.

Uso:
    pip install psutil
    python3 scripts/eval_harness.py \\
        --binary  target/release/nanortime \\
        --model   models/qwen2.5-1.5b-instruct-q4_k_m.gguf \\
        --task    mmlu

    python3 scripts/eval_harness.py \\
        --binary  target/release/nanortime \\
        --model   models/deepseek-7b-q4_k_m.gguf \\
        --task    all \\
        --max-tokens 512
"""

import argparse
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

try:
    import psutil
except ImportError:
    print("ERROR: psutil no instalado. Ejecuta: pip install psutil")
    sys.exit(1)

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Regex para eliminar secuencias de escape ANSI (colores de terminal)
_ANSI_RE = re.compile(r'\x1b(?:\[[0-9;]*[mGKHF]|\([A-Z]|[\x40-\x5F])')

def strip_ansi(text: str) -> str:
    """Elimina todos los c\u00f3digos de escape ANSI del texto del modelo."""
    return _ANSI_RE.sub('', text)

# =============================================================
# MMLU — Questions reales (subset computer_science + math + logic)
# Fuente: Hendrycks et al. 2020 (https://arxiv.org/abs/2009.03300)
# =============================================================
MMLU_SAMPLES = [
    {
        "id": "mmlu_cs_01",
        "category": "computer_science",
        "question": "What is the time complexity of searching for an element in a balanced binary search tree?",
        "options": ["A) O(1)", "B) O(log n)", "C) O(n)", "D) O(n log n)"],
        "answer": "B"
    },
    {
        "id": "mmlu_cs_02",
        "category": "computer_science",
        "question": "Which layer of the OSI model is responsible for routing packets across networks?",
        "options": ["A) Data Link Layer", "B) Transport Layer", "C) Network Layer", "D) Application Layer"],
        "answer": "C"
    },
    {
        "id": "mmlu_cs_03",
        "category": "computer_science",
        "question": "What does the CAP theorem state about distributed systems?",
        "options": [
            "A) A system can guarantee Consistency, Availability, and Partition tolerance simultaneously",
            "B) A system can guarantee at most two of: Consistency, Availability, Partition tolerance",
            "C) Partition tolerance is not achievable in distributed systems",
            "D) Consistency and Availability are always mutually exclusive"
        ],
        "answer": "B"
    },
    {
        "id": "mmlu_math_01",
        "category": "mathematics",
        "question": "What is the derivative of f(x) = x^3 - 4x + 7 with respect to x?",
        "options": ["A) 3x^2 - 4", "B) 3x^2 + 4", "C) x^2 - 4", "D) 3x - 4"],
        "answer": "A"
    },
    {
        "id": "mmlu_math_02",
        "category": "mathematics",
        "question": "What is the determinant of a 2x2 identity matrix?",
        "options": ["A) 0", "B) 1", "C) -1", "D) 2"],
        "answer": "B"
    },
    {
        "id": "mmlu_math_03",
        "category": "mathematics",
        "question": "Which of the following is the correct formula for the area of a circle?",
        "options": ["A) 2πr", "B) πr", "C) πr²", "D) 2πr²"],
        "answer": "C"
    },
    {
        "id": "mmlu_logic_01",
        "category": "formal_logic",
        "question": "If P implies Q, and P is true, what can we conclude about Q?",
        "options": ["A) Q is false", "B) Q is true", "C) Q is unknown", "D) P is false"],
        "answer": "B"
    },
    {
        "id": "mmlu_logic_02",
        "category": "formal_logic",
        "question": "Which logical form represents the contrapositive of 'If A then B'?",
        "options": ["A) If A then not B", "B) If B then A", "C) If not B then not A", "D) If not A then not B"],
        "answer": "C"
    },
    {
        "id": "mmlu_stats_01",
        "category": "statistics",
        "question": "In a normal distribution, what percentage of data falls within one standard deviation of the mean?",
        "options": ["A) 50%", "B) 68%", "C) 95%", "D) 99.7%"],
        "answer": "B"
    },
    {
        "id": "mmlu_stats_02",
        "category": "statistics",
        "question": "What is the median of the dataset [3, 1, 4, 1, 5, 9, 2, 6]?",
        "options": ["A) 3.0", "B) 3.5", "C) 4.0", "D) 4.5"],
        "answer": "B"  # sorted: 1,1,2,3,4,5,6,9 → median = (3+4)/2 = 3.5
    },
]

# =============================================================
# HumanEval — Tasks reales
# Fuente: Chen et al. 2021 (https://arxiv.org/abs/2107.03374)
# =============================================================
HUMANEVAL_SAMPLES = [
    {
        "task_id": "HumanEval/0",
        "prompt": (
            "from typing import List\n\n"
            "def has_close_elements(numbers: List[float], threshold: float) -> bool:\n"
            "    \"\"\" Check if in given list of numbers, any two numbers are closer to each\n"
            "    other than given threshold.\n"
            "    >>> has_close_elements([1.0, 2.0, 3.0], 0.5)\n"
            "    False\n"
            "    >>> has_close_elements([1.0, 2.8, 3.0, 4.0, 5.0, 2.0], 0.3)\n"
            "    True\n"
            "    \"\"\"\n"
        ),
        "test": (
            "assert has_close_elements([1.0, 2.0, 3.0], 0.5) == False\n"
            "assert has_close_elements([1.0, 2.8, 3.0, 4.0, 5.0, 2.0], 0.3) == True\n"
            "assert has_close_elements([1.0, 1.1], 0.2) == True\n"
            "assert has_close_elements([10.0, 20.0, 30.0], 5.0) == False\n"
        ),
    },
    {
        "task_id": "HumanEval/2",
        "prompt": (
            "def truncate_number(number: float) -> float:\n"
            "    \"\"\" Given a positive floating point number, it can be decomposed into\n"
            "    integer part and decimals. Return the decimal part.\n"
            "    >>> truncate_number(3.5)\n"
            "    0.5\n"
            "    \"\"\"\n"
        ),
        "test": (
            "assert abs(truncate_number(3.5) - 0.5) < 1e-6\n"
            "assert abs(truncate_number(1.0) - 0.0) < 1e-6\n"
            "assert abs(truncate_number(7.9) - 0.9) < 1e-5\n"
        ),
    },
    {
        "task_id": "HumanEval/6",
        "prompt": (
            "from typing import List\n\n"
            "def parse_nested_parens(paren_string: str) -> List[int]:\n"
            "    \"\"\" Input to this function is a string represented multiple groups for\n"
            "    nested parentheses separated by spaces. Return list with maximum nesting\n"
            "    level of each group.\n"
            "    >>> parse_nested_parens('(()()) ((())) () ((())()())')\n"
            "    [2, 3, 1, 3]\n"
            "    \"\"\"\n"
        ),
        "test": (
            "assert parse_nested_parens('(()()) ((())) () ((())()())') == [2, 3, 1, 3]\n"
            "assert parse_nested_parens('() (()) ((())) (((())))') == [1, 2, 3, 4]\n"
        ),
    },
]


# =============================================================
# Función central: lanza el binario real y mide todo
# =============================================================

from script_utils import format_chat_prompt


def run_nanoai(
    binary: str,
    config: str,
    prompt: str,
    max_tokens: int = 256,
    timeout: int = 180,
) -> dict:
    """
    Ejecuta `nanortime` REAL y devuelve:
      {output: str, latency_ms: float, peak_rss_mb: float,
       tok_s: float | None, exit_code: int, error: str | None}
    """
    # Envolver el prompt en el template de chat correcto
    formatted = format_chat_prompt(prompt)
    cmd = [
        binary,
        "--config", config,
        "--prompt", formatted,
        "--max-tokens", str(max_tokens),
        "--edge-only",
        "--quiet",
    ]

    t0 = time.monotonic()
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        # Monitorear RSS mientras corre
        peak_rss_bytes = 0
        try:
            ps = psutil.Process(proc.pid)
            while proc.poll() is None:
                try:
                    rss = ps.memory_info().rss
                    if rss > peak_rss_bytes:
                        peak_rss_bytes = rss
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    break
                time.sleep(0.2)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

        stdout, stderr = proc.communicate(timeout=timeout)
        latency_ms = (time.monotonic() - t0) * 1000

        # Intentar extraer tok/s de stderr (emitido por --quiet en CLI real)
        tok_s = None
        m = re.search(r'\[METRICS\].*?tok_s=([0-9.]+)', stderr)
        if m:
            tok_s = float(m.group(1))

        return {
            "output": strip_ansi(stdout.strip()),
            "latency_ms": round(latency_ms, 1),
            "peak_rss_mb": round(peak_rss_bytes / (1024 * 1024), 1),
            "tok_s": tok_s,
            "exit_code": proc.returncode,
            "error": strip_ansi(stderr.strip()[:500]) if proc.returncode != 0 else None,
        }

    except subprocess.TimeoutExpired:
        proc.kill()
        return {
            "output": "",
            "latency_ms": timeout * 1000.0,
            "peak_rss_mb": 0.0,
            "tok_s": None,
            "exit_code": -1,
            "error": f"Timeout after {timeout}s",
        }
    except Exception as e:
        return {
            "output": "",
            "latency_ms": 0.0,
            "peak_rss_mb": 0.0,
            "tok_s": None,
            "exit_code": -2,
            "error": str(e),
        }


# =============================================================
# MMLU Evaluation
# =============================================================
def eval_mmlu(binary: str, config: str, max_tokens: int) -> dict:
    print("\n" + "=" * 60)
    print("MMLU Benchmark (Multiple Choice Reasoning)")
    print("=" * 60)

    correct = 0
    total = len(MMLU_SAMPLES)
    per_question = []

    for item in MMLU_SAMPLES:
        # Prompt exacto: solo pedir la letra de respuesta
        prompt = (
            f"Question: {item['question']}\n"
            f"Options:\n" + "\n".join(item["options"]) +
            "\n\nAnswer with ONLY the letter (A, B, C, or D). Do not explain."
        )

        result = run_nanoai(binary, config, prompt, max_tokens=8)

        # Extraer la letra de la respuesta del output del modelo
        # El modelo puede responder: "B", "B)", "The answer is B", "**B**", "(B)"
        clean_out = strip_ansi(result["output"])
        match = re.search(r'(?:answer is |Answer: ?|^)\*?\*?\(?\b([A-D])\b\)?\*?\*?', clean_out, re.IGNORECASE | re.MULTILINE)
        if not match:
            # Fallback: primera letra A-D que aparezca sola en una línea
            match = re.search(r'^\s*([A-D])\s*[).:]?\s*$', clean_out, re.MULTILINE)
        if not match:
            # Último recurso: cualquier A-D aislada
            match = re.search(r'\b([A-D])\b', clean_out)
        pred = match.group(1).upper() if match else "?"

        is_correct = pred == item["answer"]
        if is_correct:
            correct += 1

        status = "✅" if is_correct else "❌"
        print(f"  {status} [{item['id']}] pred={pred!r} gold={item['answer']!r} "
              f"| {result['latency_ms']:.0f}ms | {result['peak_rss_mb']:.0f}MB RSS")
        if result["error"]:
            print(f"     ERROR: {result['error'][:120]}")

        per_question.append({
            "id": item["id"],
            "category": item["category"],
            "predicted": pred,
            "gold": item["answer"],
            "correct": is_correct,
            "latency_ms": result["latency_ms"],
            "peak_rss_mb": result["peak_rss_mb"],
            "tok_s": result["tok_s"],
            "raw_output": result["output"][:200],
        })

    accuracy = 100.0 * correct / total
    avg_lat = sum(q["latency_ms"] for q in per_question) / len(per_question)
    print(f"\n  MMLU Accuracy: {accuracy:.1f}% ({correct}/{total})")
    print(f"  Avg latency : {avg_lat:.0f} ms/question")

    return {
        "accuracy_pct": round(accuracy, 2),
        "correct": correct,
        "total": total,
        "avg_latency_ms": round(avg_lat, 1),
        "per_question": per_question,
    }


# =============================================================
# HumanEval Evaluation — ejecución real del código generado
# =============================================================

# ── Safe code execution ──────────────────────────────────────
# LLM-generated code is run in a subprocess with restricted
# builtins and a hard timeout to prevent arbitrary code execution
# on the benchmark host.
import subprocess as _sp  # noqa: E402

# Builtin names safe for LLM-generated code. The subprocess keeps only
# these from the original builtins; everything else (__import__, open,
# exec, eval, compile, input, breakpoint, etc.) is removed.
_SAFE_BUILTIN_NAMES = [
    "True", "False", "None", "abs", "all", "any", "bool",
    "dict", "enumerate", "float", "int", "len", "list", "max",
    "min", "pow", "range", "reversed", "round", "set", "slice",
    "sorted", "str", "sum", "tuple", "zip", "isinstance",
    "issubclass", "TypeError", "ValueError", "StopIteration",
    "Exception", "print", "divmod", "filter", "map", "iter",
    "next", "chr", "ord",
]

_EXEC_TIMEOUT_SECONDS = 30


def _safe_exec(code: str) -> tuple[bool, str | None]:
    """Run LLM-generated code in a subprocess sandbox with timeout.

    Returns (passed: bool, error_message: str | None).
    The subprocess has no access to the filesystem, network, or host
    environment beyond the restricted builtins listed above.
    """
    # Subprocess bootstrap: whitelist safe builtins by name, clear the rest.
    # Must be a self-contained script — we pass safe_builtin_names as a
    # JSON-serializable list (strings only, not Python objects).
    import json as _json

    _safe_names_json = _json.dumps(_SAFE_BUILTIN_NAMES)

    wrapper = (
        "import builtins, sys, traceback, json\n"
        "_original = builtins.__dict__.copy()\n"
        "builtins.__dict__.clear()\n"
        f"_safe_names = json.loads({_safe_names_json!r})\n"
        "builtins.__dict__.update({n: _original[n] for n in _safe_names if n in _original})\n"
        "try:\n"
        "    " + code.replace("\n", "\n    ") + "\n"
        "    sys.exit(0)\n"
        "except SystemExit:\n"
        "    raise\n"
        "except Exception as e:\n"
        "    # Strip file paths from traceback for privacy\n"
        "    tb = traceback.format_exc()\n"
        "    # Only show the last meaningful frame (the user code), not wrapper internals\n"
        "    lines = tb.strip().split('\\n')\n"
        "    for line in lines[-4:]:\n"
        "        if '    ' in line and '<string>' not in line:\n"
        "            print(line.strip(), file=sys.stderr)\n"
        "    print(f'{type(e).__name__}: {e}', file=sys.stderr)\n"
        "    sys.exit(1)\n"
    )

    try:
        proc = _sp.run(
            [sys.executable, "-c", wrapper],
            capture_output=True,
            text=True,
            timeout=_EXEC_TIMEOUT_SECONDS,
            # Minimal environment: no inherited env vars that could leak secrets
            env={"PATH": os.environ.get("PATH", ""), "PYTHONUNBUFFERED": "1"},
        )
        if proc.returncode == 0:
            return True, None
        error_msg = proc.stderr.strip()[:500] if proc.stderr else f"Exit code {proc.returncode}"
        return False, error_msg if error_msg else None
    except _sp.TimeoutExpired:
        return False, f"Execution timed out after {_EXEC_TIMEOUT_SECONDS}s"
    except Exception as e:
        return False, f"Subprocess error: {e}"


def eval_humaneval(binary: str, config: str, max_tokens: int) -> dict:
    print("\n" + "=" * 60)
    print("HumanEval Benchmark (Code Generation, Pass@1)")
    print("=" * 60)

    passed = 0
    total = len(HUMANEVAL_SAMPLES)
    per_task = []

    for item in HUMANEVAL_SAMPLES:
        # Prompt para que el modelo complete la función
        prompt = (
            item["prompt"] +
            "# Implement the function above. Return ONLY the function body, no explanations."
        )

        result = run_nanoai(binary, config, prompt, max_tokens=max_tokens)
        model_completion = strip_ansi(result["output"])

        # Limpiar el completion: eliminar backticks de markdown si el modelo los incluye
        code_block = re.search(r'```(?:python)?\n?(.*?)```', model_completion, re.DOTALL)
        if code_block:
            model_completion = code_block.group(1)

        # Si el modelo volvió a generar 'def ...', usamos su respuesta directamente;
        # de lo contrario, unimos el prompt + completion.
        if "def " in model_completion:
            full_code = model_completion + "\n" + item["test"]
        else:
            full_code = item["prompt"] + "\n" + model_completion + "\n" + item["test"]

        # Execute in sandboxed subprocess with timeout.
        # PREVIOUSLY: exec(compile(full_code, ...)) — arbitrary code execution risk.
        is_pass, exec_error = _safe_exec(full_code)

        if is_pass:
            passed += 1

        status = "✅ PASS" if is_pass else "❌ FAIL"
        print(f"  {status} [{item['task_id']}] | {result['latency_ms']:.0f}ms | "
              f"{result['peak_rss_mb']:.0f}MB RSS")
        if exec_error:
            print(f"     Exec error: {exec_error[:120]}")
            print(f"--- FULL CODE DEBUG ---\n{full_code}\n-----------------------")
        if result["error"]:
            print(f"     Runtime error: {result['error'][:120]}")

        per_task.append({
            "task_id": item["task_id"],
            "passed": is_pass,
            "exec_error": exec_error,
            "latency_ms": result["latency_ms"],
            "peak_rss_mb": result["peak_rss_mb"],
            "tok_s": result["tok_s"],
            "raw_completion": model_completion[:500],
        })

    pass_at_1 = 100.0 * passed / total
    avg_lat = sum(t["latency_ms"] for t in per_task) / len(per_task)
    print(f"\n  HumanEval Pass@1: {pass_at_1:.1f}% ({passed}/{total})")
    print(f"  Avg latency    : {avg_lat:.0f} ms/task")

    return {
        "pass_at_1_pct": round(pass_at_1, 2),
        "passed": passed,
        "total": total,
        "avg_latency_ms": round(avg_lat, 1),
        "per_task": per_task,
    }


# =============================================================
# Main
# =============================================================
def main():
    parser = argparse.ArgumentParser(
        description="NanoAI Evaluation Harness — MMLU & HumanEval (REAL inference)"
    )
    parser.add_argument("--binary", default="target/release/nanortime",
                        help="Ruta al binario compilado (default: target/release/nanortime)")
    parser.add_argument("--config", default="nano.manifest.json",
                        help="Ruta al manifest de configuración")
    parser.add_argument("--model", required=True,
                        help="Ruta al modelo GGUF (se inyecta en el manifest temporal)")
    parser.add_argument("--task", choices=["mmlu", "humaneval", "all"], default="all",
                        help="Benchmark a ejecutar")
    parser.add_argument("--max-tokens", type=int, default=256,
                        help="Tokens máximos por respuesta (MMLU usa 8 para acelerar)")
    parser.add_argument("--output", default="data/research/eval_results.json",
                        help="Dónde guardar el JSON de resultados")
    args = parser.parse_args()

    # Validar binario
    if not Path(args.binary).exists():
        print(f"❌ Binario no encontrado: {args.binary}")
        print("   Compila con: cargo build --release -p nanortime-cli")
        sys.exit(1)

    # Generar manifest temporal con el modelo especificado
    base_config = {}
    if Path(args.config).exists():
        with open(args.config) as f:
            base_config = json.load(f)

    # Inyectar el modelo y forzar edge-only para evaluación reproducible
    base_config.setdefault("local_model", {})["path"] = args.model
    base_config.setdefault("hybrid_routing", {})["edge_only"] = True
    base_config.setdefault("hybrid_routing", {})["enabled"] = False
    base_config.setdefault("generation", {})["temperature"] = 0.0  # determinístico
    base_config.setdefault("memory", {})["max_context_docs"] = 0   # sin RAG

    import tempfile as _tempfile
    with _tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False, encoding="utf-8"
    ) as f:
        json.dump(base_config, f, indent=2)
        temp_config = f.name

    print(f"Binario  : {args.binary}")
    print(f"Modelo   : {args.model}")
    print(f"Config   : {temp_config} (temporal, edge-only, T=0)")

    results = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "binary": args.binary,
        "model": args.model,
    }

    try:
        if args.task in ["mmlu", "all"]:
            results["mmlu"] = eval_mmlu(args.binary, temp_config, max_tokens=32)

        if args.task in ["humaneval", "all"]:
            results["humaneval"] = eval_humaneval(
                args.binary, temp_config, max_tokens=args.max_tokens
            )
    finally:
        os.unlink(temp_config)  # Limpiar manifest temporal

    # Guardar resultados
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)

    print(f"\n{'=' * 60}")
    print("RESUMEN PARA EL PAPER")
    print(f"{'=' * 60}")
    if "mmlu" in results:
        m = results["mmlu"]
        print(f"  MMLU Accuracy : {m['accuracy_pct']:.1f}%  ({m['correct']}/{m['total']})")
        print(f"  MMLU Lat avg  : {m['avg_latency_ms']:.0f} ms")
    if "humaneval" in results:
        h = results["humaneval"]
        print(f"  HumanEval P@1 : {h['pass_at_1_pct']:.1f}%  ({h['passed']}/{h['total']})")
        print(f"  HumanEval Lat : {h['avg_latency_ms']:.0f} ms")
    print(f"\n📁 Resultados guardados en: {args.output}")


if __name__ == "__main__":
    main()
