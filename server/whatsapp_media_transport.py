"""Subida manual acotada a Meta. Sin URLs arbitrarias ni credenciales en el móvil."""
import base64
import binascii
import json
import re
import secrets
from urllib.request import Request, build_opener
from urllib.error import HTTPError, URLError
from fastapi import HTTPException
from .whatsapp_graph_transport import NoCredentialRedirect


def upload_media(payload, token, phone, version):
    name = str(payload.get("filename", "archivo"))
    mime = str(payload.get("mime_type", ""))
    allowed = {"application/pdf", "image/jpeg", "image/png", "image/webp", "video/mp4", "audio/mpeg", "audio/ogg", "audio/mp4"}
    if mime not in allowed or not re.fullmatch(r"[^\\/\r\n\"]{1,160}", name):
        raise HTTPException(422, "Nombre o tipo de archivo no admitido")
    try:
        data = base64.b64decode(payload.get("content", ""), validate=True)
    except (ValueError, TypeError, binascii.Error):
        raise HTTPException(422, "Archivo ilegible") from None
    if not data or len(data) > 6*1024*1024:
        raise HTTPException(413, "El archivo supera el límite de 6 MB")
    boundary = secrets.token_hex(24)
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="messaging_product"\r\n\r\nwhatsapp\r\n'
            f'--{boundary}\r\nContent-Disposition: form-data; name="type"\r\n\r\n{mime}\r\n'
            f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{name}"\r\nContent-Type: {mime}\r\n\r\n').encode()+data+f'\r\n--{boundary}--\r\n'.encode()
    request = Request(f"https://graph.facebook.com/{version}/{phone}/media", data=body,
        headers={"Authorization": "Bearer "+token, "Content-Type": "multipart/form-data; boundary="+boundary}, method="POST")
    try:
        with build_opener(NoCredentialRedirect()).open(request, timeout=20) as response:
            result = json.loads(response.read(65536))
        if not isinstance(result, dict) or not str(result.get("id", "")).isdigit():
            raise ValueError()
        return {"id": result["id"]}
    except HTTPError as error:
        error.close()
        raise HTTPException(502, "Meta rechazó la subida del archivo") from None
    except (URLError, OSError, ValueError):
        raise HTTPException(502, "Meta no confirmó la subida del archivo") from None
