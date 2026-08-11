import json, os, glob


def verify_core_claims() -> bool:
    """Verify the 12 core claims (speed + accuracy) from the original
    _verify_claims.py. Returns True if all pass.

    Extracted as a shared function so _verify_claims.py can delegate
    here instead of duplicating the JSON-loading-and-checking logic.
    """
    checks = []
    with open('data/research/evidence_package/logs/oppo_stress_50.json') as f:
        d = json.load(f)
    checks.append(('OPPO 50/50', d['successful'] == 50))
    checks.append(('OPPO 2.90 tok/s', abs(d['avg_speed_tok_s'] - 2.90) < 0.05))

    with open('data/research/evidence_package/logs/samsung_stress_30.json') as f:
        d = json.load(f)
    checks.append(('Samsung 30/30', d['successful'] == 30))
    checks.append(('Samsung 2.27 tok/s', abs(d['avg_speed_tok_s'] - 2.27) < 0.05))

    with open('data/research/evidence_package/logs/oppo_7b_stress.json') as f:
        d = json.load(f)
    checks.append(('DeepSeek 7B 0.43 tok/s', abs(d['avg_speed_tok_s'] - 0.43) < 0.02))

    with open('data/research/pc_ablation_results.json') as f:
        d = json.load(f)
    checks.append(('PC NR 10.74 tok/s', abs(d['summary']['nanortime_tok_s'] - 10.74) < 0.1))
    checks.append(('PC NR 1840 MB RSS', abs(d['summary']['nanortime_rss_mb'] - 1840) < 5))

    with open('data/research/eval_results.json') as f:
        d = json.load(f)
    checks.append(('MMLU 90.0%', d['mmlu']['accuracy_pct'] == 90.0))
    checks.append(('HumanEval 66.7%', abs(d['humaneval']['pass_at_1_pct'] - 66.67) < 0.1))

    with open('data/research/routing_results.json') as f:
        d = json.load(f)
    checks.append(('Routing avg entropy 0.216', abs(d['summary']['performance']['avg_entropy_local'] - 0.216) < 0.01))
    checks.append(('Routing 100% savings', d['summary']['cost']['cost_savings_pct'] == 100.0))

    all_ok = True
    for c, ok in checks:
        status = "OK" if ok else "FAIL"
        print(f'  [{status}] {c}')
        if not ok:
            all_ok = False
    return all_ok


print("=" * 70)
print("  CROSS-REFERENCE: Paper Claims vs Real JSON Data")
print("=" * 70)
print()

# Find all JSON files
log_dir = "data/research/evidence_package/logs"
research_dir = "data/research"

all_jsons = glob.glob(f"{log_dir}/*.json") + glob.glob(f"{research_dir}/*.json")

# Track all claims
claims = []

# 1. OPPO stress tests
with open(f"{log_dir}/oppo_stress_50.json") as f:
    d = json.load(f)
claims.append(("OPPO 50/50 stress test", d['successful'] == 50 and d['iterations'] == 50,
              f"{d['successful']}/{d['iterations']} success, {d['avg_speed_tok_s']} tok/s",
              "oppo_stress_50.json"))

with open(f"{log_dir}/android_stress_results.json") as f:
    d = json.load(f)
claims.append(("OPPO 20/20 (prev)", d['successful'] == 20,
              f"{d['successful']}/{d['iterations']} success, {d['avg_speed_tok_s']} tok/s",
              "android_stress_results.json"))

with open(f"{log_dir}/oppo_tech_15.json") as f:
    d = json.load(f)
claims.append(("OPPO 15/15 tech queries", d['successful'] == 15,
              f"{d['successful']}/{d['iterations']} success, {d['avg_speed_tok_s']} tok/s",
              "oppo_tech_15.json"))

# 2. Samsung stress tests
with open(f"{log_dir}/samsung_stress_30.json") as f:
    d = json.load(f)
claims.append(("Samsung 30/30 stress test", d['successful'] == 30,
              f"{d['successful']}/{d['iterations']} success, {d['avg_speed_tok_s']} tok/s",
              "samsung_stress_30.json"))

