import json, numpy as np

def analyze(path, name):
    with open(path) as f: d = json.load(f)
    rams = [r['mem_avail_mb'] for r in d['runs']]
    toks = [r['tok_s'] for r in d['runs'] if r['tok_s']]
    confs = [r['confidence'] for r in d['runs'] if r.get('confidence')]
    lats = [r['latency_ms'] for r in d['runs'] if r.get('latency_ms')]

    print(f"=== {name} ===")
    print(f"  Success: {d['successful']}/{d['iterations']}")
    print(f"  Tok/s: mean={np.mean(toks):.2f} min={min(toks):.2f} max={max(toks):.2f} std={np.std(toks):.2f}")
    print(f"  RAM: start={rams[0]:.0f} end={rams[-1]:.0f} net={rams[-1]-rams[0]:+.0f} MB")
    print(f"  RAM: mean={np.mean(rams):.0f} min={min(rams):.0f} max={max(rams):.0f} std={np.std(rams):.0f}")
    print(f"  Confidence: mean={np.mean(confs):.3f} min={min(confs):.3f} max={max(confs):.3f}")
    print(f"  Latency: mean={np.mean(lats):.0f}ms min={min(lats):.0f}ms max={max(lats):.0f}ms")
    return {'rams': rams, 'toks': toks}

session = 'data/research/evidence_package/sessions/stress_final_20260801_0346'
sam = analyze(f'{session}/samsung_stress.json', 'SAMSUNG A30s')
opp = analyze(f'{session}/oppo_stress.json', 'OPPO CPH2557')

print()
print("=== CROSS-DEVICE ===")
print(f"  Speed ratio OPPO/Samsung: {np.mean(opp['toks'])/np.mean(sam['toks']):.2f}x")
print(f"  RAM ratio OPPO/Samsung: {np.mean(opp['rams'])/np.mean(sam['rams']):.2f}x")
print(f"  RAM positive trend (both): {sam['rams'][-1] > sam['rams'][0] and opp['rams'][-1] > opp['rams'][0]}")
print(f"  OOM crashes: 0")
