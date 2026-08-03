import json

checks = []
with open('data/research/evidence_package/logs/oppo_stress_50.json') as f: d=json.load(f)
checks.append(('OPPO 50/50', d['successful']==50))
checks.append(('OPPO 2.90 tok/s', abs(d['avg_speed_tok_s']-2.90)<0.05))

with open('data/research/evidence_package/logs/samsung_stress_30.json') as f: d=json.load(f)
checks.append(('Samsung 30/30', d['successful']==30))
checks.append(('Samsung 2.27 tok/s', abs(d['avg_speed_tok_s']-2.27)<0.05))

with open('data/research/evidence_package/logs/oppo_7b_stress.json') as f: d=json.load(f)
checks.append(('DeepSeek 7B 0.43 tok/s', abs(d['avg_speed_tok_s']-0.43)<0.02))

with open('data/research/pc_ablation_results.json') as f: d=json.load(f)
checks.append(('PC NR 10.74 tok/s', abs(d['summary']['nanortime_tok_s']-10.74)<0.1))
checks.append(('PC NR 1840 MB RSS', abs(d['summary']['nanortime_rss_mb']-1840)<5))

with open('data/research/eval_results.json') as f: d=json.load(f)
checks.append(('MMLU 90.0%', d['mmlu']['accuracy_pct']==90.0))
checks.append(('HumanEval 66.7%', abs(d['humaneval']['pass_at_1_pct']-66.67)<0.1))

with open('data/research/routing_results.json') as f: d=json.load(f)
checks.append(('Routing avg entropy 0.216', abs(d['summary']['performance']['avg_entropy_local']-0.216)<0.01))
checks.append(('Routing 100% savings', d['summary']['cost']['cost_savings_pct']==100.0))

all_ok = True
for c,ok in checks:
    status = "OK" if ok else "FAIL"
    print(f'  [{status}] {c}')
    if not ok: all_ok = False
print(f'VERDICT: {"ALL 12 CLAIMS VERIFIED" if all_ok else "DISCREPANCY FOUND"}')
