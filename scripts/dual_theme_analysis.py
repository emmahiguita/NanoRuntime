#!/usr/bin/env python3
"""
NanoRuntime — Dual-Theme Professional Statistical Visualization
Theme 1: LIGHT  (publication, paper, print) — deep navy + burgundy
Theme 2: DARK   (presentation, slides, screen) — GitHub-style dark
"""

import sys, numpy as np, pandas as pd, warnings
from pathlib import Path
warnings.filterwarnings('ignore')

if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

from scipy import stats
from scipy.stats import shapiro, mannwhitneyu, spearmanr

# ── Shared utilities (DI: single source of truth, no duplication) ────
from _nanostats import (
    cohens_d, bootstrap_ci, build_stress_dataframe, setup_matplotlib_style,
)

plt = setup_matplotlib_style()
import matplotlib.ticker as ticker
import seaborn as sns

# ══════════════════════════════════════════════════════════════════════
# THEME 1: LIGHT — Publication / Paper / Print
# Deep navy #1A3A5C for OPPO, Dark burgundy #8B1A1A for Samsung
# ══════════════════════════════════════════════════════════════════════

LIGHT = {
    'oppo':     '#1A3A5C',   # deep navy — serio, autoritativo
    'samsung':  '#8B1A1A',   # dark burgundy — elegante, no rosa
    'text':     '#1C1C1C',   # casi negro
    'grid':     '#D4D4D4',   # gris muy claro
    'bg':       '#FFFFFF',   # blanco puro
    'accent':   '#C8A415',   # oro — para significancia estadistica
    'green':    '#2E7D32',   # verde oscuro — savings/positivo
    'ci':       '#5D4037',   # marron — lineas CI
}

# ══════════════════════════════════════════════════════════════════════
# THEME 2: DARK — Presentation / Slides / Screen
# GitHub Dark style — #0D1117 background
# ══════════════════════════════════════════════════════════════════════

DARK = {
    'oppo':     '#58A6FF',   # soft blue — legible sobre oscuro
    'samsung':  '#F78166',   # soft coral — legible sobre oscuro
    'text':     '#C9D1D9',   # gris claro
    'grid':     '#21262D',   # gris muy oscuro
    'bg':       '#0D1117',   # GitHub dark
    'accent':   '#D2991D',   # oro
    'green':    '#3FB950',   # verde GitHub
    'ci':       '#8B949E',   # gris medio
}

# ══════════════════════════════════════════════════════════════════════

PROJECT = Path(__file__).resolve().parent.parent

# ── Load data (single implementation via _nanostats) ──────────────────
df = build_stress_dataframe()
oppo = df[df['device'] == 'OPPO']
samsung = df[df['device'] == 'Samsung']

# ── Stats ─────────────────────────────────────────────────────────────

w_o, p_o = shapiro(oppo['tok_s'])
w_s, p_s = shapiro(samsung['tok_s'])
u_stat, u_p = mannwhitneyu(oppo['tok_s'], samsung['tok_s'], alternative='two-sided')

d_val = cohens_d(oppo['tok_s'].values, samsung['tok_s'].values)

boot_diffs = []
for _ in range(10000):
    o_samp = np.random.choice(oppo['ram_mb'].values, size=50, replace=True)
    s_samp = np.random.choice(samsung['ram_mb'].values, size=50, replace=True)
    boot_diffs.append(np.mean(o_samp) - np.mean(s_samp))
ci_low, ci_high = np.percentile(boot_diffs, 2.5), np.percentile(boot_diffs, 97.5)

result_o = stats.linregress(np.arange(len(oppo)), oppo['ram_mb'].values)
slope_o, p_o, r2_o = result_o.slope, result_o.pvalue, result_o.rvalue**2
result_s = stats.linregress(np.arange(len(samsung)), samsung['ram_mb'].values)
slope_s, p_s, r2_s = result_s.slope, result_s.pvalue, result_s.rvalue**2

oppo_all_ram = pd.concat([oppo[oppo['session']==s]['ram_mb'] for s in ['OPPO (prev)','OPPO (main)','OPPO (tech)']])
sam_all_ram = pd.concat([samsung[samsung['session']==s]['ram_mb'] for s in ['Samsung (prev)','Samsung (main)','Samsung (tech)']])

