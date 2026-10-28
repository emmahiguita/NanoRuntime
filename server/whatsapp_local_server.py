"""Arranque en el PC del gateway existente; no publica puertos ni abre el firewall."""

import socket
import sys

import uvicorn

from .whatsapp_local_settings import apply_settings

LOCAL_HOST = "127.0.0.1"
LOCAL_PORT = 8010
LOCAL_URL = f"http://{LOCAL_HOST}:{LOCAL_PORT}"


def server_config() -> uvicorn.Config:
    """Conserva registros en consola; pythonw no tiene streams y usa un handler nulo.

    El panel comunica fallos mediante su controlador, sin registrar credenciales
    ni intentar escribir en stdout/stderr inexistentes.
    """
    logging_config = uvicorn.config.LOGGING_CONFIG
    if sys.stdout is None or sys.stderr is None:
        logging_config = {
            "version": 1, "disable_existing_loggers": False,
            "handlers": {"silent": {"class": "logging.NullHandler"}},
            "loggers": {
                name: {"handlers": ["silent"], "level": "WARNING", "propagate": False}
                for name in ("uvicorn", "uvicorn.error", "uvicorn.access")
            },
        }
    return uvicorn.Config("server.whatsapp_templates_api:app", host=LOCAL_HOST,
                          port=LOCAL_PORT, access_log=False, log_level="warning",
                          workers=1, limit_concurrency=32, timeout_keep_alive=5,
                          timeout_graceful_shutdown=8, log_config=logging_config)


def build_server() -> tuple[uvicorn.Server, socket.socket]:
    """Reserva el puerto exclusivamente para impedir instancias dobles, sin matar terceros."""
    apply_settings()
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        listener.bind((LOCAL_HOST, LOCAL_PORT))
        listener.listen(128)
    except OSError:
        listener.close()
        raise OSError("El puerto 8010 está ocupado; no se reemplazó ningún proceso") from None
    # El creador conserva propiedad del socket hasta entregar ambos recursos.
    # Así también lo libera si falla la configuración, antes de llegar al panel.
    try:
        return uvicorn.Server(server_config()), listener
    except (Exception, SystemExit):
        listener.close()
        raise


def main() -> None:
    """Ejecuta sin autoreload ni procesos auxiliares; el cierre libera socket y SQLite."""
    listener = None
    try:
        server, listener = build_server()
        print(f"Gateway local: {LOCAL_URL}; no equivale a conexión Meta verificada.")
        server.run(sockets=[listener])
    except (OSError, ValueError):
        raise SystemExit("No se pudo iniciar: revisa configuración privada o puerto 8010") from None
    finally:
        if listener is not None:
            listener.close()


if __name__ == "__main__":
    main()
