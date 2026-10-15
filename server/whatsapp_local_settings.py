"""Credenciales del gateway local: disco privado, DPAPI y escritura atómica."""

import json
import os
import re
import secrets
import subprocess
import tempfile
from pathlib import Path

from .windows_dpapi import transform

# Lista cerrada: ningún valor del formulario se convierte en comando o ruta arbitraria.
FIELDS = ("META_WHATSAPP_ACCESS_TOKEN", "META_WHATSAPP_WABA_ID",
          "META_WHATSAPP_PHONE_NUMBER_ID", "META_GRAPH_API_VERSION", "META_APP_SECRET")
PRIVATE_FIELDS = ("NANO_WHATSAPP_API_KEY", "META_WEBHOOK_VERIFY_TOKEN",
                  "NANO_WHATSAPP_SEND_KEY", "NANO_WHATSAPP_ADMIN_KEY")


def data_directory() -> Path:
    """Separa secretos y mensajes del código versionado; no usa una carpeta temporal."""
    value = os.environ.get("LOCALAPPDATA", "")
    if os.name != "nt" or not value or not Path(value).is_absolute():
        raise ValueError("El servidor local requiere LOCALAPPDATA de Windows")
    path = Path(value) / "Nano" / "WhatsAppServer"
    if path.exists() and path.stat().st_file_attributes & 0x400:
        raise ValueError("La carpeta privada no puede ser un enlace o junction")
    return path


def prepare_directory() -> Path:
    """Restringe esta carpeta a la cuenta actual antes de guardar contenido privado."""
    path = data_directory()
    path.mkdir(parents=True, exist_ok=True)
    # Script fijo, sin secretos ni interpolación del usuario; la ruta viaja como argumento.
    script = r"$p=Join-Path $env:LOCALAPPDATA 'Nano\WhatsAppServer'; "
    script += "$s=[System.Security.Principal.WindowsIdentity]::GetCurrent().User; "
    script += "$a=New-Object System.Security.AccessControl.DirectorySecurity; "
    script += "$a.SetAccessRuleProtection($true,$false); $a.SetOwner($s); "
    script += "$r=New-Object System.Security.AccessControl.FileSystemAccessRule($s,'FullControl','ContainerInherit,ObjectInherit','None','Allow'); "
    script += "$a.AddAccessRule($r); [System.IO.Directory]::SetAccessControl($p,$a)"
    executable = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    result = subprocess.run([str(executable), "-NoProfile", "-NonInteractive", "-Command", script],
                            capture_output=True, timeout=15, creationflags=subprocess.CREATE_NO_WINDOW)
    if result.returncode:
        raise OSError("No se pudo restringir el acceso al directorio privado")
    return path


def validate(values: dict) -> dict[str, str]:
    """Exige activos reales y formato explícito; no considera válido un token por su forma."""
    result = {key: str(values.get(key, "")).strip() for key in (*FIELDS, *PRIVATE_FIELDS)}
    for key, value in result.items():
        if len(value) > 8192 or any(char.isspace() for char in value):
            raise ValueError("La configuración contiene espacios o valores excesivos")
    if not result[FIELDS[0]]:
        raise ValueError("Falta el token real de Meta")
    if not all(re.fullmatch(r"[0-9]+", result[key]) for key in FIELDS[1:3]):
        raise ValueError("Los identificadores WABA y Phone Number ID deben ser numéricos")
    if not re.fullmatch(r"v[0-9]+\.[0-9]+", result[FIELDS[3]]):
        raise ValueError("Indica la versión Graph de tu app, por ejemplo v25.0")
    # Los dos últimos campos pueden faltar al leer archivos anteriores, no al guardarlos.
    if any(not 32 <= len(result[key]) <= 256 for key in PRIVATE_FIELDS[:2]):
        raise ValueError("Las llaves privadas de Nano deben tener 32 caracteres o más")
    if any(result[key] and not 32 <= len(result[key]) <= 256 for key in PRIVATE_FIELDS[2:]):
        raise ValueError("Las llaves de permisos deben tener entre 32 y 256 caracteres")
    access = [result[key] for key in (PRIVATE_FIELDS[0], *PRIVATE_FIELDS[2:]) if result[key]]
    if len(set(access)) != len(access):
        raise ValueError("Lectura, envío y administración requieren llaves distintas")
    return result


def load_settings() -> dict[str, str]:
    """Nunca imprime credenciales; si no hay archivo conserva el estado no configurado."""
    path = data_directory() / "settings.dpapi"
    if not path.exists():
        return {}
    if path.stat().st_size > 65536 or path.stat().st_file_attributes & 0x400:
        raise ValueError("El archivo privado no es válido")
    return validate(json.loads(transform(path.read_bytes(), decrypt=True)))


def save_settings(values: dict) -> None:
    """Conserva llaves de Nano al renovar Meta; solo reemplaza un archivo ya cifrado."""
    previous = load_settings()
    combined = {key: values.get(key, "") for key in FIELDS}
    combined.update({key: previous.get(key) or secrets.token_urlsafe(48) for key in PRIVATE_FIELDS})
    encoded = transform(json.dumps(validate(combined)).encode("utf-8"))
    directory = prepare_directory()
    # Conserva una copia CIFRADA del esquema anterior antes de migrar permisos.
    original, backup = directory / "settings.dpapi", directory / "settings.before-permissions.dpapi"
    if previous and not all(previous.get(key) for key in PRIVATE_FIELDS[2:]) and not backup.exists():
        with backup.open("xb") as stream:
            stream.write(original.read_bytes())
            stream.flush()
            os.fsync(stream.fileno())
    descriptor, temporary = tempfile.mkstemp(prefix="settings-", suffix=".dpapi", dir=directory)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, directory / "settings.dpapi")
    finally:
        if Path(temporary).exists():
            Path(temporary).unlink()


def apply_settings() -> bool:
    """Carga secretos únicamente en el proceso del gateway, antes del arranque."""
    values = upgrade_permissions()
    if not values:
        return False
    os.environ.update(values)
    os.environ["NANO_WHATSAPP_WEBHOOK_DB"] = str(data_directory() / "inbox.sqlite3")
    return True


def upgrade_permissions() -> dict[str, str]:
    """Migración local automática e idempotente; conserva token, IDs, lectura e historial."""
    values = load_settings()
    if values and not all(values.get(key) for key in PRIVATE_FIELDS[2:]):
        save_settings(values)
        values = load_settings()
    return values