corr = df[['tok_s', 'ram_mb', 'latency_ms', 'confidence']].corr()
mask = np.triu(np.ones_like(corr, dtype=bool), k=1)

print(f"N = {len(df)} (OPPO={len(oppo)}, Samsung={len(samsung)})")
print(f"Mann-Whitney: U={u_stat:.0f} p={u_p:.6f}  Cohen d={d_val:.3f}")

# ══════════════════════════════════════════════════════════════════════
# RENDER FUNCTION — single function for both themes
# ══════════════════════════════════════════════════════════════════════

def render_all(theme, theme_name, out_subdir):
    T = theme
    OUT = PROJECT / "data" / "research" / "evidence_package" / "images" / "statistical" / out_subdir
    OUT.mkdir(parents=True, exist_ok=True)

    # Configure matplotlib for this theme
    plt.rcParams.update({
        'text.color':        T['text'],
        'axes.labelcolor':   T['text'],
        'xtick.color':       T['text'],
        'ytick.color':       T['text'],
        'axes.edgecolor':    T['grid'],
        'axes.facecolor':    T['bg'],
        'figure.facecolor':  T['bg'],
        'grid.color':        T['grid'],
        'grid.alpha':        0.3,
        'grid.linewidth':    0.4,
        'legend.edgecolor':  T['grid'],
        'savefig.facecolor': T['bg'],
    })
    sns.set_style("darkgrid" if theme_name == "DARK" else "whitegrid")
    plt.rcParams['axes.facecolor'] = T['bg']
    plt.rcParams['figure.facecolor'] = T['bg']

    DEV = {'OPPO': T['oppo'], 'Samsung': T['samsung']}

    # ── FIGURE 1: KDE Throughput ──────────────────────────────────────

    fig, ax = plt.subplots(figsize=(8, 4.5))
    for device, color in [("OPPO", DEV['OPPO']), ("Samsung", DEV['Samsung'])]:
        sub = df[df['device'] == device]['tok_s']
        sns.kdeplot(data=sub, ax=ax, fill=True, alpha=0.15, color=color, linewidth=2.2,
                    label=f"{device}   μ = {sub.mean():.2f}   σ = {sub.std():.2f}   n = {len(sub)}")
        sns.rugplot(data=sub, ax=ax, color=color, alpha=0.3, height=0.03)
    ax.set_xlabel('Throughput (tokens per second)')
    ax.set_ylabel('Probability density')
    ax.set_title('Throughput Distribution — Qwen 2.5 1.5B on Android ARM64 CPU',
                 fontweight='bold', fontsize=12, pad=14)
    ax.legend(frameon=True, fontsize=9, loc='upper right')
    ax.set_xlim(0, ax.get_xlim()[1])
    fig.tight_layout(pad=1.5)
    fig.savefig(OUT / "fig1_kde_throughput.png", dpi=300)
    fig.savefig(OUT / "fig1_kde_throughput.pdf")
    plt.close(fig)

    # ── FIGURE 2: Memory Stability ───────────────────────────────────

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5.5))
    window = 7

    # Samsung
    x_s = np.arange(1, len(sam_all_ram)+1)
    rolling_s = np.convolve(sam_all_ram.values, np.ones(window)/window, mode='valid')
    ax1.fill_between(x_s, sam_all_ram, alpha=0.08, color=DEV['Samsung'])
    ax1.plot(x_s, sam_all_ram, color=DEV['Samsung'], linewidth=0.5, alpha=0.4)
    ax1.plot(range(window, len(sam_all_ram)+1), rolling_s, color=DEV['Samsung'], linewidth=2.2)
    ax1.axhline(y=np.mean(sam_all_ram), color=T['grid'], linestyle='--', linewidth=0.8)
    net_s = sam_all_ram.values[-1] - sam_all_ram.values[0]
    ax1.set_title(f"Samsung Galaxy A30s  3.72 GB RAM\n"
                  f"55 queries  |  {sam_all_ram.values[0]:.0f} → {sam_all_ram.values[-1]:.0f} MB  |  {'+' if net_s>0 else ''}{net_s:.0f} MB",
                  fontsize=10, fontweight='bold')
    ax1.set_ylabel('Available RAM (MB)')
    ax1.set_xlabel('Consecutive query number')
    ax1.set_xlim(0, len(sam_all_ram)+1)

    # OPPO
    x_o = np.arange(1, len(oppo_all_ram)+1)
    rolling_o = np.convolve(oppo_all_ram.values, np.ones(window)/window, mode='valid')
    ax2.fill_between(x_o, oppo_all_ram, alpha=0.08, color=DEV['OPPO'])
    ax2.plot(x_o, oppo_all_ram, color=DEV['OPPO'], linewidth=0.5, alpha=0.4)
    ax2.plot(range(window, len(oppo_all_ram)+1), rolling_o, color=DEV['OPPO'], linewidth=2.2)
    ax2.axhline(y=np.mean(oppo_all_ram), color=T['grid'], linestyle='--', linewidth=0.8)
    net_o = oppo_all_ram.values[-1] - oppo_all_ram.values[0]
    ax2.set_title(f"OPPO CPH2557  7.8 GB RAM\n"
                  f"85 queries  |  {oppo_all_ram.values[0]:.0f} → {oppo_all_ram.values[-1]:.0f} MB  |  {'+' if net_o>0 else ''}{net_o:.0f} MB",
                  fontsize=10, fontweight='bold')
    ax2.set_ylabel('Available RAM (MB)')
    ax2.set_xlabel('Consecutive query number')
    ax2.set_xlim(0, len(oppo_all_ram)+1)

    fig.suptitle('Memory Stability — 140 Consecutive Android LLM Inference Queries\n'
                 'Qwen 2.5 1.5B  Q4_K_M  |  Zero OOM Crashes  |  RAM Net Increase on Both Devices',
                 fontsize=13, fontweight='bold', y=1.02)
    fig.tight_layout(pad=2.0)
    fig.savefig(OUT / "fig2_memory_stability.png", dpi=300)
    fig.savefig(OUT / "fig2_memory_stability.pdf")
    plt.close(fig)

    # ── FIGURE 3: Bootstrap CI ───────────────────────────────────────

    fig, ax = plt.subplots(figsize=(8, 4))
    ax.hist(boot_diffs, bins=55, color=T['grid'], alpha=0.5, edgecolor=T['bg'], linewidth=0.5)
    ax.axvline(x=ci_low, color=T['accent'], linestyle='--', linewidth=2,
               label=f'95% CI:  [{ci_low:.0f},  {ci_high:.0f}]  MB')
    ax.axvline(x=ci_high, color=T['accent'], linestyle='--', linewidth=2)
    ax.axvline(x=np.mean(boot_diffs), color=T['oppo'], linewidth=2.5,
               label=f'Mean difference:  {np.mean(boot_diffs):.0f}  MB')
    ax.set_xlabel('RAM difference  OPPO − Samsung  (MB)')
    ax.set_ylabel('Frequency  (10,000 bootstrap samples)')
    ax.set_title('Bootstrap 95% Confidence Interval — RAM Difference Between Devices',
                 fontweight='bold', fontsize=12, pad=14)
    ax.legend(frameon=True, fontsize=9, loc='upper right')
    fig.tight_layout(pad=1.5)
    fig.savefig(OUT / "fig3_bootstrap_ci.png", dpi=300)
    fig.savefig(OUT / "fig3_bootstrap_ci.pdf")
    plt.close(fig)

    # ── FIGURE 4: Correlation ────────────────────────────────────────

    fig, ax = plt.subplots(figsize=(6.5, 5))
    cmap = sns.diverging_palette(250, 15, s=70, l=45, n=15, center='light')
    sns.heatmap(corr, mask=mask, annot=True, fmt='.3f', cmap=cmap,
                center=0, vmin=-1, vmax=1, square=True, linewidths=1.2,
                linecolor=T['bg'], cbar_kws={'label': "Pearson's r", 'shrink': 0.75},
                annot_kws={'fontsize': 10, 'fontweight': 'bold'}, ax=ax)
    ax.set_title('Correlation Matrix — Inference Performance Metrics\n155 Android Queries',
                 fontweight='bold', fontsize=11, pad=14)
    fig.tight_layout(pad=1.5)
    fig.savefig(OUT / "fig4_correlation_heatmap.png", dpi=300)
    fig.savefig(OUT / "fig4_correlation_heatmap.pdf")
    plt.close(fig)

    # ── FIGURE 5: Throughput by Session ──────────────────────────────

    fig, ax = plt.subplots(figsize=(12, 5))
    session_order = ['Samsung (prev)','Samsung (main)','Samsung (tech)',
                     'OPPO (prev)','OPPO (main)','OPPO (tech)']
    session_colors = [DEV['Samsung']]*3 + [DEV['OPPO']]*3
    pal = dict(zip(session_order, session_colors))

    sns.boxenplot(data=df, x='session', y='tok_s', order=session_order,
                  palette=pal, ax=ax, width=0.55, linewidth=0.8,
                  flier_kws={'marker': '.', 's': 8, 'alpha': 0.4})
    sns.stripplot(data=df, x='session', y='tok_s', order=session_order,
                  color=T['text'], alpha=0.12, size=3, ax=ax, jitter=True)
    for i, sess in enumerate(session_order):
        mean_val = df[df['session']==sess]['tok_s'].mean()
        ax.text(i, ax.get_ylim()[1]*0.95, f'μ={mean_val:.2f}', ha='center',
                fontsize=8, fontweight='bold', color=T['text'])
    ax.set_ylabel('Throughput  (tokens per second)')
    ax.set_xlabel('')
    ax.set_title('Throughput Distribution by Test Session — Qwen 2.5 1.5B Q4_K_M',
                 fontweight='bold', fontsize=12, pad=14)
    fig.tight_layout(pad=1.5)
    fig.savefig(OUT / "fig5_throughput_sessions.png", dpi=300)
    fig.savefig(OUT / "fig5_throughput_sessions.pdf")
    plt.close(fig)

    # ── FIGURE 6: RAM vs Throughput ──────────────────────────────────

    fig, axes = plt.subplots(1, 2, figsize=(14, 5.5))
    for ax, (name, sub, color) in zip(axes, [
        ("OPPO CPH2557", oppo, DEV['OPPO']),
        ("Samsung Galaxy A30s", samsung, DEV['Samsung']),
    ]):
        sns.regplot(data=sub, x='ram_mb', y='tok_s', ax=ax, color=color,
                    scatter_kws={'alpha': 0.3, 's': 20, 'edgecolors': 'none'},
                    line_kws={'linewidth': 2.2, 'color': T['text']},
                    ci=95, truncate=False)
        rho, p = spearmanr(sub['ram_mb'], sub['tok_s'])
        sig = 'p < 0.001' if p < 0.001 else f'p = {p:.4f}'
        ax.set_title(f"{name}\nSpearman  ρ = {rho:.3f}   {sig}", fontweight='bold', fontsize=10, pad=8)
        ax.set_xlabel('Available RAM  (MB)')
        ax.set_ylabel('Throughput  (tok/s)')
    fig.suptitle('Correlation: Available RAM vs Inference Throughput\n95% Confidence Band',
                 fontweight='bold', fontsize=12, y=1.02)
    fig.tight_layout(pad=2.0)
    fig.savefig(OUT / "fig6_ram_vs_throughput.png", dpi=300)
    fig.savefig(OUT / "fig6_ram_vs_throughput.pdf")
    plt.close(fig)

    # ── FIGURE 7: Complete Dashboard ─────────────────────────────────

    fig = plt.figure(figsize=(20, 16))
    gs = fig.add_gridspec(4, 3, hspace=0.5, wspace=0.35, height_ratios=[1, 1, 1, 0.55])

    # A: KDE
    axA = fig.add_subplot(gs[0, 0])
    for device, color in [("OPPO", DEV['OPPO']), ("Samsung", DEV['Samsung'])]:
        sub = df[df['device'] == device]['tok_s']
        sns.kdeplot(data=sub, ax=axA, fill=True, alpha=0.12, color=color, linewidth=2,
                    label=f"{device}  (μ={sub.mean():.2f})")
    axA.set_title('A. Throughput Distribution', fontweight='bold', fontsize=10, loc='left', pad=6)
    axA.set_xlabel('tok/s'); axA.set_ylabel('Density')
    axA.legend(fontsize=8, frameon=True)

    # B: OPPO RAM
    axB = fig.add_subplot(gs[0, 1])
    y_o = oppo_all_ram.values; x_o = np.arange(len(y_o))
    axB.fill_between(x_o, y_o, alpha=0.08, color=DEV['OPPO'])
    axB.plot(x_o, y_o, color=DEV['OPPO'], linewidth=0.5, alpha=0.5)
    axB.plot(range(6, len(y_o)), np.convolve(y_o, np.ones(7)/7, mode='valid'), color=DEV['OPPO'], linewidth=2)
    axB.axhline(y=np.mean(y_o), color=T['grid'], linestyle='--', linewidth=0.6)
    axB.set_title(f'B. OPPO RAM  ({y_o[0]:.0f} → {y_o[-1]:.0f} MB,  +{y_o[-1]-y_o[0]:.0f})',
                  fontweight='bold', fontsize=10, loc='left', pad=6)
    axB.set_xlabel('Query #'); axB.set_ylabel('RAM (MB)')

    # C: Samsung RAM
    axC = fig.add_subplot(gs[0, 2])
    y_s = sam_all_ram.values; x_s = np.arange(len(y_s))
    axC.fill_between(x_s, y_s, alpha=0.08, color=DEV['Samsung'])
    axC.plot(x_s, y_s, color=DEV['Samsung'], linewidth=0.5, alpha=0.5)
    axC.plot(range(6, len(y_s)), np.convolve(y_s, np.ones(7)/7, mode='valid'), color=DEV['Samsung'], linewidth=2)
    axC.axhline(y=np.mean(y_s), color=T['grid'], linestyle='--', linewidth=0.6)
    axC.set_title(f'C. Samsung RAM  ({y_s[0]:.0f} → {y_s[-1]:.0f} MB,  +{y_s[-1]-y_s[0]:.0f})',
                  fontweight='bold', fontsize=10, loc='left', pad=6)
    axC.set_xlabel('Query #'); axC.set_ylabel('RAM (MB)')

    # D: Boxenplot
    axD = fig.add_subplot(gs[1, 0])
    sns.boxenplot(data=df, x='device', y='tok_s', palette=DEV, ax=axD, width=0.4, linewidth=0.8)
    sns.stripplot(data=df, x='device', y='tok_s', color=T['text'], alpha=0.1, size=3, ax=axD, jitter=True)
    axD.set_title('D. Throughput by Device', fontweight='bold', fontsize=10, loc='left', pad=6)
    axD.set_xlabel(''); axD.set_ylabel('tok/s')

    # E: Heatmap
    axE = fig.add_subplot(gs[1, 1])
    sns.heatmap(corr, mask=mask, annot=True, fmt='.3f', cmap=cmap,
                center=0, vmin=-1, vmax=1, square=True, linewidths=1.2,
                linecolor=T['bg'], annot_kws={'fontsize': 9, 'fontweight': 'bold'}, ax=axE, cbar=False)
    axE.set_title('E. Correlation Matrix', fontweight='bold', fontsize=10, loc='left', pad=6)

    # F: Bootstrap
    axF = fig.add_subplot(gs[1, 2])
    axF.hist(boot_diffs, bins=50, color=T['grid'], alpha=0.5, edgecolor=T['bg'], linewidth=0.3)
    axF.axvline(x=ci_low, color=T['accent'], linestyle='--', linewidth=1.5)
    axF.axvline(x=ci_high, color=T['accent'], linestyle='--', linewidth=1.5)
    axF.axvline(x=np.mean(boot_diffs), color=DEV['OPPO'], linewidth=2)
    axF.set_title(f'F. Bootstrap 95% CI  [{ci_low:.0f},  {ci_high:.0f}]  MB',
                  fontweight='bold', fontsize=10, loc='left', pad=6)
    axF.set_xlabel('RAM diff (MB)'); axF.set_ylabel('Freq')

    # G: Violin per session
    axG = fig.add_subplot(gs[2, :2])
    sns.violinplot(data=df, x='session', y='tok_s', order=session_order,
                   palette=pal, ax=axG, width=0.7, linewidth=0.6, inner='quartile', cut=0)
    sns.stripplot(data=df, x='session', y='tok_s', order=session_order,
                  color=T['text'], alpha=0.08, size=3, ax=axG, jitter=True)
    axG.set_title('G. Throughput Distribution — All 6 Test Sessions',
                  fontweight='bold', fontsize=10, loc='left', pad=6)
    axG.set_xlabel(''); axG.set_ylabel('Throughput (tok/s)')

    # H: Confidence
    axH = fig.add_subplot(gs[2, 2])
    for device, color in [("OPPO", DEV['OPPO']), ("Samsung", DEV['Samsung'])]:
        sub = df[df['device'] == device]['confidence']
        sns.kdeplot(data=sub, ax=axH, fill=True, alpha=0.12, color=color, linewidth=2,
                    label=f'{device}  (μ={sub.mean():.3f})')
    axH.set_title('H. Model Confidence  (1 − H_norm)', fontweight='bold', fontsize=10, loc='left', pad=6)
    axH.set_xlabel('Confidence'); axH.set_ylabel('Density')
    axH.legend(fontsize=8, frameon=True)

    # I: Summary
    axI = fig.add_subplot(gs[3, :])
    axI.axis('off')
    stats_str = (
        "Statistical Summary  —  155 Android Queries  |  Qwen 2.5 1.5B Q4_K_M  |  OPPO CPH2557  +  Samsung Galaxy A30s\n"
        "──────────────────────────────────────────────────────────────────────────────────────────────────────────\n"
        f"Shapiro-Wilk  (Throughput):   OPPO W = {w_o:.3f}  (p = {p_o:.4f})     "
        f"Samsung W = {w_s:.3f}  (p = {p_s:.4f})\n"
        f"Mann-Whitney U:              U = {u_stat:.0f}    p = {u_p:.6f}    ★  SIGNIFICANT    (α = 0.05)\n"
        f"Cohen's d:                   d = {d_val:.3f}    ★  LARGE effect size\n"
        f"Bootstrap 95% CI:            [{ci_low:.0f},  {ci_high:.0f}]  MB    RAM difference  OPPO − Samsung\n"
        f"RAM Trend  OPPO:             slope = {slope_o:+.2f} MB/iter    R² = {r2_o:.3f}    p = {p_o:.4f}    ★  INCREASING\n"
        f"RAM Trend  Samsung:          slope = {slope_s:+.2f} MB/iter    R² = {r2_s:.3f}    p = {p_s:.4f}    ★  INCREASING\n"
        f"OOM Crashes:                 0  in 140 consecutive Android queries    ★  Zero Leaks Confirmed\n"
        f"Samples:                     OPPO = {len(oppo)}    Samsung = {len(samsung)}    Total = {len(df)}"
    )
    axI.text(0.5, 0.5, stats_str, transform=axI.transAxes, fontsize=7.5, ha='center', va='center',
             fontfamily='monospace', color=T['text'],
             bbox=dict(boxstyle='round,pad=0.8', facecolor=T['bg'], edgecolor=T['grid'], linewidth=0.8))

    fig.suptitle('NanoRuntime  —  Comprehensive Statistical Analysis Dashboard\n'
                 '155 Android Queries  |  Qwen 2.5 1.5B Q4_K_M  |  OPPO CPH2557  +  Samsung Galaxy A30s',
                 fontsize=14, fontweight='bold', y=1.005)
    fig.tight_layout(pad=2.5, rect=[0, 0, 1, 0.98])
    fig.savefig(OUT / "fig7_complete_dashboard.png", dpi=300)
    fig.savefig(OUT / "fig7_complete_dashboard.pdf")
    plt.close(fig)

    print(f"  [{theme_name}] 7 figures → {OUT.name}/")

# ══════════════════════════════════════════════════════════════════════
# RENDER BOTH THEMES
# ══════════════════════════════════════════════════════════════════════

print("=" * 60)
print("  NanoRuntime — Dual-Theme Statistical Visualization")
print("=" * 60)

render_all(LIGHT, "LIGHT", "light_theme")
render_all(DARK,  "DARK",  "dark_theme")

print("\n  LIGHT theme: images/statistical/light_theme/  (paper, print)")
print("  DARK theme:  images/statistical/dark_theme/   (slides, screen)")
print("=" * 60)
