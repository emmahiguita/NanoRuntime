# Nano Desktop · gateway local de WhatsApp

Reutiliza `whatsapp_templates_api:app`. El panel auxiliar configura y controla ese
gateway; **no es una pantalla ya incorporada al ejecutable Tauri instalado**.
No altera los modelos, el motor de escritorio, WhatsApp Web ni el agente personal.

## Iniciar en este PC

Desde la raíz del repositorio, con Python para Windows y las dependencias de
`server/requirements-whatsapp.txt`:

```powershell
python -m server.whatsapp_local_panel
```

1. Introduce el token de Meta, WABA, Phone Number ID y versión Graph reales.
2. El App Secret es opcional para lectura/envío; necesario para el webhook firmado.
3. Pulsa **Guardar cifrado**. No escribas secretos en comandos, chat ni archivos del repo.
4. Pulsa **Iniciar** y después **Comprobar Meta**. Solo consulta plantillas, no las crea
   ni envía mensajes. Un error es un fallo real, nunca una confirmación simulada.
5. **Detener** cierra el gateway. Cerrar el panel detiene su propio servidor; no mata otros procesos.

Las credenciales se guardan en `%LOCALAPPDATA%/Nano/WhatsAppServer/settings.dpapi`,
protegidas con DPAPI del usuario Windows y ACL de esa carpeta. La clave de Nano y
el token de verificación se generan localmente una sola vez y se conservan al
renovar el token de Meta. El panel no copia credenciales al portapapeles ni a logs.
DPAPI no impide que un programa malicioso que ya se ejecute como el mismo usuario
acceda al secreto en memoria. No protege contra una cuenta Windows comprometida.

La SQLite persistente se ubica junto a la configuración. **SQLite no está cifrada**;
contendrá datos personales cuando exista recepción real. Ver las obligaciones de
disco cifrado, backup y retención en `README_WHATSAPP_WEBHOOK.md`.

## Ciclo de vida y límites comprobables

- Solo escucha `127.0.0.1:8010`. No abre firewall, LAN, túneles ni exposición pública.
- Un único gateway/hilo, sin autoreload, trabajadores hijos ni bucles de inferencia.
- Reserva exclusiva del puerto; si está ocupado falla sin matar ni adoptar al dueño.
- La consulta Meta y el guardado no bloquean la interfaz. El cierre espera sus
  operaciones acotadas por timeout antes de terminar.
- El token se carga al iniciar. Detén, guarda y reinicia para renovarlo.
- Sin archivo privado, el proceso puede arrancar, pero las rutas Cloud devuelven
  503. Un archivo existente ilegible falla sin reemplazarlo ni inventar claves.
- `/api/v1/whatsapp/health` informa proceso/configuración, **no** validez remota,
  recepción, envío, entrega ni HTTPS. El panel solo confirma acceso si la consulta
  de plantillas realmente obtiene datos de Meta.

Para ejecutar sin el panel: `python -m server.whatsapp_local_server`.
Detén con Ctrl+C. No se instala como servicio Windows ni arranque automático.
No se promete operación 24/7: el PC debe permanecer encendido, conectado y sin suspensión.

## Lo que sigue pendiente

1. Validar el token real con **Comprobar Meta**. El token temporal puede caducar.
2. Elegir HTTPS público estable y autorizar su publicación. Meta no puede enviar
   eventos a `127.0.0.1`; no se inventa una URL accesible.
3. Configurar App Secret, callback, campo `messages` y suscripción de la WABA.
4. Implementar el adaptador MCP del gateway y el consumidor para el panel/agente.
   El cliente MCP existente no equivale a ese servidor implementado.
5. Autorizar destinatario y mensaje concretos antes de validar un envío.

## Fuentes primarias

- [Microsoft: CryptProtectData / DPAPI](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata)
- [Uvicorn: configuración y ejecución programática](https://www.uvicorn.org/settings/)
