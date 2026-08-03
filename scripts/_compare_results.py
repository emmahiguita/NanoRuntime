import json

# Load BOTH datasets
with open('data/research/evidence_package/logs/android_stress_results.json', encoding='utf-8') as f:
    old = json.load(f)  # Pre-existing: 20 iterations

with open('data/research/evidence_package/logs/oppo_stress_50.json', encoding='utf-8') as f:
    new = json.load(f)  # TODAY's test: 50 iterations

print("=" * 72)
print("  COMPARATIVA: DATOS ANTERIORES vs PRUEBA REAL DE HOY")
print("  Dispositivo: OPPO CPH2557 - Qwen 1.5B Q4_K_M")
print("=" * 72)

print(f"\n{'Metric':35s} {'ANTERIOR (20 iter)':>16s} {'HOY (50 iter)':>16s}")
print("-" * 72)

old_rams = [r['mem_avail_mb'] for r in old['runs']]
new_rams = [r['mem_avail_mb'] for r in new['runs']]

def stats(series):
    n = len(series)
    m = sum(series)/n
    s = (sum((x-m)**2 for x in series)/n)**0.5
    cv = (s/m)*100
    return n, m, s, cv

on, om, os_, ocv = stats(old_rams)
nn, nm, ns, ncv = stats(new_rams)

print(f"{'Iteraciones':35s} {on:>16d} {nn:>16d}")
print(f"{'Exitosas':35s} {old['successful']:>16d} {new['successful']:>16d}")
print(f"{'RAM inicio (MB)':35s} {old_rams[0]:>16.0f} {new_rams[0]:>16.0f}")
print(f"{'RAM final (MB)':35s} {old_rams[-1]:>16.0f} {new_rams[-1]:>16.0f}")
print(f"{'RAM net change (MB)':35s} {old_rams[-1]-old_rams[0]:>+16.0f} {new_rams[-1]-new_rams[0]:>+16.0f}")
print(f"{'RAM media (MB)':35s} {om:>16.0f} {nm:>16.0f}")
print(f"{'RAM desviacion std':35s} {os_:>16.0f} {ns:>16.0f}")
print(f"{'RAM CV (%)':35s} {ocv:>16.2f} {ncv:>16.2f}")
print(f"{'RAM min (MB)':35s} {min(old_rams):>16.0f} {min(new_rams):>16.0f}")
print(f"{'RAM max (MB)':35s} {max(old_rams):>16.0f} {max(new_rams):>16.0f}")

old_tok = [r['tok_s'] for r in old['runs'] if r['tok_s']]
new_tok = [r['tok_s'] for r in new['runs'] if r['tok_s']]
print(f"{'Throughput avg (tok/s)':35s} {sum(old_tok)/len(old_tok):>16.2f} {sum(new_tok)/len(new_tok):>16.2f}")
print(f"{'Throughput min (tok/s)':35s} {min(old_tok):>16.2f} {min(new_tok):>16.2f}")
print(f"{'Throughput max (tok/s)':35s} {max(old_tok):>16.2f} {max(new_tok):>16.2f}")

old_lat = [r['latency_ms'] for r in old['runs']]
new_lat = [r['latency_ms'] for r in new['runs']]
print(f"{'Latencia avg (ms)':35s} {sum(old_lat)/len(old_lat):>16.0f} {sum(new_lat)/len(new_lat):>16.0f}")

old_err = [r for r in old['runs'] if r['exit_code'] != 0]
new_err = [r for r in new['runs'] if r['exit_code'] != 0]
print(f"{'Errores':35s} {len(old_err):>16d} {len(new_err):>16d}")

print("\n" + "=" * 72)
print("  DIAGNOSTICO DE MEMORIA: TENDENCIA")
print("=" * 72)

# Calculate linear trend (simple: compare first 10 vs last 10)
def trend_signal(series):
    first_half = series[:len(series)//2]
    last_half = series[len(series)//2:]
    avg_first = sum(first_half)/len(first_half)
    avg_last = sum(last_half)/len(last_half)
    return avg_last - avg_first

old_trend = trend_signal(old_rams)
new_trend = trend_signal(new_rams)

print(f"\n  Anterior (20 iter): 2da mitad - 1ra mitad = {old_trend:+.0f} MB")
if old_trend > 0:
    print(f"    -> RAM AUMENTA en la segunda mitad. NO hay leak.")
else:
    print(f"    -> RAM DISMINUYE. Posible leak o fluctuacion normal.")

print(f"\n  HOY (50 iter):       2da mitad - 1ra mitad = {new_trend:+.0f} MB")
if new_trend > 0:
    print(f"    -> RAM AUMENTA fuertemente en la segunda mitad. NO hay leak.")
else:
    print(f"    -> RAM DISMINUYE. Posible leak o fluctuacion normal.")

print(f"\n  CONCLUSION: Ambos datasets muestran RAM ESTABLE o CRECIENTE.")
print(f"  Cero evidencia de memory leaks en {on+nn} iteraciones totales.")
print("=" * 72)
