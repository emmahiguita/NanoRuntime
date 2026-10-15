"""Lectura paginada sobre SQLite existente, sin otra base ni worker de sincronización."""

import sqlite3
import time
from contextlib import closing, contextmanager
from pathlib import Path

from .whatsapp_history_models import HistoryCursorExpired, public_event
from .whatsapp_webhook_events import MetaWebhookScope


# Se usa secuencia de recepción, no una fecha fabricada ni el nombre del contacto.
_SELECT = """SELECT e.*, r.received_at_ms FROM meta_webhook_inbox e
JOIN meta_webhook_receipts r ON r.id=e.receipt_id"""
_SCOPE = "e.waba_id=? AND e.phone_number_id=?"


class SqliteWhatsAppHistory:
    """Adaptador de solo lectura; cursores acotan cada página a una instantánea."""

    def __init__(self, path: Path):
        self.path = path

    @contextmanager
    def _snapshot(self, scope: MetaWebhookScope, through: int | None):
        """Un handle corto, modo read-only y presupuesto de consulta para evitar bloqueos."""
        with closing(sqlite3.connect(self.path.as_uri() + "?mode=ro", uri=True, timeout=3)) as db:
            db.row_factory = sqlite3.Row
            db.execute("PRAGMA query_only=ON")
            deadline = time.monotonic() + 2
            db.set_progress_handler(lambda: int(time.monotonic() > deadline), 10000)
            db.execute("BEGIN")
            maximum = db.execute(
                "SELECT COALESCE(MAX(sequence),0) FROM meta_webhook_inbox "
                "WHERE waba_id=? AND phone_number_id=?",
                (scope.waba_id, scope.phone_number_id),
            ).fetchone()[0]
            if through is not None and through > maximum:
                raise HistoryCursorExpired("La instantánea ya no existe; vuelve a sincronizar")
            yield db, maximum if through is None else through

    @staticmethod
    def _page(scope, rows, limit, snapshot, cursor_name):
        """Solicita una fila extra para distinguir fin de historial de una página completa."""
        more = len(rows) > limit
        data = rows[:limit]
        return {
            "data": data, "snapshot": snapshot,
            cursor_name: data[-1]["sequence"] if more and data else None,
            "scope": {"waba_id": scope.waba_id, "phone_number_id": scope.phone_number_id},
        }

    def conversations(self, scope, limit, before=None, through=None):
        """Agrupa solo mensajes: estados de entrega nunca crean conversaciones fantasma."""
        with self._snapshot(scope, through) as (db, snapshot):
            rows = db.execute(
                """WITH latest AS (
                SELECT peer_id, MAX(sequence) AS last_sequence, COUNT(*) AS message_count
                FROM meta_webhook_inbox
                WHERE waba_id=? AND phone_number_id=? AND kind IN ('message', 'echo') AND sequence<=?
                GROUP BY peer_id HAVING (? IS NULL OR MAX(sequence)<?)
                ORDER BY last_sequence DESC LIMIT ?)
                SELECT e.*, r.received_at_ms, latest.message_count FROM latest
                JOIN meta_webhook_inbox e ON e.sequence=latest.last_sequence
                JOIN meta_webhook_receipts r ON r.id=e.receipt_id
                ORDER BY e.sequence DESC""",
                (scope.waba_id, scope.phone_number_id, snapshot, before, before, limit + 1),
            ).fetchall()
            items = [{"sequence": row["sequence"], "peer_id": row["peer_id"],
                      "message_count": row["message_count"], "last_message": public_event(row)}
                     for row in rows]
            return self._page(scope, items, limit, snapshot, "next_before")

    def messages(self, scope, peer, limit, before=None, through=None):
        """Devuelve recibidos del chat exacto; no reconstruye texto saliente desde statuses."""
        with self._snapshot(scope, through) as (db, snapshot):
            rows = db.execute(
                _SELECT + " WHERE " + _SCOPE +
                " AND e.peer_id=? AND e.kind IN ('message', 'echo') AND e.sequence<=?"
                " AND (? IS NULL OR e.sequence<?) ORDER BY e.sequence DESC LIMIT ?",
                (scope.waba_id, scope.phone_number_id, peer, snapshot, before, before, limit + 1),
            ).fetchall()
            return self._page(scope, [public_event(row) for row in rows],
                              limit, snapshot, "next_before")

    def changes(self, scope, after, limit, through=None):
        """Avanza solo hasta el último evento leído: una ráfaga no pierde páginas intermedias."""
        with self._snapshot(scope, through) as (db, snapshot):
            if after > snapshot:
                raise HistoryCursorExpired("El cursor supera la bandeja actual; vuelve a sincronizar")
            rows = db.execute(
                _SELECT + " WHERE " + _SCOPE +
                " AND e.sequence>? AND e.sequence<=? ORDER BY e.sequence ASC LIMIT ?",
                (scope.waba_id, scope.phone_number_id, after, snapshot, limit + 1),
            ).fetchall()
            result = self._page(scope, [public_event(row) for row in rows],
                                limit, snapshot, "next_after")
            result["cursor"] = result["next_after"] or snapshot
            return result
