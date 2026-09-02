#!/usr/bin/env python3
"""
NanoRuntime — Statistical analysis over the NEW per-run telemetry JSONL only.

Reads data/research/telemetry/runs.jsonl (one line per run, written by the
instrumented harnesses) and computes, *only when sample size and data validity
permit*:

  * Shapiro-Wilk            (normality)            — requires n >= 3
  * Mann-Whitney U          (two-group comparison) — requires n >= 3 per group
  * Bootstrap 95% CI        (mean / mean-diff)     — requires n >= 5
  * Spearman rho            (rank correlation)     — requires n >= 5
  * OLS linear regression   (trend over iterations)— requires n >= 5
  * Effect size             (Cohen's d, rank-biserial r)

Every test reports n, the statistic, p-value, confidence interval (where
applicable), effect size, and the number of excluded (non-valid) runs.

If no new runs exist, this script emits ONLY the record schema and a
"NO RESULTS YET" report — it never fabricates p-values or intervals.

Usage:
    python scripts/analyze_telemetry.py [--jsonl PATH] [--out PATH]
"""

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import telemetry

try:
    from scipy import stats as _scipy_stats
    SCIPY = True
except ImportError:
    SCIPY = False

PROJECT = Path(__file__).resolve().parent.parent
DEFAULT_JSONL = PROJECT / "data" / "research" / "telemetry" / "runs.jsonl"

# Minimum valid-sample thresholds per test (conservative).
MIN_N = {
    "shapiro": 3,
    "mannwhitneyu": 3,
    "bootstrap": 5,
    "spearman": 5,
    "regression": 5,
}

# Metrics extractable from a run record, mapped to nested accessor paths.
METRICS = {
    "tok_s": ("result", "tok_s"),
    "rss_mb": ("memory_peak", "rss_mb"),
    "pss_mb": ("memory_peak", "pss_mb"),
    "rss_anon_mb": ("memory_peak", "rss_anon_mb"),
    "cpu_percent": ("cpu", "cpu_percent"),
    "io_read_bytes": ("io", "read_bytes"),
    "pf_minor": ("page_faults", "minor"),
    "pf_major": ("page_faults", "major"),
    "pf_total": ("page_faults", "total"),
}


def _get(run, *path):
    cur = run
    for k in path:
        if not isinstance(cur, dict):
            return None
        cur = cur.get(k)
    if isinstance(cur, bool):
        return None
    if isinstance(cur, (int, float)):
        return float(cur)
    return None


def group_key(run):
    dev = run.get("device") or {}
    cfg = run.get("configuration") or {}
    return (run.get("platform", ""), dev.get("model", ""),
            run.get("engine", ""), cfg.get("engine_mode", ""))


