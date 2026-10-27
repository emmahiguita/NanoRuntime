---
name: nano-canonical-messaging-integrity
description: Conecta y audita el historial canónico de Nano Mobile, su deduplicación y el contexto del modelo sin inventar cobertura ni entrega.
metadata:
  short-description: Mantener mensajería canónica verificable
---

# Integridad de mensajería canónica

Usa esta guía al cambiar la ingesta Web/notificaciones/Meta, el Centro de
Mensajería, la deduplicación o el contexto conversacional del modelo.

## Flujo obligatorio

1. Traza proveedor → `CanonicalMessageStore` → lectura → prompt o panel.
   Persistir un mensaje no demuestra que un consumidor lo esté leyendo.
2. Conserva `providerMessageId` cuando exista. Si falta, usa una huella estable
   con proveedor, conversación, dirección, tiempo y contenido normalizado.
3. No fusiones chats solo por título. Exige paquete/cuenta y teléfono, JID,
   shortcut o identificador técnico compatible. Ante contradicción, conserva
   ambos chats.
4. Registra huecos de cobertura. Un preview Web o una notificación aislada no
   equivale a historial completo.
5. Acota el contexto por cantidad y caracteres. Una lectura SQLite lenta debe
   tener timeout corto y degradar a la memoria existente, nunca detener la cola.
6. Separa estados observables: abierto, acción despachada, aceptado por
   `RemoteInput`, enviado por proveedor, entregado y leído.
7. Antes de multimedia, verifica el destinatario. Un nombre visible o hash Web
   no es teléfono/JID. Falla cerrado si la identidad es ambigua.
8. Revisa suscripciones, timers, colas y callbacks al cerrar pantalla o proceso;
   evita reintentos de resultados desconocidos para no duplicar envíos.

## Rendimiento

- Para verificar apertura Web, consulta solo cabecera/cuenta; no extraigas todo
  el historial DOM antes de mostrar el chat. Conserva verificación de identidad.
- Una URI multimedia pertenece a su `MessagingStyle.Message`, no al contenedor
  completo. No adjuntes el último audio a todos los mensajes del replay.
- La clave de caché debe ser estable por paquete/URI/tiempo, no por hora del
  contenedor. No atribuyas archivos de carpetas compartidas por proximidad temporal.
- Los fallos de resolución multimedia deben caducar; una caché negativa eterna
  oculta archivos que aparecen después. Acota también su tamaño.
- Distingue fuente Web/instalada sin fusionar por nombre. Un cambio de fuente
  solo debe ofrecerse cuando haya identidad compatible para esa conversación.

- Evita búsquedas lineales dentro de comparaciones por parejas.
- Construye índices una vez por lote y conserva las comparaciones estrictas.
- No releas SQLite por cada cambio del DOM; combina snapshot Web en memoria con
  fuentes locales ya hidratadas.
- Mide en dispositivo antes de afirmar mejoras de velocidad.

## Regresiones comprobadas de Android y contexto

- La clave de notificación identifica un contenedor reutilizable, no un mensaje.
  Convierte cada elemento de `messages` conservando tiempo, autor y `isSelf`;
  prueba dos mensajes distintos bajo la misma clave y el replay de ambos.
- `live:` es un prefijo de presentación: retíralo antes de persistir para que el
  modelo consulte la misma identidad. Mantén separados cuenta y paquete.
- No deduzcas duplicados de texto dentro de una ventana de cinco segundos: dos
  mensajes idénticos pueden ser legítimos. Exige evidencia temporal exacta.
- El listado canónico nativo devuelve los recientes en orden ascendente.
  El prompt conserva ese orden y reserva primero espacio para los más recientes.
- La paginación debe ordenar y comparar el mismo identificador efectivo,
  incluyendo el fallback cuando `provider_message_id` está vacío.
- Android `gfxinfo` no mide por sí solo toda la rasterización Flutter. Cero
  fotogramas Android en reposo no demuestra ausencia de lags ni fugas de RAM.
- `audio_service` puede crear y ejecutar su motor al registrar plugins desde
  el headless. Reserva el motor UI sin Dart antes de ese registro; la Activity
  registra canales y ruta antes de ejecutar main. Comprueba en dispositivo
  la ruta visible y los `MissingPluginException` del PID recién iniciado.

## Validación

- El menú y el detalle deben activar WhatsApp mediante el mismo controlador:
  persiste su regla antes de conceder ownership Bot. Mostrar «activado» no basta.
- Limpiar contexto debe invalidar el turno y retirar autorización antes de borrar;
  advierte que Nano quedará pausado. No borres WhatsApp ni añadas reactivación implícita.
- En hojas modales, captura servicios antes del await y comprueba mounted antes
  de usar contexto/editores. Un callback de biblioteca puede sobrevivir al chat.
- Los botones de confirmación deben recibir el contexto de su propio diálogo.
  No cierres rutas con contextos previos ni timers de autocierre después de enviar.
- Web puede presentarse antes del archivo local; si falla este último, muestra
  carga parcial y reintento explícito. No conviertas el fallo en un inbox vacío.

- Mantén archivos nuevos por debajo de 200 líneas y comenta qué, cómo y por qué
  en fronteras, invariantes y decisiones no obvias.
- Ejecuta análisis estático, compilación de la variante afectada y actualización
  de Graphify después de editar.
- Para declarar envío o historial completo, exige una prueba E2E con evidencia
  real del proveedor. Compilar no prueba entrega, lectura ni cobertura total.
