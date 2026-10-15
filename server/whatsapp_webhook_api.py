"""Entrada oficial del gateway; no envía mensajes ni ejecuta el LLM en el webhook."""

import asyncio
import json
import logging
import sqlite3
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import APIRouter, Depends, FastAPI, HTTPException, Request
from fastapi.responses import PlainTextResponse

from .whatsapp_webhook_events import MetaWebhookScope, WebhookInbox
from .whatsapp_webhook_normalizer import normalize_webhook
from .whatsapp_webhook_security import (
    verify_signature,
    verify_subscription,
    webhook_database_path,
    webhook_settings,
)
from .whatsapp_webhook_store import SqliteWebhookInbox
from .whatsapp_history_store import SqliteWhatsAppHistory


# Límite local de defensa, no una promesa sobre el tamaño permitido por Meta.
_MAX_BODY_BYTES = 4 * 1024 * 1024
router = APIRouter()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def webhook_lifespan(app: FastAPI):
    """Inicializa disco una vez; sin configuración conserva las rutas anteriores."""
    path = webhook_database_path()
    store = SqliteWebhookInbox(path) if path is not None else None
    if store is not None:
        await asyncio.to_thread(store.initialize)
    app.state.meta_webhook_inbox = store
    # Misma base: el cliente lee la evidencia que el webhook ya confirmó en disco.
    app.state.meta_history_reader = SqliteWhatsAppHistory(path) if path is not None else None
    try:
        yield
    finally:
        # No hay polling ni handles persistentes que puedan quedar huérfanos.
        app.state.meta_webhook_inbox = None
        app.state.meta_history_reader = None


def _inbox(request: Request) -> WebhookInbox:
    """El handler no conoce SQLite; ausencia de almacenamiento nunca es éxito."""
    store = getattr(request.app.state, "meta_webhook_inbox", None)
    if store is None:
        raise HTTPException(503, "Bandeja duradera de Meta no configurada")
    return store


async def _raw_body(request: Request) -> bytes:
    """Limita la lectura incluso sin Content-Length; rechaza compresión no soportada."""
    if request.headers.get("content-encoding", "identity").lower() != "identity":
        raise HTTPException(415, "El webhook requiere cuerpo sin compresión")
    content_type = request.headers.get("content-type", "").split(";", 1)[0].strip()
    if content_type.lower() != "application/json":
        raise HTTPException(415, "El webhook requiere application/json")
    content = bytearray()
    async for chunk in request.stream():
        if len(content) + len(chunk) > _MAX_BODY_BYTES:
            raise HTTPException(413, "Webhook supera el límite local de recepción")
        content.extend(chunk)
    return bytes(content)


def _reject_constant(_: str):
    """JSON estricto: NaN e Infinity no pertenecen al protocolo JSON de Meta."""
    raise ValueError("Constante JSON no válida")


# Depends se evalúa como metadato: verifica almacenamiento en ambas rutas.
InboxDependency = Annotated[WebhookInbox, Depends(_inbox)]


@router.get("/api/v1/whatsapp/webhook", response_class=PlainTextResponse)
async def verify_webhook(request: Request, inbox: InboxDependency):
    """Handshake de Meta: usa token de verificación, no la llave privada de Nano."""
    settings = webhook_settings()
    query = request.query_params
    challenge = query.get("hub.challenge", "")
    verify_subscription(
        query.get("hub.mode", ""),
        query.get("hub.verify_token", ""),
        challenge,
        settings.verify_token,
    )
    return PlainTextResponse(challenge)


@router.post("/api/v1/whatsapp/webhook", response_class=PlainTextResponse)
async def receive_webhook(request: Request, inbox: InboxDependency):
    """Firma → lote completo → commit; el ACK no significa entrega ni respuesta IA."""
    settings = webhook_settings()
    try:
        raw = await asyncio.wait_for(_raw_body(request), timeout=10)
    except TimeoutError as error:
        raise HTTPException(408, "Lectura de webhook incompleta") from error
    verify_signature(
        raw,
        request.headers.get("X-Hub-Signature-256", ""),
        settings.app_secret,
    )
    try:
        payload = json.loads(raw.decode("utf-8"), parse_constant=_reject_constant)
    except (ValueError, UnicodeDecodeError, RecursionError) as error:
        raise HTTPException(400, "Cuerpo JSON de Meta no válido") from error
    # La validación de lotes grandes no bloquea las otras rutas HTTP del gateway.
    scope = MetaWebhookScope(settings.waba_id, settings.phone_number_id)
    try:
        batch = await asyncio.to_thread(normalize_webhook, payload, scope)
    except PermissionError as error:
        raise HTTPException(403, str(error)) from error
    except ValueError as error:
        raise HTTPException(400, str(error)) from error
    try:
        receipt = await asyncio.to_thread(inbox.save, raw, batch)
    except (sqlite3.Error, OSError) as error:
        # Solo clase del error: jamás cuerpo, teléfonos, tokens o contenido privado.
        logger.error("Meta inbox persistencia fallida: %s", type(error).__name__)
        raise HTTPException(
            503,
            "No se pudo persistir el webhook; recepción no confirmada",
        ) from error
    if batch.issues:
        logger.warning(
            "Meta inbox requiere revisión: receipt=%d issues=%d",
            receipt.receipt_id,
            len(batch.issues),
        )
    return PlainTextResponse("EVENT_RECEIVED")
