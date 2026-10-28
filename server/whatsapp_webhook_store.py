"""Bandeja SQLite duradera; no abre una conexión permanente ni dispara respuestas."""

import hashlib
import json
import sqlite3
import time
from contextlib import closing
from pathlib import Path

from .whatsapp_webhook_events import InboxReceipt, NormalizedWebhook


# Esquema dedicado y versionado: no altera las tablas del teléfono ni del CRM.
_SCHEMA = """
CREATE TABLE IF NOT EXISTS meta_webhook_schema (
    version INTEGER PRIMARY KEY CHECK (version = 1)
);
CREATE TABLE IF NOT EXISTS meta_webhook_receipts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    body_sha256 TEXT NOT NULL UNIQUE,
    raw_body BLOB NOT NULL,
    received_at_ms INTEGER NOT NULL,
    normalization_issues_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS meta_webhook_inbox (
    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
    event_key TEXT NOT NULL UNIQUE,
    receipt_id INTEGER NOT NULL REFERENCES meta_webhook_receipts(id),
    kind TEXT NOT NULL CHECK (kind IN ('message', 'status')),
    waba_id TEXT NOT NULL,
    phone_number_id TEXT NOT NULL,
    wamid TEXT NOT NULL,
    peer_id TEXT NOT NULL,
    provider_timestamp TEXT,
    provider_state TEXT NOT NULL,
    payload_json TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS meta_inbox_wamid_status
ON meta_webhook_inbox(waba_id, phone_number_id, wamid, kind);
CREATE INDEX IF NOT EXISTS meta_inbox_scope_sequence
ON meta_webhook_inbox(waba_id, phone_number_id, sequence);
CREATE INDEX IF NOT EXISTS meta_inbox_peer_messages
ON meta_webhook_inbox(waba_id, phone_number_id, peer_id, sequence)
WHERE kind='message';
"""


class SqliteWebhookInbox:
    """Adaptador del puerto: commit de cuerpo y eventos antes de devolver recibo."""

    def __init__(self, path: Path):
        self.path = path

    def _connect(self) -> sqlite3.Connection:
        """Un handle por operación, espera acotada y fsync antes del ACK HTTP."""
        connection = sqlite3.connect(self.path, timeout=3)
        try:
            connection.execute("PRAGMA foreign_keys=ON")
            connection.execute("PRAGMA synchronous=FULL")
            return connection
        except BaseException:
            connection.close()
            raise

    def initialize(self) -> None:
        """Arranque sin worker: verifica versión y prepara WAL en disco local."""
        with closing(self._connect()) as connection:
            if connection.execute("PRAGMA journal_mode=WAL").fetchone()[0] != "wal":
                raise ValueError("La bandeja Meta requiere WAL en disco local")
            connection.executescript(_SCHEMA)
            with connection:
                connection.execute(
                    "INSERT INTO meta_webhook_schema(version) VALUES (1) "
                    "ON CONFLICT DO NOTHING"
                )
                versions = connection.execute(
                    "SELECT version FROM meta_webhook_schema"
                ).fetchall()
                if versions != [(1,)]:
                    raise ValueError("Versión de bandeja Meta no compatible")

    def save(self, raw: bytes, batch: NormalizedWebhook) -> InboxReceipt:
        """Restricciones únicas funcionan también con reintentos y varios procesos."""
        digest = hashlib.sha256(raw).hexdigest()
        with closing(self._connect()) as connection, connection:
            connection.execute("BEGIN IMMEDIATE")
            cursor = connection.execute(
                "INSERT INTO meta_webhook_receipts(body_sha256,raw_body,received_at_ms,"
                "normalization_issues_json) VALUES (?,?,?,?) "
                "ON CONFLICT(body_sha256) DO NOTHING",
                (digest, raw, time.time_ns() // 1_000_000, json.dumps(batch.issues)),
            )
            receipt_id = connection.execute(
                "SELECT id FROM meta_webhook_receipts WHERE body_sha256=?",
                (digest,),
            ).fetchone()[0]
            inserted = 0
            if cursor.rowcount == 1:
                for event in batch.events:
                    row = connection.execute(
                        "INSERT INTO meta_webhook_inbox("
                        "event_key,receipt_id,kind,waba_id,phone_number_id,"
                        "wamid,peer_id,provider_timestamp,provider_state,payload_json) "
                        "VALUES (?,?,?,?,?,?,?,?,?,?) "
                        "ON CONFLICT(event_key) DO NOTHING",
                        (
                            event.event_key,
                            receipt_id,
                            "message" if event.kind == "echo" else event.kind,
                            event.waba_id,
                            event.phone_number_id,
                            event.wamid,
                            event.peer_id,
                            event.provider_timestamp,
                            event.state,
                            json.dumps({**event.payload, **({"_nano_direction": "outbound"} if event.kind == "echo" else {})}),
                        ),
                    )
                    inserted += row.rowcount
            receipt = InboxReceipt(receipt_id, inserted, len(batch.events) - inserted)
        # Fuera del context manager: un error del commit impide devolver éxito.
        return receipt
