import sys, io, subprocess, sqlite3
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

data = subprocess.check_output([
    'adb', '-s', 'VGL7MVFMDYQG8T55', 'exec-out', 'run-as', 'dev.nanoai.mobile', 'cat', 'databases/nano_automation.db'
])
con = sqlite3.connect(':memory:')
con.deserialize(data)

tables = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
print("TABLES in nano_automation.db:", tables)

for t in tables:
    print(f"\n--- {t} (last 5) ---")
    try:
        for r in con.execute(f"SELECT * FROM {t} ORDER BY rowid DESC LIMIT 5").fetchall():
            print(r)
    except Exception as e:
        print("Error:", e)
