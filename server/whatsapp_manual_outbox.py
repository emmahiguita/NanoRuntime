"""Registro aditivo de solicitudes manuales. No altera ni elimina tablas existentes."""
import hashlib
import json
import sqlite3
import time
from contextlib import closing
from fastapi import HTTPException
from .whatsapp_webhook_events import MetaInboxEvent, NormalizedWebhook


def reserve(path, scope, request_id, body):
    """Un resultado incierto nunca autoriza repetir el POST a Meta."""
    if path is None:
        raise HTTPException(503, "Configura almacenamiento durable antes de enviar")
    digest = hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()
    with closing(sqlite3.connect(path, timeout=3)) as db, db:
        db.execute("CREATE TABLE IF NOT EXISTS meta_manual_outbox (scope TEXT NOT NULL, request_id TEXT NOT NULL, digest TEXT NOT NULL, wamid TEXT, created_ms INTEGER NOT NULL, PRIMARY KEY(scope,request_id))")
        db.execute("INSERT OR IGNORE INTO meta_manual_outbox VALUES (?,?,?,NULL,?)", (scope,request_id,digest,time.time_ns()//1000000))
        inserted = db.execute("SELECT changes()").fetchone()[0]
        saved = db.execute("SELECT digest,wamid FROM meta_manual_outbox WHERE scope=? AND request_id=?", (scope,request_id)).fetchone()
        if saved[0] != digest:
            raise HTTPException(409, "Este envío pendiente tiene otro contenido; revisa el historial")
        if not inserted and not saved[1]:
            raise HTTPException(409, "Resultado del envío anterior incierto; no se reenvi?")
        return saved[1]


def accepted(path, scope, request_id, wamid):
    with closing(sqlite3.connect(path, timeout=3)) as db, db:
        db.execute("UPDATE meta_manual_outbox SET wamid=? WHERE scope=? AND request_id=?", (wamid,scope,request_id))


def save_outbound(inbox, waba, phone, request_id, body, response):
    """Solo guarda contenido saliente despu?s de recibir el WAMID real de Meta."""
    kind = body["type"]
    payload = {**body, "_nano_direction": "outbound", "_nano_source": "meta_send_response", "_nano_delivery": "accepted"}
    wamid = response["messages"][0]["id"]
    event = MetaInboxEvent("message", waba, phone, wamid, body["to"], str(int(time.time())), kind, payload)
    raw = json.dumps({"outbound_request_id": request_id, "response": response, "phone": phone}).encode()
    inbox.save(raw, NormalizedWebhook((event,), ()))
