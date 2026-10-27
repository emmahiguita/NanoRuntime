import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import subprocess
import sqlite3

data = subprocess.check_output([
    'adb', '-s', 'VGL7MVFMDYQG8T55', 'exec-out', 'run-as', 'dev.nanoai.mobile', 'cat', 'databases/nano_automation_store.db'
])
con = sqlite3.connect(':memory:')
con.deserialize(data)

tables = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE '%fts%'").fetchall()]
print("MAIN TABLES:", tables)

for t in tables:
    print(f"\n==================== {t} ====================")
    rows = con.execute(f"SELECT * FROM {t} ORDER BY rowid DESC LIMIT 5").fetchall()
    for r in rows:
        print(r)