with open(f"{log_dir}/samsung_a30_stress_results.json") as f:
    d = json.load(f)
claims.append(("Samsung 10/10 (prev)", d['successful'] == 10,
              f"{d['successful']}/{d['iterations']} success, {d['avg_speed_tok_s']} tok/s",
              "samsung_a30_stress_results.json"))

with open(f"{log_dir}/samsung_tech_15.json") as f:
    d = json.load(f)
claims.append(("Samsung 15/15 tech queries", d['successful'] == 15,
              f"{d['successful']}/{d['iterations']} success, {d['avg_speed_tok_s']} tok/s",
              "samsung_tech_15.json"))

# 3. DeepSeek 7B
with open(f"{log_dir}/oppo_7b_stress.json") as f:
    d = json.load(f)
claims.append(("DeepSeek 7B on OPPO", d['successful'] >= 4,
              f"{d['successful']}/{d['iterations']} success, {d['avg_speed_tok_s']} tok/s",
              "oppo_7b_stress.json"))

# 4. PC Ablation
with open(f"{research_dir}/pc_ablation_results.json") as f:
    d = json.load(f)
s = d['summary']
claims.append(("PC NR tok/s 10.74", abs(s['nanortime_tok_s'] - 10.74) < 0.1,
              f"{s['nanortime_tok_s']}", "pc_ablation_results.json"))
claims.append(("PC NR RSS 1840 MB", abs(s['nanortime_rss_mb'] - 1840) < 10,
              f"{s['nanortime_rss_mb']} MB", "pc_ablation_results.json"))
claims.append(("PC llama no-mmap 2038 MB", abs(s['llamacpp_no_mmap_rss_mb'] - 2038) < 10,
              f"{s['llamacpp_no_mmap_rss_mb']} MB", "pc_ablation_results.json"))
claims.append(("PC llama mmap 2510 MB", abs(s['llamacpp_mmap_rss_mb'] - 2510) < 10,
              f"{s['llamacpp_mmap_rss_mb']} MB", "pc_ablation_results.json"))

# 5. Quality benchmarks
with open(f"{research_dir}/eval_results.json") as f:
    d = json.load(f)
claims.append(("MMLU 90.0%", d['mmlu']['accuracy_pct'] == 90.0,
              f"{d['mmlu']['accuracy_pct']}% ({d['mmlu']['correct']}/{d['mmlu']['total']})",
              "eval_results.json"))
claims.append(("HumanEval 66.7%", abs(d['humaneval']['pass_at_1_pct'] - 66.67) < 0.1,
              f"{d['humaneval']['pass_at_1_pct']}%",
              "eval_results.json"))

# 6. Routing
with open(f"{research_dir}/routing_results.json") as f:
    d = json.load(f)
claims.append(("Routing 20/20 local", d['summary']['total_prompts'] == 20,
              f"{d['summary']['successful_runs']}/{d['summary']['total_prompts']} success",
              "routing_results.json"))
claims.append(("Routing H_norm 0.216", abs(d['summary']['performance']['avg_entropy_local'] - 0.216) < 0.01,
              f"{d['summary']['performance']['avg_entropy_local']}", "routing_results.json"))
claims.append(("Routing 100% savings", d['summary']['cost']['cost_savings_pct'] == 100.0,
              f"{d['summary']['cost']['cost_savings_pct']}%", "routing_results.json"))

# Print results
for claim, ok, detail, source in claims:
    status = "OK" if ok else "FAIL"
    print(f"  [{status}] {claim}")
    print(f"         {detail}  ({source})")

# Summary
ok_count = sum(1 for _, ok, _, _ in claims if ok)
total = len(claims)
print()
print(f"  VERIFIED: {ok_count}/{total} claims match real JSON data")
print(f"  ALL REAL: {ok_count == total}")

# Count total real queries
total_queries = 0
for f in glob.glob(f"{log_dir}/*.json"):
    with open(f) as fh:
        d = json.load(fh)
        if 'runs' in d:
            total_queries += len(d['runs'])

print(f"  Total real queries in JSON logs: {total_queries}")
