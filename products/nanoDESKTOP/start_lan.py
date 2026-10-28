"""
MÓDULO: start_lan.py
QUÉ HACE: Inicia el servidor de NanoAI Desktop en red local (0.0.0.0:3001) para conectar Nano Mobile.
CÓMO FUNCIONA: Genera o reutiliza una clave API segura de 32 caracteres en .nano_lan_key,
               detecta la IP local de la tarjeta Wi-Fi/Ethernet y arranca dev_server.py.
POR QUÉ: Cumple el contrato de seguridad de request_access.py (evita ataques en redes compartidas)
         y permite a Nano Mobile enviar prompts a los modelos grandes del PC.
"""
import os
import secrets
import socket
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
KEY_FILE = ROOT / ".nano_lan_key"


def get_or_create_key() -> str:
    """Obtiene o crea una clave fija de 32 caracteres para no tener que reconfigurar el móvil cada vez."""
    if KEY_FILE.is_file():
        key = KEY_FILE.read_text(encoding="utf-8").strip()
        if len(key) >= 32:
            return key
    new_key = secrets.token_hex(16)  # 32 caracteres hexadecimales
    KEY_FILE.write_text(new_key, encoding="utf-8")
    return new_key


def get_local_ip() -> str:
    """Detecta la IP privada del PC en la red local (Wi-Fi / Ethernet)."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


def main():
    api_key = get_or_create_key()
    local_ip = get_local_ip()
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 3001

    env = dict(os.environ, NANO_HOST="0.0.0.0", NANO_API_KEY=api_key)

    print("=" * 64)
    print("  PUENTE DE MODELOS GRANDES PARA NANO MOBILE (PC -> MOBILE)")
    print("=" * 64)
    print(f"IP del PC en tu Wi-Fi:      {local_ip}")
    print(f"Puerto:                     {port}")
    print(f"URL Base:                   http://{local_ip}:{port}")
    print(f"Endpoint Nano Mobile:       http://{local_ip}:{port}/completion")
    print(f"Endpoint OpenAI Compatible: http://{local_ip}:{port}/v1/chat/completions")
    print(f"API Key (Bearer / Header):  {api_key}")
    print("=" * 64)
    print("Iniciando servidor de red...")

    cmd = [sys.executable, "-B", str(ROOT / "dev_server.py"), str(port)]
    subprocess.run(cmd, env=env, cwd=ROOT)


if __name__ == "__main__":
    main()
