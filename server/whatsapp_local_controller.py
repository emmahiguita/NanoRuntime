"""Ciclo de vida del gateway del panel: un solo hilo, sin hijos huérfanos."""

import threading

from .whatsapp_local_server import build_server


class GatewayController:
    """El panel posee el servidor y solicita su cierre al terminar; no controla terceros."""

    def __init__(self):
        self.server = None
        self.thread = None
        self.error = None
        self.stopping = threading.Event()

    @property
    def active(self) -> bool:
        """Distingue hilo vivo de servidor listo; la UI puede mostrar el arranque real."""
        return bool(self.thread and self.thread.is_alive())

    def start(self) -> None:
        """Evita doble arranque y deja el trabajo de disco/red fuera del hilo visual."""
        if self.active:
            raise ValueError("Detén el servidor antes de reiniciarlo")
        self.server = None
        self.error = None
        self.stopping.clear()
        self.thread = threading.Thread(target=self._run, name="nano-whatsapp-gateway", daemon=True)
        self.thread.start()

    def _run(self) -> None:
        """Liberación explícita del socket incluso si Uvicorn no alcanza a iniciar."""
        listener = None
        try:
            self.server, listener = build_server()
            if self.stopping.is_set():
                return
            self.server.run(sockets=[listener])
            if not self.server.started and not self.stopping.is_set():
                self.error = "Arranque fallido: el gateway no completó su inicialización"
        except OSError:
            # No mostrar excepciones crudas: pueden contener rutas o datos privados.
            self.error = "Arranque fallido: revisa acceso a archivos y disponibilidad del puerto 8010"
        except ImportError:
            self.error = "Arranque fallido: faltan dependencias del servidor en este Python"
        except ValueError:
            self.error = "Arranque fallido: revisa los campos guardados de la configuración privada"
        except (Exception, SystemExit):
            self.error = "Arranque fallido durante la inicialización del gateway; no se enviaron mensajes"
        finally:
            if listener is not None:
                listener.close()

    def stop(self) -> None:
        """Cierre cooperativo: permite finalizar peticiones y transacciones pendientes."""
        self.stopping.set()
        if self.server is not None:
            self.server.should_exit = True

    def wait(self, seconds: float = 10) -> bool:
        """Espera acotada solo al cerrar; nunca bloquea la escritura normal del panel."""
        if self.thread:
            self.thread.join(seconds)
        return not self.active
