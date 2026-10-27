# Búho AI: capacidades conectadas y límites

Revisión de código del 26 de octubre de 2026. Sin pruebas automatizadas,
sin recorridos de dispositivo y sin enviar mensajes durante esta implementación.
Las rutas implementadas no acreditan una ejecución manual satisfactoria.

## Flujo conectado

Editor o dictado → herramienta elegida → admisión única → adaptador →
coordinador existente → permisos/identidad → WhatsApp instalado → resultado tipado.
El modelo responde consultas; no acredita por sí mismo la ejecución de acciones.

| Capacidad | Estado en código | Límite real |
| --- | --- | --- |
| Conversación | Usa el modelo/destino seleccionado en Nano | Requiere motor listo y libre; sin sustitución silenciosa de modelo. |
| Dictado | Micrófono real Android en Flutter y overlay | Prepara texto; conserva el borrador y nunca autoenvía. Depende del motor/permisos Android; no se garantiza voz offline. |
| Leer respuesta | TTS Android bajo demanda | Aceptar la lectura no acredita fin del audio; se solicita detener al cerrar. |
| Número y nombre guardado | Reutiliza resolución existente | Número válido; nombre exacto y único, permiso de agenda cuando corresponda. |
| @usuario | Ruta existente por enlace/perfil | Autoenvío condicionado a verificar identidad exacta; no búsqueda universal garantizada. |
| Texto con enlace | Sigue ruta WhatsApp | Ya no se desvía a descarga por contener URL; Media requiere selección explícita. |
| Cámara/fotos/archivos | Selector existente conectado a ambos paneles | Solo prepara un archivo; requiere Activity/permisos y acceso al proveedor Android. Cancelar conserva el anterior. |
| Foto/vídeo/PDF existente | Orden de adjunto al ejecutor existente | No transforma un adjunto en comprensión visual; si falta identidad verificable, no promete autoenvío. |
| Producto | Genera PDF del producto real por nombre exacto | Duplicados/ausencia piden aclaración; no inventa stock ni precio. |
| Catálogo | Genera PDF con los productos guardados | Un catálogo vacío falla de forma explícita. |
| PDF por nombre | Busca en biblioteca del negocio configurado | Nombre exacto y único; no busca indiscriminadamente otras bibliotecas/carpetas. |
| Leer pantalla | Ventana de aplicación no-Nano, texto accesible | No es OCR de una imagen ni visión multimodal. Contexto limitado a la consulta solicitada. |
| Retorno a Nano | Mantiene controlador de retorno existente | No observado de nuevo durante esta revisión; abrir no equivale a enviar. |
| Objetivos de varios pasos | Conectados a AutomationEngine.runGoal | Solo vocabulario, perceptores y flujos ya soportados; no cobertura universal. |
| Resultado visible | Recibo por turno y sesión temporal del servicio | Ocupado, aclaración, cancelado y no verificable no se convierten en entrega. |
| Ventana flotante de WhatsApp | Sin ampliar soporte del fabricante | La estrategia OPPO existente usa pantalla completa. El búho sigue como overlay autorizado. |

## Uso manual desde el búho

1. Selecciona WhatsApp; escribe o dicta. Revisa el borrador antes de pulsar ejecutar.
2. Para adjuntos usa + → Cámara, Fotos o Archivos. Luego escribe
   `Envía el adjunto a Emm` con un destinatario real y no ambiguo.
3. Artefactos del negocio usan estas órdenes delimitadas:
   - `Comparte el producto "Nombre exacto" con "Destinatario"`
   - `Comparte el catálogo PDF con "Destinatario"`
   - `Comparte el PDF "archivo.pdf" con "Destinatario"`
4. Para compartir otro producto/PDF, quita primero el adjunto preparado.
5. El micrófono dicta; leer respuesta habla. Son acciones separadas y explícitas.
6. Ante un resultado incierto, revisa WhatsApp y el historial antes de repetir.

## Pendiente de comprobar manualmente

- Apertura y retorno por número/nombre/usuario en la versión instalada de WhatsApp.
- Identidad ambigua, permiso denegado, desconexión de accesibilidad y resultado incierto.
- Foto, vídeo y PDF; seleccionar desde el overlay cuando Nano está en segundo plano.
- Voz con permiso denegado, cancelación, cierre del panel y reconocimiento disponible.
- Horizontal, teclado, escala de letra y animación restaurada.

No se implementó un agente que vea cualquier imagen, decida y responda autónomamente
cualquier chat. Tampoco control universal de formularios de otras apps. Las órdenes
deterministas y las consultas al modelo conservan responsabilidades separadas.

## Ciclo de vida y C++

El proveedor conserva el requestId y la conexión de su generación; solicita cancelar
al router antes de cerrar su conexión. Usa el límite de inactividad del runtime real.
Los demonios existentes tienen recolección de procesos. No se modificó C++ por intuición.
En MNN la cancelación cooperativa puede esperar al prefill síncrono; no se garantiza
cancelación instantánea ni reducción térmica sin mediciones.

La animación restaurada mantiene reposo de 3200 ms, vuelo de 560 ms y sueño reversible
de 2000 ms, con pintura directa de sprites. Esta implementación conecta callbacks y
estado del editor; no rediseña esos movimientos.

Actualización: la conexión de objetivos y confirmación exacta está documentada
en `OBJETIVOS_CONECTADOS.md`; su APK quedó instalado sin pruebas de dispositivo.

Actualización de respuesta dentro del chat, formularios y ventana: ver
`WHATSAPP_DENTRO_FORMULARIOS_VENTANA.md` y `WHATSAPP_REAL_VERIFICACION.json`.
La versión está instalada; la ejecución de esos recorridos sigue pendiente de revisión manual.
