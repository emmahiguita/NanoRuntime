# Informe de mensajería WhatsApp — 14 de octubre de 2026

## Resultado ejecutivo

El Centro de Mensajería funciona como agregador de WhatsApp Web, notificaciones
Android y memoria local. En el dispositivo auditado, la sesión Web publicó 33
conversaciones después de instalar la corrección. Esto demuestra observación,
no 33 inferencias simultáneas.

Se corrigieron tres puntos durante esta revisión:

1. Los cambios del DOM de WhatsApp Web ya no fuerzan a releer SQLite,
   notificaciones, ownership y asignaciones en cada snapshot.
2. `BurstTurnGate` dejó de escribir texto privado de mensajes en Logcat.
3. Nano Negocio expone un acceso directo a la pantalla oficial de Meta Cloud,
   plantillas y gateway desde la pestaña Canales.

La compilación `fullSideloadDebug` pasó análisis estático, se instaló y arrancó
sin cierres. El feed Web reanudó el observador y reportó 33 filas.

## Cobertura comprobada

| Área | Estado | Evidencia y alcance |
|---|---|---|
| Lista de conversaciones | Funcional | Une Personal, Negocio, historial local, notificaciones activas y feed Web con deduplicación. |
| Velocidad del panel | Mejorada | La carga local queda cacheada mientras Web actualiza solo su snapshot en memoria. |
| WhatsApp Web | Funcional con sesión vinculada | Observador por mutaciones, debounce de 120 ms, sondeo de recuperación cada 5 s y límite visible de 80 filas. |
| Historial visual Web | Funcional | Abre el chat real dentro del WebView oficial; WhatsApp renderiza texto, fotos, videos, audios, reacciones y carga anterior. |
| Historial por notificaciones | Parcial por diseño Android | Solo existe desde que Nano observó notificaciones y con los campos que WhatsApp entregó a Android. |
| Envío de texto | Funcional con límites | Prioriza `RemoteInput`; sin acción activa abre el chat verificado de WhatsApp. Abrir o pulsar no prueba entrega/lectura. |
| Adjuntos desde el panel | Funcional guiado | Selector de imágenes, videos, PDF, biblioteca y otros archivos; copia estable y comparte mediante WhatsApp. |
| Adjuntos por WebView | Bloqueado intencionalmente | El transporte Web multimedia devuelve `false` hasta poder verificar preview, destinatario y commit. |
| Formularios | Plantillas de texto | Contacto, encuesta y pedido se insertan en el compositor; no son WhatsApp Flows interactivos. |
| Identidad Nano Personal | Funcional | Nombre, descripción y tono se guardan de forma durable en el repositorio de Persona. |
| Separación Personal/Negocio | Funcional | Asignación por conversación, ownership y memorias separadas; el catálogo solo entra en Negocio. |
| Meta Cloud profesional | Parcialmente listo | Gateway HTTPS, almacenamiento seguro, inbox, texto y administración de plantillas existen; requiere servidor y llaves configuradas. |

## Lo que no puede prometerse

- Android Notification Listener no puede reconstruir el historial completo
  anterior ni acceder libremente a los datos privados de WhatsApp móvil.
- El historial completo visual procede de la sesión vinculada de WhatsApp Web.
  Ese DOM no equivale todavía a un índice estructurado completo para el modelo.
- El envío multimedia directo por el bridge Web está deshabilitado porque la
  implementación anterior confundía “archivo adjuntado” con “archivo enviado”.
- Los formularios actuales son texto reutilizable, no recursos oficiales de
  WhatsApp Flows.
- Meta Cloud necesita un Nano Gateway operativo. El móvil no guarda el token
  de Meta; solo guarda llaves propias del gateway mediante almacenamiento seguro.

## Pendientes prioritarios

### P0 — Historial canónico

Crear una entidad `CanonicalMessage` con observaciones Web/notificación,
`providerMessageId`, dirección, emisor y adjuntos. Añadir cobertura temporal por
conversación para que Nano sepa desde qué fecha posee evidencia.

### P0 — Multimedia oficial

Implementar envío de imagen, video, audio y documento en Nano Gateway/Meta Cloud
con ID de mensaje devuelto por Meta. Para WebView, mantener el bloqueo hasta
verificar destinatario, preview y acción de envío sin riesgo de duplicados.

### P1 — Historial para el modelo

Extraer de forma estructurada únicamente mensajes autorizados y recientes del
chat abierto, persistirlos con deduplicación y construir un resumen acotado. La
vista completa de WhatsApp Web no debe copiarse entera al prompt.

### P1 — Rendimiento medido

Instrumentar TTFT, tokens por segundo, edad de cola, profundidad, turnos
superseded, memoria, temperatura y retraso Web. La cifra sostenible de chats
solo puede publicarse después de una prueba de carga y temperatura en el equipo.

### P2 — Pantalla Meta Cloud

Agregar diagnóstico de webhook, número/WABA conectado, permisos disponibles,
estado de envío multimedia y prueba de extremo a extremo con un destinatario de
prueba. Mantener mensajes de error sin secretos.

## Capacidad real hoy

Nano puede vigilar decenas de conversaciones y el equipo auditado mostró 33
chats Web sincronizados. El runtime local usa una sesión de inferencia y atiende
turnos de forma serializada; por tanto, “33 chats observados” no significa “33
respuestas generadas simultáneamente”. El límite sostenible depende de la tasa
de mensajes, longitud de respuesta, modelo, temperatura y velocidad del equipo.

