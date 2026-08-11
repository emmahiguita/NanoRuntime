#!/usr/bin/env python3
"""
_nanostats.py — Shared statistical and data-loading utilities.
Injected as a dependency by analysis scripts. Single source of truth for:
  - load_json(name)          JSON file loader from LOG_DIR
  - cohens_d(x, y)           Cohen's d effect size
  - bootstrap_ci(a, b, ...)  Bootstrap confidence interval
  - build_stress_dataframe() Build unified DataFrame from stress-test JSON files
  - setup_matplotlib_style() Publication-grade matplotlib rcParams
  - PALETTE                   Tol Muted colorblind-safe palette

Usage:
    from _nanostats import load_json, cohens_d, build_stress_dataframe, PALETTE
"""
import json, sys
import numpy as np
from pathlib import Path

# ── Project root discovery ───────────────────────────────────────────
PROJECT = Path(__file__).resolve().parent.parent
LOG_DIR = PROJECT / "data" / "research" / "evidence_package" / "logs"


# ── JSON loader ──────────────────────────────────────────────────────
def load_json(name: str) -> dict:
    """Load a JSON file from LOG_DIR. Single implementation — no duplication.
    Raises FileNotFoundError with a helpful message if the file is missing
    (so callers get a clear error, not a cryptic JSONDecodeError)."""
    path = LOG_DIR / name
    if not path.exists():
        raise FileNotFoundError(
            f"Data file not found: {path}\n"
            f"Run the benchmark scripts first to generate this file."
        )
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# ── Statistics ───────────────────────────────────────────────────────
def cohens_d(x: np.ndarray, y: np.ndarray) -> float:
    """Cohen's d effect size. Single implementation — no duplication."""
    nx, ny = len(x), len(y)
    dof = nx + ny - 2
    pooled_std = np.sqrt(
        ((nx - 1) * np.var(x, ddof=1) + (ny - 1) * np.var(y, ddof=1)) / dof
    )
    return (np.mean(x) - np.mean(y)) / pooled_std


def bootstrap_ci(a: np.ndarray, b: np.ndarray, n_iter: int = 10000, ci: float = 95.0) -> tuple:
    """Bootstrap confidence interval for difference of means (a - b)."""
    diffs = []
    for _ in range(n_iter):
        sa = np.random.choice(a, size=min(50, len(a)), replace=True)
        sb = np.random.choice(b, size=min(50, len(b)), replace=True)
        diffs.append(np.mean(sa) - np.mean(sb))
    low_pct = (100.0 - ci) / 2.0
    high_pct = 100.0 - low_pct
    return np.percentile(diffs, low_pct), np.percentile(diffs, high_pct)


# ── Stress-test DataFrame builder ────────────────────────────────────
STRESS_DATASET_NAMES = {
    "OPPO (prev)":    "android_stress_results.json",
    "OPPO (main)":    "oppo_stress_50.json",
    "OPPO (tech)":    "oppo_tech_15.json",
    "Samsung (prev)": "samsung_a30_stress_results.json",
    "Samsung (main)": "samsung_stress_30.json",
    "Samsung (tech)": "samsung_tech_15.json",
}


def build_stress_dataframe() -> "pd.DataFrame":
    """Load all stress-test JSON files and build a unified DataFrame.
    Single implementation — previously duplicated across professional_analysis.py
    and dual_theme_analysis.py.
    """
    import pandas as pd
    rows = []
    for name, filename in STRESS_DATASET_NAMES.items():
        data = load_json(filename)
        device = "OPPO" if "OPPO" in name else "Samsung"
        for r in data.get("runs", []):
            if r.get("tok_s") is not None and r.get("mem_avail_mb") is not None:
                rows.append({
                    "device": device,
                    "session": name,
                    "tok_s": r["tok_s"],
                    "ram_mb": r["mem_avail_mb"],
                    "latency_ms": r.get("latency_ms", 0),
                    "confidence": r.get("confidence", 0),
                })
    return pd.DataFrame(rows)


# ── Matplotlib professional style ────────────────────────────────────
# Tol Muted palette (Paul Tol, SRON) — colorblind-safe, printer-safe
PALETTE = {
    "blue":    "#2166AC",
    "red":     "#B2182B",
    "dark":    "#2C2C2C",
    "grey":    "#878787",
    "light":   "#D0D0D0",
    "bg":      "#F8F8F8",
    "gold":    "#D4A017",
    "green":   "#439B5A",
    "oppo":    "#2166AC",
    "samsung": "#B2182B",
}


def setup_matplotlib_style() -> None:
    """Apply publication-grade matplotlib rcParams. Idempotent."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    matplotlib.rcParams.update({
        "font.family":        "serif",
        "font.serif":         ["Times New Roman", "DejaVu Serif", "Computer Modern Roman"],
        "font.size":          10,
        "axes.titlesize":     12,
        "axes.labelsize":     10,
        "xtick.labelsize":    9,
        "ytick.labelsize":    9,
        "legend.fontsize":    9,
        "figure.dpi":         300,
        "savefig.dpi":        300,
        "savefig.bbox":       "tight",
        "savefig.pad_inches": 0.1,
        "axes.spines.top":    False,
        "axes.spines.right":  False,
        "axes.grid":          True,
        "grid.alpha":         0.3,
        "grid.linestyle":     ":",
        "figure.facecolor":   "white",
        "axes.facecolor":     "white",
    })
    return plt


if __name__ == "__main__":
    # Self-test: verify the module loads and computes correctly
    setup_matplotlib_style()
    a = np.array([1.0, 2.0, 3.0, 4.0, 5.0])
    b = np.array([2.0, 3.0, 4.0, 5.0, 6.0])
    d = cohens_d(a, b)
    print(f"cohens_d test: {d:.4f} (expected ~-0.7071)")
    lo, hi = bootstrap_ci(a, b, n_iter=1000)
    print(f"bootstrap_ci test: [{lo:.2f}, {hi:.2f}]")
    print("_nanostats module OK")
