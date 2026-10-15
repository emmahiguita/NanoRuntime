# Nano · recepción oficial de WhatsApp (sprint 2)

Entrada del gateway existente `server.whatsapp_templates_api:app`. No se crea otro servidor, agente, pantalla, modelo o bucle en segundo plano. WhatsApp Web y las notificaciones Android no cambian.

## Configuración real

Además de la configuración saliente existente, configura exclusivamente en el servidor:

| Variable | Uso |
| --- | --- |
| `META_APP_SECRET` | Secreto real de la aplicación Meta, para HMAC-SHA256 |
| `META_WEBHOOK_VERIFY_TOKEN` | Token aleatorio propio de al menos 32 caracteres, igual al configurado en Meta |
| `META_WHATSAPP_WABA_ID` | WABA que esta instancia está autorizada a recibir |
| `META_WHATSAPP_PHONE_NUMBER_ID` | Número Cloud que atiende esta instancia |
| `NANO_WHATSAPP_WEBHOOK_DB` | Ruta absoluta de un archivo SQLite en almacenamiento persistente local |

No confundas el token de verificación con el secreto de aplicación, el token Graph o `X-Nano-API-Key`. No pegues sus valores en chats, código ni registros. Reinicia el gateway cuando cambies la configuración.

Prepara un directorio de datos fuera del repositorio, con permisos solo para la cuenta del servicio. La carpeta debe existir; el servicio crea el archivo, no directorios arbitrarios. No uses SQLite en NFS/SMB, una carpeta pública o un volumen efímero. La base contiene datos personales: exige disco cifrado, copias consistentes, control de acceso y una política de retención. SQLite no cifra estos datos por sí mismo. Las copias en caliente requieren la API de backup de SQLite o una herramienta compatible con WAL; copiar únicamente `.sqlite3` con el servicio activo puede omitir datos.

Con las variables configuradas, desde la raíz:

```powershell
python -m uvicorn server.whatsapp_templates_api:app --host 127.0.0.1 --port 8010 --no-access-log --limit-concurrency 32
```

El proxy HTTPS también debe evitar registrar query strings: el GET contiene `hub.verify_token`. Protege las otras rutas con la llave Nano ya existente. No publiques el servidor de telemetría `server.main` como sustituto de este gateway.

Configura en Meta la URL pública HTTPS terminada en `/api/v1/whatsapp/webhook`, el token de verificación y el campo `messages`; suscribe la app a la WABA. La ruta POST exige firma incluso cuando Meta ofrece un botón de prueba. Configuración sin base devuelve 503 para el webhook, no recepción ficticia; las rutas salientes anteriores permanecen disponibles. Una ruta de base inválida o almacenamiento inaccesible impide un arranque configurado inseguro.

Esta versión atiende una WABA y un número explícitos por instancia. Una firma válida no autoriza otro activo: devuelve 403 ante un WABA/número diferente, sin persistir parcialmente el lote. No es un backend SaaS multiempresa; si la suscripción también envía eventos de otros números, configura su encaminamiento antes de usarlo.

## Flujo y evidencia

1. GET compara `hub.verify_token` y devuelve únicamente `hub.challenge` como texto.
2. POST limita lectura a 10 s y cuerpo a 4 MiB (defensas locales, no cuotas oficiales de Meta).
3. Verifica `X-Hub-Signature-256` sobre los bytes originales, antes de interpretar JSON.
4. Recorre todos los `entry[]`, `changes[]`, `messages[]` y `statuses[]`; comprueba el ámbito.
5. Guarda cuerpo firmado y eventos normalizados en la misma transacción SQLite, con `synchronous=FULL` y WAL.
6. Responde `200 EVENT_RECEIVED` únicamente después de completar el commit. Esto confirma almacenamiento, no respuesta IA, envío ni entrega al cliente.

No se ejecuta inferencia en el webhook. No hay worker, cola de tareas temporales ni conexiones SQLite permanentes; cada handle se cierra al terminar. Persistencia/normalización se ejecutan fuera del event loop. Espera de bloqueo SQLite: hasta 3 s; fallo de persistencia devuelve 503, nunca éxito. No se promete latencia fija ni disponibilidad 24 horas sin desplegar y medir el servicio.

## Datos guardados

