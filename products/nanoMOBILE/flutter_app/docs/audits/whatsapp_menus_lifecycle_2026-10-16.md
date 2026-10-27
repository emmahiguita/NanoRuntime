# WhatsApp: menús y ciclo de vida

Correcciones del 16 de octubre de 2026. Sin tests automatizados por solicitud del usuario.

## Implementado

- Menú Material desplazable, limitado por ventana y con objetivos táctiles normales.
- Acciones frecuentes visibles; transferencia y limpieza agrupadas en opciones avanzadas.
- Respeta glassEnabled y reduce el blur del menú a un máximo de 12.
- Evita abrir otra instancia del menú del mismo chat; libera la clave en finally.
- Confirmaciones usan el contexto de su ruta, no el Navigator de la pantalla previa.
- Diálogos ajustados al contenido; los botones pasan a varias filas si no caben.
- Menú, detalle y diálogo respetan la preferencia del sistema de reducir animaciones.
- Activación común: cargar regla WhatsApp, habilitarla y persistirla antes de Bot.
- Limpiar pausa explícitamente e invalida turnos antes de eliminar el contexto.
- Transferir agente invalida borradores pendientes del agente anterior.
- Controlador no refresca providers después de su dispose.
- Compartir varios archivos deja de iniciar el siguiente al cerrar el chat.
- El envío registra una aceptación usando servicios capturados; no consulta Ref destruido.
- Retirado el cierre automático diferido tras aprobar un envío.
- Borradores tienen cancelación por solicitud al cerrar la hoja o pasar a control humano.
- ExecutionBudget enlaza cancelación padre/hijo y libera cada registro al terminar.
- Cliente HTTP registra cancelación por requestId; LiteRT/MNN conservan su cancelación propia.
- Se conserva el glass de la superficie del chat, sin otro filtro por cada burbuja.
- Web no espera al archivo Android; el error local se muestra como carga parcial.
- Dependencias de la carga local se capturan antes de esperar fuentes asíncronas.

## Validación

- Análisis estático de once unidades principales: sin incidencias.
- fullSideloadProfile compilado correctamente (128.9 MB).
- Instalación con conservación de datos: Success en VGL7MVFMDYQG8T55.
- Apertura confirmada por Android: Status ok, WARM, TotalTime 658 ms, PID 19877.
  Esto no mide el tiempo de carga del panel ni los fotogramas de las animaciones.
- Actualización observada en el teléfono: 2026-10-16 06:01:45.
- Componentes del menú, diálogo y detalle modificados: menos de 200 líneas cada uno.
- Grafo actualizado; ambas skills validadas correctamente.
- Skills de mensajería actualizadas con los fallos concretos y su prevención.

## Límites de la verificación

Se repararon rutas comprobables por código; no se afirma ausencia total de
procesos zombis, fugas o lags en todas las situaciones. El cierre de sockets,
cancelación nativa, animaciones y carga bajo uso real requieren revisión manual.
No se hicieron envíos de prueba ni se borraron conversaciones del teléfono.