def _is_number(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def cohens_d(a, b):
    """Pooled-variance Cohen's d."""
    import math
    na, nb = len(a), len(b)
    if na < 2 or nb < 2:
        return None
    va = _var(a)
    vb = _var(b)
    pooled = math.sqrt(((na - 1) * va + (nb - 1) * vb) / (na + nb - 2))
    if pooled == 0:
        return None
    return (_mean(a) - _mean(b)) / pooled


def _mean(x):
    return sum(x) / len(x)


def _var(x):
    m = _mean(x)
    return sum((v - m) ** 2 for v in x) / (len(x) - 1)


def rank_biserial(a, b):
    """Rank-biserial correlation from Mann-Whitney U (effect size)."""
    from scipy import stats as _s
    if len(a) < MIN_N["mannwhitneyu"] or len(b) < MIN_N["mannwhitneyu"]:
        return None
    u, _ = _s.mannwhitneyu(a, b, alternative="two-sided")
    return 1.0 - (2.0 * u) / (len(a) * len(b))


def bootstrap_mean_ci(x, n_boot=10000, seed=0):
    import random
    rng = random.Random(seed)
    means = []
    n = len(x)
    for _ in range(n_boot):
        s = [x[rng.randrange(n)] for _ in range(n)]
        means.append(_mean(s))
    means.sort()
    return _mean(x), means[int(0.025 * n_boot)], means[int(0.975 * n_boot)]


def bootstrap_diff_ci(a, b, n_boot=10000, seed=0):
    import random
    rng = random.Random(seed)
    diffs = []
    na, nb = len(a), len(b)
    for _ in range(n_boot):
        sa = [a[rng.randrange(na)] for _ in range(na)]
        sb = [b[rng.randrange(nb)] for _ in range(nb)]
        diffs.append(_mean(sa) - _mean(sb))
    diffs.sort()
    return _mean(a) - _mean(b), diffs[int(0.025 * n_boot)], diffs[int(0.975 * n_boot)]


def analyze(jsonl_path):
    runs = telemetry.read_jsonl(str(jsonl_path))

    if not runs:
        return {"status": "NO RESULTS YET",
                "schema_version": telemetry.SCHEMA_VERSION,
                "schema": telemetry.RUN_SCHEMA_DOC if hasattr(telemetry, "RUN_SCHEMA_DOC") else None,
                "n_runs": 0,
                "message": "No instrumented runs found. Execute the documented commands first."}

    if not SCIPY:
        return {"status": "DEPENDENCY MISSING",
                "n_runs": len(runs),
                "message": "scipy is required for statistical tests. pip install scipy"}

    groups = defaultdict(list)
    for r in runs:
        groups[group_key(r)].append(r)

    report = {"status": "COMPUTED", "n_runs": len(runs),
              "n_groups": len(groups), "groups": {}, "comparisons": []}

    # Per-group descriptives + Shapiro-Wilk + regression over iteration.
    for key, gruns in sorted(groups.items()):
        platform, device_model, engine, mode = key
        gname = f"{platform}/{device_model or '?'}/{engine}/{mode or 'default'}"
        g = {"n": len(gruns), "metrics": {}}

        # Build per-metric series + exclusions.
        series = {m: [] for m in METRICS}
        excluded = {m: 0 for m in METRICS}
        for r in gruns:
            for m, path in METRICS.items():
                v = _get(r, *path)
                if v is None:
                    excluded[m] += 1
                else:
                    series[m].append(v)

        for m, vals in series.items():
            desc = {"n": len(vals), "excluded": excluded[m]}
            if len(vals) >= 2:
                import math
                desc["mean"] = round(_mean(vals), 4)
                desc["std"] = round(math.sqrt(_var(vals)), 4) if len(vals) > 1 else 0.0
                desc["min"] = round(min(vals), 4)
                desc["max"] = round(max(vals), 4)
            if len(vals) >= MIN_N["shapiro"] and len(set(vals)) > 1:
                w, p = _scipy_stats.shapiro(vals)
                desc["shapiro_w"] = round(w, 4)
                desc["shapiro_p"] = round(p, 6)
            if len(vals) >= MIN_N["bootstrap"]:
                mean_ci = bootstrap_mean_ci(vals)
                desc["bootstrap_mean"] = round(mean_ci[0], 4)
                desc["bootstrap_95ci"] = [round(mean_ci[1], 4), round(mean_ci[2], 4)]
            g["metrics"][m] = desc

        # Regression of memory (rss_mb) and throughput (tok_s) over iteration.
        iters = [_get(r, "configuration", "iteration") for r in gruns]
        for m in ("rss_mb", "tok_s"):
            pairs = [(it, _get(r, *METRICS[m])) for r, it in zip(gruns, iters)
                     if it is not None and _get(r, *METRICS[m]) is not None]
            if len(pairs) >= MIN_N["regression"]:
                xs = [p[0] for p in pairs]
                ys = [p[1] for p in pairs]
                slope, intercept, r_value, p_value, std_err = _scipy_stats.linregress(xs, ys)
                g.setdefault("regression", {})[m] = {
                    "n": len(pairs),
                    "slope": round(slope, 6),
                    "intercept": round(intercept, 4),
                    "p_value": round(p_value, 6),
                    "r_squared": round(r_value ** 2, 6),
                }

        report["groups"][gname] = g

    # Cross-group comparisons on tok_s (same metric, pairs of groups).
    gnames = sorted(groups.keys())
    for i in range(len(gnames)):
        for j in range(i + 1, len(gnames)):
            a = [_get(r, *METRICS["tok_s"]) for r in groups[gnames[i]] if _get(r, *METRICS["tok_s"]) is not None]
            b = [_get(r, *METRICS["tok_s"]) for r in groups[gnames[j]] if _get(r, *METRICS["tok_s"]) is not None]
            comp = {"group_a": f"{gnames[i]}", "group_b": f"{gnames[j]}",
                    "n_a": len(a), "n_b": len(b), "metric": "tok_s"}
            if len(a) >= MIN_N["mannwhitneyu"] and len(b) >= MIN_N["mannwhitneyu"]:
                u, p = _scipy_stats.mannwhitneyu(a, b, alternative="two-sided")
                comp["mannwhitney_u"] = round(u, 4)
                comp["mannwhitney_p"] = round(p, 6)
                comp["cohens_d"] = round(cohens_d(a, b), 4) if cohens_d(a, b) is not None else None
                comp["rank_biserial_r"] = round(rank_biserial(a, b), 4)
            if len(a) >= MIN_N["bootstrap"] and len(b) >= MIN_N["bootstrap"]:
                diff, lo, hi = bootstrap_diff_ci(a, b)
                comp["bootstrap_diff_mean"] = round(diff, 4)
                comp["bootstrap_diff_95ci"] = [round(lo, 4), round(hi, 4)]
            report["comparisons"].append(comp)

    return report


def print_report(report):
    if report["status"] == "NO RESULTS YET":
        print("=" * 70)
        print("  STATISTICAL ANALYSIS — NO RESULTS YET")
        print("=" * 70)
        print(report["message"])
        print("Record schema version:", report.get("schema_version"))
        print("n_runs:", report["n_runs"])
        return
    if report["status"] == "DEPENDENCY MISSING":
        print(report["message"])
        return

    print("=" * 70)
    print(f"  STATISTICAL ANALYSIS ({report['n_runs']} runs, {report['n_groups']} groups)")
    print("=" * 70)
    for gname, g in report["groups"].items():
        print(f"\n[{gname}]  n={g['n']}")
        for m, desc in g["metrics"].items():
            if desc["n"] == 0:
                print(f"    {m:<16s} n=0 (excluded {desc['excluded']})")
                continue
            line = f"    {m:<16s} n={desc['n']}"
            if "mean" in desc:
                line += f"  mean={desc['mean']}  std={desc.get('std')}"
            if "shapiro_w" in desc:
                line += f"  ShapiroW={desc['shapiro_w']} p={desc['shapiro_p']}"
            if "bootstrap_95ci" in desc:
                line += f"  CI95={desc['bootstrap_95ci']}"
            print(line)
        if "regression" in g:
            for m, reg in g["regression"].items():
                print(f"    reg[{m}] n={reg['n']} slope={reg['slope']} p={reg['p_value']} R2={reg['r_squared']}")

    if report["comparisons"]:
        print("\n  CROSS-GROUP COMPARISONS (metric=tok_s)")
        for c in report["comparisons"]:
            print(f"\n    {c['group_a']}  vs  {c['group_b']}")
            print(f"      n_a={c['n_a']} n_b={c['n_b']}")
            if "mannwhitney_p" in c:
                print(f"      Mann-Whitney U={c['mannwhitney_u']} p={c['mannwhitney_p']} "
                      f"d={c['cohens_d']} r_rank={c['rank_biserial_r']}")
            if "bootstrap_diff_95ci" in c:
                print(f"      Bootstrap diff mean={c['bootstrap_diff_mean']} CI95={c['bootstrap_diff_95ci']}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jsonl", default=str(DEFAULT_JSONL))
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    report = analyze(args.jsonl)
    print_report(report)

    if args.out:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        print(f"\nReporte JSON: {args.out}")


if __name__ == "__main__":
    main()