| Tabla | Evidencia |
| --- | --- |
| `meta_webhook_receipts` | Cuerpo original, hash único, hora local de recepción y anomalías de normalización |
| `meta_webhook_inbox` | Eventos inmutables con secuencia, cuenta, número, WAMID, interlocutor, fecha y tipo/estado del proveedor |
| `meta_webhook_schema` | Versión de este esquema dedicado; no altera bases del móvil |

Los mensajes se deduplican por WABA + número + WAMID. Los estados por ese ámbito + estado + timestamp del proveedor + destinatario. Cuerpos idénticos no crean otro recibo; el mismo mensaje repetido dentro de cuerpos/lotes diferentes no crea otra entrada. Los cuerpos diferentes siguen conservándose como evidencia, aunque sus eventos estén repetidos. No hay actualización ciega de estado actual: los estados son eventos; recibir `sent` después de `read` no borra la evidencia de lectura.

Tipos desconocidos, referencias a medios, errores y contexto permanecen en el JSON original. No se descargan adjuntos, no se genera texto que los sustituya y no se inventa una fecha si falta. Elementos imposibles de identificar no entran como mensajes; quedan en el cuerpo y en `normalization_issues_json` para reprocesamiento controlado. Los campos de control de Meta se conservan, pero no aparecen como conversaciones. Todavía no hay un consumidor/reprocesador ni API móvil de historial; se implementan en los siguientes sprints.

Un ACK con anomalías significa que la evidencia se conservó, no que todos los elementos pudieron normalizarse. Los registros técnicos incluyen únicamente clase del error o recibo/cantidad de anomalías, nunca cuerpos, teléfonos o secretos.

## Comprobación manual con una cuenta autorizada

Sin crear tests automáticos ni mensajes ficticios:

1. Configura los valores reales, inicia el gateway y registra el callback HTTPS en Meta. Confirma que el handshake se acepta.
2. Desde tu teléfono de prueba, envía un mensaje al número Cloud autorizado. Consulta la base local: debe existir un recibo y una entrada con su WAMID real. El panel móvil todavía no lo consume.
3. Mediante la herramienta de replay autorizada del proxy, repite **los mismos bytes y firma** de un evento capturado. No edites ni publiques su contenido. Los conteos de recibos/entradas deben permanecer iguales.
4. Reenvía esa captura con una firma alterada: debe obtener 403 y ningún registro nuevo.
5. Envía otro mensaje real idéntico en texto: si tiene otro WAMID debe generar otra entrada. No deduplicar por texto o nombre.
6. Cuando haya un envío autorizado por el gateway existente, confirma eventos `sent`, `delivered`, `read` o `failed` **solo si Meta realmente los entrega**. La ausencia de un evento no autoriza inventar ese estado.
7. Reinicia el gateway y comprueba conservación de datos. Una caída de disco/bloqueo debe dar error sin ACK; el reproceso no debe duplicar entradas.

Consultas locales de inspección, sin mostrar contenido privado:

```sql
SELECT COUNT(*) FROM meta_webhook_receipts;
SELECT kind, COUNT(*) FROM meta_webhook_inbox GROUP BY kind;
SELECT provider_state, COUNT(*) FROM meta_webhook_inbox WHERE kind='status' GROUP BY provider_state;
SELECT id, normalization_issues_json FROM meta_webhook_receipts WHERE normalization_issues_json <> '[]';
PRAGMA integrity_check;
```

No se ejecutaron esos envíos/replays en esta implementación. Las credenciales, HTTPS, suscripción y recepción real son validaciones de despliegue pendientes. La APK del sprint 1 sigue instalada: este cambio es del servidor, no necesita otra APK por sí solo.

## Referencias primarias consultadas

- [Ejemplo de Meta: verificación y firma de webhooks](https://github.com/fbsamples/whatsapp-api-examples/blob/main/signature-validation-with-webhooks-payloads/app.py). Nano aplica comparación constante, diferencia secretos y no copia la respuesta automática de demostración.
- [Colección oficial Meta: estructura y estados del webhook](https://www.postman.com/meta/whatsapp-business-platform/folder/tduohwq/webhook-payload-reference).
- [Colección oficial Meta: suscripción a la WABA](https://www.postman.com/meta/whatsapp-business-platform/documentation/wlk6lh4/whatsapp-cloud-api?entity=request-13382743-ba924e99-3d98-4954-b4e3-73a519939c33).
