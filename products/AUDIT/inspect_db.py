import sqlite3
import json

conn = sqlite3.connect('c:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/AUDIT/nano_automation_store_clean.db')
c = conn.cursor()
c.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = [r[0] for r in c.fetchall()]
print("Tables in DB:", tables)

for t in tables:
    c.execute(f"SELECT COUNT(*) FROM {t}")
    count = c.fetchone()[0]
    print(f"Table {t}: {count} rows")

print("\n--- CANONICAL MESSAGES RECENT ---")
c.execute("PRAGMA table_info(canonical_messages)")
cols = [r[1] for r in c.fetchall()]
print("Columns:", cols)

c.execute("SELECT * FROM canonical_messages ORDER BY rowid DESC LIMIT 30")
rows = c.fetchall()
for r in reversed(rows):
    d = dict(zip(cols, r))
    direction = d.get('direction', '')
    sender = d.get('sender_name') or d.get('sender') or ''
    text = d.get('body') or d.get('content') or d.get('text') or ''
    ts = d.get('timestamp') or d.get('created_at') or ''
    conv = d.get('conversation_id') or ''
    print(f"[{direction}] [{sender}] ({conv}): {text}")

print("\n--- NOTIFICATION TURNS / DRAFTS ---")
for t in tables:
    if 'turn' in t.lower() or 'draft' in t.lower() or 'reply' in t.lower() or 'decision' in t.lower():
        print(f"\n--- {t} ---")
        c.execute(f"PRAGMA table_info({t})")
        tcols = [r[1] for r in c.fetchall()]
        c.execute(f"SELECT * FROM {t} ORDER BY rowid DESC LIMIT 10")
        for r in c.fetchall():
            print(dict(zip(tcols, r)))
