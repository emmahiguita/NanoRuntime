"""API de bandeja oficial autenticada; leer no consulta Meta ni envía mensajes."""

import asyncio
import logging
import os
import re
import sqlite3
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, Query, Request, Response

from .whatsapp_gateway_auth import authenticate_gateway
from .whatsapp_history_models import HistoryCursorExpired, WhatsAppHistoryReader
from .whatsapp_webhook_events import MetaWebhookScope


router = APIRouter(dependencies=[Depends(authenticate_gateway)])
logger = logging.getLogger(__name__)
# SQLite usa enteros signed de 64 bits; valores enormes nunca llegan al adaptador.
Cursor = Annotated[int | None, Query(ge=0, le=9223372036854775807)]
Limit = Annotated[int, Query(ge=1, le=100)]


def _reader(request: Request) -> WhatsAppHistoryReader:
    """La instancia la inyecta el lifespan del gateway, no se abre otro servidor."""
    reader = getattr(request.app.state, "meta_history_reader", None)
    if reader is None:
        raise HTTPException(503, "Historial oficial no configurado")
    return reader


def _scope() -> MetaWebhookScope:
    """Una llave accede únicamente a los activos configurados de este gateway."""
    waba = os.environ.get("META_WHATSAPP_WABA_ID", "")
    phone = os.environ.get("META_WHATSAPP_PHONE_NUMBER_ID", "")
    if not all(re.fullmatch(r"[0-9]{1,32}", value) for value in (waba, phone)):
        raise HTTPException(503, "Ámbito oficial no configurado")
    return MetaWebhookScope(waba, phone)


async def _read(response: Response, operation, *args):
    """SQLite fuera del event loop; errores no revelan teléfonos, SQL ni cuerpos privados."""
    response.headers["Cache-Control"] = "private, no-store"
    try:
        return await asyncio.to_thread(operation, _scope(), *args)
    except HistoryCursorExpired as error:
        raise HTTPException(409, str(error)) from error
    except (sqlite3.Error, OSError, ValueError, TypeError, KeyError) as error:
        logger.error("Meta historial lectura fallida: %s", type(error).__name__)
        raise HTTPException(503, "No se pudo leer el historial oficial") from error


Reader = Annotated[WhatsAppHistoryReader, Depends(_reader)]


@router.get("/api/v1/whatsapp/conversations")
async def conversations(response: Response, reader: Reader, limit: Limit = 50,
                        before: Cursor = None, through: Cursor = None):
    """Último mensaje por interlocutor, paginado sin mezclar cuentas."""
    return await _read(response, reader.conversations, limit, before, through)


@router.get("/api/v1/whatsapp/conversations/{peer_id}/messages")
async def messages(response: Response, reader: Reader,
                   peer_id: Annotated[str, Path(pattern=r"^[0-9]{1,32}$")],
                   limit: Limit = 50, before: Cursor = None, through: Cursor = None):
    """Historial recibido del interlocutor exacto, del más reciente al más antiguo."""
    return await _read(response, reader.messages, peer_id, limit, before, through)


@router.get("/api/v1/whatsapp/changes")
async def changes(response: Response, reader: Reader,
                  after: Annotated[int, Query(ge=0, le=9223372036854775807)] = 0,
                  limit: Limit = 100, through: Cursor = None):
    """Eventos persistidos para sincronizar/reanudar; no afirma estados no recibidos."""
    return await _read(response, reader.changes, after, limit, through)
